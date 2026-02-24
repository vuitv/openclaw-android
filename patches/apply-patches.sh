#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Apply Patches — Orchestrator for all Termux compatibility patches
# ============================================================================
# Applies all necessary patches to build OpenClaw natively on Termux:
#   1. renameat2 / RENAME_NOREPLACE compat header
#   2. POSIX spawn stubs
#   3. ar symlink fix (Termux uses llvm-ar)
#   4. Path fixes (/tmp → $PREFIX/tmp, etc.)
#   5. systemctl stub
#   6. --disable-warning bypass
# ============================================================================

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

apply_all_patches() {
    info "Applying Termux compatibility patches..."

    # ── 1. Install compat headers ───────────────────────────────────────
    info "Installing compatibility headers..."
    local INCLUDE_DIR="${PREFIX}/include/termux"
    mkdir -p "$INCLUDE_DIR"

    cp "${PATCH_DIR}/termux-compat.h" "$INCLUDE_DIR/"
    cp "${PATCH_DIR}/spawn.h" "${INCLUDE_DIR}/spawn-compat.h"
    ok "Headers installed to ${INCLUDE_DIR}"

    # ── 2. Fix 'ar' command (Termux uses llvm-ar) ──────────────────────
    info "Checking ar toolchain..."
    if ! command -v ar &>/dev/null; then
        if command -v llvm-ar &>/dev/null; then
            info "Creating ar → llvm-ar symlink..."
            ln -sf "$(command -v llvm-ar)" "${PREFIX}/bin/ar"
            ok "ar symlink: llvm-ar"
        else
            warn "'ar' not found and llvm-ar unavailable"
        fi
    else
        ok "ar: $(command -v ar)"
    fi

    # ── 3. Fix 'ranlib' command ─────────────────────────────────────────
    if ! command -v ranlib &>/dev/null; then
        if command -v llvm-ranlib &>/dev/null; then
            info "Creating ranlib → llvm-ranlib symlink..."
            ln -sf "$(command -v llvm-ranlib)" "${PREFIX}/bin/ranlib"
            ok "ranlib symlink: llvm-ranlib"
        fi
    fi

    # ── 4. Fix 'strip' command ──────────────────────────────────────────
    if ! command -v strip &>/dev/null; then
        if command -v llvm-strip &>/dev/null; then
            info "Creating strip → llvm-strip symlink..."
            ln -sf "$(command -v llvm-strip)" "${PREFIX}/bin/strip"
            ok "strip symlink: llvm-strip"
        fi
    fi

    # ── 5. Install systemctl stub ───────────────────────────────────────
    info "Installing systemctl stub..."
    local SYSTEMCTL_STUB="${PREFIX}/bin/systemctl"
    if [[ ! -f "$SYSTEMCTL_STUB" ]] || grep -q "OpenClaw stub" "$SYSTEMCTL_STUB" 2>/dev/null; then
        cp "${PATCH_DIR}/systemctl" "$SYSTEMCTL_STUB"
        chmod +x "$SYSTEMCTL_STUB"
        ok "systemctl stub installed"
    else
        warn "systemctl already exists (not overwriting)"
    fi

    # ── 6. Path patches ────────────────────────────────────────────────
    info "Ensuring Termux directory structure..."
    source "${PATCH_DIR}/patch-paths.sh"
    ensure_termux_dirs

    # Patch OpenClaw sources if they exist
    local OPENCLAW_DIR="${HOME}/openclaw"
    if [[ -d "$OPENCLAW_DIR" ]]; then
        info "Patching OpenClaw source paths..."
        patch_directory "$OPENCLAW_DIR" "c,cpp,h,hpp,cmake,txt"

        # Patch CMakeLists specifically
        if [[ -f "${OPENCLAW_DIR}/CMakeLists.txt" ]]; then
            patch_cmake_file "${OPENCLAW_DIR}/CMakeLists.txt"
        fi

        # Patch all nested CMakeLists
        find "$OPENCLAW_DIR" -name "CMakeLists.txt" -type f | while read -r cmake_file; do
            patch_cmake_file "$cmake_file"
        done
    fi

    # ── 7. Disable compiler warnings-as-errors ─────────────────────────
    info "Configuring compiler warning bypass..."
    export CFLAGS="${CFLAGS:-} -Wno-error -I${INCLUDE_DIR}"
    export CXXFLAGS="${CXXFLAGS:-} -Wno-error -I${INCLUDE_DIR}"

    # Some builds use CPPFLAGS
    export CPPFLAGS="${CPPFLAGS:-} -I${INCLUDE_DIR}"

    ok "Warning bypass configured"

    # ── 8. Ensure $PREFIX/tmp permissions ───────────────────────────────
    info "Setting temp directory permissions..."
    mkdir -p "${PREFIX}/tmp"
    chmod 1777 "${PREFIX}/tmp" 2>/dev/null || true
    ok "Temp dir: ${PREFIX}/tmp"

    # ── Summary ─────────────────────────────────────────────────────────
    printf "\n"
    info "Patch Summary:"
    printf "  ${CYAN}•${NC} termux-compat.h  (renameat2 + RENAME_NOREPLACE)\n"
    printf "  ${CYAN}•${NC} spawn-compat.h   (POSIX spawn fallback)\n"
    printf "  ${CYAN}•${NC} ar/ranlib/strip   (llvm toolchain symlinks)\n"
    printf "  ${CYAN}•${NC} systemctl stub    (no-op for service commands)\n"
    printf "  ${CYAN}•${NC} Path mappings     (/tmp → \$PREFIX/tmp, etc.)\n"
    printf "  ${CYAN}•${NC} Warning bypass    (-Wno-error)\n"
    printf "\n"
}
