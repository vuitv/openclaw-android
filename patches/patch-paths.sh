#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Patch Paths — Fix hardcoded /tmp, /usr, /etc paths for Termux
# ============================================================================
# Termux uses $PREFIX (/data/data/com.termux/files/usr) instead of standard
# Linux FHS paths. This script patches source files before building.
# ============================================================================

set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"

# ── Path mappings ───────────────────────────────────────────────────────────
# Format: "original_path:termux_path"
PATH_MAPPINGS=(
    "/tmp:${PREFIX}/tmp"
    "/usr/local:${PREFIX}"
    "/usr/share:${PREFIX}/share"
    "/usr/lib:${PREFIX}/lib"
    "/usr/include:${PREFIX}/include"
    "/usr/bin:${PREFIX}/bin"
    "/usr/sbin:${PREFIX}/bin"
    "/etc:${PREFIX}/etc"
    "/var/log:${PREFIX}/var/log"
    "/var/run:${PREFIX}/var/run"
    "/var/tmp:${PREFIX}/tmp"
    "/opt:${PREFIX}/opt"
)

# ── patch_file ──────────────────────────────────────────────────────────────
# Patches a single file with all path mappings.
# Usage: patch_file <filepath>
patch_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    local modified=0

    for mapping in "${PATH_MAPPINGS[@]}"; do
        local orig="${mapping%%:*}"
        local replacement="${mapping#*:}"

        # Only patch if the original path exists in the file
        if grep -q "$orig" "$file" 2>/dev/null; then
            # Replace only paths NOT already under the Termux prefix
            # Use negative lookbehind pattern to avoid double-patching
            sed -i "s|\([^a-zA-Z/]\)${orig}|\1${replacement}|g; s|^${orig}|${replacement}|g" "$file"
            modified=1
        fi
    done

    if [[ $modified -eq 1 ]]; then
        printf "  ${GREEN}Patched:${NC} %s\n" "$file"
    fi
}

# ── patch_directory ─────────────────────────────────────────────────────────
# Recursively patch all source files in a directory.
# Usage: patch_directory <dirpath> [extensions]
patch_directory() {
    local dir="$1"
    local extensions="${2:-c,cpp,h,hpp,cmake,txt,sh,py,mk,in,cfg,conf}"

    if [[ ! -d "$dir" ]]; then
        echo "Directory not found: $dir" >&2
        return 1
    fi

    info "Patching paths in: ${dir}"

    # Build find expression for file extensions
    local find_expr=""
    IFS=',' read -ra EXTS <<< "$extensions"
    for ext in "${EXTS[@]}"; do
        if [[ -n "$find_expr" ]]; then
            find_expr="${find_expr} -o"
        fi
        find_expr="${find_expr} -name '*.${ext}'"
    done

    # Find and patch files
    local count=0
    while IFS= read -r -d '' file; do
        patch_file "$file"
        ((count++)) || true
    done < <(find "$dir" -type f \( $find_expr \) -print0 2>/dev/null)

    ok "Processed ${count} files in ${dir}"
}

# ── patch_cmake_file ────────────────────────────────────────────────────────
# Specifically handle CMakeLists.txt files
patch_cmake_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Fix common CMake path issues
    sed -i \
        -e "s|/usr/local|${PREFIX}|g" \
        -e "s|/usr/lib|${PREFIX}/lib|g" \
        -e "s|/usr/include|${PREFIX}/include|g" \
        -e "s|/usr/share|${PREFIX}/share|g" \
        -e "s|DESTINATION /usr|DESTINATION ${PREFIX}|g" \
        "$file"

    printf "  ${GREEN}CMake patched:${NC} %s\n" "$file"
}

# ── Ensure target directories exist ────────────────────────────────────────
ensure_termux_dirs() {
    local dirs=(
        "${PREFIX}/tmp"
        "${PREFIX}/var/log"
        "${PREFIX}/var/run"
        "${PREFIX}/opt"
        "${PREFIX}/etc"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" 2>/dev/null || true
    done
}

# ── Main (when run standalone) ──────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/../install.sh" 2>/dev/null || {
        # Minimal color definitions
        GREEN='\033[0;32m'
        CYAN='\033[0;36m'
        NC='\033[0m'
        info() { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
        ok()   { printf "${GREEN}[ OK ]${NC}  %s\n" "$*"; }
    }

    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <directory> [extensions]"
        echo "  extensions: comma-separated list (default: c,cpp,h,hpp,cmake,txt,sh)"
        exit 1
    fi

    ensure_termux_dirs
    patch_directory "$@"
fi
