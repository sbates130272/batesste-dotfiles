#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[dotfiles] $*"; }

check_deps() {
    local missing=()
    for dep in stow git; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing dependencies: ${missing[*]}"
        echo "Install with: sudo apt install ${missing[*]}"
        exit 1
    fi
}

stow_package() {
    local pkg="$1"
    if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
        log "Stowing $pkg"
        stow --dir="$DOTFILES_DIR" --target="$HOME" --restow "$pkg"
    else
        log "Skipping $pkg (directory not found)"
    fi
}

usage() {
    echo "Usage: $0 [packages...]"
    echo ""
    echo "Available packages:"
    for d in "$DOTFILES_DIR"/*/; do
        echo "  $(basename "$d")"
    done
    echo ""
    echo "With no arguments, installs all packages."
}

main() {
    check_deps

    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        # Install all packages (skip hidden dirs and non-directories)
        while IFS= read -r -d '' dir; do
            packages+=("$(basename "$dir")")
        done < <(find "$DOTFILES_DIR" -maxdepth 1 -mindepth 1 -type d -not -name '.*' -print0 | sort -z)
    fi

    log "Installing dotfiles from $DOTFILES_DIR"
    for pkg in "${packages[@]}"; do
        stow_package "$pkg"
    done

    post_install_reminders
    log "Done."
}

post_install_reminders() {
    local warned=0

    # Claude: settings.json contains REPLACE_ME placeholders for secrets
    local claude_settings="$HOME/.claude/settings.json"
    if [[ -f "$claude_settings" ]] && grep -q "REPLACE_ME" "$claude_settings"; then
        echo ""
        echo "[dotfiles] ACTION REQUIRED: ~/.claude/settings.json contains REPLACE_ME placeholders."
        echo "           Fill in: ANTHROPIC_API_KEY, ANTHROPIC_CUSTOM_HEADERS subscription key,"
        echo "           and OTEL_RESOURCE_ATTRIBUTES (user.name, user.id, session.id)."
        warned=1
    fi

    # HuggingFace: token file must exist at the path referenced by HF_TOKEN_FILE.
    # On Ansible-managed machines this file is written from vault by user_setup — skip
    # this reminder if it already exists (Ansible got there first).
    local hf_token="${HF_TOKEN_FILE:-$HOME/.batesste-hugging-face-read-march-2026.token}"
    if [[ ! -f "$hf_token" ]]; then
        echo ""
        echo "[dotfiles] ACTION REQUIRED: HuggingFace token not found at $hf_token"
        echo "           Option A (manual): echo 'hf_...' > $hf_token && chmod 600 $hf_token"
        echo "           Option B (Ansible): run user_setup with vault_hf_token set in secrets.yml"
        warned=1
    fi

    [[ "$warned" -eq 1 ]] && echo ""
}

main "$@"
