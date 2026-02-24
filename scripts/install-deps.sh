#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Install Dependencies — All required Termux packages
# ============================================================================

# Core packages required for running OpenClaw
CORE_PACKAGES=(
    nodejs
    git
    wget
    curl
)

# Build tools (needed for native npm modules)
BUILD_PACKAGES=(
    build-essential
    python3
    pkg-config
)

# Infrastructure packages
INFRA_PACKAGES=(
    openssh
    tmux
    termux-services
    termux-tools
)

# Optional but useful
OPTIONAL_PACKAGES=(
    nano
    htop
    ncurses-utils
)

install_dependencies() {
    info "Refreshing package lists..."
    pkg update -y 2>&1 | tail -3 | tee -a "${LOG_FILE:-/dev/null}"

    # Upgrade existing packages first
    info "Upgrading existing packages..."
    pkg upgrade -y 2>&1 | tail -3 | tee -a "${LOG_FILE:-/dev/null}"

    # ── Core packages ───────────────────────────────────────────────────
    info "Installing core packages (Node.js, git, curl)..."
    for pkg_name in "${CORE_PACKAGES[@]}"; do
        install_pkg "$pkg_name"
    done

    # ── Build packages (for native npm modules) ─────────────────────────
    info "Installing build tools for native modules..."
    for pkg_name in "${BUILD_PACKAGES[@]}"; do
        install_pkg "$pkg_name"
    done

    # ── Infrastructure packages ─────────────────────────────────────────
    info "Installing infrastructure (SSH, tmux, services)..."
    for pkg_name in "${INFRA_PACKAGES[@]}"; do
        install_pkg "$pkg_name"
    done

    # ── Optional packages ───────────────────────────────────────────────
    info "Installing optional tools..."
    for pkg_name in "${OPTIONAL_PACKAGES[@]}"; do
        install_pkg "$pkg_name" || warn "Optional package ${pkg_name} failed (non-fatal)"
    done

    # ── Verify critical tools ───────────────────────────────────────────
    info "Verifying critical tools..."
    local CRITICAL_CMDS=(node npm git ssh tmux)
    for cmd in "${CRITICAL_CMDS[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            ok "  ${cmd}: $(command -v "$cmd")"
        else
            error "Critical command not found: ${cmd}"
        fi
    done
}

install_pkg() {
    local name="$1"
    if dpkg -s "$name" &>/dev/null 2>&1; then
        printf "  ${DIM}%-25s already installed${NC}\n" "$name"
        return 0
    fi
    printf "  Installing %-25s" "$name..."
    if pkg install -y "$name" >> "${LOG_FILE:-/dev/null}" 2>&1; then
        printf "${GREEN}done${NC}\n"
        return 0
    else
        printf "${RED}FAILED${NC}\n"
        return 1
    fi
}
