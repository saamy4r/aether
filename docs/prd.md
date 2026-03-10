# Aether — Product Requirements Document
Version 1.0 | Status: Living Document

---

## 1. Product Overview

Aether is a cross-platform Flutter application for Android, iOS, and Linux that provides a **Mobile Desktop Environment** for managing Virtual Private Servers. It is not a traditional SSH client. It is a desktop shell — with a wallpaper, draggable icons, a glassmorphic taskbar, floating resizable windows, and live server metrics — all driven over SSH without requiring any agent or daemon installed on the remote host.

**Target users:** Developers and sysadmins who manage one or more Linux VPS instances and want a native mobile-first dashboard that feels like a full desktop environment, not a terminal emulator bolted onto a phone.

---

## 2. Core Design Principles

### 2.1 No-Agent Philosophy
Aether **MUST NOT** require the installation of any software on the remote server. Every piece of data the app collects must be obtainable via standard POSIX/Linux commands available by default on:
- Ubuntu 20.04+
- Debian 11+
- CentOS 8+ / Rocky Linux 8+
- Alpine 3.16+

This is a **hard constraint**, not a preference. If a feature cannot be implemented without a server-side component, it belongs in a future tier, not MVP.

### 2.2 One Connection Per Host
Each VPS gets exactly **one `SSHClient`** (dartssh2). Multiple logical "channels" (terminal sessions, SFTP subsystem, exec sessions for polling) are multiplexed over that single TCP connection. The app must never open a second TCP connection to the same host for the same user session.

### 2.3 Desktop Metaphor First
Every interaction model decision must start from "how does this work on a desktop?" and then adapt for touch. Floating windows have title bars. They can be dragged by their title bar. They can be resized by dragging a corner handle. They stack with z-ordering. They can be minimized to the taskbar.

---

## 3. User Stories

### Epic 1: VPS Onboarding

**US-001 — Add a new VPS**
As a user, I want to add a VPS by entering a hostname/IP, port, username, and choosing between SSH key or password auth, so that Aether can connect to my server.

Acceptance Criteria:
- Form validates hostname (IP or FQDN format)
- Port defaults to 22, accepts 1–65535
- Username required, non-empty
- Auth method selector: "SSH Key" or "Password"
- On "SSH Key": user can paste a private key, import via file picker, or generate a new Ed25519 keypair in-app
- On "Password": password field with show/hide toggle; password stored in `flutter_secure_storage`, never in SharedPreferences or plain files
- "Test Connection" button validates credentials before saving
- Saved VPS appears as a draggable icon on the Desktop

**US-002 — SSH Key Generation**
As a user, I want to generate an Ed25519 keypair inside the app and copy the public key to clipboard, so I can paste it into `~/.ssh/authorized_keys` on my server without leaving Aether.

Acceptance Criteria:
- Key generation runs in a Dart `Isolate` (never on the main thread — Ed25519 keygen is CPU-intensive)
- Generated private key stored via `flutter_secure_storage` with a per-VPS key ID
- Public key displayed in a selectable text field with one-tap copy
- Warning displayed: "Copy this public key to your server before proceeding"

**US-003 — Biometric Unlock**
As a user, I want the app to lock after backgrounding and require biometric/PIN authentication to unlock, so that my SSH credentials are protected if my device is lost.

Acceptance Criteria:
- App locks after 60 seconds in background (configurable: 30s / 60s / 5min / never)
- Uses `local_auth` with `biometricOnly: false` (fallback to PIN/pattern/password)
- Locked state renders a frosted glass overlay over the entire screen
- SSH connections are **NOT** dropped during lock (they persist in background)
- All credential access from `flutter_secure_storage` requires a successful auth unlock

---

### Epic 2: Desktop Shell

**US-004 — VPS Desktop Icons**
As a user, I want to see each saved VPS as an icon on the Desktop with a label, so I can identify and launch it at a glance.

Acceptance Criteria:
- Desktop icons positioned on a virtual grid (not freeform in MVP)
- Long-press enters "jiggle mode" enabling drag-to-reorder
- Icon state reflects connection status: disconnected (grey), connecting (pulsing teal), connected (solid teal glow)
- Double-tap opens the VPS Dashboard window
- Icon positions persisted to `shared_preferences`

**US-005 — Glassmorphic Taskbar**
As a user, I want a taskbar pinned to the bottom of the screen for quick access to open windows and system functions.

