#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

_DO_FORCE=0
_DO_PROXY=0
_DATESTAMP=""
_OLD_ROOT=""
_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
_STATE_FILE="$_STATE_DIR/install-state"

# Top-level directories that are not stow packages. templates/ holds
# envsubst inputs consumed by expand_templates() and scripts/ is run from the
# repo; stowing either drops its contents straight into $HOME, which is how
# ~/aws-credentials and friends appeared.
_NON_PACKAGES=(templates scripts vendor)

log() { echo "[dotfiles] $*"; }

is_package() {
    local candidate="$1" np
    for np in "${_NON_PACKAGES[@]}"; do
        [[ "$candidate" == "$np" ]] && return 1
    done
    return 0
}

check_secrets_unlocked() {
    local secrets_src="$DOTFILES_DIR/secrets/.secrets.env"

    # If secrets/ is not in the repo at all, nothing to check.
    [[ -d "$DOTFILES_DIR/secrets" ]] || return 0

    # git-crypt leaves encrypted files as binary blobs. grep -qI tests whether
    # the file contains only printable text; failure means it is still locked.
    if [[ ! -f "$secrets_src" ]] || ! grep -qI '' "$secrets_src" 2>/dev/null; then
        echo ""
        echo "[dotfiles] ERROR: secrets/.secrets.env is still encrypted (git-crypt is locked)."
        echo "           Run:   git-crypt unlock"
        echo "           Then re-run: ./install.sh"
        echo ""
        exit 1
    fi
}

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

        # When stow folds a package subdirectory into a single symlink,
        # $HOME/<rel> resolves *through* it to the package file itself. That
        # file is not a symlink, so the -f test below would treat it as a
        # conflict and mv the repo's own file out to a .<stamp> backup.
        local resolved_target
        resolved_target="$(readlink -f "$target" 2>/dev/null || true)"
        if [[ -n "$resolved_target" && "$resolved_target" == "$DOTFILES_DIR"/* ]]; then
            continue
        fi

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
    if ! is_package "$pkg"; then
        log "Refusing to stow $pkg (not a stow package; its contents belong in the repo)"
        return 0
    fi
    if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
        [[ "$_DO_FORCE" -eq 1 ]] && backup_conflicts "$pkg"
        log "Stowing $pkg"
        stow --dir="$DOTFILES_DIR" --target="$HOME" --restow "$pkg"
        if [[ "$pkg" == "claude" ]]; then generate_claude_settings_base; fi
    else
        log "Skipping $pkg (directory not found)"
    fi
}


usage() {
    echo "Usage: $0 [--proxy] [--force] [packages...]"
    echo ""
    echo "Options:"
    echo "  --proxy       Add HTTP_PROXY/HTTPS_PROXY env vars to the generated"
    echo "                ~/.claude/settings.local.json and VS Code Machine settings."
    echo "                Use on machines that reach llm-api.amd.com via a local tunnel"
    echo "                on localhost:8888. Default is no proxy (direct AMD network access)."
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
        is_package "$(basename "$d")" && echo "  $(basename "$d")"
    done
    echo ""
    echo "With no arguments, installs all packages without running bootstrap."
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    check_deps
    check_secrets_unlocked

    local args=()
    local pkg_name
    local argv=("$@")
    local i=0
    while [[ $i -lt ${#argv[@]} ]]; do
        local arg="${argv[$i]}"
        if [[ "$arg" == "--proxy" ]]; then
            _DO_PROXY=1
        elif [[ "$arg" == "--force" ]]; then
            _DO_FORCE=1
            _DATESTAMP="$(date +%Y%m%d_%H%M%S)"
        elif [[ "$arg" == --* ]]; then
            echo "ERROR: unknown option: $arg" >&2
            exit 1
        else
            args+=("$arg")
        fi
        i=$((i+1))
    done

    local packages=("${args[@]+"${args[@]}"}")
    local full_install=0

    if [[ ${#packages[@]} -eq 0 ]]; then
        full_install=1
        # Install all packages (skip hidden dirs, non-directories, non-packages)
        while IFS= read -r -d '' dir; do
            pkg_name="$(basename "$dir")"
            is_package "$pkg_name" && packages+=("$pkg_name")
        done < <(find "$DOTFILES_DIR" -maxdepth 1 -mindepth 1 -type d -not -name '.*' -print0 | sort -z)
    fi

    log "Installing dotfiles from $DOTFILES_DIR"

    init_submodules

    # Both run before anything is stowed, so a stale or downgraded install is
    # reported while the tree is still untouched.
    check_relocation "${packages[@]}"
    version_check

    for pkg in "${packages[@]}"; do
        stow_package "$pkg"
    done

    if [[ "$full_install" -eq 1 ]]; then
        expand_templates
        install_git_hooks
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
            DOCKER_USERNAME
            DOCKER_PAT
            GH_TOKEN_STEBATES_AMDENG
            GH_TOKEN_SBATES130272
            HF_TOKEN
            OPENROUTER_API_KEY
            ANTHROPIC_API_KEY
            ANTHROPIC_CUSTOM_HEADERS
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

        DOCKER_AUTH=$(printf '%s:%s' "$DOCKER_USERNAME" "$DOCKER_PAT" | base64 -w 0)
        export DOCKER_AUTH

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

        generate_claude_settings
        generate_vscode_settings
    )
    install_amd_skills
}

install_git_hooks() {
    local hooks_src="$DOTFILES_DIR/scripts/hooks"
    local hooks_dst="$DOTFILES_DIR/.git/hooks"
    [[ -d "$hooks_src" ]] || return 0
    for hook in "$hooks_src"/*; do
        local name
        name="$(basename "$hook")"
        if [[ -e "$hooks_dst/$name" ]]; then
            if [[ "${_DO_FORCE:-0}" -eq 1 ]]; then
                log "WARNING: overwriting existing git hook: $name (--force)"
                cp "$hook" "$hooks_dst/$name"
                chmod +x "$hooks_dst/$name"
            fi
        else
            cp "$hook" "$hooks_dst/$name"
            chmod +x "$hooks_dst/$name"
            log "Installed git hook: $name"
        fi
    done
}

init_submodules() {
    [[ -f "$DOTFILES_DIR/.gitmodules" ]] || return 0
    log "Initialising git submodules"
    git -C "$DOTFILES_DIR" submodule update --init --recursive
}

# Generate the portable (non-secret) portion of ~/.claude/settings.local.json
# from the template. Called every time the claude stow package is restowed so
# permissions and hooks are available without needing secrets to be present.
# Preserves any existing .env block written by generate_claude_settings().
generate_claude_settings_base() {
    local tmpl="$DOTFILES_DIR/templates/claude-settings-local.json"
    local out="$HOME/.claude/settings.local.json"
    local out_tmp
    out_tmp="$(dirname "$out")/.settings.local.json.tmp"

    [[ -f "$tmpl" ]] || return 0

    install -d "$HOME/.claude"

    local existing
    existing=$( [[ -f "$out" ]] && cat "$out" || echo '{}' )

    # $e * $t: template wins on all keys it defines (permissions, hooks, theme…).
    # The template has no .env key, so any existing .env block is preserved as-is.
    ( umask 077
      jq -n \
          --argjson e "$existing" \
          --argjson t "$(cat "$tmpl")" \
          '$e * $t' \
          > "$out_tmp"
      mv "$out_tmp" "$out" )
    chmod 600 "$out"
    log "Generated base $out"
}

# Generate ~/.claude/settings.local.json by merging three layers:
#   existing file (preserves keys from other tools) <- template (portable config wins)
# then inject the .env block: existing env + template env + secrets (secrets win).
# Called inside the expand_templates() subshell so secrets are already exported.
generate_claude_settings() {
    local tmpl="$DOTFILES_DIR/templates/claude-settings-local.json"
    local out="$HOME/.claude/settings.local.json"
    local out_tmp
    out_tmp="$(dirname "$out")/.settings.local.json.tmp"

    install -d "$HOME/.claude"

    local existing
    existing=$( [[ -f "$out" ]] && cat "$out" || echo '{}' )

    local env_add
    env_add=$(jq -n \
        --arg ca   "/etc/ssl/certs/ca-certificates.crt" \
        --arg hdrs "$ANTHROPIC_CUSTOM_HEADERS" \
        --arg key  "$ANTHROPIC_API_KEY" \
        '{NODE_EXTRA_CA_CERTS:$ca,ANTHROPIC_CUSTOM_HEADERS:$hdrs,ANTHROPIC_API_KEY:$key}')

    if [[ "$_DO_PROXY" -eq 1 ]]; then
        env_add=$(jq \
            '. + {HTTP_PROXY:"http://localhost:8888",HTTPS_PROXY:"http://localhost:8888",NO_PROXY:"localhost,127.0.0.1"}' \
            <<<"$env_add")
    fi

    ( umask 077
      jq -n \
          --argjson e "$existing" \
          --argjson t "$(cat "$tmpl")" \
          --argjson a "$env_add" \
          '$e * $t | .env = (($e.env // {}) * ($t.env // {}) * $a)' \
          > "$out_tmp"
      mv "$out_tmp" "$out" )
    chmod 600 "$out"
    log "Generated $out"
}

# Write ~/.vscode-server/data/Machine/settings.json so the VS Code extension
# picks up the AMD API gateway credentials and model names.
# Called inside the expand_templates() subshell so secrets are already exported.
generate_vscode_settings() {
    local vscode_settings="$HOME/.vscode-server/data/Machine/settings.json"
    install -d "$(dirname "$vscode_settings")"
    [[ -f "$vscode_settings" ]] || echo '{}' > "$vscode_settings"

    local proxy_url=""
    [[ "$_DO_PROXY" -eq 1 ]] && proxy_url="http://localhost:8888"

    python3 - "$vscode_settings" "$ANTHROPIC_CUSTOM_HEADERS" "$ANTHROPIC_API_KEY" "$proxy_url" <<'PYEOF'
import sys, json
path, custom_headers, api_key, proxy_url = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path) as f:
    s = json.load(f)
env = [
    {"name": "ANTHROPIC_CUSTOM_HEADERS",       "value": custom_headers},
    {"name": "ANTHROPIC_API_KEY",              "value": api_key},
    {"name": "NODE_EXTRA_CA_CERTS",            "value": "/etc/ssl/certs/ca-certificates.crt"},
    {"name": "ANTHROPIC_BASE_URL",             "value": "https://llm-api.amd.com/Anthropic"},
    {"name": "ANTHROPIC_MODEL",                "value": "Claude-Opus-5[1m]"},
    {"name": "ANTHROPIC_DEFAULT_OPUS_MODEL",   "value": "Claude-Opus-5[1m]"},
    {"name": "ANTHROPIC_DEFAULT_SONNET_MODEL", "value": "Claude-Sonnet-4.6"},
    {"name": "ANTHROPIC_DEFAULT_HAIKU_MODEL",  "value": "Claude-Haiku-4.5"},
]
if proxy_url:
    env += [
        {"name": "HTTP_PROXY",  "value": proxy_url},
        {"name": "HTTPS_PROXY", "value": proxy_url},
        {"name": "NO_PROXY",    "value": "localhost,127.0.0.1"},
    ]
s["claudeCode.environmentVariables"] = env
with open(path, "w") as f:
    json.dump(s, f, indent=4)
    f.write("\n")
PYEOF
    log "Generated $vscode_settings"
}

install_amd_skills() {
    local skills_src="$DOTFILES_DIR/vendor/amd-skills/skills"
    [[ -d "$skills_src" ]] || {
        echo "WARNING: $skills_src not found — run: git submodule update --init" >&2
        return 0
    }
    install -d "$HOME/.claude/skills"
    for _skill_dir in "$skills_src"/*/; do
        [[ -d "$_skill_dir" ]] || continue
        _skill_name="$(basename "$_skill_dir")"
        cp -r "$_skill_dir" "$HOME/.claude/skills/$_skill_name"
        log "Installed AMD skill: $_skill_name"
    done
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
