# batesste-dotfiles

[![Validate](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/validate.yml/badge.svg)](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/validate.yml)
[![Integration](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/integration.yml/badge.svg)](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/integration.yml)
[![Install Check](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/install-check.yml/badge.svg)](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/install-check.yml)
[![Secret Scan](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/secret-scan.yml/badge.svg)](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/secret-scan.yml)
[![README Structure](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/readme-structure.yml/badge.svg)](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/readme-structure.yml)
[![Shell Check](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/shellcheck.yml)
[![Spellcheck](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/spellcheck.yml/badge.svg)](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/spellcheck.yml)
[![Release](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/release.yml/badge.svg)](https://github.com/sbates130272/batesste-dotfiles/actions/workflows/release.yml)
[![Latest Release](https://img.shields.io/github/v/release/sbates130272/batesste-dotfiles)](https://github.com/sbates130272/batesste-dotfiles/releases/latest)
[![License](https://img.shields.io/github/license/sbates130272/batesste-dotfiles)](LICENSE)

Personal dotfiles for Stephen Bates, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Structure

Each top-level directory is a **stow package** — its contents mirror `$HOME`. For example:

```text
ansible/       # ~/.ansible.cfg
aws/           # ~/.aws/config (non-secret region/output settings)
bash/          # ~/.bashrc, ~/.profile
claude/        # ~/.claude/settings.json and hooks
docker/        # ~/.docker/daemon.json
emacs/         # ~/.emacs, ~/.emacs.d/init.el
gh/            # ~/.config/gh/config.yml (non-secret gh settings)
git/           # ~/.gitconfig, ~/.config/git/hooks/pre-commit
secrets/       # ~/.secrets.env (git-crypt encrypted)
ssh/           # ~/.ssh/config
```

Run `./install.sh` from the repo root to stow all packages. Two directories are **not** stow packages and their contents stay in the repo:

- `templates/` — `envsubst` inputs expanded by `install.sh` into `$HOME` at install time
- `scripts/` — bootstrap and helper scripts invoked directly from the repo

## Requirements

```bash
sudo apt install stow git git-crypt gettext-base
```

(`gettext-base` provides `envsubst`, used to expand secret templates at install time.)

Your GPG private key must be available on any new machine (used for both commit signing and decrypting secrets via git-crypt).

## Install

```bash
git clone git@github.com:sbates130272/batesste-dotfiles.git <install-location>
cd <install-location>
git-crypt unlock    # requires your GPG private key
./install.sh
```

On a fresh machine, run bootstrap after stowing to write `~/.claude/settings.local.json` and the VS Code Machine settings. Pass `proxy` for machines that reach the AMD API gateway via an SSH reverse tunnel on `localhost:8888`, or `noproxy` for machines with direct AMD network access:

```bash
./install.sh --bootstrap proxy     # SSH-tunnel machines
./install.sh --bootstrap noproxy   # direct AMD network access
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

## Adding a Claude slash command

User-level Claude Code slash commands live in `claude/.claude/commands/`. Each
command is a single `.md` file; the filename (without `.md`) becomes the
`/command-name` available in any Claude Code session after stowing.

1. Create `claude/.claude/commands/<name>.md`.
2. Write the prompt body. Use `$ARGUMENTS` anywhere you want text typed after
   the command name to be substituted.
3. Run `./install.sh claude` (or `stow claude`) to symlink the new file into
   `~/.claude/commands/`.
4. Commit and push.

## Secrets

Secrets are stored encrypted in this repo using [git-crypt](https://github.com/AGWA/git-crypt). The following files are encrypted at rest and only readable after `git-crypt unlock`:

| File | Purpose |
| --- | --- |
| `secrets/.secrets.env` | All secret values (API keys, tokens, credentials) |

`install.sh` uses `envsubst` to expand templates in `templates/` into `$HOME` after sourcing the secrets file. Some secrets are written directly to well-known locations rather than exported as shell environment variables.

Secrets are encrypted with git-crypt. Import your GPG private key before running `git-crypt unlock`.

## Machine-local Claude settings

`claude/settings.local.json` is excluded from stow (via `claude/.stow-local-ignore`) so each machine manages it independently. Two bootstrap scripts write the correct `settings.local.json` and the VS Code Machine `settings.json` for a given network topology:

| Script | When to use |
| --- | --- |
| `scripts/bootstrap-proxy.sh` | Machines that reach `llm-api.amd.com` via an SSH reverse tunnel on `localhost:8888` (e.g. bare Linux boxes without ZScaler) |
| `scripts/bootstrap-noproxy.sh` | Machines with direct AMD network access (e.g. WSL2 behind ZScaler) |

Invoke via `./install.sh --bootstrap proxy` or `./install.sh --bootstrap noproxy` — see the Install section above.

## Notes

- GPG commit signing is enabled in `.gitconfig`; the same key used for secrets also signs commits.
- ROCm WSL environment is sourced from `~/.config/rocm/wsl-env.sh` (not tracked here, managed by Ansible).
- `REQUESTS_CA_BUNDLE` is set in `.bashrc` for Claude CLI to work behind the AMD ZScaler CA.
