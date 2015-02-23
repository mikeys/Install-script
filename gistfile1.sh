#!/bin/sh

# Welcome to the thoughtbot laptop script!
# Be prepared to turn your laptop (or desktop, no haters here)
# into an awesome development machine.

fancy_echo() {
  # Set local variable fmt to a string containing the first argument
  local fmt="$1"

  # shift = used when an unknown number of arguments is passed to a function
  # Initially use shift to remove the first argument from $1 and set it to second argument
  # Use shift again to remove the 2nd argument from $1 and set it to the 3rd argument
  # etc'
  shift

  # printf - Just like the C implementation:
  # First argument is the formatting
  # All arguments afterward specify the formatted data
  # $@ = All arguments as different strings
  # $* = All arguments as one concatenated string (space as delimiter)
  printf "\n$fmt\n" "$@"
}

append_to_zshrc() {
  # define two variables, define var "text" to the first func argument
  # define var "zshrc" without assigning it any value.
  local text="$1" zshrc

  # ${var:-value} - if $var is set to any value except the empty string, use it;
  # otherwise, use value instead'.
  # ${var-value} - if $var is set to any value (including an empty string), use it;
  # otherwise, use value instead.
  # In this context, the first variation applies: if the 2nd argument ($2) is
  # set to any value except an empty string, then use it.
  local skip_new_line="${2:-0}"

  # The -w option is used to test if a FILE exists and write permission is granted
  # or not. It returns true if a file is writable.
  if [ -w "$HOME/.zshrc.local" ]; then
    zshrc="$HOME/.zshrc.local"
  else
    zshrc="$HOME/.zshrc"
  fi

  # grep: search for text or a regular expression in files, directories, etc'
  # -q option: quiet, do not write anything to standard output, exit immediately
  # with zero status if any match is found.
  # -s option: Suppress error messages about nonexistent or unreadable files.
  # -F option: Interpret PATTERN as a list of fixed strings, separated by new-
  # lines, any of which is to be matched.
  if ! grep -Fqs "$text" "$zshrc"; then
    # Check for a condition.
    # Condition is essentially a command. Surrounding a comparison with square brackets
    # is the same as using the test command.
    # Therefore in our context the below statement could've been written like:
    # if test "$skip_new_line" -eq 1; then
    # more info @ https://linuxacademy.com/blog/linux/conditions-in-bash-scripting-if-statements/
    if [ "$skip_new_line" -eq 1 ]; then
      printf "%s\n" "$text" >> "$zshrc"
    else
      printf "\n%s\n" "$text" >> "$zshrc"
    fi
  fi
}

trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e

# Create directory if directory does not exist
if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

# Create file if file does not exist
if [ ! -f "$HOME/.zshrc" ]; then
  touch "$HOME/.zshrc"
fi

append_to_zshrc 'export PATH="$HOME/.bin:$PATH"'

case "$SHELL" in
  */zsh) : ;;
  *)
    fancy_echo "Changing your shell to zsh ..."
      chsh -s "$(which zsh)"
    ;;
esac

brew_install_or_upgrade() {
  if brew_is_installed "$1"; then
    if brew_is_upgradable "$1"; then
      fancy_echo "Upgrading %s ..." "$1"
      brew upgrade "$@"
    else
      fancy_echo "Already using the latest version of %s. Skipping ..." "$1"
    fi
  else
    fancy_echo "Installing %s ..." "$1"
    brew install "$@"
  fi
}

brew_is_installed() {
  local name="$(brew_expand_alias "$1")"

  brew list -1 | grep -Fqx "$name"
}

brew_is_upgradable() {
  local name="$(brew_expand_alias "$1")"

  ! brew outdated --quiet "$name" >/dev/null
}

brew_tap() {
  brew tap "$1" 2> /dev/null
}

