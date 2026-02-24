#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Pre-flight Checks — Validate Termux environment before installation
# ============================================================================

run_preflight_checks() {
    local errors=0

    # ── Check: Running inside Termux ────────────────────────────────────
    info "Checking Termux environment..."
    if [[ -z "${PREFIX:-}" ]]; then
        export PREFIX="/data/data/com.termux/files/usr"
    fi

    if [[ ! -d "$PREFIX" ]]; then
        error "Cannot find Termux prefix at ${PREFIX}. Are you running inside Termux?"
    fi
    ok "Termux prefix: ${PREFIX}"

    # ── Check: Architecture ─────────────────────────────────────────────
    local ARCH
    ARCH=$(uname -m)
    info "Architecture: ${ARCH}"
    case "$ARCH" in
        aarch64|arm64)
            ok "Architecture supported (64-bit ARM)"
            ;;
        armv7l|armv8l)
            warn "32-bit ARM detected — may have limited support"
            ;;
        x86_64)
            ok "Architecture supported (x86_64)"
            ;;
        *)
            error "Unsupported architecture: ${ARCH}"
            ;;
    esac

    # ── Check: Storage permission ───────────────────────────────────────
    info "Checking storage access..."
    if [[ -d "${HOME}/storage" ]]; then
        ok "Storage permission granted"
    else
        warn "Storage permission not detected"
        info "Run: termux-setup-storage (if you need shared storage access)"
    fi

    # ── Check: Available disk space (need at least 500MB) ───────────────
    info "Checking available disk space..."
    local AVAIL_KB
    AVAIL_KB=$(df "${HOME}" | awk 'NR==2 {print $4}')
    local AVAIL_MB=$((AVAIL_KB / 1024))

    if [[ $AVAIL_MB -lt 500 ]]; then
        error "Insufficient disk space: ${AVAIL_MB}MB available (need 500MB+)"
    fi
    ok "Disk space: ${AVAIL_MB}MB available"

    # ── Check: Network connectivity ─────────────────────────────────────
    info "Checking network connectivity..."
    if ping -c 1 -W 3 github.com &>/dev/null 2>&1; then
        ok "Network: connected"
    elif curl -sf --max-time 5 https://github.com &>/dev/null 2>&1; then
        ok "Network: connected (via HTTPS)"
    else
        error "No network connectivity. Please check your connection."
    fi

    # ── Check: Not running as root ──────────────────────────────────────
    if [[ "$(id -u)" -eq 0 ]]; then
        warn "Running as root is not recommended in Termux"
    fi

    # ── Check: Termux package manager ───────────────────────────────────
    info "Checking package manager..."
    if command -v pkg &>/dev/null; then
        ok "pkg available"
        info "Updating package lists..."
        pkg update -y 2>&1 | tail -1 | tee -a "${LOG_FILE:-/dev/null}"
    elif command -v apt &>/dev/null; then
        ok "apt available (fallback)"
        apt update -y 2>&1 | tail -1 | tee -a "${LOG_FILE:-/dev/null}"
    else
        error "No package manager found (pkg or apt)"
    fi

    # ── Check: Android version ──────────────────────────────────────────
    info "Checking Android version..."
    local ANDROID_VER
    ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null || echo "unknown")
    if [[ "$ANDROID_VER" != "unknown" ]]; then
        ok "Android version: ${ANDROID_VER}"
        local MAJOR_VER="${ANDROID_VER%%.*}"
        if [[ "$MAJOR_VER" -lt 7 ]]; then
            warn "Android ${ANDROID_VER} may not be fully supported (7+ recommended)"
        fi
    else
        warn "Could not detect Android version"
    fi

    # ── Summary ─────────────────────────────────────────────────────────
    if [[ $errors -gt 0 ]]; then
        error "${errors} pre-flight check(s) failed"
    fi

    ok "All pre-flight checks passed"
}