Acceptance Criteria:
- Taskbar height: 56dp on mobile, 48dp on Linux desktop
- Left: "Start Menu" button (Aether logo icon)
- Center: per-window buttons (icon + label, max 8 chars). Active window highlighted with accent color.
- Right: System tray — clock (HH:mm), active connection count badge, settings gear
- Glassmorphism: blur sigma 20, `background: white 8% opacity`, top border 1dp `white 20% opacity`, bottom SafeArea respected
- Taskbar cannot be hidden in MVP

**US-006 — Start Menu**
As a user, I want to open a Start Menu from the taskbar to launch tools (Terminal, File Manager, Docker Manager) for a connected VPS and access app settings.

Acceptance Criteria:
- Start Menu opens as a glassmorphic panel sliding up from bottom-left
- Panel contains: VPS selector (dropdown of connected hosts), then sections: "Tools" (Terminal, File Manager, Docker Manager) and "System" (Settings, About, Disconnect All)
- Selecting a tool while a VPS is active opens that tool's floating window for that VPS
- Linux keyboard shortcut: `Super` key or `Ctrl+Escape`

---

### Epic 3: Dashboard & Live Widgets

**US-007 — VPS Dashboard Window**
As a user, I want a Dashboard floating window for a connected VPS that shows live CPU, RAM, storage, network I/O, and uptime.

Acceptance Criteria:
- Floating, draggable, resizable window. Default: 380×420dp. Minimum: 280×320dp.
- Metrics update every 5 seconds via SSH exec polling
- CPU: percentage arc gauge + sparkline (last 60 readings = 5 min of history)
- RAM: used/total in GB + percentage bar
- Disk: per-mount-point bar, sorted by usage descending
- Network: bytes_in/bytes_out per second (delta between two `/proc/net/dev` reads)
- Uptime: formatted as `Xd Xh Xm`
- Load average: 1m, 5m, 15m displayed numerically

**US-008 — No-Agent Stat Collection: Exact Commands**

The polling loop executes a compound command per cycle via `SSHSession.execute()` (NOT a PTY). `LANG=C` is mandatory on every command — some locales use comma decimal separators which break parsing.

**CPU, RAM, Load Average, Uptime** (every 5s):
```sh
LANG=C top -bn1 | head -5; LANG=C free -b; LANG=C cat /proc/uptime; LANG=C cat /proc/loadavg
```

**Disk Usage** (every 30s — less volatile):
```sh
LANG=C df -B1 -x tmpfs -x devtmpfs -x overlay
```

**Network I/O** (two-sample delta, 1-second interval):
```sh
LANG=C cat /proc/net/dev; sleep 1; LANG=C cat /proc/net/dev
```

**Process Count**:
```sh
LANG=C ps aux --no-headers | wc -l
```

Parsing responsibilities:
- `top -bn1`: extract line starting with `%Cpu(s):`, parse the `us` (user) field
- `free -b`: parse `Mem:` line — fields: total, used, free, shared, buff/cache, available
- `/proc/uptime`: first field is float seconds since boot
- `/proc/loadavg`: first three space-separated fields are 1m/5m/15m averages
- `df -B1`: columns — Filesystem, 1B-blocks, Used, Available, Use%, Mounted-on
- `/proc/net/dev`: for lines containing `:`, column 2 = bytes received, column 10 = bytes transmitted. Delta ÷ 1.0s = bytes/sec.

---

### Epic 4: Terminal

**US-009 — Terminal Window**
As a user, I want a full-featured terminal window connected to a VPS so I can run arbitrary commands on the server.

Acceptance Criteria:
- Floating, draggable, resizable window. Default: 480×320dp. Minimum: 320×200dp.
- Rendered by the `xterm` Flutter package (`TerminalView` widget)
- Each terminal window gets its own `SSHSession` with PTY: type `xterm-256color`, rows/columns derived from widget size
- Window resize propagates PTY resize via `session.resizeTerminal(cols, rows, pixelW, pixelH)`
- Multiple terminal windows to the same host are supported — each is a separate `SSHSession`, still multiplexed over the same `SSHClient`
- Mobile keyboard toolbar: Tab, Ctrl, Esc, arrow keys, Fn keys row
- Title bar shows: `Terminal — hostname (session N)`
- Shell started: user's default login shell (no hardcoded `/bin/bash`)

**US-010 — Terminal Themes**
As a user, I want to choose a terminal color theme.

Acceptance Criteria:
- MVP ships 3 themes: Aether Dark (default), Solarized Dark, One Dark
- Defined as `TerminalTheme` objects (xterm package model)
- Theme applies globally to all terminals, configurable in Settings

