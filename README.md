# dotfiles-dev

Personal dotfiles for my development environment on **Debian/Ubuntu**, including VS Code DevContainers.

## What's included

**Shell (Zsh):**
- **Oh My Posh** prompt with environment-aware colors (purple for dev containers, orange for codespaces)
- **zsh-autosuggestions** - fish-like history suggestions (Right Arrow to accept)
- **zsh-syntax-highlighting** - colors commands as you type

**Tools:**
- **Atuin** - visual history search (Up arrow to browse, Ctrl+R to search)
- **fzf** - fuzzy finder (Ctrl+T for files, Alt+C for cd, `**` completion)
- **tmux** - terminal multiplexer with mouse support and 256-color
- **Zoxide** - smart `cd` replacement (`z` to jump to frequent directories)
- **lazydocker** - terminal UI for Docker (optional)
- **lazygit** - terminal UI for Git (optional)
- **navi** - interactive cheatsheets (Ctrl+G to search and insert a command) (optional)

**Editor:**
- Minimal Vim config with search highlighting, smart indent, and system clipboard

## Install

One-liner:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/marcfabregatb/dotfiles-dev/main/install.sh)
```

Or manually:

```bash
git clone https://github.com/marcfabregatb/dotfiles-dev.git ~/dotfiles-dev
cd ~/dotfiles-dev && ./install.sh
```

### VS Code DevContainers

Add to your VS Code **settings.json**:

```json
"dotfiles.repository": "https://github.com/marcfabregatb/dotfiles-dev.git",
"dotfiles.targetPath": "~/dotfiles-dev",
"dotfiles.installCommand": "bash ./install.sh"
```

## Nerd Fonts

For prompt icons, install a [Nerd Font](https://www.nerdfonts.com/) on your host:

```bash
oh-my-posh font install CaskaydiaCove
```

Then in VS Code settings:

```json
"terminal.integrated.fontFamily": "'CaskaydiaCove Nerd Font'"
```

## Files

| File | Purpose |
|---|---|
| `install.sh` | Idempotent installer (only installs what's missing) |
| `.zshrc` | Zsh config: plugins, tools, completion, history |
| `.vimrc` | Vim settings |
| `theme.omp.json` | Oh My Posh prompt theme |
