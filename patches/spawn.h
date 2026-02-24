/*
 * ============================================================================
 * spawn.h — POSIX spawn stub for Android/Bionic
 * ============================================================================
 * Some build systems expect posix_spawn* functions that may be missing or
 * incomplete on older Android NDK / Bionic versions. This provides stubs
 * that fall back to fork+exec.
 * ============================================================================
 */

#ifndef TERMUX_SPAWN_H
#define TERMUX_SPAWN_H

#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>



/* ── Minimal type definitions ─────────────────────────────────────────────── */

typedef struct {
    int __flags;
    pid_t __pgrp;
    sigset_t __sd;
    sigset_t __ss;
    struct sched_param __sp;
    int __policy;
    int __pad[16];
} posix_spawnattr_t;

typedef struct {
    int __allocated;
    int __used;
    struct __spawn_action *__actions;
    int __pad[16];
} posix_spawn_file_actions_t;

/* ── posix_spawn — fork+exec fallback ─────────────────────────────────────── */

static inline int posix_spawn(pid_t *pid, const char *path,
                              const posix_spawn_file_actions_t *file_actions,
                              const posix_spawnattr_t *attrp,
                              char *const argv[], char *const envp[])
{
    pid_t child = fork();
    if (child < 0) {
        return errno;
    }
    if (child == 0) {
        /* Child process */
        if (envp) {
            execve(path, argv, envp);
        } else {
            execv(path, argv);
        }
        _exit(127); /* exec failed */
    }
    /* Parent */
    if (pid) *pid = child;
    return 0;
}

static inline int posix_spawnp(pid_t *pid, const char *file,
                               const posix_spawn_file_actions_t *file_actions,
                               const posix_spawnattr_t *attrp,
                               char *const argv[], char *const envp[])
{
    pid_t child = fork();
    if (child < 0) {
        return errno;
    }
    if (child == 0) {
        /* Child — use execvp for PATH lookup */
        if (envp) {
            execvpe(file, argv, envp);
        } else {
            execvp(file, argv);
        }
        _exit(127);
    }
    if (pid) *pid = child;
    return 0;
}

/* ── Attribute stubs (no-op) ──────────────────────────────────────────────── */

static inline int posix_spawnattr_init(posix_spawnattr_t *attr)
{
    (void)attr;
    return 0;
}

static inline int posix_spawnattr_destroy(posix_spawnattr_t *attr)
{
    (void)attr;
    return 0;
}

static inline int posix_spawn_file_actions_init(posix_spawn_file_actions_t *fa)
{
    (void)fa;
    return 0;
}

static inline int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *fa)
{
    (void)fa;
    return 0;
}

static inline int posix_spawnattr_setflags(posix_spawnattr_t *attr, short flags)
{
    if (attr) attr->__flags = flags;
    return 0;
}

#endif /* TERMUX_SPAWN_H */
#endif /* TERMUX_SPAWN_H */
