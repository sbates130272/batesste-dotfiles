# ~/.profile: executed by the command interpreter for login shells.
# Not read by bash(1) if ~/.bash_profile or ~/.bash_login exists.

#umask 022

# Include .bashrc if running bash
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# Include ~/bin in PATH if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# Include ~/.local/bin in PATH if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# ROCm WSL environment
if [ -f "$HOME/.config/rocm/wsl-env.sh" ]; then
  . "$HOME/.config/rocm/wsl-env.sh"
fi

# Claude Code gateway env (also sourced from .bashrc; harmless if repeated)
if [ -f "$HOME/.config/claude/env.sh" ]; then
  . "$HOME/.config/claude/env.sh"
fi
