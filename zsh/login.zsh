# First-run sign-in for the isolated HOME. Sourced by .zshrc; re-run any time with `devbox-login`.
# Everything is written under $HOME (.config/gh, .gitconfig, .ssh), never the host's Keychain or dotfiles.
# Skip it for a session with DEVBOX_SKIP_LOGIN=1. Undo it with `devbox-logout`.
#
#   devbox-login          sign in, asking https, ssh, or skip
#   devbox-login ssh      switch git to SSH (box-only key, uploaded to GitHub)
#   devbox-login https    switch git to HTTPS (gh token)
#   login-box / logout-box are aliases for devbox-login / devbox-logout.

DEVBOX_SSH_KEY="$HOME/.ssh/id_ed25519"
DEVBOX_LOGIN_SKIPPED="$HOME/.config/devbox/login-skipped"   # set by choosing skip; new shells don't ask again

devbox-login() {
  local proto="$1"
  if [[ -n "$proto" && "$proto" != (https|ssh) ]]; then
    print -u2 "usage: devbox-login [https|ssh]"; return 2
  fi

  # GitHub: token stored in $HOME/.config/gh/hosts.yml (--insecure-storage keeps it out of the shared Keychain).
  # --skip-ssh-key because the SSH key is made and uploaded below, under a known path and title.
  if ! gh auth token --hostname github.com >/dev/null 2>&1; then
    print -P "%F{117}GitHub sign-in for this devbox%f"
    if [[ -z "$proto" ]]; then
      local key
      read -k1 "key?git protocol: [1] https (Enter)  [2] ssh  [3] skip GitHub  "
      print
      case "$key" in
        2|s) proto=ssh ;;
        1|h|$'\n') proto=https ;;
        3) proto=skip ;;
        *) print -u2 "expected 1, 2 or 3"; return 2 ;;
      esac
    fi
    if [[ "$proto" == skip ]]; then
      mkdir -p "${DEVBOX_LOGIN_SKIPPED:h}" && : > "$DEVBOX_LOGIN_SKIPPED"
      print "Skipped GitHub sign-in. Run devbox-login to sign in later."
      _devbox_git_identity
      return 0
    fi
    rm -f "$DEVBOX_LOGIN_SKIPPED"
    local scopes=user:email
    [[ "$proto" == ssh ]] && scopes+=,admin:public_key
    gh auth login --hostname github.com --git-protocol "$proto" --web \
      --insecure-storage --skip-ssh-key --scopes "$scopes" || return 1
    local signed_in_now=1
  fi

  if [[ -n "$proto" ]]; then
    gh config set --host github.com git_protocol "$proto"
  else
    proto="$(gh config get --host github.com git_protocol 2>/dev/null)"
    [[ "$proto" == ssh ]] || proto=https
    # Run by hand while signed in: say so, rather than silently re-applying the config.
    [[ -z "$DEVBOX_LOGIN_AUTO" ]] &&
      print "Signed in to GitHub as $(gh api user --jq .login 2>/dev/null) using $proto." \
            "Switch with devbox-login https|ssh; sign out with devbox-logout."
  fi

  # gh's git credential helper, for https remotes and gh itself. Rewritten every time because
  # `gh auth login`/`setup-git` pin gh's Nix store path, which breaks when gh is upgraded.
  local host
  for host in github.com gist.github.com; do
    git config --global --remove-section "credential.https://$host" 2>/dev/null
    git config --global "credential.https://$host.helper" ''
    git config --global --add "credential.https://$host.helper" '!gh auth git-credential'
  done

  # Send every GitHub remote over the chosen protocol, whichever form it was cloned with.
  git config --global --remove-section url.https://github.com/ 2>/dev/null
  git config --global --remove-section url.git@github.com: 2>/dev/null
  if [[ "$proto" == ssh ]]; then
    _devbox_ssh_setup || return 1
    git config --global url.git@github.com:.insteadOf https://github.com/
  else
    git config --global url.https://github.com/.insteadOf git@github.com:
  fi

  _devbox_git_identity ${signed_in_now:+github}
}

# Commit identity. Asked at shell start only when missing or right after signing in; asked every time devbox-login
# is run by hand so it can be changed. The default is shown in brackets and Enter keeps it: the GitHub account's
# name and primary email right after signing in (pass "github"), otherwise the current value, else GitHub's.
# Plain `read`, not vared: zsh-autocomplete hooks the line editor and can hide a prefilled value.
_devbox_git_identity() {
  local name="$(git config --global user.name)" email="$(git config --global user.email)" gh_name gh_email
  [[ -n "$DEVBOX_LOGIN_AUTO" && "$1" != github && -n "$name" && -n "$email" ]] && return 0
  if [[ "$1" == github || -z "$name" || -z "$email" ]]; then
    gh_name="$(gh api user --jq '.name // .login' 2>/dev/null)"
    gh_email="$(gh api user/emails --jq 'map(select(.primary))[0].email' 2>/dev/null)"
  fi
  if [[ "$1" == github ]]; then
    name="${gh_name:-$name}" email="${gh_email:-$email}"
  else
    name="${name:-$gh_name}" email="${email:-$gh_email}"
  fi
  _devbox_ask_git user.name "$name"
  _devbox_ask_git user.email "$email"
  [[ -n "$(git config --global user.name)" && -n "$(git config --global user.email)" ]] ||
    print -u2 "git name/email incomplete; commits will fail. You'll be asked again in the next shell."
}

