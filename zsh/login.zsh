# First-run sign-in for the isolated HOME. Sourced by .zshrc; re-run any time with `devbox-login`.
# Everything is written under $HOME (.config/gh, .gitconfig, .ssh), never the host's Keychain or dotfiles.
# Skip it for a session with DEVBOX_SKIP_LOGIN=1. Undo it with `devbox-logout`.
#
#   devbox-login          sign in, asking https or ssh the first time
#   devbox-login ssh      switch git to SSH (box-only key, uploaded to GitHub)
#   devbox-login https    switch git to HTTPS (gh token)
#   login-box / logout-box are aliases for devbox-login / devbox-logout.

DEVBOX_SSH_KEY="$HOME/.ssh/id_ed25519"

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
      read -k1 "key?git protocol: [1] https (Enter)  [2] ssh  "
      print
      case "$key" in
        2|s) proto=ssh ;;
        1|h|$'\n') proto=https ;;
        *) print -u2 "expected 1 or 2"; return 2 ;;
      esac
    fi
    local scopes=user:email
    [[ "$proto" == ssh ]] && scopes+=,admin:public_key
    gh auth login --hostname github.com --git-protocol "$proto" --web \
      --insecure-storage --skip-ssh-key --scopes "$scopes" || return 1
  fi

  if [[ -n "$proto" ]]; then
    gh config set --host github.com git_protocol "$proto"
  else
    proto="$(gh config get --host github.com git_protocol 2>/dev/null)"
    [[ "$proto" == ssh ]] || proto=https
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

  # Commit identity, defaulting to the GitHub account's name and primary email.
  if [[ -z "$(git config --global user.email)" ]]; then
    local name email
    name="$(gh api user --jq '.name // .login' 2>/dev/null)"
    email="$(gh api user/emails --jq 'map(select(.primary))[0].email' 2>/dev/null)"
    vared -p "git user.name:  " name
    vared -p "git user.email: " email
    git config --global user.name "$name"
    git config --global user.email "$email"
  fi
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
  local key="$DEVBOX_SSH_KEY"
  if [[ -s "$key.github-id" ]]; then
    gh api -X DELETE "user/keys/$(<"$key.github-id")" && print "Removed SSH key from GitHub."
  fi
  [[ -s "$HOME/.ssh/agent.pid" ]] && kill "$(<"$HOME/.ssh/agent.pid")" 2>/dev/null
  gh auth logout --hostname github.com
  rm -rf "$HOME/.ssh" "$HOME/.gitconfig"
  print "Signed out. Run ./shell to sign in again."
  exit
}

# Shorter names that completion finds from "log".
alias login-box=devbox-login logout-box=devbox-logout

if [[ -o interactive && -z "$DEVBOX_SKIP_LOGIN" ]]; then
  devbox-login
fi
