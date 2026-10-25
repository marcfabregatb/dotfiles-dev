# -- Environment --
export DOTFILES_DIR="${${(%):-%x}:A:h}"
export PATH="$HOME/.local/bin:$PATH"
export COLORTERM=truecolor

# Homebrew
if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# -- Atuin env (adds ~/.atuin/bin to PATH) --
[[ -f "$HOME/.atuin/bin/env" ]] && source "$HOME/.atuin/bin/env"

# -- Plugins --
# Autosuggestions (fish-like ghost text, accept with Right Arrow)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
[[ -f "$DOTFILES_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "$DOTFILES_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Syntax Highlighting (colors commands as you type; must load last among plugins)
[[ -f "$DOTFILES_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
    source "$DOTFILES_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# -- Tools --
# fzf (Ctrl+T for files, Alt+C for cd, ** for completion)
if command -v fzf &> /dev/null; then
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
fi

# Atuin (visual history search: Up arrow to browse, Ctrl+R to search)
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

# Zoxide (smart cd: use 'z' to jump to frequent directories)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
    alias cd="z"
fi

# Navi (interactive cheatsheets: Ctrl+G to search and insert a command)
if command -v navi &> /dev/null; then
    eval "$(navi widget zsh)"
fi

# Oh My Posh prompt
if command -v oh-my-posh &> /dev/null; then
    eval "$(oh-my-posh init zsh --config "$DOTFILES_DIR/theme.omp.json")"
fi

# -- Completion --
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select

# -- History --
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