# Ask for one git setting and save it right away, so Ctrl-C on a later prompt keeps earlier answers.
_devbox_ask_git() {
  local setting="$1" value="$2" answer
  read -r "answer?git $setting${value:+ [$value]}: "
  [[ -n "$answer" ]] && value="$answer"
  [[ -n "$value" ]] && git config --global "$setting" "$value"
}

# Box-only SSH key, pinned GitHub host keys, and an agent if the key has a passphrase.
_devbox_ssh_setup() {
  local key="$DEVBOX_SSH_KEY" title="devbox:${DEVBOX_PROJECT_ROOT:t}"
  mkdir -p -m 700 "$HOME/.ssh"

  # Pin the host keys GitHub publishes instead of trusting the first connection.
  if ! grep -qs '^github.com ' "$HOME/.ssh/known_hosts"; then
    gh api meta --jq '.ssh_keys[] | "github.com " + .' >> "$HOME/.ssh/known_hosts" || return 1
  fi

  if [[ ! -f "$key" ]]; then
    print "Leave the passphrase empty for none; with one, you type it once per boot."
    ssh-keygen -t ed25519 -C "$title" -f "$key" || return 1
  fi

  # Upload once; the GitHub key id is kept so devbox-logout can remove it.
  if [[ ! -s "$key.github-id" ]]; then
    if ! gh auth status --hostname github.com 2>&1 | grep -q admin:public_key; then
      print "Approve key upload access for gh in the browser:"
      gh auth refresh --hostname github.com --insecure-storage --scopes admin:public_key || return 1
    fi
    local pub="${$(<"$key.pub")% *}"   # GitHub stores the key without its comment
    local id="$(gh api user/keys --jq ".[] | select(.key == \"$pub\") | .id")"
    [[ -n "$id" ]] || id="$(gh api user/keys -f title="$title" -f key="$pub" --jq .id)" || return 1
    print -r -- "$id" > "$key.github-id"
  fi

  _devbox_ssh_agent
}

# One agent per box, shared by its shells, only needed when the key has a passphrase.
_devbox_ssh_agent() {
  local key="$DEVBOX_SSH_KEY"
  [[ -f "$key" ]] || return 0
  ssh-keygen -y -P '' -f "$key" >/dev/null 2>&1 && return 0
  ssh-add -l >/dev/null 2>&1
  if (( $? == 2 )); then   # no agent listening on $SSH_AUTH_SOCK
    rm -f "$SSH_AUTH_SOCK"
    ssh-agent -a "$SSH_AUTH_SOCK" -s | sed -n 's/^SSH_AGENT_PID=\([0-9]*\);.*/\1/p' > "$HOME/.ssh/agent.pid"
  fi
  ssh-add -l >/dev/null 2>&1 || ssh-add "$key"
}

# Remove this box's GitHub key, sign gh out, clear git/ssh state, and leave the shell; ./shell signs in fresh.
devbox-logout() {
  setopt localoptions no_err_return no_err_exit   # every step runs even if an earlier one fails
  local key="$DEVBOX_SSH_KEY"
  if [[ -s "$key.github-id" ]]; then
    local id="$(<"$key.github-id")"
    if gh api -X DELETE "user/keys/$id" >/dev/null 2>&1; then
      print "Removed SSH key from GitHub."
    elif gh api "user/keys/$id" >/dev/null 2>&1; then
      print -u2 "Couldn't remove SSH key $id from GitHub; delete it at https://github.com/settings/keys"
    else
      print "SSH key was already removed from GitHub."   # 404: deleted earlier or by hand
    fi
  fi
  [[ -s "$HOME/.ssh/agent.pid" ]] && kill "$(<"$HOME/.ssh/agent.pid")" 2>/dev/null
  gh auth token --hostname github.com >/dev/null 2>&1 && gh auth logout --hostname github.com
  rm -rf "$HOME/.ssh" "$HOME/.gitconfig" "$DEVBOX_LOGIN_SKIPPED"
  print "Signed out. Run ./shell to sign in again."
  exit
}

# Shorter names that completion finds from "log".
alias login-box=devbox-login logout-box=devbox-logout

# A skip is only honoured once the git name/email are set; until then every shell offers the three options again.
if [[ -o interactive && -z "$DEVBOX_SKIP_LOGIN" ]] &&
   ! [[ -f "$DEVBOX_LOGIN_SKIPPED" && -n "$(git config --global user.name)" && -n "$(git config --global user.email)" ]]; then
  DEVBOX_LOGIN_AUTO=1 devbox-login
fi
