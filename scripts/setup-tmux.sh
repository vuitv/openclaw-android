#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# tmux Session Setup — Persistent OpenClaw session for the gateway
# ============================================================================

TMUX_SESSION="openclaw"

setup_tmux_session() {
    info "Configuring tmux..."

    # ── Write tmux config ───────────────────────────────────────────────
    local TMUX_CONF="${HOME}/.tmux.conf"

    if [[ ! -f "$TMUX_CONF" ]]; then
        info "Creating tmux configuration..."
        cat > "$TMUX_CONF" << 'TMUXEOF'
# OpenClaw Android — tmux Configuration

# Use 256 colors
set -g default-terminal "screen-256color"

# Increase scrollback buffer
set -g history-limit 10000

# Enable mouse support
set -g mouse on

# Status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left '#[fg=green]#S #[fg=cyan]| '
set -g status-right '#[fg=cyan]%Y-%m-%d %H:%M '
set -g status-interval 60

# Window settings
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Automatically rename windows
setw -g automatic-rename on

# Activity monitoring
setw -g monitor-activity on
set -g visual-activity off

# Reduce escape time (better for vim)
set -sg escape-time 10

# Keep session alive
set -g remain-on-exit off
set -g destroy-unattached off
TMUXEOF
        ok "tmux config: ${TMUX_CONF}"
    else
        ok "tmux config already exists"
    fi

    # ── Kill existing session if orphaned ───────────────────────────────
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        info "Existing tmux session '${TMUX_SESSION}' found"
        info "Killing old session..."
        tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    fi

    # ── Create new detached session ─────────────────────────────────────
    info "Creating tmux session '${TMUX_SESSION}'..."
    tmux new-session -d -s "$TMUX_SESSION" -n "main" 2>/dev/null || {
        warn "Could not create tmux session (may already exist)"
    }

    # Send initial commands to the session
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        tmux send-keys -t "$TMUX_SESSION" "cd ${HOME}" Enter
        tmux send-keys -t "$TMUX_SESSION" "echo '🦞 OpenClaw tmux session ready'" Enter
        tmux send-keys -t "$TMUX_SESSION" "echo 'Type: openclaw   to start'" Enter
        ok "tmux session '${TMUX_SESSION}' created"
    fi

    # ── Usage info ──────────────────────────────────────────────────────
    printf "\n"
    info "tmux Quick Reference:"
    printf "  ${CYAN}Attach:${NC}   tmux attach -t ${TMUX_SESSION}\n"
    printf "  ${CYAN}Detach:${NC}   Ctrl+B, then D\n"
    printf "  ${CYAN}Kill:${NC}     tmux kill-session -t ${TMUX_SESSION}\n"
    printf "  ${CYAN}List:${NC}     tmux ls\n"
    printf "\n"
}
