# Troubleshooting Guide — OpenClaw Android

## Table of Contents

- [Build Errors](#build-errors)
- [Runtime Errors](#runtime-errors)
- [SSH Issues](#ssh-issues)
- [tmux Issues](#tmux-issues)
- [Android-Specific Issues](#android-specific-issues)
- [Performance Issues](#performance-issues)
- [Reset & Reinstall](#reset--reinstall)

---

## Build Errors

### `renameat2` / `RENAME_NOREPLACE` not found

**Symptom:** Compilation fails with `undefined reference to renameat2` or `RENAME_NOREPLACE undeclared`.

**Fix:** The installer should auto-apply this patch. If it didn't:

```bash
export CFLAGS="-I$HOME/openclaw-android/patches"
export CXXFLAGS="-I$HOME/openclaw-android/patches"
```

Then rebuild.

### `ar: command not found`

**Symptom:** Build fails because `ar` is missing.

**Fix:** Termux ships `llvm-ar` instead of GNU `ar`:

```bash
ln -sf $(which llvm-ar) $PREFIX/bin/ar
ln -sf $(which llvm-ranlib) $PREFIX/bin/ranlib
```

### `fatal error: spawn.h: No such file or directory`

**Symptom:** Some sources require `<spawn.h>` which may be missing.

**Fix:**

```bash
cp ~/openclaw-android/patches/spawn.h $PREFIX/include/
```

### CMake can't find SDL2 libraries

**Symptom:** `Could NOT find SDL2` during cmake configuration.

**Fix:**

```bash
pkg install libsdl2 libsdl2-image libsdl2-mixer libsdl2-ttf libsdl2-gfx
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig
```

### Compiler warnings treated as errors

**Symptom:** Build fails with `-Werror` promoting warnings to errors.

**Fix:**

```bash
export CFLAGS="$CFLAGS -Wno-error"
export CXXFLAGS="$CXXFLAGS -Wno-error"
```

Or edit `CMakeLists.txt` to remove `-Werror`.

---

## Runtime Errors

### `openclaw: command not found`

**Fix:** The binary may be in the build directory:

```bash
# Check if it exists
ls ~/openclaw/build/openclaw

# Add to PATH
export PATH="$HOME/openclaw/build:$PATH"

# Or run directly
~/openclaw/build/openclaw
```

### OpenClaw crashes immediately

**Possible causes:**

1. **Missing game assets** — OpenClaw requires the original game assets (CLAW.REZ):
   ```bash
   ls ~/.local/share/openclaw/assets/
   ```

2. **Missing libraries** — Check with:
   ```bash
   ldd ~/openclaw/build/openclaw 2>/dev/null || readelf -d ~/openclaw/build/openclaw
   ```

3. **Display issues** — OpenClaw needs a display. On Termux:
   ```bash
   # Install VNC or use X11
   pkg install tigervnc x11-repo
   ```

### Segmentation fault

Run with debug info:

```bash
cd ~/openclaw/build
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)
./openclaw 2>&1 | tee crash.log
```

---

## SSH Issues

### Can't connect via SSH

1. **Check sshd is running:**
   ```bash
   pgrep sshd || sshd
   ```

2. **Check the port:**
   ```bash
   grep Port $PREFIX/etc/ssh/sshd_config
   # Default: 8022
   ```

3. **Find your device IP:**
   ```bash
   ip addr show wlan0 | grep inet
   ```

4. **Connect:**
   ```bash
   ssh -p 8022 user@<device-ip>
   ```

### Permission denied (password)

Reset your password:

```bash
passwd
```

### Permission denied (publickey)

```bash
# On your PC, copy your key:
ssh-copy-id -p 8022 user@<device-ip>

# Or manually:
cat ~/.ssh/id_rsa.pub | ssh -p 8022 user@<device-ip> "cat >> ~/.ssh/authorized_keys"
```

### SSH connection drops

Likely Android killing the background process. Enable wakelock:

```bash
termux-wake-lock
```

Also see [Android-Specific Issues](#android-specific-issues).

---

## tmux Issues

### `tmux: command not found`

```bash
pkg install tmux
```

### Can't attach to session

```bash
# List sessions
tmux ls

# If no session exists, create one
tmux new-session -d -s openclaw

# Attach
tmux attach -t openclaw
```

### tmux session dies when switching apps

This is Android killing the Termux process. Solutions:

1. **Wakelock** (recommended):
   ```bash
   termux-wake-lock
   ```

2. **Disable battery optimization for Termux** in Android Settings

3. **Install Termux:Boot** for auto-restart on reboot

---

## Android-Specific Issues

### Termux process killed by Android

Android aggressively kills background apps. Mitigations:

1. **Acquire wakelock:**
   ```bash
   termux-wake-lock
   ```

2. **Disable battery optimization:**
   - Settings → Apps → Termux → Battery → Unrestricted

3. **Pin the app:**
   - Open recent apps → Pin Termux

4. **Disable phantom process killer (Android 12+):**
   ```bash
   # Via ADB (computer required):
   adb shell "settings put global settings_enable_monitor_phantom_procs false"
   ```

### `/tmp` doesn't exist

Termux uses `$PREFIX/tmp` instead of `/tmp`:

```bash
mkdir -p $PREFIX/tmp
export TMPDIR=$PREFIX/tmp
```

### `systemctl: command not found`

Termux doesn't use systemd. The installer provides a stub, but for services:

```bash
# Use termux-services instead
pkg install termux-services

# Start a service
sv up sshd

# Stop a service
sv down sshd
```

### Storage permission

If you need access to shared storage:

```bash
termux-setup-storage
```

---

## Performance Issues

### Build is very slow

Limit parallel jobs to avoid memory pressure:

```bash
make -j2  # Instead of -j$(nproc)
```

If OOM (out of memory):

```bash
make -j1
```

### Game runs slowly

1. Lower the resolution in config:
   ```bash
   nano ~/.config/openclaw/config.xml
   # Set Width/Height to lower values
   ```

2. Disable unnecessary services

3. Close other apps on the device

---

## Reset & Reinstall

### Start fresh

```bash
# Remove OpenClaw
rm -rf ~/openclaw
rm -rf ~/.config/openclaw
rm -rf ~/.local/share/openclaw

# Remove installer
rm -rf ~/openclaw-android

# Remove boot script
rm -f ~/.termux/boot/openclaw-start.sh

# Re-run installer
curl -fsSL https://raw.githubusercontent.com/user/openclaw-android/main/bootstrap.sh | bash
```

### Keep config, reinstall binary

```bash
cd ~/openclaw
rm -rf build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
make install
```

---

## Getting Help

1. Check the install log: `cat ~/openclaw-android/install.log`
2. Run the verification: `bash ~/openclaw-android/tests/verify-install.sh`
3. Open an issue: https://github.com/user/openclaw-android/issues
