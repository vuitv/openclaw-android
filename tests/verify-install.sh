#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Verify Installation — Post-install health check
# ============================================================================
# Runs a comprehensive set of checks to validate that OpenClaw was installed
# correctly and all services are operational.
# ============================================================================

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

check_pass() {
    printf "  ${GREEN}✔${NC}  %s\n" "$*"
    ((CHECKS_PASSED++))
}

check_fail() {
    printf "  ${RED}✘${NC}  %s\n" "$*"
    ((CHECKS_FAILED++))
}

check_warn() {
    printf "  ${YELLOW}⚠${NC}  %s\n" "$*"
    ((CHECKS_WARNED++))
}

run_verification() {
    printf "\n${BOLD}Running post-install verification...${NC}\n\n"

    local PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

    # ── 1. Termux environment ──────────────────────────────────────────
    printf "${CYAN}[Environment]${NC}\n"

    if [[ -d "$PREFIX" ]]; then
        check_pass "Termux PREFIX exists: ${PREFIX}"
    else
        check_fail "Termux PREFIX missing: ${PREFIX}"
    fi

    if [[ -d "${PREFIX}/tmp" ]]; then
        check_pass "Temp directory exists: ${PREFIX}/tmp"
    else
        check_fail "Temp directory missing: ${PREFIX}/tmp"
    fi

    if [[ -n "${TMPDIR:-}" ]]; then
        check_pass "TMPDIR is set: ${TMPDIR}"
    else
        check_warn "TMPDIR not set in current session"
    fi

    # ── 2. Required commands ───────────────────────────────────────────
    printf "\n${CYAN}[Required Commands]${NC}\n"

    local REQUIRED_CMDS=(gcc g++ cmake git make ssh sshd tmux pkg-config)
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            check_pass "${cmd}: $(command -v "$cmd")"
        else
            check_fail "${cmd}: NOT FOUND"
        fi
    done

    # ── 3. Libraries ───────────────────────────────────────────────────
    printf "\n${CYAN}[Libraries]${NC}\n"

    local REQUIRED_LIBS=(sdl2 SDL2_image SDL2_mixer SDL2_ttf SDL2_gfx tinyxml2 zlib)
    for lib in "${REQUIRED_LIBS[@]}"; do
        if pkg-config --exists "$lib" 2>/dev/null; then
            local ver
            ver=$(pkg-config --modversion "$lib" 2>/dev/null || echo "?")
            check_pass "${lib}: ${ver}"
        else
            # Try alternate names
            local alt_lib=$(echo "$lib" | tr '[:upper:]' '[:lower:]')
            if pkg-config --exists "$alt_lib" 2>/dev/null; then
                check_pass "${lib} (as ${alt_lib})"
            else
                check_warn "${lib}: not found via pkg-config (may still work)"
            fi
        fi
    done

    # ── 4. OpenClaw ────────────────────────────────────────────────────
    printf "\n${CYAN}[OpenClaw]${NC}\n"

    local OPENCLAW_DIR="${HOME}/openclaw"
    if [[ -d "$OPENCLAW_DIR" ]]; then
        check_pass "Source directory: ${OPENCLAW_DIR}"
    else
        check_fail "Source directory missing: ${OPENCLAW_DIR}"
    fi

    if [[ -d "${OPENCLAW_DIR}/build" ]]; then
        check_pass "Build directory exists"
    else
        check_fail "Build directory missing"
    fi

    if command -v openclaw &>/dev/null; then
        check_pass "openclaw binary: $(command -v openclaw)"
    elif [[ -f "${OPENCLAW_DIR}/build/openclaw" ]]; then
        check_pass "openclaw binary: ${OPENCLAW_DIR}/build/openclaw"
    elif [[ -f "${PREFIX}/bin/openclaw" ]]; then
        check_pass "openclaw binary: ${PREFIX}/bin/openclaw"
    else
        check_warn "openclaw binary not found in PATH"
    fi

    # Config
    if [[ -f "${HOME}/.config/openclaw/config.xml" ]]; then
        check_pass "Config: ${HOME}/.config/openclaw/config.xml"
    else
        check_warn "Config file not found"
    fi

    # ── 5. SSH ─────────────────────────────────────────────────────────
    printf "\n${CYAN}[SSH Server]${NC}\n"

    if pgrep -x sshd &>/dev/null; then
        check_pass "sshd is running"
    else
        check_warn "sshd is not running (start with: sshd)"
    fi

    if [[ -f "${PREFIX}/etc/ssh/sshd_config" ]]; then
        local ssh_port
        ssh_port=$(grep -E "^Port " "${PREFIX}/etc/ssh/sshd_config" 2>/dev/null | awk '{print $2}')
        if [[ -n "$ssh_port" ]]; then
            check_pass "SSH port: ${ssh_port}"
        else
            check_warn "SSH port not configured"
        fi
    else
        check_fail "sshd_config missing"
    fi

    if [[ -f "${HOME}/.ssh/authorized_keys" ]]; then
        local key_count
        key_count=$(wc -l < "${HOME}/.ssh/authorized_keys" 2>/dev/null || echo "0")
        check_pass "authorized_keys: ${key_count} key(s)"
    else
        check_warn "No authorized_keys file"
    fi

    # ── 6. tmux ────────────────────────────────────────────────────────
    printf "\n${CYAN}[tmux]${NC}\n"

    if command -v tmux &>/dev/null; then
        check_pass "tmux: $(tmux -V 2>/dev/null || echo 'installed')"
    else
        check_fail "tmux not installed"
    fi

    if tmux has-session -t openclaw 2>/dev/null; then
        check_pass "tmux session 'openclaw' active"
    else
        check_warn "tmux session 'openclaw' not running"
    fi

    if [[ -f "${HOME}/.tmux.conf" ]]; then
        check_pass "tmux config: ~/.tmux.conf"
    else
        check_warn "tmux config not found"
    fi

    # ── 7. Boot / Auto-start ──────────────────────────────────────────
    printf "\n${CYAN}[Auto-Start]${NC}\n"

    if [[ -f "${HOME}/.termux/boot/openclaw-start.sh" ]]; then
        check_pass "Boot script installed"
        if [[ -x "${HOME}/.termux/boot/openclaw-start.sh" ]]; then
            check_pass "Boot script is executable"
        else
            check_fail "Boot script is not executable"
        fi
    else
        check_warn "Boot script not installed"
    fi

    # ── 8. Patches ─────────────────────────────────────────────────────
    printf "\n${CYAN}[Patches]${NC}\n"

    if [[ -f "${PREFIX}/include/termux/termux-compat.h" ]]; then
        check_pass "termux-compat.h installed"
    else
        check_warn "termux-compat.h not found"
    fi

    if [[ -f "${PREFIX}/bin/systemctl" ]]; then
        check_pass "systemctl stub installed"
    else
        check_warn "systemctl stub not found"
    fi

    if command -v ar &>/dev/null; then
        check_pass "ar command available"
    else
        check_fail "ar command missing"
    fi

    # ── Summary ────────────────────────────────────────────────────────
    printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${BOLD}  Verification Results${NC}\n"
    printf "  ${GREEN}Passed:${NC}  %d\n" "$CHECKS_PASSED"
    printf "  ${YELLOW}Warned:${NC}  %d\n" "$CHECKS_WARNED"
    printf "  ${RED}Failed:${NC}  %d\n" "$CHECKS_FAILED"
    printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if [[ $CHECKS_FAILED -gt 0 ]]; then
        printf "\n${RED}${BOLD}Some checks failed.${NC} See docs/troubleshooting.md for help.\n"
        return 1
    elif [[ $CHECKS_WARNED -gt 0 ]]; then
        printf "\n${YELLOW}${BOLD}All critical checks passed${NC} (${CHECKS_WARNED} warnings)\n"
        return 0
    else
        printf "\n${GREEN}${BOLD}All checks passed!${NC}\n"
        return 0
    fi
}

# Allow standalone execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
    run_verification
fi
