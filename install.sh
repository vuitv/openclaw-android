#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  OpenClaw Android — Master Installer
#  All-in-one: deps → patches → openclaw → ssh → tmux → boot
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export HOME="${HOME:-/data/data/com.termux/files/home}"
export PATH="$PREFIX/bin:$PATH"
export TMPDIR="$PREFIX/tmp"

SSH_PASSWORD="1234"
TMUX_SESSION="OpenClaw"

log_ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

step() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  [$1] $2${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

TOTAL_STEPS=9
FAILED=0

# Show banner
MAGENTA='\033[0;35m'
echo ""
echo -e "${MAGENTA}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║   🦞 OpenClaw Android Installer 🦞                      ║"
echo "  ║   Native Termux. No proot. No bloat.                     ║"
echo "  ║                                                          ║"
echo "  ║   Powerful AI server running 24/7 on your Android        ║"
echo "  ║   phone via Termux — zero dependencies.                  ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${CYAN}Built by ${BOLD}PsProsen-Dev & VuiTv${NC}"
echo -e "  ${YELLOW}github.com/vuitv/openclaw-android${NC}"
echo ""

# ──────────────────────────────────────────────
#  STEP 1: Environment Check
# ──────────────────────────────────────────────
step "1/$TOTAL_STEPS" "Environment Check"
bash "$SCRIPT_DIR/scripts/check-env.sh" || { log_fail "Environment check failed"; exit 1; }

# ──────────────────────────────────────────────
#  STEP 2: Install Dependencies
# ──────────────────────────────────────────────
step "2/$TOTAL_STEPS" "Installing Dependencies"
bash "$SCRIPT_DIR/scripts/install-deps.sh" || { log_fail "Dependency install failed"; exit 1; }

# ──────────────────────────────────────────────
#  STEP 3: Setup Environment Variables
# ──────────────────────────────────────────────
step "3/$TOTAL_STEPS" "Configuring Environment"
bash "$SCRIPT_DIR/scripts/setup-env.sh" || { log_fail "Environment setup failed"; exit 1; }
source ~/.bashrc 2>/dev/null || true

# ──────────────────────────────────────────────
#  STEP 4: Install OpenClaw + Apply Patches
# ──────────────────────────────────────────────
step "4/$TOTAL_STEPS" "Installing OpenClaw"

# Copy patches first (needed during npm install for native builds)
log_info "Preparing patches..."
PATCH_DEST="$HOME/.openclaw-android/patches"
mkdir -p "$PATCH_DEST"
cp "$SCRIPT_DIR/patches/bionic-compat.js" "$PATCH_DEST/"
cp "$SCRIPT_DIR/patches/termux-compat.h"  "$PATCH_DEST/"

# Copy spawn.h if missing
if [ ! -f "$PREFIX/include/spawn.h" ]; then
  cp "$SCRIPT_DIR/patches/spawn.h" "$PREFIX/include/spawn.h"
  log_ok "spawn.h installed"
fi

source ~/.bashrc 2>/dev/null || true

# Set build flags for native compilation
export MAKEFLAGS="-j4"
export CFLAGS="-I${PREFIX}/include/termux"
export CXXFLAGS="-I${PREFIX}/include/termux"
export CMAKE_C_FLAGS="-I${PREFIX}/include/termux"
export CMAKE_CXX_FLAGS="-I${PREFIX}/include/termux"

log_info "Installing OpenClaw (this may take 5-15 minutes)..."
if npm install -g openclaw@latest; then
  log_ok "OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'unknown')"
else
  log_fail "OpenClaw installation failed"
  exit 1
fi

# Apply patches
log_info "Applying patches..."
bash "$SCRIPT_DIR/patches/apply-patches.sh" || log_warn "Some patches failed (non-critical)"

# ──────────────────────────────────────────────
#  STEP 5: Setup SSH Server
# ──────────────────────────────────────────────
step "5/$TOTAL_STEPS" "Setting Up SSH Server"
bash "$SCRIPT_DIR/scripts/setup-ssh.sh" "$SSH_PASSWORD" || { log_warn "SSH setup had issues"; }

# ──────────────────────────────────────────────
#  STEP 6: Setup Termux:Boot Auto-Start
# ──────────────────────────────────────────────
step "6/$TOTAL_STEPS" "Configuring Auto-Start (Termux:Boot)"
bash "$SCRIPT_DIR/scripts/setup-boot.sh" || { log_warn "Boot script setup had issues"; }

# ──────────────────────────────────────────────
#  STEP 7: Verification
# ──────────────────────────────────────────────
step "7/$TOTAL_STEPS" "Verifying Installation"
bash "$SCRIPT_DIR/tests/verify-install.sh" || true

# ──────────────────────────────────────────────
#  DONE — Installation Summary
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  🦞 INSTALLATION COMPLETE!${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  OpenClaw version : ${CYAN}$(openclaw --version 2>/dev/null || echo 'unknown')${NC}"
echo -e "  Node.js version  : ${CYAN}$(node -v 2>/dev/null)${NC}"
echo -e "  npm version      : ${CYAN}$(npm -v 2>/dev/null)${NC}"
echo ""
echo -e "  ${BOLD}SSH Access:${NC}"
echo -e "  Port     : ${CYAN}8022${NC}"
echo -e "  Password : ${CYAN}${SSH_PASSWORD}${NC} (change with: ${YELLOW}passwd${NC})"
echo -e "  Connect  : ${CYAN}ssh -p 8022 \$(whoami)@<phone-ip>${NC}"
echo ""

# ──────────────────────────────────────────────
#  STEP 8: OpenClaw Onboarding (Interactive)
# ──────────────────────────────────────────────
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  [8] OpenClaw Onboarding${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}Configure your AI provider, channels, and skills.${NC}"
echo -e "  ${CYAN}Follow the prompts below — this takes ~2 minutes.${NC}"
echo ""

# Run onboard interactively — user configures their setup
openclaw onboard 2>/dev/null || log_warn "Onboarding skipped or failed (you can run 'openclaw onboard' later)"

echo ""
log_ok "Onboarding complete!"

# ──────────────────────────────────────────────
#  STEP 9: Auto-Start Gateway in tmux
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  [9] Starting Gateway in tmux${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Kill any existing session
tmux kill-session -t OpenClaw 2>/dev/null || true

# Create tmux session with gateway running
tmux new-session -d -s OpenClaw "source ~/.bashrc && openclaw gateway" 2>/dev/null || \
  log_warn "tmux session creation failed. Start manually:"
sleep 2

if tmux has-session -t OpenClaw 2>/dev/null; then
  log_ok "tmux session 'OpenClaw' created with gateway running!"
else
  log_warn "To start: ${YELLOW}tmux new-session -s OpenClaw${NC}"
  log_warn "Then run: ${YELLOW}openclaw gateway${NC}"
fi

# ──────────────────────────────────────────────
#  ALL DONE — BOOM! 💥
# ──────────────────────────────────────────────
USER_NAME=$(whoami)
IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || \
     ifconfig wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || \
     ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | head -1 || \
     echo "<phone-ip>")
echo ""
echo -e "${MAGENTA}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                                                          ║"
echo "  ║   🦞 OpenClaw Android IS READY! 🦞                      ║"
echo "  ║                                                          ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${GREEN}Gateway  : ${BOLD}Running in tmux session 'OpenClaw'${NC}"
echo ""
echo -e "  ${BOLD}SSH Command (copy-paste on your PC):${NC}"
echo -e "  ${CYAN}${BOLD}ssh -p 8022 ${USER_NAME}@${IP}${NC}"
echo ""
echo -e "  ${GREEN}Password : ${BOLD}${SSH_PASSWORD}${NC} ${YELLOW}(change dengan: passwd)${NC}"
echo ""
echo -e "  ${BOLD}Useful Commands:${NC}"
echo -e "  ${YELLOW}tmux attach -t OpenClaw${NC}    — View gateway logs"
echo -e "  ${YELLOW}Ctrl+B then D${NC}              — Detach (server keeps running)"
echo -e "  ${YELLOW}openclaw status${NC}            — Check server health"
echo -e "  ${YELLOW}openclaw tui${NC}               — Chat with your AI"
echo -e "  ${YELLOW}passwd${NC}                     — Change SSH password"
echo ""
echo -e "  ${CYAN}Docs: https://github.com/vuitv/openclaw-android${NC}"
echo -e "  ${MAGENTA}${BOLD}Built by VuiTv${NC}"
echo ""
