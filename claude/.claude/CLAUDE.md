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
