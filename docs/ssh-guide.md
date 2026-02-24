# SSH Key Setup Guide — OpenClaw Android

## Overview

Password authentication works out of the box, but SSH keys provide stronger security and convenience. This guide covers setting up key-based authentication for connecting to your OpenClaw Termux instance.

---

## Quick Setup (From Your Computer)

### 1. Generate an SSH Key (if you don't have one)

```bash
ssh-keygen -t ed25519 -C "openclaw-android"
```

Press Enter to accept defaults. Optionally set a passphrase.

### 2. Copy Your Key to the Device

```bash
ssh-copy-id -p 8022 USER@DEVICE_IP
```

Replace:
- `USER` — your Termux username (run `whoami` in Termux)
- `DEVICE_IP` — your Android device's IP (run `ip addr show wlan0` in Termux)

### 3. Test the Connection

```bash
ssh -p 8022 USER@DEVICE_IP
```

You should connect without being prompted for a password.

---

## Manual Key Setup

If `ssh-copy-id` isn't available:

### On Your Computer

```bash
# Display your public key
cat ~/.ssh/id_ed25519.pub
```

Copy the output.

### On Termux (Android)

```bash
# Create .ssh directory if needed
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add the key
echo "PASTE_YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## SSH Config (Convenience)

Add this to `~/.ssh/config` on your computer:

```
Host openclaw
    HostName DEVICE_IP
    Port 8022
    User USER
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 5
```

Then connect with just:

```bash
ssh openclaw
```

---

## Disable Password Auth (Optional — More Secure)

Once key auth works, you can disable passwords:

**On Termux:**

```bash
nano $PREFIX/etc/ssh/sshd_config
```

Change:
```
PasswordAuthentication no
```

Restart sshd:
```bash
pkill sshd && sshd
```

> **Warning:** Make sure key auth works before disabling passwords, or you'll lock yourself out!

---

## Connecting from Different Platforms

### macOS / Linux

```bash
ssh -p 8022 user@device-ip
```

### Windows (PowerShell / Terminal)

```powershell
ssh -p 8022 user@device-ip
```

### Windows (PuTTY)

1. Open PuTTY
2. Host: `device-ip`
3. Port: `8022`
4. Connection → SSH → Auth → Browse for your private key (.ppk)
5. Save the session and connect

### iOS (Termius, Blink, etc.)

1. Add a new host
2. Hostname: `device-ip`
3. Port: `8022`
4. Import or paste your private key

---

## SCP / SFTP (File Transfer)

### Copy files TO the device

```bash
scp -P 8022 local-file.txt user@device-ip:~/
```

### Copy files FROM the device

```bash
scp -P 8022 user@device-ip:~/openclaw/build/openclaw ./
```

### SFTP session

```bash
sftp -P 8022 user@device-ip
```

---

## Troubleshooting

### "Connection refused"

1. Is sshd running? `pgrep sshd` (on Termux)
2. Start it: `sshd`
3. Check port: `grep Port $PREFIX/etc/ssh/sshd_config`

### "Permission denied (publickey)"

1. Check key permissions:
   ```bash
   # On Termux
   ls -la ~/.ssh/
   # authorized_keys should be 600
   # .ssh directory should be 700
   ```

2. Check sshd_config allows pubkey:
   ```bash
   grep PubkeyAuthentication $PREFIX/etc/ssh/sshd_config
   # Should be: PubkeyAuthentication yes
   ```

3. Check key format — ensure you pasted the **public** key (ending in `.pub`).

### "Host key verification failed"

If you reinstalled Termux, the host keys changed. Remove the old key:

```bash
ssh-keygen -R "[device-ip]:8022"
```

### Connection drops after idle

Add to your SSH config (`~/.ssh/config`):

```
Host openclaw
    ServerAliveInterval 60
    ServerAliveCountMax 5
```

Or connect with:

```bash
ssh -o ServerAliveInterval=60 -p 8022 user@device-ip
```

---

## Security Best Practices

1. **Use ed25519 keys** — faster and more secure than RSA
2. **Set a passphrase** on your private key
3. **Disable password auth** once key auth works
4. **Use a non-default port** (already using 8022)
5. **Keep Termux updated**: `pkg upgrade`
6. **Limit key access** — only add keys you trust to `authorized_keys`
