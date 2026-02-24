/*
 * ============================================================================
 * termux-compat.h — renameat2() + RENAME_NOREPLACE for Android/Bionic
 * ============================================================================
 * Android's Bionic libc does not expose renameat2() or RENAME_NOREPLACE.
 * This header provides a compatibility shim using the syscall interface.
 *
 * Usage: Include this header or add -I<patches-dir> to CFLAGS.
 * ============================================================================
 */

#ifndef TERMUX_COMPAT_H
#define TERMUX_COMPAT_H

#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/syscall.h>

/* ── RENAME_NOREPLACE ────────────────────────────────────────────────────── */
#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif

#ifndef RENAME_EXCHANGE
#define RENAME_EXCHANGE (1 << 1)
#endif

#ifndef RENAME_WHITEOUT
#define RENAME_WHITEOUT (1 << 2)
#endif

/* ── renameat2() syscall shim ────────────────────────────────────────────── */
#ifndef SYS_renameat2

#if defined(__aarch64__)
#define SYS_renameat2 276
#elif defined(__arm__)
#define SYS_renameat2 382
#elif defined(__x86_64__)
#define SYS_renameat2 316
#elif defined(__i386__)
#define SYS_renameat2 353
#else
#error "Unsupported architecture for renameat2 syscall"
#endif

#endif /* SYS_renameat2 */

/**
 * renameat2 - rename a file, optionally with flags
 *
 * @olddirfd:  Directory fd for old path (AT_FDCWD for cwd)
 * @oldpath:   Old file path
 * @newdirfd:  Directory fd for new path (AT_FDCWD for cwd)
 * @newpath:   New file path
 * @flags:     RENAME_NOREPLACE, RENAME_EXCHANGE, etc.
 *
 * Returns 0 on success, -1 on error with errno set.
 *
 * If flags == 0, behaves like regular renameat().
 * If RENAME_NOREPLACE is set, fails with EEXIST if newpath exists.
 */
static inline int renameat2(int olddirfd, const char *oldpath,
                            int newdirfd, const char *newpath,
                            unsigned int flags)
{
    /* If no special flags, just use standard renameat */
    if (flags == 0) {
        return renameat(olddirfd, oldpath, newdirfd, newpath);
    }

    int ret = (int)syscall(SYS_renameat2, olddirfd, oldpath,
                           newdirfd, newpath, flags);
    if (ret < 0) {
        /* Fallback: RENAME_NOREPLACE can be emulated with link + unlink */
        if (flags == RENAME_NOREPLACE && errno == ENOSYS) {
            /* Check if newpath already exists */
            if (faccessat(newdirfd, newpath, F_OK, 0) == 0) {
                errno = EEXIST;
                return -1;
            }
            /* Use standard rename (small race window, but best effort) */
            return renameat(olddirfd, oldpath, newdirfd, newpath);
        }
        return -1;
    }
    return ret;
}

/**
 * Convenience wrapper: rename2() using AT_FDCWD
 */
static inline int rename_noreplace(const char *oldpath, const char *newpath)
{
    return renameat2(AT_FDCWD, oldpath, AT_FDCWD, newpath, RENAME_NOREPLACE);
}

#endif /* TERMUX_COMPAT_H */
