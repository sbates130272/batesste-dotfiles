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
gpg/           # ~/.gnupg/gpg-agent.conf (pinentry and agent settings)
secrets/       # ~/.secrets.env (git-crypt encrypted)
ssh/           # ~/.ssh/config
```

Run `./install.sh` from the repo root to stow all packages. Three directories are **not** stow packages and their contents stay in the repo:

- `templates/` — `envsubst` inputs expanded by `install.sh` into `$HOME` at install time
- `scripts/` — bootstrap and helper scripts invoked directly from the repo
- `vendor/` — vendored external content (git submodules); currently contains [amd/skills](https://github.com/amd/skills)

## Requirements

```bash
sudo apt install stow git git-crypt gettext-base
```

(`gettext-base` provides `envsubst`, used to expand secret templates at install time.)

Your GPG private key must be available on any new machine (used for both commit signing and decrypting secrets via git-crypt).

## Install

```bash
git clone --recurse-submodules git@github.com:sbates130272/batesste-dotfiles.git <install-location>
cd <install-location>
git-crypt unlock    # requires your GPG private key
./install.sh
```

A full install (no package arguments) also generates `~/.claude/settings.local.json` from `templates/claude-settings-local.json`, writes the VS Code Machine settings, and installs the [AMD skills](https://github.com/amd/skills) into `~/.claude/skills/`. Pass `--proxy` on machines that reach the AMD API gateway via an SSH reverse tunnel on `localhost:8888`; omit it on machines with direct AMD network access (e.g. WSL2 behind ZScaler):

```bash
./install.sh           # direct AMD network access (default)
./install.sh --proxy   # SSH-tunnel machines (adds HTTP_PROXY vars)
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

## GitHub tokens

GitHub tokens for all accounts live in `secrets/.secrets.env` and are written to `~/.config/gh/` by `install.sh`.

### Naming convention

| Variable | Purpose |
| --- | --- |
| `GH_TOKEN_<ACCOUNT>` | Active token for that account (used by `gh` CLI via `~/.config/gh/hosts.yml`) |
| `GH_TOKEN_<ACCOUNT>_EXPIRES` | Expiry date in `YYYY-MM-DD` format |
| `GH_TOKEN_<ACCOUNT>_<SCOPE>` | Alternate scoped token for the same account (e.g. `_ROCM` for ROCm org access) |
| `GH_TOKEN_<ACCOUNT>_<SCOPE>_EXPIRES` | Expiry date for that scoped token |

`<ACCOUNT>` is the GitHub username uppercased with hyphens replaced by underscores, e.g. `SBATES130272` or `STEBATES_AMDENG`.

### Adding a new token or expiry date

1. Unlock secrets: `git-crypt unlock`
2. Edit `secrets/.secrets.env` and add the token and (recommended) its expiry:

   ```bash
   GH_TOKEN_SBATES130272=github_pat_...
   GH_TOKEN_SBATES130272_EXPIRES=2026-12-01

   # Optional scoped PAT for ROCm org access
   GH_TOKEN_SBATES130272_ROCM=github_pat_...
   GH_TOKEN_SBATES130272_ROCM_EXPIRES=2026-12-15
   ```

3. Re-run `./install.sh` to regenerate `~/.config/gh/tokens.env` and `~/.config/gh/hosts.yml`.
4. Reload your shell (`source ~/.bashrc`) or open a new terminal.

Adding a new `_<SCOPE>` token beyond `_ROCM` also requires a matching block in the `expand_templates()` function in `install.sh`.

### Checking and using tokens

```bash
gh-token-check                            # show days until expiry for all registered tokens
gh-as SBATES130272_ROCM repo list ROCm    # run any gh command with a named alternate token
```

`gh-token-check` warns at 14 days and flags expired tokens. Both functions are defined in `bash/.bashrc` and available in any interactive shell once `~/.config/gh/tokens.env` has been generated.

## Notes

- GPG commit signing is enabled in `.gitconfig`; the same key used for secrets also signs commits.
- ROCm WSL environment is sourced from `~/.config/rocm/wsl-env.sh` (not tracked here, managed by Ansible).
- `REQUESTS_CA_BUNDLE` is set in `.bashrc` for Claude CLI to work behind the AMD ZScaler CA.