brew_expand_alias() {
  # 2>/dev/null
  # The > operator redirects the output usually to a file but it can be to a device. You can also use >> to append.
  # If you don't specify a number then the standard output stream is assumed but you can also redirect errors
  # > file redirects stdout to file
  # 1> file redirects stdout to file
  # 2> file redirects stderr to file
  # &> file redirects stdout and stderr to file
  # /dev/null is the null device it takes any input you want and throws it away. It can be used to suppress any output.
  # head: strip first X lines
  # awk: The Awk is mostly used for pattern scanning and processing. 
  # It searches one or more files to see if they contain lines that matches with the specified patterns
  # and then perform associated actions.
  # in our context, there's no pattern so the 'gsubbing' and 'printing' is done for 'every' line (in our
  # case, since we're using head -1, it only performs it on one line).
  # more info @ http://www.thegeekstuff.com/2010/01/awk-introduction-tutorial-7-awk-print-examples/
  brew info "$1" 2>/dev/null | head -1 | awk '{gsub(/:/, ""); print $1}'
}

brew_launchctl_restart() {
  local name="$(brew_expand_alias "$1")"
  local domain="homebrew.mxcl.$name"
  local plist="$domain.plist"

  fancy_echo "Restarting %s ..." "$1"
  mkdir -p "$HOME/Library/LaunchAgents"
  ln -sfv "/usr/local/opt/$name/$plist" "$HOME/Library/LaunchAgents"

  if launchctl list | grep -Fq "$domain"; then
    launchctl unload "$HOME/Library/LaunchAgents/$plist" >/dev/null
  fi
  launchctl load "$HOME/Library/LaunchAgents/$plist" >/dev/null
}

gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    fancy_echo "Updating %s ..." "$1"
    gem update "$@"
  else
    fancy_echo "Installing %s ..." "$1"
    gem install "$@"
    rbenv rehash
  fi
}

# command - execute a shell command with the specified args, ignoring aliases
# and functions.
# e.g. if we created an alias: alias ls="ls -G" and we want to execute the original
# ls, we would use 'command ls'
# -v option: a string is printed describing COMMAND. The -V option produces a more
# verbose description:
if ! command -v brew >/dev/null; then
  fancy_echo "Installing Homebrew ..."
  curl -fsS \
    'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby

  append_to_zshrc '# recommended by brew doctor'

  # shellcheck disable=SC2016
  append_to_zshrc 'export PATH="/usr/local/bin:$PATH"' 1

  export PATH="/usr/local/bin:$PATH"
else
  fancy_echo "Homebrew already installed. Skipping ..."
fi

fancy_echo "Updating Homebrew formulas ..."
brew update

brew_install_or_upgrade 'git'
brew_install_or_upgrade 'postgres'
brew_launchctl_restart 'postgresql'
brew_install_or_upgrade 'redis'
brew_launchctl_restart 'redis'
brew_install_or_upgrade 'the_silver_searcher'
brew_install_or_upgrade 'vim'
brew_install_or_upgrade 'ctags'
brew_install_or_upgrade 'tmux'
brew_install_or_upgrade 'reattach-to-user-namespace'
brew_install_or_upgrade 'imagemagick'
brew_install_or_upgrade 'qt'
brew_install_or_upgrade 'hub'
brew_install_or_upgrade 'node'

brew_install_or_upgrade 'rbenv'
brew_install_or_upgrade 'ruby-build'

# shellcheck disable=SC2016
append_to_zshrc 'eval "$(rbenv init - zsh --no-rehash)"' 1

brew_install_or_upgrade 'openssl'
brew unlink openssl && brew link openssl --force
brew_install_or_upgrade 'libyaml'

ruby_version="$(curl -sSL http://ruby.thoughtbot.com/latest)"

eval "$(rbenv init - zsh)"

if ! rbenv versions | grep -Fq "$ruby_version"; then
  rbenv install -s "$ruby_version"
fi

rbenv global "$ruby_version"
rbenv shell "$ruby_version"

gem update --system

gem_install_or_update 'bundler'

fancy_echo "Configuring Bundler ..."
  number_of_cores=$(sysctl -n hw.ncpu)
  bundle config --global jobs $((number_of_cores - 1))

brew_install_or_upgrade 'heroku-toolbelt'

if ! command -v rcup >/dev/null; then
  brew_tap 'thoughtbot/formulae'
  brew_install_or_upgrade 'rcm'
fi

if [ -f "$HOME/.laptop.local" ]; then
  . "$HOME/.laptop.local"
fi