---

### Epic 5: File Manager

**US-011 — File Manager Window**
As a user, I want a floating file manager to browse, upload, download, and delete remote files without a separate SFTP client.

Acceptance Criteria:
- Floating, draggable, resizable window. Default: 500×400dp. Minimum: 360×280dp.
- Uses `SftpClient` from dartssh2 — **NOT** a separate TCP connection
- Initial directory: `/home/username` resolved via SFTP `realpath`
- Directory listing: icon (file/folder), name, size, permissions (`rwxrwxrwx`), modification date
- Navigation: tap folder to enter, breadcrumb bar at top, back button
- Upload: tap `+` button → `file_picker` → transfer via `sftp.open()` with `write | create | truncate` modes
- Download: long-press → "Download" → saved to platform Downloads directory
- Delete: long-press → "Delete" → confirmation dialog required
- Rename: long-press → "Rename" → inline edit field
- Drag-and-drop upload (Linux desktop): drop files from OS file manager onto Aether File Manager — accepts `DragTarget<Uri>`
- Progress bar for transfers > 100 KB (linear progress indicator in transfer panel at window bottom)
- SFTP permission denied → SnackBar message, window never auto-closes on error

---

### Epic 6: Docker Manager

**US-012 — Docker Manager Window**
As a user, I want to see and control Docker containers on my VPS without manually SSHing.

Acceptance Criteria:
- Floating, draggable, resizable window. Default: 520×440dp.
- Detection command: `which docker && docker --version 2>/dev/null`
- If Docker not found: "Docker not detected on this host." message with docs link
- Container list command:
  ```sh
  LANG=C docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
  ```
- Columns: Name, Image, Status (green=running, yellow=paused, red=exited), Ports, Actions
- Actions: Start (`docker start <id>`), Stop (`docker stop <id>`), Restart (`docker restart <id>`), Logs (new window streaming `docker logs --follow --tail=100 <id>`), Remove (with confirmation)
- Image list tab:
  ```sh
  LANG=C docker images --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
  ```
- Auto-refresh every 15s when window is focused; manual Refresh button

---

## 4. Window Management Requirements

| ID | Requirement |
|----|-------------|
| WM-001 | Every open window has an integer `zIndex`. Tapping anywhere on a window raises it to `max(all) + 1`. Taskbar is always above all windows. |
| WM-002 | Windows draggable by title bar only. Dragging clamped: `x ∈ [0, screenW - windowW]`, `y ∈ [0, screenH - taskbarH - windowH]`. |
| WM-003 | Resize handle: 20×20dp target at bottom-right corner. Minimum sizes enforced per window type. Terminal resize propagates PTY resize signal. |
| WM-004 | Minimize: removes from Stack, adds to taskbar button. Restore: window reappears at last position, raised to top. SSH sessions **not** dropped on minimize. |
| WM-005 | Close: disposes all resources. Terminal: sends `exit\n` to PTY then `SSHSession.close()`. File Manager: cancels in-flight SFTP ops, closes `SftpClient` (not `SSHClient`). Dashboard: cancels `Timer.periodic`. |

---

## 5. Feature Tiers

### MVP — v1.0
- VPS CRUD (add / edit / delete)
- SSH key + password auth
- Desktop with static grid icons + connection state glow
- Glassmorphic taskbar + Start Menu
- Dashboard window: CPU / RAM / disk / network live gauges
- Terminal window: xterm PTY, mobile keyboard toolbar
- File Manager window: SFTP browse + upload + download
- Docker Manager: container list + start/stop/restart + logs
- `flutter_secure_storage` for all credentials
- Biometric/PIN app lock

### v1.1 — Quality of Life
- SSH jump hosts / bastion server support
- Terminal tabs (multiple sessions in one window)
- File manager dual-pane view
- Desktop background image picker
- Window snapping (snap to left/right screen halves)
- Docker Compose: `up` / `down` / `ps`

### v1.2 — Power Features
- Port forwarding management UI (local and remote tunnels)
- Cron job viewer (`crontab -l` + `/etc/cron.*`)
- Systemd service manager (`systemctl list-units`, start/stop/enable/disable)
- Multi-server terminal broadcast (type to N terminals simultaneously)
- Desktop mini-widgets (persistent CPU/RAM gauges without opening a window)

### v2.0 — Ecosystem
- Team sharing: export VPS config (without private key) via QR code
- Plugin API: community-built tool windows
- iPad split-view support
- macOS target
