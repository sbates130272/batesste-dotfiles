# batesste-dotfiles

Personal dotfiles for Stephen Bates, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Structure

Each top-level directory is a **stow package** — its contents mirror `$HOME`. For example:

```text
bash/
  .bashrc
  .profile
git/
  .gitconfig
gh/
  .config/
    gh/
      config.yml
```

Running `stow bash` from the repo root creates `~/.bashrc -> ~/Projects/batesste-dotfiles/bash/.bashrc` etc.

## Requirements

```bash
sudo apt install stow git git-crypt
```

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
| `claude/.claude/settings.json` | Anthropic API key, subscription key, OTEL attributes |
| `gh/.config/gh/hosts.yml` | GitHub CLI auth token |
| `hf/.hf_token` | HuggingFace read token |
| `docker/.docker/config.json` | Docker Hub auth credential |
| `docker/.docker-bateste-pat-july-2026` | Docker personal access token |

Secrets are encrypted with git-crypt. Import your GPG private key before running `git-crypt unlock`.

## Notes

- GPG commit signing is enabled in `.gitconfig`; the same key used for secrets also signs commits.
- ROCm WSL environment is sourced from `~/.config/rocm/wsl-env.sh` (not tracked here, managed by Ansible).
- `REQUESTS_CA_BUNDLE` is set in `.bashrc` for Claude CLI to work behind the AMD ZScaler CA.
