#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[dotfiles] $*"; }

check_deps() {
    local missing=()
    for dep in stow git git-crypt envsubst; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing dependencies: ${missing[*]}"
        echo "Install with: sudo apt install stow git git-crypt gettext-base"
        echo "Missing: ${missing[*]}"
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

    expand_templates
    run_host_bootstrap
    post_install_reminders
    log "Done."
}

expand_templates() {
    local secrets="$HOME/.secrets.env"
    local tmpl_dir="$DOTFILES_DIR/templates"

    if [[ ! -f "$secrets" ]]; then
        log "Skipping template expansion: ~/.secrets.env not found (run git-crypt unlock first)"
        return
    fi

    # If the file is still encrypted (binary/locked), sourcing it would fail.
    if ! grep -qI '' "$secrets" 2>/dev/null; then
        log "Skipping template expansion: ~/.secrets.env is still encrypted (run git-crypt unlock, then re-run install.sh)"
        return
    fi

    # Source secrets into a subshell so envsubst can see them, then write outputs.
    (
        # Use eval-based export to handle values with spaces (e.g. HTTP header strings)
        # that plain `set -a; . file` would misparse as commands.
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line//[[:space:]]/}" ]] && continue
            export "${line?}"
        done < "$secrets"

        local missing=()
        local required=(
            AWS_ACCESS_KEY_ID
            AWS_SECRET_ACCESS_KEY
            AWS_BATESSTE_PMEM_KEY_B64
            DOCKER_AUTH
            GH_TOKEN_STEBATES_AMDENG
            GH_TOKEN_SBATES130272
            HF_TOKEN
        )
        for var in "${required[@]}"; do
            [[ -z "${!var:-}" ]] && missing+=("$var")
        done
        if [[ ${#missing[@]} -gt 0 ]]; then
            echo "[dotfiles] ERROR: secrets file is missing required variables:" >&2
            for var in "${missing[@]}"; do
                echo "  - $var" >&2
            done
            echo "[dotfiles] Re-run after fixing ~/.secrets.env (check git-crypt unlock status)" >&2
            exit 1
        fi

        install -d "$HOME/.config/gh"
        envsubst < "$tmpl_dir/gh-hosts.yml" > "$HOME/.config/gh/hosts.yml"
        chmod 600 "$HOME/.config/gh/hosts.yml"
        log "Expanded gh/hosts.yml"

        install -d "$HOME/.docker"
        envsubst < "$tmpl_dir/docker-config.json" > "$HOME/.docker/config.json"
        chmod 600 "$HOME/.docker/config.json"
        log "Expanded docker/config.json"

        install -d "$HOME/.aws"
        envsubst < "$tmpl_dir/aws-credentials" > "$HOME/.aws/credentials"
        chmod 600 "$HOME/.aws/credentials"
        log "Expanded aws/credentials"

        local pmem_name="batesste-20160101.pmem"
        printf '%s' "$AWS_BATESSTE_PMEM_KEY_B64" | base64 -d > "$HOME/.aws/$pmem_name"
        chmod 600 "$HOME/.aws/$pmem_name"
        log "Expanded aws/$pmem_name"

        install -d "$HOME/.cache/huggingface"
        printf '%s' "$HF_TOKEN" > "$HOME/.cache/huggingface/token"
        chmod 600 "$HOME/.cache/huggingface/token"
        log "Expanded huggingface/token"
    )
}

run_host_bootstrap() {
    local host
    host="$(hostname -s)"
    local script="$DOTFILES_DIR/scripts/bootstrap-${host}.sh"
    if [[ -x "$script" ]]; then
        log "Running host bootstrap: $script"
        "$script"
    fi
}

check_gpg_key() {
    # Derive the required fingerprint from the git-crypt key file name.
    local key_dir="$DOTFILES_DIR/.git-crypt/keys/default/0"
    local fingerprint
    fingerprint="$(ls "$key_dir" 2>/dev/null | sed 's/\.gpg$//')"
    if [[ -z "$fingerprint" ]]; then
        return  # can't determine key, skip check
    fi
    if ! gpg --list-secret-keys "$fingerprint" &>/dev/null 2>&1; then
        echo ""
        echo "[dotfiles] WARNING: GPG private key $fingerprint is not available."
        echo "           git-crypt unlock and GPG commit signing will not work until"
        echo "           this key is imported. Transfer it from another machine with:"
        echo "             gpg --export-secret-keys $fingerprint | gpg --import"
    fi
}

post_install_reminders() {
    local warned=0

    check_gpg_key

    # git-crypt: secrets are encrypted in this repo — unlock before stowing.
    if git -C "$DOTFILES_DIR" crypt status 2>/dev/null | grep -q "not encrypted"; then
        : # unlocked, nothing to warn about
    elif git -C "$DOTFILES_DIR" crypt status 2>/dev/null | grep -qv "not encrypted"; then
        echo ""
        echo "[dotfiles] ACTION REQUIRED: git-crypt secrets are still locked."
        echo "           Run: git-crypt unlock"
        echo "           (requires your GPG private key, then re-run install.sh)"
        warned=1
    fi

    if [[ "$warned" -eq 1 ]]; then echo ""; fi
}

main "$@"
