# Global Claude Preferences — Stephen Bates

## Environment
- Running in WSL2 on AMD corporate network (ZScaler proxy, AMD API gateway)
- Shell: bash; Editor: emacs
- Git commits require GPG signing — never use --no-gpg-sign or --no-verify

## Behavior
- Terse responses; no trailing summaries of what you just did
- No emojis unless explicitly requested
- When referencing code locations, use markdown [file](path#Lnn) links
- Prefer editing existing files over creating new ones
- Default to writing no comments — only add one when the WHY is non-obvious
- Don't create planning or analysis documents unless explicitly asked
- When writing a plan (ExitPlanMode), prefix the plan filename with the repo name derived from `basename $(git rev-parse --show-toplevel)`, e.g. `<repo-name>-<description>.md`

## Security
- Never read, print, or commit secrets, API keys, or credentials
- ANTHROPIC_API_KEY and custom headers live in secrets/.secrets.env (git-crypt encrypted)

## Git
- Always GPG-sign commits; never skip hooks or signing
- Prefer new commits over amending published commits
- Confirm before: git push, force operations, branch deletion
- When asked for a "commit message" or to "commit": write the message to /tmp/<repo-name>-commit-msg.txt and show the git command to use it. Never commit directly.
- Always include `-s` (signoff) in git commit commands.

## GitHub
- Use `gh` (GitHub CLI) for all GitHub operations: PR status, issue tracking, checks, reviews, release info
- Default account is `sbates130272` — verify with `gh auth status` if switching accounts; never assume another account is active
- Always act as `sbates130272` (e.g. opening issues, commenting, creating PRs) unless the user explicitly directs otherwise
- Prefer `gh` over direct API calls or web URLs for any GitHub state queries

## GitHub PATs and the gh tool

Three tokens are in play; pick the right one for the operation:

| Token | Variable | Type | Scope |
| --- | --- | --- | --- |
| `GITHUB_TOKEN` (env) | `GH_TOKEN_SBATES130272_ROCM` | Fine-grained PAT | Personal + ROCm/AMD org repos; set automatically at login via `~/.config/gh/tokens.env` |
| `sbates130272` (hosts.yml) | `GH_TOKEN_SBATES130272` | Classic PAT | Full personal GitHub — org admin, enterprise, GPG keys, etc. |
| `stebates_amdeng` (hosts.yml) | `GH_TOKEN_STEBATES_AMDENG` | Classic PAT | AMD org — `repo` + `read:org` only |

- `gh` automatically uses `GITHUB_TOKEN` when set — prefer this for day-to-day PR/check work
- Switch to a named account only when the fine-grained PAT lacks the required scope: `gh auth switch -u <account>`
- Use `gh-as <TOKEN_NAME> <args>` to run a single command under an alternate token without changing the active account
- Use `gh-token-check` to see expiry status of all registered tokens
- For ROCm git operations use `rocm-git <args>` (wraps git with `GH_TOKEN` set to the fine-grained PAT)
