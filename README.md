# Isolated zsh devbox

```sh
./shell
```

Starts the devbox's own zsh (`--pure`, `HOME=.devbox/home`, config from `zsh/`).
On first run it signs in to GitHub in the browser, asks whether git should use
HTTPS or SSH, and sets your git name/email. All of it is stored in the isolated
HOME, not the host's Keychain, dotfiles or `~/.ssh`. Set `DEVBOX_SKIP_LOGIN=1`
to skip it for a session.

## HTTPS or SSH

| | HTTPS (default) | SSH |
|---|---|---|
| Auth | gh's token | a key made for this box, uploaded to your GitHub account as `devbox:<folder>` |
| Remotes | `git@github.com:` URLs are rewritten to HTTPS | `https://github.com/` URLs are rewritten to SSH |

Switch any time inside the box:

```sh
devbox-login ssh     # or: devbox-login https
```

Switching to SSH asks gh for one extra permission (uploading SSH keys) in the
browser, then runs `ssh-keygen`. Leave the passphrase empty for none. With a
passphrase, a per-box ssh-agent keeps it unlocked, so you type it once per boot.
SSH always uses `ssh/config`, which points at the box's own key and pinned
GitHub host keys.

## Resetting the login

```sh
devbox-logout        # exits the box; then: ./shell
```

`devbox-logout` deletes this box's SSH key from your GitHub account (if it made
one), stops its ssh-agent, signs gh out, removes `.gitconfig` and `.ssh` from
the box HOME, and exits the shell. The next `./shell` starts from scratch:
browser sign-in, protocol choice, git name/email.

Signing out doesn't revoke the gh token on GitHub's side. To revoke it, go to
GitHub → Settings → Applications → Authorized OAuth Apps → GitHub CLI.

To wipe everything in the box HOME instead, including shell history and caches:

```sh
devbox-logout
rm -rf .devbox/home
```
