#!/usr/bin/env bash
# Bootstrap for machines with direct access to llm-api.amd.com (no proxy needed).
# Run via: ./install.sh --bootstrap noproxy
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

[[ -L "$SETTINGS" ]] && rm "$SETTINGS"

( umask 077; cat > "$SETTINGS" << EOF
{
  "env": {
    "NODE_EXTRA_CA_CERTS": "/etc/ssl/certs/ca-certificates.crt",
    "ANTHROPIC_CUSTOM_HEADERS": "${ANTHROPIC_CUSTOM_HEADERS}",
    "ANTHROPIC_API_KEY": "${ANTHROPIC_API_KEY}"
  }
}
EOF
)
chmod 600 "$SETTINGS"
echo "[dotfiles] Wrote $SETTINGS"

# VS Code extension reads claudeCode.environmentVariables, not settings.local.json.
VSCODE_SETTINGS="$HOME/.vscode-server/data/Machine/settings.json"
install -d "$(dirname "$VSCODE_SETTINGS")"
[[ -f "$VSCODE_SETTINGS" ]] || echo '{}' > "$VSCODE_SETTINGS"

python3 - "$VSCODE_SETTINGS" "$ANTHROPIC_CUSTOM_HEADERS" "$ANTHROPIC_API_KEY" <<'PYEOF'
import sys, json
path, custom_headers, api_key = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    s = json.load(f)
s["claudeCode.environmentVariables"] = [
    {"name": "ANTHROPIC_CUSTOM_HEADERS",       "value": custom_headers},
    {"name": "ANTHROPIC_API_KEY",              "value": api_key},
    {"name": "NODE_EXTRA_CA_CERTS",            "value": "/etc/ssl/certs/ca-certificates.crt"},
    {"name": "ANTHROPIC_BASE_URL",             "value": "https://llm-api.amd.com/Anthropic"},
    {"name": "ANTHROPIC_MODEL",                "value": "Claude-Opus-5[1m]"},
    {"name": "ANTHROPIC_DEFAULT_OPUS_MODEL",   "value": "Claude-Opus-5[1m]"},
    {"name": "ANTHROPIC_DEFAULT_SONNET_MODEL", "value": "Claude-Sonnet-4.6"},
    {"name": "ANTHROPIC_DEFAULT_HAIKU_MODEL",  "value": "Claude-Haiku-4.5"},
]
with open(path, "w") as f:
    json.dump(s, f, indent=4)
    f.write("\n")
PYEOF
echo "[dotfiles] Updated $VSCODE_SETTINGS"
