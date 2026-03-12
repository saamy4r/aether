# Aether

A cross-platform VPS management app built with Flutter. Aether gives you a **glassmorphic desktop environment** on your phone or PC — manage multiple servers through SSH with floating windows, a live stats dashboard, terminal, file manager, Docker manager, and firewall tool.

> Supports **Android** and **Linux**. iOS/macOS/Windows support is planned.

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

Download the latest `.apk` from the [Releases](../../releases) page, then:

```bash
adb install aether-v1.0.0.apk
```

Or tap the `.apk` directly on your device (enable *Install from unknown sources* in Android settings first).

---

### Linux

Download `aether-linux-v1.0.0.tar.gz` from the [Releases](../../releases) page:

```bash
tar -xzf aether-linux-v1.0.0.tar.gz
cd aether
./aether
```

Optional — install system-wide:

```bash
sudo cp -r aether /opt/aether
sudo ln -s /opt/aether/aether /usr/local/bin/aether
```

---

## Build from Source

### Requirements

- Flutter SDK `>=3.18.0` → [install](https://docs.flutter.dev/get-started/install)
- Android: Android SDK / Android Studio
- Linux build deps (Ubuntu/Debian/Mint):

```bash
sudo apt install ninja-build cmake libgtk-3-dev pkg-config
```

### Clone & run

```bash
git clone https://github.com/your-username/aether.git
cd aether
flutter pub get

flutter run -d linux              # Linux desktop
flutter run -d <device-id>        # Android  (flutter devices to list)
```

### Release builds

```bash
# Linux
flutter build linux --release
# Output: build/linux/x64/release/bundle/

# Android APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Android App Bundle (Play Store)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Package for Release

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

Upload both files as assets on the GitHub Releases page and tag the release `v1.0.0`.

---

## SSH Setup

No agent or server-side software required — Aether connects directly over SSH.

1. Tap the login prompt → **Add Server**
2. Enter your VPS IP, port, and username
3. Choose **SSH Key** (recommended) — the app generates an Ed25519 key pair
4. Copy the public key shown in the app to your server:
   ```bash
   echo "your-public-key" >> ~/.ssh/authorized_keys
   ```
5. Tap **Test Connection** → **Save**

---

## License

MIT
