#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# OpenClaw Android — Master Installer (10 Steps)
# ============================================================================
# Installs OpenClaw natively on Termux without proot or Ubuntu containers.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/install.log"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { printf "${CYAN}[INFO]${NC}  %s\n" "$*" | tee -a "$LOG_FILE"; }
ok()    { printf "${GREEN}[ OK ]${NC}  %s\n" "$*" | tee -a "$LOG_FILE"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*" | tee -a "$LOG_FILE"; }
error() { printf "${RED}[FAIL]${NC}  %s\n" "$*" | tee -a "$LOG_FILE"; exit 1; }

step() {
    local num="$1"; shift
    printf "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${BOLD}  Step %s/10: %s${NC}\n" "$num" "$*"
    printf "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# ── Source helpers ──────────────────────────────────────────────────────────
source_script() {
    local script="${SCRIPT_DIR}/$1"
    if [[ -f "$script" ]]; then
        source "$script"
    else
        error "Missing script: $1"
    fi
}

# ── Banner ──────────────────────────────────────────────────────────────────
banner() {
    printf "${BOLD}${CYAN}"
    cat << 'EOF'
   ___                    ____ _
  / _ \ _ __   ___ _ __  / ___| | __ ___      __
 | | | | '_ \ / _ \ '_ \| |   | |/ _` \ \ /\ / /
 | |_| | |_) |  __/ | | | |___| | (_| |\ V  V /
  \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/
       |_|           Android Installer v1.0
EOF
    printf "${NC}\n"
    printf "${DIM}  Native Termux install — no proot, no Ubuntu, no bloat${NC}\n\n"
}

# ── Elapsed timer ───────────────────────────────────────────────────────────
SECONDS=0
elapsed() {
    local mins=$((SECONDS / 60))
    local secs=$((SECONDS % 60))
    printf "${DIM}⏱  Elapsed: %dm %ds${NC}\n" "$mins" "$secs"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    banner

    # Initialize log
    echo "=== OpenClaw Android Install Log ===" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    # ── Step 1: Pre-flight Checks ───────────────────────────────────────
    step 1 "Pre-flight Checks"
    source_script "scripts/check-env.sh"
    run_preflight_checks
    ok "Environment ready"

    # ── Step 2: Install Termux Packages ─────────────────────────────────
    step 2 "Installing Termux Packages"
    source_script "scripts/install-deps.sh"
    install_dependencies
    ok "All packages installed"

    # ── Step 3: Configure Environment ───────────────────────────────────
    step 3 "Configuring Environment"
    source_script "scripts/setup-env.sh"
    setup_environment
    ok "Environment configured"

    # ── Step 4: Apply Native Patches ────────────────────────────────────
    step 4 "Applying Native Compatibility Patches"
    source_script "patches/apply-patches.sh"
    apply_all_patches
    ok "Patches applied"

    # ── Step 5: Install OpenClaw ────────────────────────────────────────
    step 5 "Installing OpenClaw"
    install_openclaw
    ok "OpenClaw installed"

    # ── Step 6: Configure OpenClaw ──────────────────────────────────────
    step 6 "Configuring OpenClaw"
    configure_openclaw
    ok "OpenClaw configured"

    # ── Step 7: Setup SSH Server ────────────────────────────────────────
    step 7 "Setting Up SSH Server"
    source_script "scripts/setup-ssh.sh"
    setup_ssh_server
    ok "SSH server configured (port 8022)"

    # ── Step 8: Setup tmux Session ──────────────────────────────────────
    step 8 "Setting Up tmux Session"
    source_script "scripts/setup-tmux.sh"
    setup_tmux_session
    ok "tmux session ready"

    # ── Step 9: Setup Auto-Start (Boot) ─────────────────────────────────
    step 9 "Configuring Auto-Start"
    source_script "scripts/setup-boot.sh"
    setup_boot_script
    ok "Auto-start configured"

    # ── Step 10: Verify Installation ────────────────────────────────────
    step 10 "Verifying Installation"
    source_script "tests/verify-install.sh"
    run_verification
    ok "All checks passed"

    # ── Done ────────────────────────────────────────────────────────────
    printf "\n"
    printf "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${BOLD}${GREEN}║          🦞  OpenClaw Installed Successfully!  🦞           ║${NC}\n"
    printf "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
    elapsed

    printf "\n${BOLD}Quick Start:${NC}\n"
    printf "  ${CYAN}1.${NC} Attach to the session:  ${BOLD}tmux attach -t openclaw${NC}\n"
    printf "  ${CYAN}2.${NC} SSH from another device: ${BOLD}ssh -p 8022 $(whoami)@<device-ip>${NC}\n"
    printf "  ${CYAN}3.${NC} Acquire wakelock:        ${BOLD}termux-wake-lock${NC}\n"
    printf "\n"
    printf "${DIM}Log saved to: ${LOG_FILE}${NC}\n"
    printf "${DIM}Troubleshooting: docs/troubleshooting.md${NC}\n\n"
}

# ── Step 5 Implementation ──────────────────────────────────────────────────
install_openclaw() {
    local OPENCLAW_DIR="${HOME}/openclaw"

    if [[ -d "${OPENCLAW_DIR}" ]]; then
        info "Existing OpenClaw directory found, updating..."
        cd "${OPENCLAW_DIR}"
        git pull --ff-only 2>/dev/null || {
            warn "Pull failed — performing clean reinstall"
            cd "${HOME}"
            rm -rf "${OPENCLAW_DIR}"
            git clone https://github.com/nicholasgasior/OpenClaw.git "${OPENCLAW_DIR}"
            cd "${OPENCLAW_DIR}"
        }
    else
        info "Cloning OpenClaw repository..."
        git clone https://github.com/nicholasgasior/OpenClaw.git "${OPENCLAW_DIR}"
        cd "${OPENCLAW_DIR}"
    fi

    info "Building OpenClaw..."

    # Create build directory
    mkdir -p build && cd build

    # Configure with Termux-compatible flags
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_C_FLAGS="-I${SCRIPT_DIR}/patches -Wno-error" \
        -DCMAKE_CXX_FLAGS="-I${SCRIPT_DIR}/patches -Wno-error" \
        2>&1 | tee -a "$LOG_FILE"

    # Build with available cores (leave 1 free)
    local JOBS=$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))
    info "Building with ${JOBS} parallel jobs..."
    make -j"${JOBS}" 2>&1 | tee -a "$LOG_FILE"

    # Install
    make install 2>&1 | tee -a "$LOG_FILE"

    cd "${SCRIPT_DIR}"
}

# ── Step 6 Implementation ──────────────────────────────────────────────────
configure_openclaw() {
    local CONFIG_DIR="${HOME}/.config/openclaw"
    local DATA_DIR="${HOME}/.local/share/openclaw"

    mkdir -p "${CONFIG_DIR}" "${DATA_DIR}"

    # Create default config if not exists
    if [[ ! -f "${CONFIG_DIR}/config.xml" ]]; then
        info "Creating default OpenClaw configuration..."
        cat > "${CONFIG_DIR}/config.xml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<Configuration>
    <Display>
        <Width>800</Width>
        <Height>600</Height>
        <Fullscreen>false</Fullscreen>
    </Display>
    <Audio>
        <Frequency>44100</Frequency>
        <SoundVolume>50</SoundVolume>
        <MusicVolume>50</MusicVolume>
    </Audio>
    <Assets>
        <RezArchive></RezArchive>
        <ResourceCacheSize>50</ResourceCacheSize>
    </Assets>
</Configuration>
XMLEOF
    else
        info "Existing config found, preserving..."
    fi

    # Ensure data directories
    mkdir -p "${DATA_DIR}/saves"
    mkdir -p "${DATA_DIR}/assets"

    ok "Config: ${CONFIG_DIR}/config.xml"
    ok "Data:   ${DATA_DIR}"
}

main "$@"
