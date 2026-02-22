#!/bin/bash

REPO_URL="https://github.com/marcfabregatb/dotfiles.git"
TARGET_DIR="$HOME/dotfiles"

# Bootstrap: if run via curl|bash, clone the repo first
if [ -z "${BASH_SOURCE[0]}" ] || [ "${BASH_SOURCE[0]}" = "bash" ] || [[ "${BASH_SOURCE[0]}" == /dev/* ]]; then
    echo "Cloning dotfiles..."
    command -v git &> /dev/null || { sudo apt-get update && sudo apt-get install -y git; }
    git clone "$REPO_URL" "$TARGET_DIR" 2>/dev/null || git -C "$TARGET_DIR" pull
    exec bash "$TARGET_DIR/install.sh"
fi

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "Starting dotfiles installation..."

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
apt_packages=(vim zoxide zsh curl git fzf unzip tmux)
missing=()
for pkg in "${apt_packages[@]}"; do
    command -v "$pkg" &> /dev/null || missing+=("$pkg")
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "Installing missing packages: ${missing[*]}..."
    sudo apt-get update && sudo apt-get install -y "${missing[@]}"
fi

# -- Symlink config files (before tool installs so ~/.zshrc exists) --
echo "Creating symlinks..."
ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"

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
    curl -s https://ohmyposh.dev/install.sh | sudo bash -s
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
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

if ask_install "claude"; then
    echo "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
fi

if ask_install "gemini"; then
    echo "Installing Gemini CLI..."
    if command -v npm &> /dev/null; then
        npm install -g @google/gemini-cli
    else
        echo "  Skipped: npm is required. Install Node.js first, then run: npm install -g @google/gemini-cli"
    fi
fi

# -- Set zsh as default shell --
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Setting zsh as default shell..."
    sudo chsh -s "$(which zsh)" "$(whoami)"
fi

echo "Done! Restart your terminal or run: source ~/.zshrc"
