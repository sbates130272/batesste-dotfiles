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
TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/claude-settings-local.json"
install -d "$HOME/.claude"

# Older checkouts stowed settings.local.json into the repo. Writing through
# that symlink would put the subscription key in the working tree, so drop it.
[[ -L "$SETTINGS" ]] && rm "$SETTINGS"

# This host reaches the AMD gateway through the reverse tunnel on the WSL2 node.
export CLAUDE_PROXY_URL="http://localhost:8888"
export ANTHROPIC_CUSTOM_HEADERS ANTHROPIC_API_KEY

( umask 077; envsubst < "$TEMPLATE" > "$SETTINGS" )
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
# The gateway/model vars come from ~/.config/claude/env.sh for shell-launched
# Claude, but the extension does not go through a login shell, so repeat them.
s["claudeCode.environmentVariables"] = [
    {"name": "ANTHROPIC_CUSTOM_HEADERS",       "value": custom_headers},
    {"name": "ANTHROPIC_API_KEY",              "value": api_key},
    {"name": "NODE_EXTRA_CA_CERTS",            "value": "/etc/ssl/certs/ca-certificates.crt"},
    {"name": "ANTHROPIC_BASE_URL",             "value": "https://llm-api.amd.com/Anthropic"},
    {"name": "ANTHROPIC_MODEL",                "value": "Claude-Opus-5[1m]"},
    {"name": "ANTHROPIC_DEFAULT_OPUS_MODEL",   "value": "Claude-Opus-5[1m]"},
    {"name": "ANTHROPIC_DEFAULT_SONNET_MODEL", "value": "Claude-Sonnet-4.6"},
    {"name": "ANTHROPIC_DEFAULT_HAIKU_MODEL",  "value": "Claude-Haiku-4.5"},
    {"name": "HTTP_PROXY",                     "value": "http://localhost:8888"},
    {"name": "HTTPS_PROXY",                    "value": "http://localhost:8888"},
    {"name": "NO_PROXY",                       "value": "localhost,127.0.0.1"},
]
with open(path, "w") as f:
    json.dump(s, f, indent=4)
    f.write("\n")
PYEOF
    echo "Updated $VSCODE_SETTINGS"
fi
