# Isolated zsh devbox

```sh
./shell
```

Starts the devbox's own zsh (`--pure`, `HOME=.devbox/home`, config from `zsh/`).
On first run it signs in to GitHub in the browser, wires git to use that login over
HTTPS, and sets your git name/email. All of it is stored in the isolated HOME, not the
host's Keychain or dotfiles. Run `devbox-login` to redo it, or set `DEVBOX_SKIP_LOGIN=1` to skip.
