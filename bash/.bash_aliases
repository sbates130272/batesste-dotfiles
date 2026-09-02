# Shell aliases and guarded commands.
# Sourced by ~/.bashrc. Guarded commands use _require_binary so they exist on
# all nodes but print a helpful error if the underlying binary is absent.

_require_binary() {
    local bin="$1"; shift
    if command -v "$bin" &>/dev/null; then
        "$bin" "$@"
    else
        echo "${FUNCNAME[1]}: requires '$bin', not found on this node" >&2
        return 1
    fi
}

# SLURM: formatted node info for a given partition (default: storage)
sinfo-sb() { _require_binary sinfo -o "%26N %7P %6t %6c %8m %70f %30G %20i %E" -N -p "${1:-storage}"; }
