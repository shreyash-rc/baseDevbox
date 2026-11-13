# First-run sign-in for the isolated HOME. Sourced by .zshrc; re-run any time with `devbox-login`.
# Everything is written under $HOME (.config/gh, .gitconfig), never the host's Keychain or dotfiles.
# Skip it for a session with DEVBOX_SKIP_LOGIN=1.

devbox-login() {
  # GitHub: token stored in $HOME/.config/gh/hosts.yml (--insecure-storage keeps it out of the shared Keychain).
  if ! gh auth token --hostname github.com >/dev/null 2>&1; then
    print -P "%F{117}GitHub sign-in for this devbox%f"
    gh auth login --hostname github.com --git-protocol https --web \
      --insecure-storage --scopes user:email || return 1
  fi

  # Let git push/pull over HTTPS using the gh token instead of host SSH keys. Rewritten every time because
  # `gh auth login`/`setup-git` pin gh's Nix store path, which breaks when gh is upgraded.
  local host
  for host in github.com gist.github.com; do
    git config --global --remove-section "credential.https://$host" 2>/dev/null
    git config --global "credential.https://$host.helper" ''
    git config --global --add "credential.https://$host.helper" '!gh auth git-credential'
  done
  # Repos cloned with SSH remotes go over HTTPS too, since the box has no ssh or host keys.
  git config --global url.https://github.com/.insteadOf git@github.com:

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

if [[ -o interactive && -z "$DEVBOX_SKIP_LOGIN" ]]; then
  devbox-login
fi
