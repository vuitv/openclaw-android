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

    local REQUIRED_CMDS=(node npm git ssh sshd tmux)
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            check_pass "${cmd}: $(command -v "$cmd")"
        else
            check_fail "${cmd}: NOT FOUND"
        fi
    done

    # ── 3. Node.js Environment ──────────────────────────────────────────
    printf "\n${CYAN}[Node.js Environment]${NC}\n"

    local NPM_ROOT
    NPM_ROOT=$(npm root -g 2>/dev/null || echo "unknown")
    if [[ "$NPM_ROOT" != "unknown" ]]; then
        check_pass "npm global root: ${NPM_ROOT}"
    else
        check_warn "Could not determine npm global root"
    fi

    if [[ -n "${NODE_OPTIONS:-}" ]]; then
        check_pass "NODE_OPTIONS set: ${NODE_OPTIONS}"
    else
        check_warn "NODE_OPTIONS not set (bionic-compat may not be loaded)"
    fi

    # Check bionic-compat.js exists
    local COMPAT_JS="${HOME}/openclaw-android/patches/bionic-compat.js"
    if [[ -f "$COMPAT_JS" ]]; then
        check_pass "bionic-compat.js: ${COMPAT_JS}"
    else
        check_warn "bionic-compat.js not found"
    fi

    # ── 4. OpenClaw ────────────────────────────────────────────────────
    printf "\n${CYAN}[OpenClaw]${NC}\n"

    # Check Node.js & npm
    if command -v node &>/dev/null; then
        check_pass "Node.js: $(node --version 2>/dev/null)"
    else
        check_fail "Node.js: NOT FOUND"
    fi

    if command -v npm &>/dev/null; then
        check_pass "npm: $(npm --version 2>/dev/null)"
    else
        check_fail "npm: NOT FOUND"
    fi

    # Check openclaw npm package
    if command -v openclaw &>/dev/null; then
        local claw_ver
        claw_ver=$(openclaw --version 2>/dev/null || echo "installed")
        check_pass "openclaw: ${claw_ver} ($(command -v openclaw))"
    else
        check_fail "openclaw: NOT FOUND (run: npm install -g openclaw@latest)"
    fi

    # Check npm global package
    if npm list -g openclaw &>/dev/null 2>&1; then
        local npm_ver
        npm_ver=$(npm list -g openclaw --depth=0 2>/dev/null | grep openclaw || echo "?")
        check_pass "npm global: ${npm_ver}"
    else
        check_warn "openclaw not in npm global list"
    fi

    # Config
    if [[ -f "${HOME}/.config/openclaw/config.json" ]]; then
        check_pass "Config: ${HOME}/.config/openclaw/config.json"
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

    if [[ -f "${PREFIX}/bin/systemctl" ]]; then
        check_pass "systemctl stub installed"
    else
        check_warn "systemctl stub not found"
    fi

    local COMPAT_DIR="${PREFIX}/include/termux"
    if [[ -d "$COMPAT_DIR" ]]; then
        check_pass "Compat headers: ${COMPAT_DIR}"
    else
        check_warn "Compat headers not found"
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
