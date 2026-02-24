#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Termux:Boot Auto-Start — Survives device restarts
# ============================================================================
# Requires: Termux:Boot app from F-Droid
# The boot script directory: ~/.termux/boot/
# ============================================================================

setup_boot_script() {
    local BOOT_DIR="${HOME}/.termux/boot"
    local BOOT_SCRIPT="${BOOT_DIR}/openclaw-start.sh"

    # ── Create boot directory ───────────────────────────────────────────
    info "Setting up Termux:Boot directory..."
    mkdir -p "$BOOT_DIR"

    # ── Write boot script ───────────────────────────────────────────────
    info "Writing auto-start script..."
    cat > "$BOOT_SCRIPT" << 'BOOTEOF'
#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# OpenClaw Android — Termux:Boot Auto-Start Script
# ============================================================================
# This script runs automatically when the device boots (via Termux:Boot).
# ============================================================================

# Wait for system to stabilize
sleep 5

# Acquire wakelock to prevent Android from killing Termux
termux-wake-lock 2>/dev/null

# Start SSH server
sshd 2>/dev/null

# Start OpenClaw in a tmux session (if not already running)
if ! tmux has-session -t openclaw 2>/dev/null; then
    tmux new-session -d -s openclaw -n main
    tmux send-keys -t openclaw "openclaw" Enter
fi

# Log boot start
echo "$(date): OpenClaw auto-started" >> "${HOME}/openclaw-android/boot.log"
BOOTEOF

    chmod +x "$BOOT_SCRIPT"
    ok "Boot script: ${BOOT_SCRIPT}"

    # ── Check Termux:Boot availability ──────────────────────────────────
    if [[ -d "/data/data/com.termux.boot" ]] || pm list packages 2>/dev/null | grep -q "com.termux.boot"; then
        ok "Termux:Boot detected — auto-start is active"
    else
        warn "Termux:Boot app not detected"
        printf "  ${CYAN}Install from F-Droid:${NC} https://f-droid.org/packages/com.termux.boot/\n"
        printf "  ${DIM}Auto-start will activate once Termux:Boot is installed${NC}\n"
    fi

    # ── Termux properties ───────────────────────────────────────────────
    local TERMUX_PROPS="${HOME}/.termux/termux.properties"
    if [[ ! -f "$TERMUX_PROPS" ]]; then
        info "Creating termux.properties..."
        cat > "$TERMUX_PROPS" << 'PROPEOF'
# OpenClaw Android — Termux Properties
# Allow external apps to run Termux commands
allow-external-apps = true

# Wake lock notification
# Keeps the notification when wakelock is active
wake-lock-notification = true
PROPEOF
        ok "termux.properties created"
    fi

    info "Run 'termux-reload-settings' to apply properties"
}
