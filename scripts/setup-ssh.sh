#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# SSH Server Setup — Configure OpenSSH for remote access
# ============================================================================

SSH_PORT=8022

setup_ssh_server() {
    info "Configuring SSH server on port ${SSH_PORT}..."

    # ── Generate host keys if missing ───────────────────────────────────
    if [[ ! -f "${PREFIX}/etc/ssh/ssh_host_rsa_key" ]]; then
        info "Generating SSH host keys..."
        ssh-keygen -A 2>&1 | tee -a "${LOG_FILE:-/dev/null}"
        ok "Host keys generated"
    else
        ok "Host keys already exist"
    fi

    # ── Configure sshd ──────────────────────────────────────────────────
    local SSHD_CONFIG="${PREFIX}/etc/ssh/sshd_config"

    # Back up original config
    if [[ -f "$SSHD_CONFIG" && ! -f "${SSHD_CONFIG}.bak" ]]; then
        cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"
    fi

    info "Writing sshd_config..."
    cat > "$SSHD_CONFIG" << SSHEOF
# OpenClaw Android — SSH Configuration
# Port (Termux cannot use ports below 1024)
Port ${SSH_PORT}

# Authentication
PrintMotd yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Security
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Subsystem
Subsystem sftp ${PREFIX}/libexec/sftp-server
SSHEOF

    ok "sshd_config written"

    # ── Set user password ───────────────────────────────────────────────
    info "Setting up SSH password..."
    local CURRENT_USER
    CURRENT_USER=$(whoami)

    if [[ -t 0 ]]; then
        # Interactive mode — prompt for password
        printf "\n${BOLD}Set a password for SSH access:${NC}\n"
        printf "${DIM}(User: ${CURRENT_USER}, Port: ${SSH_PORT})${NC}\n\n"
        passwd
    else
        # Non-interactive — generate random password
        local GEN_PASS
        GEN_PASS=$(head -c 12 /dev/urandom | base64 | tr -d '/+=' | head -c 10)
        printf "%s\n%s\n" "$GEN_PASS" "$GEN_PASS" | passwd 2>/dev/null || {
            warn "Could not set password automatically"
            warn "Please run 'passwd' manually to set your SSH password"
        }
        printf "\n"
        printf "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════╗${NC}\n"
        printf "${BOLD}${YELLOW}║  SSH Password (SAVE THIS):  %-24s ║${NC}\n" "$GEN_PASS"
        printf "${BOLD}${YELLOW}║  User: %-20s  Port: %-12s ║${NC}\n" "$CURRENT_USER" "$SSH_PORT"
        printf "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════╝${NC}\n"
        printf "\n"
    fi

    # ── Ensure .ssh directory ───────────────────────────────────────────
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    touch "${HOME}/.ssh/authorized_keys"
    chmod 600 "${HOME}/.ssh/authorized_keys"

    # ── Start SSHD ─────────────────────────────────────────────────────
    info "Starting SSH server..."
    pkill sshd 2>/dev/null || true
    sleep 1
    sshd 2>&1 | tee -a "${LOG_FILE:-/dev/null}" || warn "sshd failed to start"

    # Verify
    if pgrep -x sshd &>/dev/null; then
        ok "SSH server running on port ${SSH_PORT}"
        local DEVICE_IP
        DEVICE_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' || echo "<device-ip>")
        info "Connect: ssh -p ${SSH_PORT} ${CURRENT_USER}@${DEVICE_IP}"
    else
        warn "SSH server may not have started — check 'logcat' for details"
    fi
}
