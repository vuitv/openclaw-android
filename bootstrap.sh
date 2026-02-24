`#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# OpenClaw Android — Bootstrap Installer
# ============================================================================
# Usage (curl one-liner):
#   curl -fsSL https://raw.githubusercontent.com/user/openclaw-android/main/bootstrap.sh | bash
#
# Or clone and run:
#   git clone https://github.com/user/openclaw-android.git
#   cd openclaw-android && bash bootstrap.sh
# ============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; exit 1; }

# ── Banner ──────────────────────────────────────────────────────────────────
banner() {
    printf "${BOLD}${CYAN}"
    cat << 'EOF'
   ___                    ____ _
  / _ \ _ __   ___ _ __  / ___| | __ ___      __
 | | | | '_ \ / _ \ '_ \| |   | |/ _` \ \ /\ / /
 | |_| | |_) |  __/ | | | |___| | (_| |\ V  V /
  \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/
       |_|           Android Installer
EOF
    printf "${NC}\n"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    banner

    # Ensure we're running inside Termux
    if [[ -z "${TERMUX_VERSION:-}" && ! -d "/data/data/com.termux" ]]; then
        error "This script must be run inside Termux on Android."
    fi

    INSTALL_DIR="${HOME}/openclaw-android"
    REPO_URL="https://github.com/user/openclaw-android.git"

    # If running from a pipe (curl | bash), clone the repo first
    if [[ ! -f "install.sh" ]]; then
        info "Downloading OpenClaw Android installer..."

        # Install git if missing
        if ! command -v git &>/dev/null; then
            info "Installing git..."
            pkg install -y git 2>/dev/null || apt install -y git
        fi

        if [[ -d "${INSTALL_DIR}" ]]; then
            warn "Existing installation found at ${INSTALL_DIR}"
            info "Updating..."
            cd "${INSTALL_DIR}"
            git pull --ff-only 2>/dev/null || {
                warn "Git pull failed, re-cloning..."
                cd "${HOME}"
                rm -rf "${INSTALL_DIR}"
                git clone "${REPO_URL}" "${INSTALL_DIR}"
                cd "${INSTALL_DIR}"
            }
        else
            git clone "${REPO_URL}" "${INSTALL_DIR}"
            cd "${INSTALL_DIR}"
        fi
    fi

    # Ensure install.sh exists
    if [[ ! -f "install.sh" ]]; then
        error "install.sh not found. Please check the repository."
    fi

    # Make all scripts executable
    find . -name "*.sh" -exec chmod +x {} \;

    ok "Bootstrap complete — launching installer..."
    printf "\n"

    # Hand off to the master installer
    exec bash install.sh "$@"
}

main "$@"
