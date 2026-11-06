# zsh config for the devbox shell. Loaded because devbox sets ZDOTDIR to this folder.
# Oh My Zsh and the plugins come from Nix (see devbox_2.json), pinned by devbox.lock.
# HOME is the isolated $DEVBOX_PROJECT_ROOT/.devbox/home, so all state below stays there.

SHARE="$DEVBOX_PACKAGES_DIR/share"         # read-only Nix packages

export ZSH="$SHARE/oh-my-zsh"
ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
zstyle ':omz:update' mode disabled         # Nix store is read-only; update via devbox instead
# zsh-autocomplete records recent dirs here on every cd; create it since HOME starts empty.
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/zsh"

ZSH_THEME="robbyrussell"
plugins=(git)

# zsh-autocomplete must load before Oh My Zsh.
source "$SHARE/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
source "$ZSH/oh-my-zsh.sh"

# Custom symbols/colours on top of robbyrussell. %2{..%} tells zsh an emoji is 2 columns wide.
PROMPT='%(?:%2{🚀%}:%2{💥%}) %B%F{213}%c%f%b $(git_prompt_info)'
ZSH_THEME_GIT_PROMPT_PREFIX="%F{117}%2{🌿%} %F{220}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f "
ZSH_THEME_GIT_PROMPT_DIRTY=" %F{203}%2{🔥%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %F{120}%2{✨%}"
source "$SHARE/zsh-autosuggestions/zsh-autosuggestions.zsh"
# zsh-syntax-highlighting must be sourced last.
source "$SHARE/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Oh My Zsh rebinds the arrow keys; give them back to zsh-autocomplete.
bindkey '^[[B' down-line-or-select '^[OB' down-line-or-select
bindkey '^[[A' up-line-or-search   '^[OA' up-line-or-search
