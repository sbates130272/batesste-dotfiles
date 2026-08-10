#!/usr/bin/env bash
# Run on snoc-think to write machine-local Claude settings.
# Requires the SSH reverse tunnel (localhost:8888) to be active so
# Claude Code can reach the AMD API gateway via this WSL2 node.
set -euo pipefail

SETTINGS="$HOME/.claude/settings.local.json"
install -d "$HOME/.claude"

cat > "$SETTINGS" <<'EOF'
{
  "env": {
    "HTTP_PROXY": "http://localhost:8888",
    "HTTPS_PROXY": "http://localhost:8888",
    "NODE_EXTRA_CA_CERTS": "/etc/ssl/certs/ca-certificates.crt"
  },
  "permissions": {
    "allow": []
  }
}
EOF

chmod 600 "$SETTINGS"
echo "Wrote $SETTINGS"
