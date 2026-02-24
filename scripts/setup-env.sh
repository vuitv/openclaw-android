#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Environment Setup — Configure .bashrc and shell environment
# ============================================================================

setup_environment() {
    local BASHRC="${HOME}/.bashrc"
    local MARKER="# === OpenClaw Android Environment ==="

    # ── Create $PREFIX/tmp if missing ───────────────────────────────────
    info "Ensuring temp directories..."
    mkdir -p "${PREFIX}/tmp"
    chmod 1777 "${PREFIX}/tmp" 2>/dev/null || true

    # ── Set up environment in .bashrc ───────────────────────────────────
    info "Configuring shell environment..."

    # Remove old OpenClaw block if present
    if grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
        info "Removing old OpenClaw environment block..."
        sed -i "/${MARKER}/,/# === End OpenClaw ===/d" "$BASHRC"
    fi

    cat >> "$BASHRC" << 'ENVEOF'
# === OpenClaw Android Environment ===
# Termux paths
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="${PREFIX}/tmp"
export TEMP="${TMPDIR}"
export TMP="${TMPDIR}"

# Node.js / npm
export NODE_OPTIONS="--require=${HOME}/openclaw-android/patches/bionic-compat.js"

# OpenClaw
export OPENCLAW_DATA="${HOME}/.local/share/openclaw"
export OPENCLAW_CONFIG="${HOME}/.config/openclaw"

# Convenience aliases
alias claw-start='tmux new-session -d -s openclaw "openclaw" 2>/dev/null || tmux attach -t openclaw'
alias claw-stop='tmux kill-session -t openclaw 2>/dev/null'
alias claw-log='cat ${HOME}/openclaw-android/install.log'
alias claw-update='npm install -g openclaw@latest'
alias wakelock='termux-wake-lock'
alias wakeunlock='termux-wake-unlock'

# Path
export PATH="${PREFIX}/bin:${HOME}/.local/bin:${PATH}"
# === End OpenClaw ===
ENVEOF

    ok ".bashrc updated"

    # ── Export for current session ──────────────────────────────────────
    export TMPDIR="${PREFIX}/tmp"
    export TEMP="${TMPDIR}"
    export TMP="${TMPDIR}"
    export NODE_OPTIONS="--require=${HOME}/openclaw-android/patches/bionic-compat.js"

    # ── Create local bin directory ──────────────────────────────────────
    mkdir -p "${HOME}/.local/bin"

    # ── Wakelock hint ───────────────────────────────────────────────────
    info "Acquiring wakelock to prevent Android from killing the process..."
    if command -v termux-wake-lock &>/dev/null; then
        termux-wake-lock 2>/dev/null || warn "Wakelock failed (Termux:API may not be installed)"
        ok "Wakelock acquired"
    else
        warn "termux-wake-lock not available — install Termux:API app for wakelock support"
    fi
}
