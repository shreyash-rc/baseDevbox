# Isolated zsh devbox

```sh
./shell
```

Starts the devbox's own zsh (`--pure`, `HOME=.devbox/home`, config from `zsh/`).
On first run it signs in to GitHub in the browser, asks whether git should use
HTTPS or SSH (press 1 or Enter for HTTPS, 2 for SSH, 3 to skip GitHub), and sets your git name/email. All of it is stored in the isolated
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

## Skipping GitHub

Press 3 at the protocol prompt to use the box without GitHub. It still asks for
your git name/email so local commits work, and new shells stop asking to sign
in. Run `devbox-login` whenever you want to sign in after all. To skip only the
current session instead, start it with `DEVBOX_SKIP_LOGIN=1 ./shell`.

## Changing your git name/email

Run `devbox-login` (choose 3 if you're not signed in). It always asks for the
name and email, showing the current value in brackets; press Enter to keep it.
Right after signing in to GitHub, the brackets show your GitHub name and primary
email instead.
New shells ask only when one is missing, and blank answers aren't saved.

## Resetting the login

```sh
devbox-logout        # exits the box; then: ./shell
```

`login-box` and `logout-box` are shorter aliases for `devbox-login` and
`devbox-logout`, so typing `log` brings them up in completion.

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
