#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_DO_FORCE=0
_DATESTAMP=""
_OLD_ROOT=""
_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
_STATE_FILE="$_STATE_DIR/install-state"

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

backup_conflicts() {
    local pkg="$1"
    local pkg_dir="$DOTFILES_DIR/$pkg"

    while IFS= read -r -d '' src; do
        local rel="${src#"$pkg_dir/"}"
        local target="$HOME/$rel"
        if [[ -f "$target" && ! -L "$target" ]]; then
            log "Backing up $target -> ${target}.${_DATESTAMP}"
            mv "$target" "${target}.${_DATESTAMP}"
        elif [[ -L "$target" ]]; then
            local resolved
            resolved="$(readlink -f "$target" 2>/dev/null || true)"
            if [[ "$resolved" != "$(readlink -f "$src")" ]]; then
                log "Backing up $target -> ${target}.${_DATESTAMP}"
                mv "$target" "${target}.${_DATESTAMP}"
            fi
        fi
    done < <(find "$pkg_dir" -type f -print0)
}

# Resolve a symlink to the dotfiles checkout it points into, if it looks like a
# stow link for package file $rel. Prints that checkout's root, or returns 1.
# Uses realpath -m so it still works when the old checkout is already gone.
link_dotfiles_root() {
    local target="$1" pkg="$2" rel="$3"
    local raw abs suffix="/$pkg/$rel"

    raw="$(readlink "$target")" || return 1
    [[ "$raw" == /* ]] || raw="$(dirname "$target")/$raw"
    abs="$(realpath -m "$raw")"
    [[ "$abs" == *"$suffix" ]] || return 1
    printf '%s\n' "${abs%"$suffix"}"
}

# Emit "target<TAB>old_root" for every link in $HOME that a *different* checkout
# of this repo created. Directories are checked too: stow folds a package
# subdirectory into a single symlink when nothing else lives there, so the
# per-file scan alone would miss e.g. ~/.claude/hooks -> <old>/claude/.claude/hooks.
find_foreign_links() {
    local pkg="$1"
    local pkg_dir="$DOTFILES_DIR/$pkg"
    local src rel target root

    while IFS= read -r -d '' src; do
        rel="${src#"$pkg_dir/"}"
        target="$HOME/$rel"
        [[ -L "$target" ]] || continue
        root="$(link_dotfiles_root "$target" "$pkg" "$rel")" || continue
        [[ "$root" == "$DOTFILES_DIR" ]] && continue
        printf '%s\t%s\n' "$target" "$root"
    done < <(find "$pkg_dir" -mindepth 1 \( -type f -o -type d \) -print0 | sort -z)
}

# Moving or re-cloning the repo leaves the old checkout's symlinks in place,
# still shadowing the new one. Report them up front and refuse to continue
# unless --force, so an install can never end up split across two checkouts.
check_relocation() {
    local -a foreign=()
    local -A roots=()
    local pkg line target root

    for pkg in "$@"; do
        [[ -d "$DOTFILES_DIR/$pkg" ]] || continue
        while IFS= read -r line; do
            [[ -n "$line" ]] && foreign+=("$line")
        done < <(find_foreign_links "$pkg")
    done

    [[ ${#foreign[@]} -eq 0 ]] && return 0

    for line in "${foreign[@]}"; do
        roots["${line#*$'\t'}"]=1
    done
    for root in "${!roots[@]}"; do
        _OLD_ROOT="$root"
    done

    echo ""
    log "This repo has moved. ${#foreign[@]} link(s) still point at another checkout:"
    for root in "${!roots[@]}"; do
        echo "             old: $root"
    done
    echo "             new: $DOTFILES_DIR"
    echo ""
    for line in "${foreign[@]}"; do
        echo "               ${line%%$'\t'*}"
    done
    echo ""

    if [[ "$_DO_FORCE" -ne 1 ]]; then
        echo "[dotfiles] ERROR: refusing to take over links owned by another checkout."
        echo "           Leaving them would split this install across two repos."
        echo "           Re-run with --force to repoint them at $DOTFILES_DIR."
        echo ""
        exit 1
    fi

    log "--force given: repointing the above at $DOTFILES_DIR"
    for line in "${foreign[@]}"; do
        target="${line%%$'\t'*}"
        log "  removing $target"
        # Only the link is removed; the old checkout's content is left intact.
        rm -rf "$target"
    done
}

git_head()     { git -C "$1" rev-parse HEAD 2>/dev/null; }
git_describe() { git -C "$1" describe --tags --always --dirty 2>/dev/null || echo "unknown"; }
git_date()     { git -C "$1" log -1 --format=%cs 2>/dev/null || echo "unknown"; }

state_get() {
    [[ -f "$_STATE_FILE" ]] || return 1
    local v
    v="$(grep "^$1=" "$_STATE_FILE" 2>/dev/null | tail -1 | cut -d= -f2-)" || true
    [[ -n "$v" ]] && printf '%s\n' "$v"
}

# Shout if this checkout is behind whatever was installed last. Compares against
# the recorded install stamp, or against the old checkout when one was found
# still on disk during the relocation scan.
version_check() {
    local prev_sha prev_desc prev_date prev_src cur_sha behind

    prev_sha="$(state_get DOTFILES_INSTALLED_SHA || true)"
    prev_desc="$(state_get DOTFILES_INSTALLED_DESCRIBE || true)"
    prev_date="$(state_get DOTFILES_INSTALLED_DATE || true)"
    prev_src="$(state_get DOTFILES_INSTALLED_FROM || true)"

    if [[ -n "$_OLD_ROOT" && -d "$_OLD_ROOT/.git" ]]; then
        local old_sha
        old_sha="$(git_head "$_OLD_ROOT" || true)"
        if [[ -n "$old_sha" ]]; then
            prev_sha="$old_sha"
            prev_desc="$(git_describe "$_OLD_ROOT")"
            prev_date="$(git_date "$_OLD_ROOT")"
            prev_src="$_OLD_ROOT"
        fi
    fi

    [[ -n "$prev_sha" ]] || return 0
    cur_sha="$(git_head "$DOTFILES_DIR" || true)"
    [[ -n "$cur_sha" && "$cur_sha" != "$prev_sha" ]] || return 0

    # The previous commit has to be present here for the comparison to mean
    # anything; it will not be if that checkout was never fetched from.
    git -C "$DOTFILES_DIR" cat-file -e "${prev_sha}^{commit}" 2>/dev/null || return 0

    if git -C "$DOTFILES_DIR" merge-base --is-ancestor "$cur_sha" "$prev_sha" 2>/dev/null; then
        behind="$(git -C "$DOTFILES_DIR" rev-list --count "${cur_sha}..${prev_sha}" 2>/dev/null || echo "?")"
        echo ""
        echo "[dotfiles] ############################################################"
        echo "[dotfiles] #  WARNING: INSTALLING AN OLDER VERSION OF DOTFILES"
        echo "[dotfiles] ############################################################"
        echo "[dotfiles] #  installing : $(git_describe "$DOTFILES_DIR")  ($(git_date "$DOTFILES_DIR"))"
        echo "[dotfiles] #  previously : ${prev_desc:-$prev_sha}  (${prev_date:-unknown})"
        echo "[dotfiles] #  from       : ${prev_src:-unknown}"
        echo "[dotfiles] #"
        echo "[dotfiles] #  This checkout is $behind commit(s) BEHIND what is installed."
        echo "[dotfiles] #  Continuing will roll those changes back."
        echo "[dotfiles] ############################################################"
        echo ""
    elif ! git -C "$DOTFILES_DIR" merge-base --is-ancestor "$prev_sha" "$cur_sha" 2>/dev/null; then
        echo ""
        log "NOTE: this checkout has diverged from what was installed last"
        log "      installing : $(git_describe "$DOTFILES_DIR")"
        log "      previously : ${prev_desc:-$prev_sha} (${prev_src:-unknown})"
        echo ""
    fi
}

record_install() {
    local sha
    sha="$(git_head "$DOTFILES_DIR" || true)"
    [[ -n "$sha" ]] || return 0
    install -d "$_STATE_DIR"
    {
        echo "DOTFILES_INSTALLED_SHA=$sha"
        echo "DOTFILES_INSTALLED_DESCRIBE=$(git_describe "$DOTFILES_DIR")"
        echo "DOTFILES_INSTALLED_DATE=$(git_date "$DOTFILES_DIR")"
        echo "DOTFILES_INSTALLED_FROM=$DOTFILES_DIR"
    } > "$_STATE_FILE"
}

stow_package() {
    local pkg="$1"
    if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
        [[ "$_DO_FORCE" -eq 1 ]] && backup_conflicts "$pkg"
        log "Stowing $pkg"
        stow --dir="$DOTFILES_DIR" --target="$HOME" --restow "$pkg"
    else
        log "Skipping $pkg (directory not found)"
    fi
}

# Third-party installers (.pixel-agents) rewrite ~/.claude/settings.json from
# scratch, replacing the stow symlink with a plain file and dropping everything
# they did not author. Detect that and re-link, keeping a copy of whatever they
# wrote so its hooks can be merged back by hand.
heal_claude_settings() {
    local target="$HOME/.claude/settings.json"
    local src="$DOTFILES_DIR/claude/.claude/settings.json"

    [[ -f "$src" ]] || return 0
    [[ -e "$target" || -L "$target" ]] || return 0

    if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$src")" ]]; then
        return 0
    fi

    local stamp
    stamp="${_DATESTAMP:-$(date +%Y%m%d_%H%M%S)}"
    log "WARNING: $target is not the stow symlink — a third-party installer likely replaced it."
    log "Backing up $target -> ${target}.clobbered.${stamp}"
    mv "$target" "${target}.clobbered.${stamp}"
    ln -s "$(realpath --relative-to="$HOME/.claude" "$src")" "$target"
    log "Re-linked $target"
}

usage() {
    echo "Usage: $0 [--bootstrap] [--force] [packages...]"
    echo ""
    echo "Options:"
    echo "  --bootstrap   Run the host bootstrap script after stowing (scripts/bootstrap-<hostname>.sh)"
    echo "  --force       Back up conflicting files before stowing (backup extension: .YYYYMMDD_HHMMSS),"
    echo "                and take over symlinks left behind by another checkout of this repo."
    echo ""
    echo "If the repo has been moved or re-cloned, links from the old location are"
    echo "listed and the install aborts unless --force is given. The version actually"
    echo "being installed is compared against the last recorded install, and a"
    echo "downgrade is reported loudly before anything is changed."
    echo ""
    echo "Available packages:"
    for d in "$DOTFILES_DIR"/*/; do
        echo "  $(basename "$d")"
    done
    echo ""
    echo "With no arguments, installs all packages without running bootstrap."
}

main() {
    check_deps

    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    local do_bootstrap=0
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "--bootstrap" ]]; then
            do_bootstrap=1
        elif [[ "$arg" == "--force" ]]; then
            _DO_FORCE=1
            _DATESTAMP="$(date +%Y%m%d_%H%M%S)"
        else
            args+=("$arg")
        fi
    done

    local packages=("${args[@]+"${args[@]}"}")

    if [[ ${#packages[@]} -eq 0 ]]; then
        # Install all packages (skip hidden dirs and non-directories)
        while IFS= read -r -d '' dir; do
            packages+=("$(basename "$dir")")
        done < <(find "$DOTFILES_DIR" -maxdepth 1 -mindepth 1 -type d -not -name '.*' -print0 | sort -z)
    fi

    log "Installing dotfiles from $DOTFILES_DIR"

    # Both run before anything is stowed, so a stale or downgraded install is
    # reported while the tree is still untouched.
    check_relocation "${packages[@]}"
    version_check

    for pkg in "${packages[@]}"; do
        stow_package "$pkg"
    done

    heal_claude_settings
    expand_templates
    if [[ "$do_bootstrap" -eq 1 ]]; then
        run_host_bootstrap
    fi
    record_install
    post_install_reminders
    log "Done."
}

expand_templates() {
    local secrets="$HOME/.secrets.env"
    local tmpl_dir="$DOTFILES_DIR/templates"

    if [[ ! -f "$secrets" ]]; then
        echo ""
        echo "[dotfiles] ERROR: $secrets not found."
        echo "           Run: git-crypt unlock"
        echo "           Then re-run: ./install.sh"
        exit 1
    fi

    # If the file is still encrypted (binary/locked), sourcing it would fail.
    if ! grep -qI '' "$secrets" 2>/dev/null; then
        echo ""
        echo "[dotfiles] ERROR: $secrets is still encrypted."
        echo "           Run: git-crypt unlock"
        echo "           Then re-run: ./install.sh"
        exit 1
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
            OPENROUTER_API_KEY
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

        install -d "$HOME/.config"
        printf 'export OPENROUTER_API_KEY=%s\n' "$OPENROUTER_API_KEY" > "$HOME/.config/openrouter-env.sh"
        chmod 600 "$HOME/.config/openrouter-env.sh"
        log "Expanded openrouter-env.sh"
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
