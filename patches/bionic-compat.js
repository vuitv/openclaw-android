/**
 * ============================================================================
 * bionic-compat.js — Platform & OS patches for Node.js on Android/Termux
 * ============================================================================
 * Patches Node.js modules that make assumptions about platform, paths,
 * or OS behavior that don't hold on Android's Bionic libc.
 *
 * Usage: node -r ./patches/bionic-compat.js <script>
 *   or:  export NODE_OPTIONS="--require=/path/to/bionic-compat.js"
 * ============================================================================
 */

'use strict';

const os = require('os');
const path = require('path');

// ── Constants ──────────────────────────────────────────────────────────────
const PREFIX = process.env.PREFIX || '/data/data/com.termux/files/usr';
const HOME = process.env.HOME || '/data/data/com.termux/files/home';
const TMPDIR = process.env.TMPDIR || `${PREFIX}/tmp`;

// ── Patch os.tmpdir() ──────────────────────────────────────────────────────
// Android doesn't have /tmp; Termux uses $PREFIX/tmp
const originalTmpdir = os.tmpdir;
os.tmpdir = function() {
    return TMPDIR;
};

// ── Patch os.homedir() ─────────────────────────────────────────────────────
// Ensure homedir returns Termux home, not /root or empty
const originalHomedir = os.homedir;
os.homedir = function() {
    return HOME;
};

// ── Patch os.userInfo() ────────────────────────────────────────────────────
// Android may not have proper /etc/passwd entries
const originalUserInfo = os.userInfo;
os.userInfo = function(options) {
    try {
        return originalUserInfo.call(os, options);
    } catch (err) {
        // Fallback for systems without proper user database
        return {
            uid: process.getuid ? process.getuid() : -1,
            gid: process.getgid ? process.getgid() : -1,
            username: process.env.USER || process.env.LOGNAME || 'termux',
            homedir: HOME,
            shell: process.env.SHELL || `${PREFIX}/bin/bash`,
        };
    }
};

// ── Patch platform checks ──────────────────────────────────────────────────
// Some packages check process.platform === 'linux' but then assume glibc.
// We expose a helper to identify Termux/Bionic.
process.env.__TERMUX = '1';
process.env.__BIONIC = '1';

// ── Patch child_process spawn for Termux paths ────────────────────────────
// Intercept spawn to fix /usr/bin → $PREFIX/bin path references
const childProcess = require('child_process');
const originalSpawn = childProcess.spawn;
const originalSpawnSync = childProcess.spawnSync;

function fixSpawnArgs(argsArray) {
    // argsArray is [command, args, options] or [command, options]
    if (argsArray.length > 0 && typeof argsArray[0] === 'string') {
        argsArray[0] = argsArray[0]
            .replace(/^\/usr\/local\/bin\//, `${PREFIX}/bin/`)
            .replace(/^\/usr\/bin\//, `${PREFIX}/bin/`)
            .replace(/^\/bin\//, `${PREFIX}/bin/`)
            .replace(/^\/sbin\//, `${PREFIX}/bin/`);
    }
    
    let options = null;
    if (argsArray.length > 2) {
        options = argsArray[2];
    } else if (argsArray.length === 2 && !Array.isArray(argsArray[1])) {
        options = argsArray[1];
    }
    
    if (options && options.env && options.env.PATH) {
        // Use (^|:) to avoid matching /data/data/com.termux/files/usr/bin
        options.env.PATH = options.env.PATH
            .replace(/(^|:)\/usr\/local\/bin/g, `$1${PREFIX}/bin`)
            .replace(/(^|:)\/usr\/bin/g, `$1${PREFIX}/bin`)
            .replace(/(^|:)\/bin/g, `$1${PREFIX}/bin`)
            .replace(/(^|:)\/sbin/g, `$1${PREFIX}/bin`);
    }
    return argsArray;
}

childProcess.spawn = function(...args) {
    return originalSpawn.apply(this, fixSpawnArgs(args));
};

childProcess.spawnSync = function(...args) {
    return originalSpawnSync.apply(this, fixSpawnArgs(args));
};

// ── Patch /tmp references in environment ───────────────────────────────────
if (!process.env.TMPDIR) process.env.TMPDIR = TMPDIR;
if (!process.env.TEMP) process.env.TEMP = TMPDIR;
if (!process.env.TMP) process.env.TMP = TMPDIR;

// ── Log patch status (debug mode) ─────────────────────────────────────────
if (process.env.OPENCLAW_DEBUG) {
    console.error('[bionic-compat] Patches applied:');
    console.error(`  tmpdir:  ${os.tmpdir()}`);
    console.error(`  homedir: ${os.homedir()}`);
    console.error(`  PREFIX:  ${PREFIX}`);
}

module.exports = {
    PREFIX,
    HOME,
    TMPDIR,
    isTermux: true,
    isBionic: true,
};
