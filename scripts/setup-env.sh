#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Environment Setup — Configure .bashrc and shell environment
# ============================================================================

setup_environment() {
    local BASHRC="${HOME}/.bashrc"
    local MARKER_START="# >>> OpenClaw Android >>>"
    local MARKER_END="# <<< OpenClaw Android <<<"

    # ── Create $PREFIX/tmp if missing ───────────────────────────────────
    log_info "Ensuring temp directories..."
    mkdir -p "${PREFIX}/tmp"
    chmod 1777 "${PREFIX}/tmp" 2>/dev/null || true

    # ── Set up environment in .bashrc ───────────────────────────────────
    log_info "Configuring shell environment..."

    # Remove old OpenClaw block if present
    if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
        log_info "Removing old OpenClaw environment block..."
        sed -i "/${MARKER_START}/,/${MARKER_END}/d" "$BASHRC"
    fi

    # Detect patch directory location
    local PATCH_DIR="${HOME}/.openclaw-android/patches"

    cat >> "$BASHRC" << ENVEOF

$MARKER_START
# Temp directories
export TMPDIR="\${PREFIX}/tmp"
export TMP="\$TMPDIR"
export TEMP="\$TMPDIR"

# Node.js compatibility patches
export NODE_OPTIONS="-r $PATCH_DIR/bionic-compat.js"

# Bypass systemd checks
export CONTAINER=1

# C/C++ compatibility (renameat2, RENAME_NOREPLACE)
export CXXFLAGS="-include $PATCH_DIR/termux-compat.h"
export CFLAGS="-include $PATCH_DIR/termux-compat.h"
export CMAKE_CXX_FLAGS="-include $PATCH_DIR/termux-compat.h"
export CMAKE_C_FLAGS="-include $PATCH_DIR/termux-compat.h"

# node-gyp OS detection override
export GYP_DEFINES="OS=linux android_ndk_path=''"

# Fix: Skip OpenClaw's broken --disable-warning respawn on Node v24+
export OPENCLAW_NODE_OPTIONS_READY=1

# glib/vips headers for sharp builds
export CPATH="\$PREFIX/include/glib-2.0:\$PREFIX/lib/glib-2.0/include:\$CPATH"

# OpenClaw convenience aliases
alias claw-start='tmux new-session -d -s openclaw "openclaw" 2>/dev/null || tmux attach -t openclaw'
alias claw-stop='tmux kill-session -t openclaw 2>/dev/null'
alias claw-log='cat \${HOME}/.openclaw-android/install.log 2>/dev/null || echo "Log not found"'
alias claw-update='npm install -g openclaw@latest'
alias wakelock='termux-wake-lock'
alias wakeunlock='termux-wake-unlock'

# PATH
export PATH="\$PREFIX/bin:\$HOME/.local/bin:\$PATH"
$MARKER_END
ENVEOF

    log_ok ".bashrc updated"

    # ── Create local bin directory ──────────────────────────────────────
    mkdir -p "${HOME}/.local/bin"

    # ── Wakelock hint ───────────────────────────────────────────────────
    log_info "Acquiring wakelock to prevent Android from killing the process..."
    if command -v termux-wake-lock &>/dev/null; then
        termux-wake-lock 2>/dev/null || log_warn "Wakelock failed (Termux:API may not be installed)"
        log_ok "Wakelock acquired"
    else
        log_warn "termux-wake-lock not available — install Termux:API app for wakelock support"
    fi
}

