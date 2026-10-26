#!/bin/bash

REPO_URL="https://github.com/marcfabregatb/dotfiles-dev.git"
TARGET_DIR="$HOME/dotfiles-dev"

# Run privileged commands directly when already root (e.g. devcontainers without sudo)
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

# Bootstrap: if run via curl|bash, clone the repo first
if [ -z "${BASH_SOURCE[0]}" ] || [ "${BASH_SOURCE[0]}" = "bash" ] || [[ "${BASH_SOURCE[0]}" == /dev/* ]] || [[ "${BASH_SOURCE[0]}" == /proc/* ]]; then
    echo "Cloning dotfiles-dev..."
    command -v git &> /dev/null || { $SUDO apt-get update && $SUDO apt-get install -y git; }
    git clone "$REPO_URL" "$TARGET_DIR" 2>/dev/null || git -C "$TARGET_DIR" pull
    exec bash "$TARGET_DIR/install.sh"
fi

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "Starting dotfiles-dev installation..."

# -- Make previously installed tools visible (this runs in bash, not zsh) --
load_brew_env() {
    if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
}

export PATH="$HOME/.local/bin:$HOME/.atuin/bin:$PATH"
load_brew_env

# -- Clean up stale plugins from previous installs --
ACTIVE_PLUGINS=("zsh-autosuggestions" "zsh-syntax-highlighting")

if [ -d "$DOTFILES_DIR/plugins" ]; then
    for dir in "$DOTFILES_DIR/plugins"/*/; do
        [ ! -d "$dir" ] && continue
        plugin_name=$(basename "$dir")
        found=false
        for active in "${ACTIVE_PLUGINS[@]}"; do
            [ "$plugin_name" = "$active" ] && found=true
        done
        if [ "$found" = false ]; then
            echo "Removing old plugin: $plugin_name"
            rm -rf "$dir"
        fi
    done
fi

rm -f "$HOME"/.zcompdump*
mkdir -p "$DOTFILES_DIR/plugins"

# -- Install apt packages (only missing ones) --
apt_packages=(vim zsh curl git fzf unzip tmux rsync)
missing=()
for pkg in "${apt_packages[@]}"; do
    command -v "$pkg" &> /dev/null || missing+=("$pkg")
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "Installing missing packages: ${missing[*]}..."
    $SUDO apt-get update && $SUDO apt-get install -y "${missing[@]}"
fi

# -- Symlink config files (before tool installs so ~/.zshrc exists) --
echo "Creating symlinks..."
ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
ln -sf "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"

# -- Clone zsh plugins --
install_plugin() {
    local name=$1 url=$2
    local target="$DOTFILES_DIR/plugins/$name"
    if [ ! -d "$target" ] || [ -z "$(ls -A "$target" 2>/dev/null)" ]; then
        rm -rf "$target"
        echo "Downloading $name..."
        git clone --depth 1 "$url" "$target"
    fi
}

install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"

# -- Install Oh My Posh (direct binary, no Homebrew needed) --
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh..."
    curl -s https://ohmyposh.dev/install.sh | $SUDO bash -s -- -d /usr/local/bin
    oh-my-posh font install CaskaydiaCove
fi

# -- Install Zoxide (official installer; apt's version is too old for --cmd cd) --
if ! zoxide init zsh --cmd cd 2>/dev/null | grep -q __zoxide_cd; then
    echo "Installing Zoxide..."
    if command -v brew &> /dev/null; then
        brew install zoxide
    else
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi
fi

# -- Install Atuin (visual shell history with Up arrow navigation) --
if ! command -v atuin &> /dev/null; then
    echo "Installing Atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
    [ -f "$HOME/.atuin/bin/env" ] && source "$HOME/.atuin/bin/env"
fi

# -- Optional tools (interactive prompt) --
ask_install() {
    local name=$1
    # Skip prompt if already installed
    command -v "$name" &> /dev/null && return 1
    # Skip prompts in non-interactive mode (e.g. piped scripts in CI)
    [[ ! -t 0 ]] && return 1
    read -rp "Install $name? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

if ask_install "brew"; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Configure brew PATH for current session if it was just installed
load_brew_env

if ask_install "lazydocker"; then
    echo "Installing lazydocker..."
    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
fi

if ask_install "lazygit"; then
    echo "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    $SUDO tar xf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit
    rm -f /tmp/lazygit.tar.gz
fi

if ask_install "gh"; then
    echo "Installing GitHub CLI..."
    if command -v brew &> /dev/null; then
        brew install gh
    else
        $SUDO mkdir -p -m 755 /etc/apt/keyrings
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        $SUDO apt-get update && $SUDO apt-get install -y gh
    fi
fi

if ask_install "navi"; then
    echo "Installing navi..."
    if command -v brew &> /dev/null; then
        brew install navi
    else
        BIN_DIR="$HOME/.local/bin" bash <(curl -sL https://raw.githubusercontent.com/denisidoro/navi/master/scripts/install)
    fi
fi

# -- Set zsh as default shell --
if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo "Setting zsh as default shell..."
    $SUDO chsh -s "$(which zsh)" "$(whoami)"
fi

echo "Done! Restart your terminal or run: source ~/.zshrc"
