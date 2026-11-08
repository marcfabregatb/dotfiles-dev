#!/bin/bash
# A pipeline fails if any part fails, so "curl ... | bash" notices a failed download
set -o pipefail

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

# Steps that failed; reported at the end instead of aborting the whole install
failed=()

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
apt_packages=(vim nano zsh curl git fzf unzip tmux rsync bat)
missing=()
for pkg in "${apt_packages[@]}"; do
    command -v "$pkg" &> /dev/null && continue
    # Debian/Ubuntu install bat's command as batcat
    [ "$pkg" = "bat" ] && command -v batcat &> /dev/null && continue
    missing+=("$pkg")
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "Installing missing packages: ${missing[*]}..."
    { $SUDO apt-get update && $SUDO apt-get install -y "${missing[@]}"; } || failed+=("apt packages (${missing[*]})")
fi

# -- Symlink config files (before tool installs so ~/.zshrc exists) --
# A real file already in place is kept as <file>.bak.<timestamp> instead of being overwritten
link_file() {
    local src=$1 dest=$2
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        local backup
        backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
        echo "Backing up existing $dest to $backup"
        mv "$dest" "$backup"
    fi
    ln -sf "$src" "$dest"
}

echo "Creating symlinks..."
link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
link_file "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
link_file "$DOTFILES_DIR/.nanorc" "$HOME/.nanorc"
mkdir -p "$HOME/.nano"
for syntax in "$DOTFILES_DIR"/nano/*.nanorc; do
    link_file "$syntax" "$HOME/.nano/$(basename "$syntax")"
done

# -- Clone zsh plugins --
install_plugin() {
    local name=$1 url=$2
    local target="$DOTFILES_DIR/plugins/$name"
    if [ ! -d "$target" ] || [ -z "$(ls -A "$target" 2>/dev/null)" ]; then
        rm -rf "$target"
        echo "Downloading $name..."
        git clone --depth 1 "$url" "$target" || failed+=("$name")
    fi
}

install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"

# -- Install Oh My Posh (direct binary, no Homebrew needed) --
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing Oh My Posh..."
    if curl -fsSL https://ohmyposh.dev/install.sh | $SUDO bash -s -- -d /usr/local/bin; then
        # Nerd Fonts name for Cascadia Code; it installs as "CaskaydiaCove Nerd Font"
        oh-my-posh font install CascadiaCode || failed+=("CascadiaCode Nerd Font")
    else
        failed+=("oh-my-posh")
    fi
fi

# -- Install Zoxide (official installer; apt's version is too old for --cmd cd) --
# Captured first rather than piped into grep -q, which can cut zoxide off and fail under pipefail
if ! grep -q __zoxide_cd <<< "$(zoxide init zsh --cmd cd 2>/dev/null)"; then
    echo "Installing Zoxide..."
    if command -v brew &> /dev/null; then
        brew install zoxide || failed+=("zoxide")
    else
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh || failed+=("zoxide")
    fi
fi

# -- Install Atuin (visual shell history with Up arrow navigation) --
# Its installer appends a hook to ~/.zshrc (a symlink into this repo) unless the file
# already contains `atuin init zsh`, so keep that text in .zshrc. ~/.atuin/bin is on PATH above.
if ! command -v atuin &> /dev/null; then
    echo "Installing Atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh || failed+=("atuin")
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
    # Download first: bash -c "" on a failed download would succeed silently
    if brew_installer=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh); then
        /bin/bash -c "$brew_installer" || failed+=("Homebrew")
    else
        failed+=("Homebrew (download)")
    fi
fi

# Configure brew PATH for current session if it was just installed
load_brew_env

if ask_install "lazydocker"; then
    echo "Installing lazydocker..."
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash || failed+=("lazydocker")
fi

if ask_install "lazygit"; then
    echo "Installing lazygit..."
    case "$(uname -m)" in
        x86_64) LAZYGIT_ARCH="x86_64" ;;
        aarch64|arm64) LAZYGIT_ARCH="arm64" ;;
        *) LAZYGIT_ARCH="" ;;
    esac
    if command -v brew &> /dev/null; then
        brew install lazygit || failed+=("lazygit")
    elif [ -n "$LAZYGIT_ARCH" ]; then
        # Read the version from the releases/latest redirect (.../tag/vX.Y.Z); unlike the
        # GitHub API this has no 60-requests-per-hour limit
        LAZYGIT_TAG_URL=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/jesseduffield/lazygit/releases/latest)
        LAZYGIT_VERSION=${LAZYGIT_TAG_URL##*/v}
        if [[ "$LAZYGIT_VERSION" =~ ^[0-9][0-9.]*$ ]] \
            && curl -fsSLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz" \
            && $SUDO tar xf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit; then
            :
        else
            failed+=("lazygit")
        fi
        rm -f /tmp/lazygit.tar.gz
    else
        echo "Skipping lazygit: unsupported architecture $(uname -m)"
    fi
fi

if ask_install "gh"; then
    echo "Installing GitHub CLI..."
    if command -v brew &> /dev/null; then
        brew install gh || failed+=("gh")
    else
        {
            $SUDO mkdir -p -m 755 /etc/apt/keyrings \
            && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
            && $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
            && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
            && $SUDO apt-get update && $SUDO apt-get install -y gh
        } || failed+=("gh")
    fi
fi

if ask_install "navi"; then
    echo "Installing navi..."
    if command -v brew &> /dev/null; then
        brew install navi || failed+=("navi")
    elif navi_installer=$(curl -fsSL https://raw.githubusercontent.com/denisidoro/navi/master/scripts/install); then
        BIN_DIR="$HOME/.local/bin" bash -c "$navi_installer" || failed+=("navi")
    else
        failed+=("navi (download)")
    fi
fi

# -- Set zsh as default shell --
if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo "Setting zsh as default shell..."
    $SUDO chsh -s "$(command -v zsh)" "$(whoami)" || failed+=("set zsh as default shell")
fi

if [ ${#failed[@]} -gt 0 ]; then
    echo >&2
    echo "Finished with errors. These steps failed:" >&2
    printf '  - %s\n' "${failed[@]}" >&2
    echo "Fix the cause (often network) and re-run ./install.sh; it only retries what is missing." >&2
    exit 1
fi

echo "Done! Restart your terminal or run: source ~/.zshrc"
