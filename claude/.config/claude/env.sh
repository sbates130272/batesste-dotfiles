# shellcheck shell=sh
# Claude Code gateway + telemetry environment.
#
# Sourced, never executed, so there is no shebang; .profile may be read by a
# POSIX sh, so keep this file to plain exports.
#
# These live here rather than in ~/.claude/settings.json because third-party
# installers (.pixel-agents) rewrite settings.json from scratch, replacing the
# stow symlink and dropping its env block. Keeping the gateway config in the
# environment means a clobbered settings.json costs hooks, not connectivity.
#
# Sourced from both .profile and .bashrc so non-interactive shells (VS Code
# remote, `ssh host cmd`) get it too.

export ANTHROPIC_BASE_URL="https://llm-api.amd.com/Anthropic"

export ANTHROPIC_MODEL="Claude-Opus-5[1m]"
export ANTHROPIC_DEFAULT_OPUS_MODEL="Claude-Opus-5[1m]"
export ANTHROPIC_DEFAULT_SONNET_MODEL="Claude-Sonnet-4.6"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="Claude-Haiku-4.5"

export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS="1"
export ENABLE_TOOL_SEARCH="true"

export CLAUDE_CODE_ENABLE_TELEMETRY="1"
export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA="1"
export OTEL_EXPORTER_OTLP_ENDPOINT="https://collector.slug.amd.com"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE="cumulative"
export OTEL_METRICS_EXPORTER="otlp"
export OTEL_TRACES_EXPORTER="otlp"
export OTEL_LOGS_EXPORTER="otlp"

# Keep prompt and tool payloads out of telemetry.
export OTEL_LOG_USER_PROMPTS="0"
export OTEL_LOG_TOOL_CONTENT="0"
export OTEL_LOG_TOOL_DETAILS="0"
export OTEL_LOG_RAW_API_BODIES="0"
