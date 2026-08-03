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

    # Source secrets into a subshell so envsubst can see them, then write outputs.
    (
        set -a
        # shellcheck source=/dev/null
        . "$secrets"
        set +a

        install -d "$HOME/.config/gh"
        envsubst < "$tmpl_dir/gh-hosts.yml" > "$HOME/.config/gh/hosts.yml"
        chmod 600 "$HOME/.config/gh/hosts.yml"
        log "Expanded gh/hosts.yml"

        install -d "$HOME/.docker"
        envsubst < "$tmpl_dir/docker-config.json" > "$HOME/.docker/config.json"
        chmod 600 "$HOME/.docker/config.json"
        log "Expanded docker/config.json"
    )
}

check_gpg_key() {
    # Derive the required fingerprint from the git-crypt key file name.
    local key_dir="$DOTFILES_DIR/.git-crypt/keys/default/0"
    local fingerprint
    fingerprint="$(ls "$key_dir" 2>/dev/null | sed 's/\.gpg$//')"
    if [[ -z "$fingerprint" ]]; then
        return  # can't determine key, skip check
    fi
    if ! gpg --list-secret-keys "$fingerprint" &>/dev/null; then
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
    elif git -C "$DOTFILES_DIR" crypt status 2>/dev/null | grep -q "encrypted"; then
        echo ""
        echo "[dotfiles] ACTION REQUIRED: git-crypt secrets are still locked."
        echo "           Run: git-crypt unlock"
        echo "           (requires your GPG private key, then re-run install.sh)"
        warned=1
    fi

    [[ "$warned" -eq 1 ]] && echo ""
}

main "$@"
