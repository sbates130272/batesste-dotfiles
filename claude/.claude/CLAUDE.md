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

## Security
- Never read, print, or commit secrets, API keys, or credentials
- ANTHROPIC_API_KEY and custom headers live in secrets/.secrets.env (git-crypt encrypted)

## Git
- Always GPG-sign commits; never skip hooks or signing
- Prefer new commits over amending published commits
- Confirm before: git push, force operations, branch deletion
- When asked for a "commit message" or to "commit": write the message to /tmp/<repo-name>-commit-msg.txt and show the git command to use it. Never commit directly.

## GitHub
- Use `gh` (GitHub CLI) for all GitHub operations: PR status, issue tracking, checks, reviews, release info
- Default account is `sbates130272` — verify with `gh auth status` if switching accounts; never assume another account is active
- Always act as `sbates130272` (e.g. opening issues, commenting, creating PRs) unless the user explicitly directs otherwise
- Prefer `gh` over direct API calls or web URLs for any GitHub state queries
