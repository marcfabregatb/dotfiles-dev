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

# -- Atuin binary dir (its installer no longer writes ~/.atuin/bin/env, so add it here) --
[[ -d "$HOME/.atuin/bin" ]] && export PATH="$HOME/.atuin/bin:$PATH"

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

# -- Completion (before tools, so zoxide can register its completions) --
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select

# -- Tools --
# fzf (Ctrl+T for files, Alt+C for cd, ** for completion)
if command -v fzf &> /dev/null; then
    # fzf >= 0.48 (any install method, incl. Homebrew) prints its own setup;
    # older Debian/Ubuntu packages ship it as example files instead
    if fzf_init=$(fzf --zsh 2>/dev/null); then
        eval "$fzf_init"
    else
        [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
        [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    fi
    unset fzf_init
fi

# Atuin (visual history search: Up arrow to browse, Ctrl+R to search)
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

# Zoxide (smart cd: 'cd' jumps to frequent directories, 'cdi' to pick interactively)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh --cmd cd)"
fi

# Navi (interactive cheatsheets: Ctrl+G to search and insert a command)
if command -v navi &> /dev/null; then
    export NAVI_PATH="$DOTFILES_DIR/cheats:$HOME/.local/share/navi/cheats"
    eval "$(navi widget zsh)"
fi

# Oh My Posh prompt
if command -v oh-my-posh &> /dev/null; then
    eval "$(oh-my-posh init zsh --config "$DOTFILES_DIR/theme.omp.json")"
fi

# -- Plugins (after tools, so they see every widget) --
# Autosuggestions (fish-like ghost text, accept with Right Arrow)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
[[ -f "$DOTFILES_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "$DOTFILES_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Syntax Highlighting (colors commands as you type; must stay last in this file)
[[ -f "$DOTFILES_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
    source "$DOTFILES_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
