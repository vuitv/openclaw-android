# 🦞 OpenClaw Android

An enhanced, battle-tested installer for [OpenClaw](https://github.com/openclaw/openclaw) on Android via **Termux**. Runs natively — no proot, no Ubuntu, no bloat.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Features

| Feature | Details |
|---------|---------|
| 🦞 **OpenClaw** | Latest version, auto-installed and configured |
| 🔒 **SSH Server** | Auto-configured, port 8022 |
| 🖥️ **tmux Session** | Persistent OpenClaw session for the gateway |
| 🔄 **Auto-Start** | Termux:Boot script for restart recovery |
| 🔧 **Native Fixes** | `renameat2`, `ar` symlink, `--disable-warning` bypass |
| ⚡ **Wakelock** | Prevents Android from killing the process |

---

## Quick Start

### One-liner install

```bash
curl -fsSL https://raw.githubusercontent.com/vuitv/openclaw-android/refs/heads/master/bootstrap.sh | bash
```

### Or clone & run

```bash
git clone https://github.com/vuitv/openclaw-android.git
cd openclaw-android
bash bootstrap.sh
```

> **Requires:** [Termux](https://f-droid.org/packages/com.termux/) on Android (F-Droid version recommended)

---

## What the Installer Does

The master installer runs **10 automated steps**:

| Step | Action |
|------|--------|
| 1 | **Pre-flight checks** — arch, disk space, network, package manager |
| 2 | **Install packages** — Node.js, npm, build tools, SSH, tmux |
| 3 | **Configure environment** — `.bashrc`, `$TMPDIR`, wakelock |
| 4 | **Apply native patches** — bionic-compat, systemctl stub, path fixes |
| 5 | **Install OpenClaw** — `npm install -g openclaw@latest` |
| 6 | **Configure OpenClaw** — default config + data directories |
| 7 | **Setup SSH** — sshd on port 8022, password config |
| 8 | **Setup tmux** — persistent `openclaw` session |
| 9 | **Setup auto-start** — Termux:Boot script |
| 10 | **Verify installation** — comprehensive health check |

---

## Post-Install Usage

### Attach to the OpenClaw session

```bash
tmux attach -t openclaw
```

### Connect via SSH from another device

```bash
ssh -p 8022 <user>@<device-ip>
```

Find your device IP with:

```bash
ip addr show wlan0 | grep inet
```

### Acquire wakelock (prevent Android kill)

```bash
termux-wake-lock
```

---

## Project Structure

```
openclaw-android/
├── bootstrap.sh                  # curl one-liner entry point
├── install.sh                    # Master installer (10 steps)
├── scripts/
│   ├── check-env.sh              # Pre-flight checks
│   ├── install-deps.sh           # Termux packages
│   ├── setup-env.sh              # .bashrc environment config
│   ├── setup-ssh.sh              # SSH server + password
│   ├── setup-tmux.sh             # tmux session info
│   └── setup-boot.sh             # Termux:Boot auto-start
├── patches/
│   ├── termux-compat.h           # renameat2 + RENAME_NOREPLACE
│   ├── bionic-compat.js          # Platform + os patches
│   ├── spawn.h                   # POSIX spawn stub
│   ├── patch-paths.sh            # /tmp → $PREFIX/tmp etc.
│   ├── apply-patches.sh          # Patch orchestrator + ar fix
│   └── systemctl                 # systemctl stub
├── tests/
│   └── verify-install.sh         # Post-install health check
├── docs/
│   ├── troubleshooting.md        # Full troubleshooting guide
│   └── ssh-guide.md              # SSH key setup guide
├── LICENSE                       # MIT
└── .gitignore
```

---

## Native Compatibility Patches

OpenClaw is an npm package targeting desktop Linux (glibc). Termux runs on Android's **Bionic** libc, which requires several fixes:

| Patch | Problem | Solution |
|-------|---------|----------|
| `bionic-compat.js` | Node.js `os.tmpdir()`, `os.homedir()`, `os.userInfo()` wrong on Bionic | Runtime monkey-patches via `NODE_OPTIONS --require` |
| `bionic-compat.js` | `child_process.spawn` uses `/usr/bin` paths | Intercepts and rewrites to `$PREFIX/bin` |
| `termux-compat.h` | `renameat2()` missing in Bionic | Syscall shim (for native npm modules) |
| `spawn.h` | `posix_spawn` incomplete on old NDK | Fork+exec fallback stubs |
| `patch-paths.sh` | Hardcoded `/tmp`, `/usr` paths | Rewrite to `$PREFIX/tmp`, `$PREFIX/*` |
| `systemctl` stub | No systemd on Android | No-op stub that silently succeeds |

---

## Requirements

- **Android 7+** (ARM64 recommended)
- **Termux** — [F-Droid version](https://f-droid.org/packages/com.termux/) (Play Store version is deprecated)
- **~300MB** free disk space
- **Internet connection** for initial install

### Optional (recommended)

- [Termux:Boot](https://f-droid.org/packages/com.termux.boot/) — auto-start on device reboot
- [Termux:API](https://f-droid.org/packages/com.termux.api/) — wakelock support

---

## Verification

Run the health check at any time:

```bash
bash ~/openclaw-android/tests/verify-install.sh
```

This checks 8 categories: environment, commands, libraries, OpenClaw binary, SSH, tmux, auto-start, and patches.

---

## Troubleshooting

See the full [Troubleshooting Guide](docs/troubleshooting.md) for solutions to common issues:

- npm install errors and native module compilation
- Runtime crashes and Node.js compatibility
- SSH connection problems
- Android killing background processes
- Performance tuning

---

## SSH Key Setup

See the [SSH Guide](docs/ssh-guide.md) for:

- Generating and copying SSH keys
- Connecting from macOS, Linux, Windows, iOS
- SCP/SFTP file transfers
- Disabling password auth

---

## Uninstall

```bash
# Remove OpenClaw
npm uninstall -g openclaw
rm -rf ~/.config/openclaw ~/.local/share/openclaw

# Remove installer
rm -rf ~/openclaw-android

# Remove boot script
rm -f ~/.termux/boot/openclaw-start.sh

# Remove environment from .bashrc
sed -i '/=== OpenClaw Android Environment ===/,/=== End OpenClaw ===/d' ~/.bashrc
```

---

## License

[MIT](LICENSE)
