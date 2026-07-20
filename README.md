# batesste-dotfiles

Personal dotfiles for Stephen Bates, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Structure

Each top-level directory is a **stow package** — its contents mirror `$HOME`. For example:

```
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
sudo apt install stow git
```

## Install

Install all packages:

```bash
./install.sh
```

Install specific packages:

```bash
./install.sh bash git
```

## Adding a new package

1. Create a directory named after the tool (e.g. `tmux/`).
2. Inside it, recreate the path relative to `$HOME` (e.g. `tmux/.tmux.conf`).
3. Run `./install.sh tmux` to stow it.
4. Commit and push.

## Notes

- `gh/hosts.yml` is excluded via `.gitignore` — it contains auth tokens.
- GPG signing is enabled in `.gitconfig`; ensure your key `CB05CB5CFA5DFD9850BB814DE0C020C1975548AE` is present on any new machine.
- ROCm WSL environment is sourced from `~/.config/rocm/wsl-env.sh` (not tracked here, managed by Ansible).
- `REQUESTS_CA_BUNDLE` is set in `.bashrc` for Claude CLI to work behind the AMD ZScaler CA.
