#!/usr/bin/env bash
# Run on snoc-think to write machine-local Claude settings.
# Requires the SSH reverse tunnel (localhost:8888) to be active so
# Claude Code can reach the AMD API gateway via this WSL2 node.
# Requires git-crypt to be unlocked so ~/.secrets.env is readable.
set -euo pipefail

SECRETS="$HOME/.secrets.env"
if [[ ! -f "$SECRETS" ]] || ! grep -qI '' "$SECRETS" 2>/dev/null; then
    echo "ERROR: $SECRETS not found or still encrypted (run git-crypt unlock first)" >&2
    exit 1
fi

ANTHROPIC_CUSTOM_HEADERS="$(grep '^ANTHROPIC_CUSTOM_HEADERS=' "$SECRETS" | cut -d= -f2-)"
if [[ -z "$ANTHROPIC_CUSTOM_HEADERS" ]]; then
    echo "ERROR: ANTHROPIC_CUSTOM_HEADERS not found in $SECRETS" >&2
    exit 1
fi

ANTHROPIC_API_KEY="$(grep '^ANTHROPIC_API_KEY=' "$SECRETS" | cut -d= -f2-)"
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
    echo "ERROR: ANTHROPIC_API_KEY not found in $SECRETS" >&2
    exit 1
fi

SETTINGS="$HOME/.claude/settings.local.json"
install -d "$HOME/.claude"

# stow 2.3.1 (on snoc-think) doesn't support .stow-local-ignore, so it
# recreates the symlink. Remove it so we can write a real file.
[[ -L "$SETTINGS" ]] && rm "$SETTINGS"

cat > "$SETTINGS" <<EOF
{
  "env": {
    "HTTP_PROXY": "http://localhost:8888",
    "HTTPS_PROXY": "http://localhost:8888",
    "NO_PROXY": "localhost,127.0.0.1",
    "NODE_EXTRA_CA_CERTS": "/etc/ssl/certs/ca-certificates.crt",
    "ANTHROPIC_CUSTOM_HEADERS": "$ANTHROPIC_CUSTOM_HEADERS",
    "ANTHROPIC_API_KEY": "$ANTHROPIC_API_KEY"
  },
  "permissions": {
    "allow": []
  }
}
EOF

chmod 600 "$SETTINGS"
echo "Wrote $SETTINGS"

# VS Code extension reads claudeCode.environmentVariables, not settings.local.json.
VSCODE_SETTINGS="$HOME/.vscode-server/data/Machine/settings.json"
if [[ -f "$VSCODE_SETTINGS" ]]; then
    python3 - "$VSCODE_SETTINGS" "$ANTHROPIC_CUSTOM_HEADERS" "$ANTHROPIC_API_KEY" <<'PYEOF'
import sys, json
path, custom_headers, api_key = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    s = json.load(f)
s["claudeCode.environmentVariables"] = [
    {"name": "ANTHROPIC_CUSTOM_HEADERS", "value": custom_headers},
    {"name": "ANTHROPIC_API_KEY",        "value": api_key},
    {"name": "NODE_EXTRA_CA_CERTS",      "value": "/etc/ssl/certs/ca-certificates.crt"},
]
with open(path, "w") as f:
    json.dump(s, f, indent=4)
    f.write("\n")
PYEOF
    echo "Updated $VSCODE_SETTINGS"
fi
