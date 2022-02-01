#!/bin/sh
fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\\n$fmt\\n" "$@"
}

apple_m1() {
  sysctl -n machdep.cpu.brand_string | grep "Apple M1"
}

rosetta() {
  uname -m | grep "x86_64"
}

homebrew_installed_on_m1() {
  apple_m1 && ! rosetta && [ -d "/opt/homebrew" ]
}

homebrew_installed_on_intel() {
  ! apple_m1 && command -v brew >/dev/null
}

install_or_update_homebrew() {
  if homebrew_installed_on_m1 || homebrew_installed_on_intel; then
    update_homebrew
  else
    install_homebrew
  fi
}

create_zshrc_and_set_it_as_shell_file() {
  if [ ! -f "$HOME/.zshrc" ]; then
    touch "$HOME/.zshrc"
  fi

  shell_file="$HOME/.zshrc"
}

create_bash_profile_and_set_it_as_shell_file() {
  if [ ! -f "$HOME/.bash_profile" ]; then
    touch "$HOME/.bash_profile"
  fi

  shell_file="$HOME/.bash_profile"
}

# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e -o pipefail

case "$SHELL" in
  */zsh) :
    create_zshrc_and_set_it_as_shell_file
    ;;
  */bash)
    create_bash_profile_and_set_it_as_shell_file
    ;;
esac

install_homebrew() {
  fancy_echo "Installing Homebrew ..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

update_homebrew() {
  fancy_echo "Homebrew already installed. Updating Homebrew ..."
  brew update
}

set -e

fancy_echo 'Welcome to the bootstrap process!'
fancy_echo 'You should be and up and running with a new environment in a few minutes.'

install_or_update_homebrew

fancy_echo "Verifying the Homebrew installation..."
if brew doctor; then
  fancy_echo "Your Homebrew installation is good to go."
else
  fancy_echo "Your Homebrew installation reported some errors or warnings."
  echo "Review the Homebrew messages to see if any action is needed."
fi

fancy_echo "Installing chezmoi and applying dotfiles ..."
brew bundle --file=- <<EOF
    brew 'chezmoi'
EOF
if [ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
  chezmoi init --apply https://github.com/failbit/dotfiles.git
  chmod 0600 "$HOME/.config/chezmoi/chezmoi.toml"
fi

if [ -f "$HOME/Brewfile.local" ]; then
  fancy_echo "Installing tools and apps from Brewfile.local ..."
  if brew bundle --file="$HOME/Brewfile.local"; then
    fancy_echo "All items in Brewfile.local were installed successfully."
  else
    fancy_echo "Some items in Brewfile.local were not installed successfully."
  fi
fi

if command -v vim >/dev/null 2>&1; then
    cd "$HOME"
    fancy_echo "Bootstraping Vim"
    vim '+PlugUpdate' '+PlugClean!' '+PlugUpdate' '+qall'
fi

if [ ! -f "$HOME/.zsh/completion.zsh" ]; then
    cd ~/.zsh && wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/lib/key-bindings.zsh
    cd ~/.zsh && wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/lib/completion.zsh
fi

yes | /opt/homebrew/opt/fzf/install
/opt/homebrew/bin/broot --install

fancy_echo "All done."
