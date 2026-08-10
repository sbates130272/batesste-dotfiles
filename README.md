# batesste-dotfiles

Personal dotfiles for Stephen Bates, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Structure

Each top-level directory is a **stow package** — its contents mirror `$HOME`. For example:

```text
aws/           # ~/.aws/config (non-secret region/output settings)
bash/          # ~/.bashrc, ~/.profile
claude/        # ~/.claude/settings.json and hooks
emacs/         # ~/.emacs, ~/.emacs.d/init.el
gh/            # ~/.config/gh/config.yml (non-secret gh settings)
git/           # ~/.gitconfig, ~/.config/git/hooks/pre-commit
secrets/       # ~/.secrets.env (git-crypt encrypted)
ssh/           # ~/.ssh/config
templates/     # envsubst templates expanded by install.sh (not stowed)
```

Running `stow bash` from the repo root creates `~/.bashrc -> ~/Projects/batesste-dotfiles/bash/.bashrc` etc.

## Requirements

```bash
sudo apt install stow git git-crypt gettext-base
```

(`gettext-base` provides `envsubst`, used to expand secret templates at install time.)

Your GPG private key must be available on any new machine (used for both commit signing and decrypting secrets via git-crypt).

## Install

```bash
git clone git@github.com:sbates130272/batesste-dotfiles.git ~/Projects/batesste-dotfiles
cd ~/Projects/batesste-dotfiles
git-crypt unlock    # requires your GPG private key
./install.sh
```

Install specific packages only:

```bash
./install.sh bash git
```

## Adding a new package

1. Create a directory named after the tool (e.g. `tmux/`).
2. Inside it, recreate the path relative to `$HOME` (e.g. `tmux/.tmux.conf`).
3. Run `./install.sh tmux` to stow it.
4. Commit and push.

## Secrets

Secrets are stored encrypted in this repo using [git-crypt](https://github.com/AGWA/git-crypt). The following files are encrypted at rest and only readable after `git-crypt unlock`:

| File | Purpose |
| --- | --- |
| `secrets/.secrets.env` | All secret values (`HF_TOKEN`, `DOCKER_PAT`, `DOCKER_AUTH`, `ANTHROPIC_API_KEY`, `ANTHROPIC_CUSTOM_HEADERS`, `OTEL_RESOURCE_ATTRIBUTES`, `GH_TOKEN_*`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_BATESSTE_PMEM_KEY_B64`) |

`install.sh` uses `envsubst` to expand templates in `templates/` into `$HOME` after sourcing the secrets file. The AWS pmem key is stored base64-encoded and decoded by `install.sh` during expansion. `HF_TOKEN` is written directly to `~/.cache/huggingface/token`, which `huggingface_hub` reads natively — no shell env var sourcing required.

Secrets are encrypted with git-crypt. Import your GPG private key before running `git-crypt unlock`.

## Machine-local Claude settings

`claude/settings.local.json` is excluded from stow (via `claude/.stow-local-ignore`) so each machine manages it independently. Use the bootstrap script to write the correct `settings.local.json` for a given machine:

| Machine | Script | Notes |
| --- | --- | --- |
| `snoc-think` | `scripts/bootstrap-snoc-think.sh` | Bare Linux; reaches the AMD API gateway via SSH reverse tunnel on `localhost:8888` |

On WSL2 (`apcan-*`), write `~/.claude/settings.local.json` by hand — it only needs local permission overrides and is not secret.

## Notes

- GPG commit signing is enabled in `.gitconfig`; the same key used for secrets also signs commits.
- ROCm WSL environment is sourced from `~/.config/rocm/wsl-env.sh` (not tracked here, managed by Ansible).
- `REQUESTS_CA_BUNDLE` is set in `.bashrc` for Claude CLI to work behind the AMD ZScaler CA.
