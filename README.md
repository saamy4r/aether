# Aether

A cross-platform VPS management app built with Flutter. Aether gives you a **glassmorphic desktop environment** on your phone or PC — manage multiple servers through SSH with floating windows, a live stats dashboard, terminal, file manager, Docker manager, and firewall tool.

> **v1.0.0** — Supports **Android** and **Linux**. Windows support requires building on a Windows machine (see below).

---

## Screenshots

<!-- Replace with actual screenshots -->
| Lobby | Desktop | Terminal |
|-------|---------|----------|
| _coming soon_ | _coming soon_ | _coming soon_ |

---

## Features

- **Multi-server desktops** — each VPS gets its own isolated desktop, wallpaper, and open windows
- **Live stats widget** — CPU gauge, RAM bar, uptime updated every 5 seconds over SSH
- **Terminal** — full xterm-compatible terminal via SSH
- **File Manager** — browse, upload, download, compress files over SFTP
- **Docker Manager** — list containers, start/stop/pause, view logs, open shell
- **Firewall Manager** — UFW rules + port scan via SSH
- **Custom wallpapers** — right-click / long-press the desktop to set a background image per server
- **Biometric lock** — auto-locks after 1 minute of inactivity
- **SSH key auth** — generates Ed25519 keys or use password auth

---

## Install

### Android

1. Go to the [Releases](../../releases) page and download `aether-v1.0.0.apk`
2. On your Android device, go to **Settings → Apps → Install unknown apps** and allow your browser or file manager
3. Open the downloaded `.apk` and tap **Install**

Or install via ADB (USB debugging):
```bash
adb install aether-v1.0.0.apk
```

> Minimum Android version: **5.0 (API 21)**

---

### Linux

1. Go to the [Releases](../../releases) page and download `aether-linux-v1.0.0.tar.gz`
2. Extract and run:

```bash
tar -xzf aether-linux-v1.0.0.tar.gz -C aether/
cd aether
./aether
```

**Install system-wide (optional):**
```bash
sudo cp -r aether /opt/aether
sudo ln -s /opt/aether/aether /usr/local/bin/aether
```

**Required runtime libraries** (install if the app doesn't launch):
```bash
# Ubuntu / Debian / Linux Mint
sudo apt install libgtk-3-0 libblkid1 liblzma5

# Fedora / RHEL
sudo dnf install gtk3
```

---

### Windows

> Windows builds must be compiled on a Windows machine. Flutter does not support cross-compiling to Windows from Linux/macOS.

On a Windows machine with Flutter installed:
```powershell
git clone https://github.com/saamy4r/aether.git
cd aether
flutter pub get
flutter build windows --release
# Output: build\windows\x64\runner\Release\
```

Zip the entire `Release\` folder and distribute it.

---

## Build from Source

### Requirements

- **Flutter SDK** `>=3.18.0` → [install guide](https://docs.flutter.dev/get-started/install)
- **Android:** Android Studio + Android SDK (API 21+)
- **Linux build dependencies:**

```bash
# Ubuntu / Debian / Linux Mint
sudo apt install ninja-build cmake libgtk-3-dev pkg-config clang
```

### Clone & run in debug mode

```bash
git clone https://github.com/your-username/aether.git
cd aether
flutter pub get

flutter run -d linux              # Linux desktop
flutter run -d <device-id>        # Android — get ID with: flutter devices
```

### Build release binaries

```bash
# Linux
flutter build linux --release
# Output: build/linux/x64/release/bundle/

# Android APK (sideload)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Android App Bundle (Google Play)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab

# Windows (must run on Windows)
flutter build windows --release
# Output: build\windows\x64\runner\Release\
```

### Package for distribution

**Linux:**
```bash
flutter build linux --release
cd build/linux/x64/release/bundle
tar -czf ~/aether-linux-v1.0.0.tar.gz .
```

**Android:**
```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ~/aether-v1.0.0.apk
```

**Windows** *(on Windows)*:
```powershell
flutter build windows --release
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath aether-windows-v1.0.0.zip
```

---

## SSH Setup

No agent or server-side software required. Aether connects directly to your VPS over SSH.

1. Open Aether → tap the login prompt → **Add Server**
2. Enter your server's IP address, SSH port (default: 22), and username
3. Choose **SSH Key** (recommended) — Aether generates a unique Ed25519 key pair
4. Copy the public key displayed in the app to your server:
   ```bash
   echo "paste-public-key-here" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```
5. Tap **Test Connection** to verify, then **Save**

---

## License

MIT — see [LICENSE](LICENSE)
