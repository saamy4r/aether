# Aether — Architecture & Technical Design
Version 1.0

---

## 1. Technology Stack

| Concern | Package | Version | Rationale |
|---------|---------|---------|-----------|
| UI Framework | Flutter | 3.18+ | Single codebase for Android / iOS / Linux |
| Language | Dart | 3.9+ | Null safety, records, patterns, native isolates |
| SSH | `dartssh2` | ^2.9.0 | Pure Dart, no FFI, accurate SSH channel multiplexing |
| State Management | `flutter_riverpod` | ^2.6.1 | Compile-safe providers, async support, auto-dispose |
| Code Generation | `riverpod_annotation` + `build_runner` | ^2.3.5 / ^2.4.12 | Eliminates provider boilerplate, enforces patterns |
| Terminal Widget | `xterm` | ^3.7.0 | Full VT100/256color, PTY resize support |
| Secure Storage | `flutter_secure_storage` | ^9.2.2 | Keychain (iOS), Keystore (Android), libsecret (Linux) |
| Biometric Auth | `local_auth` | ^2.3.0 | Fingerprint/Face/PIN, platform-native |
| File Picker | `file_picker` | ^8.1.2 | Cross-platform local file selection |
| Persistence | `shared_preferences` | ^2.3.2 | Non-secret UI state (icon positions, settings) |
| Blur/Glass | `dart:ui ImageFilter` | built-in | Platform-native blur, no extra package |
| JSON/Text Parsing | `dart:convert` | built-in | UTF-8 decode of SSH command output |

---

## 2. Package Dependency Specification

```yaml
# pubspec.yaml — complete dependency block for Aether MVP

dependencies:
  flutter:
    sdk: flutter
  # SSH — pure Dart, channel multiplexing
  dartssh2: ^2.9.0
  # State management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.3.5
  # Terminal emulator
  xterm: ^3.7.0
  # Security
  flutter_secure_storage: ^9.2.2
  local_auth: ^2.3.0
  # File operations
  file_picker: ^8.1.2
  # Non-secret persistence
  shared_preferences: ^2.3.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.12
  custom_lint: ^0.7.0
  riverpod_lint: ^2.3.13
```

---

## 3. SSH Architecture: Channel Multiplexing

### 3.1 The Core Model

`dartssh2` models the SSH protocol accurately: **one TCP connection = one `SSHClient`**. Over that client, you open multiple `SSHSession` objects. Each session maps to one SSH channel (RFC 4254 §5). Aether uses three session types per VPS:

```
SSHClient  (1 per host — owns the TCP connection)
  ├── SSHSession [shell + PTY]  ─── Terminal Window #1    (xterm-256color)
  ├── SSHSession [shell + PTY]  ─── Terminal Window #2
  ├── SSHSession [exec]  ────────── Dashboard polling     (short-lived, open/close per cycle)
  ├── SSHSession [exec]  ────────── Docker Manager polling
  └── SftpClient  ───────────────── File Manager          (SFTP subsystem, persistent)
       └── SftpFile handles opened on demand for read/write
```

### 3.2 SSHClient Lifecycle

The `SSHClient` is created on first connection attempt and lives until the user explicitly disconnects or the app terminates. It is **owned exclusively by `VpsConnectionNotifier`**.

```dart
// Pseudocode — connection procedure
Future<VpsConnectionState> _connect(VpsModel vps) async {
  // Step 1: TCP socket
  final socket = await SSHSocket.connect(
    vps.host, vps.port,
    timeout: const Duration(seconds: 15),
  );

  // Step 2: Auth object — built from decrypted credentials
  final auth = credentials.isKey
      ? SSHKeyPair.fromPem(decryptedPem)       // key auth
      : SSHPasswordAuth(vps.username, password); // password auth

  // Step 3: SSH handshake
  _client = SSHClient(socket, username: vps.username, onAuthenticate: auth);
  await _client!.authenticated;  // throws SSHAuthFailException on failure

  return VpsConnectionState(client: _client!, status: ConnectionStatus.connected);
}
```

Error taxonomy at connection time:
- `SocketException` → network unreachable
- `TimeoutException` (from socket connect) → server unreachable
- `SSHAuthFailException` → wrong credentials
- `SSHHandshakeException` → key exchange / cipher negotiation failure

### 3.3 PTY Sessions (Terminal Windows)

Each terminal window opens one PTY session using `client.shell()`:

```dart
// Pseudocode — open a PTY session
final session = await sshClient.shell(
  pty: SSHPtyConfig(
    type: 'xterm-256color',
    width: terminalColumns,     // derived from TerminalView widget size
    height: terminalRows,
    pixelWidth: widgetPixelWidth.toInt(),
    pixelHeight: widgetPixelHeight.toInt(),
  ),
);

// Wire xterm Terminal model
final subscription = session.stdout.listen(
  (data) => terminal.write(String.fromCharCodes(data)),
);
terminal.onOutput = (data) => session.stdin.add(data.codeUnits);

// PTY resize on window resize
await session.resizeTerminal(newCols, newRows, newPixelW, newPixelH);
```

The session and `StreamSubscription` are stored in `TerminalNotifier` and closed in `ref.onDispose`.

### 3.4 Exec Sessions (Dashboard Polling)

Dashboard polling opens a **short-lived** `SSHSession` per poll cycle — never a persistent shell:

```dart
// Pseudocode — execute with enforced timeout
Future<String> execWithTimeout(
  SSHClient client,
  String command, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final session = await client.execute(command);
  try {
    final bytes = await session.stdout
        .toList()
        .timeout(timeout, onTimeout: () {
          session.close();  // force-close a hung channel
          throw TimeoutException('SSH exec timed out');
        });
    await session.done;
    return utf8.decode(bytes.expand((e) => e).toList());
  } finally {
    session.close();  // belt-and-suspenders
  }
}
```

### 3.5 SFTP Client

`SftpClient` is opened **once** when the File Manager window is first shown and reused:

```dart
// Open SFTP subsystem (no new TCP connection)
final sftp = await sshClient.sftp();

// List directory
final items = await sftp.listdir(path);

// Upload
final remoteFile = await sftp.open(
  remotePath,
  mode: SftpFileOpenMode.write |
        SftpFileOpenMode.create |
        SftpFileOpenMode.truncate,
);
await remoteFile.write(localBytes.toChunkedStream(chunkSize: 65536));
await remoteFile.close();

// Download
final remoteFile = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
final data = await remoteFile.readBytes();
await remoteFile.close();
```

`SftpClient` is closed in `FileManagerNotifier.dispose()`. The parent `SSHClient` is **not** closed.

---

## 4. State Management Architecture (Riverpod)

### 4.1 Provider Hierarchy

```
ProviderScope (root)
  │
  ├── vpsListProvider
  │     NotifierProvider<VpsListNotifier, List<VpsModel>>
  │     Persists to SharedPreferences. CRUD for saved VPS configs.
  │     Does NOT store credentials — those are in flutter_secure_storage.
  │
  ├── vpsConnectionProvider(vpsId)         [.family, autoDispose]
  │     AsyncNotifierProvider — one instance per VPS id.
  │     Owns SSHClient lifecycle. State: AsyncValue<VpsConnectionState>
  │
  ├── windowManagerProvider
  │     NotifierProvider<WindowManagerNotifier, WindowManagerState>
  │     Global list of all open windows. Manages z-index.
  │
  ├── dashboardProvider(vpsId)             [.family, autoDispose]
  │     AsyncNotifierProvider — owns Timer.periodic, polls stats.
  │     Reads vpsConnectionProvider(vpsId) for the SSHClient.
  │
  ├── terminalProvider(windowId)           [.family, autoDispose]
  │     NotifierProvider — one per terminal window.
  │     Owns SSHSession (PTY) + xterm Terminal object.
  │     windowId (UUID) is the key, not vpsId.
  │
  ├── fileManagerProvider(vpsId)           [.family, autoDispose]
  │     AsyncNotifierProvider — owns SftpClient.
  │     Keyed by vpsId (one SftpClient per host, shared across File Manager windows).
  │
  └── dockerManagerProvider(vpsId)         [.family, autoDispose]
        AsyncNotifierProvider — owns docker polling Timer.
```

### 4.2 VpsConnectionNotifier

```dart
// Pseudocode pattern
@riverpod
class VpsConnection extends _$VpsConnection {
  SSHClient? _client;

  @override
  Future<VpsConnectionState> build(String vpsId) async {
    ref.onDispose(_disconnect);
    final vps = ref.read(vpsListProvider).firstWhere((v) => v.id == vpsId);
    return _connect(vps);
  }

  Future<void> reconnect() async {
    _disconnect();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _connect(
      ref.read(vpsListProvider).firstWhere((v) => v.id == vpsId),
    ));
  }

  void _disconnect() {
    _client?.close();
    _client = null;
  }

  SSHClient? get client => _client;
}

// Connection state machine — valid transitions only:
// disconnected ──> connecting ──> connected ──> disconnected
//                            └──> error     ──> disconnected
enum ConnectionStatus { disconnected, connecting, connected, error }
```

### 4.3 WindowManagerNotifier

```dart
@immutable
class WindowState {
  final String windowId;    // UUID — stable key
  final String vpsId;
  final WindowType type;    // dashboard | terminal | fileManager | docker
  final double x, y;
  final double width, height;
  final int zIndex;
  final bool isMinimized;
  final String title;
  // ... copyWith omitted for brevity
}

enum WindowType { dashboard, terminal, fileManager, docker }

@riverpod
class WindowManager extends _$WindowManager {
  @override
  List<WindowState> build() => [];

  void openWindow(WindowState window) {
    state = [...state, window.copyWith(zIndex: _nextZ)];
  }

  void focusWindow(String windowId) {
    state = state.map((w) =>
      w.windowId == windowId ? w.copyWith(zIndex: _nextZ) : w
    ).toList();
  }

  void moveWindow(String windowId, Offset delta, Size screen, double taskbarH) {
    state = state.map((w) {
      if (w.windowId != windowId) return w;
      return w.copyWith(
        x: (w.x + delta.dx).clamp(0, screen.width - w.width),
        y: (w.y + delta.dy).clamp(0, screen.height - taskbarH - w.height),
      );
    }).toList();
  }

  void closeWindow(String windowId) =>
    state = state.where((w) => w.windowId != windowId).toList();

  void minimizeWindow(String windowId) =>
    state = state.map((w) =>
      w.windowId == windowId ? w.copyWith(isMinimized: true) : w
    ).toList();

  void restoreWindow(String windowId) =>
    state = state.map((w) =>
      w.windowId == windowId
        ? w.copyWith(isMinimized: false, zIndex: _nextZ)
        : w
    ).toList();

  int get _nextZ => state.isEmpty ? 1 : state.map((w) => w.zIndex).reduce(max) + 1;
}
```

### 4.4 Desktop Rendering Architecture

The **entire main screen is a single `Stack`** — no `Navigator.push`, no routes. Window "navigation" is purely state-driven.

```dart
// Root widget tree (pseudocode structure)
Scaffold(
  body: Stack(
    children: [
      // Layer 0 — Desktop background image / gradient
      const DesktopBackground(),

      // Layer 1 — VPS icon grid
      const DesktopIconGrid(),

      // Layer 2 — Floating windows (z-index sorted)
      ...windowManager.windows
          .where((w) => !w.isMinimized)
          .sorted((a, b) => a.zIndex.compareTo(b.zIndex))
          .map((w) => Positioned(
                left: w.x, top: w.y,
                width: w.width, height: w.height,
                child: WindowFrame(windowState: w),
              )),

      // Layer 3 — Taskbar (always above windows)
      const Positioned(bottom: 0, left: 0, right: 0, child: Taskbar()),

      // Layer 4 — Start Menu (conditionally above taskbar)
      if (startMenuOpen) const StartMenuPanel(),

      // Layer 5 — Lock screen overlay (above everything)
      if (locked) const LockScreen(),
    ],
  ),
)
```

**Key constraint:** This is a single `Stack`, not Flutter `Navigator`. Opening a new "window" is `windowManagerProvider.notifier.openWindow(...)`, not `Navigator.push(...)`.

---

## 5. Directory Structure

```
lib/
├── main.dart                         # ProviderScope root + app entry
├── app.dart                          # MaterialApp, theme, global AppLifecycleListener
│
├── core/
│   ├── constants/
│   │   ├── colors.dart               # AetherColors, AetherGlass (all glassmorphism values)
│   │   ├── dimensions.dart           # Taskbar height, window minimums, grid sizes
│   │   ├── ssh_commands.dart         # SshCommands abstract class — ALL command strings
│   │   └── strings.dart              # AetherStrings — all user-facing text
│   ├── models/
│   │   ├── vps_model.dart            # VpsModel (non-secret config: host, port, username)
│   │   ├── server_stats.dart         # ServerStats, CpuStats, MemStats, NetworkStats
│   │   ├── window_state.dart         # WindowState, WindowType, WindowManagerState
│   │   ├── docker_container.dart     # DockerContainer, DockerImage
│   │   └── sftp_entry.dart           # SftpEntry (file/directory listing item)
│   ├── services/
│   │   ├── credential_service.dart   # flutter_secure_storage wrapper (read/write/delete)
│   │   ├── biometric_service.dart    # local_auth wrapper
│   │   └── ssh_key_service.dart      # Key generation (Isolate), PEM parsing
│   └── parsers/
│       ├── stats_parser.dart         # Parses top/free/proc output → ServerStats
│       ├── docker_parser.dart        # Parses docker ps/images output
│       ├── df_parser.dart            # Parses df -B1 output → List<DiskMount>
│       └── net_parser.dart           # Parses /proc/net/dev deltas → NetworkStats
│
├── providers/
│   ├── vps_list_provider.dart        # vpsListProvider + VpsListNotifier
│   ├── vps_connection_provider.dart  # vpsConnectionProvider + VpsConnectionNotifier
│   ├── window_manager_provider.dart  # windowManagerProvider + WindowManagerNotifier
│   ├── dashboard_provider.dart       # dashboardProvider + DashboardNotifier
│   ├── terminal_provider.dart        # terminalProvider + TerminalNotifier
│   ├── file_manager_provider.dart    # fileManagerProvider + FileManagerNotifier
│   ├── docker_provider.dart          # dockerManagerProvider + DockerNotifier
│   └── auth_provider.dart            # biometric lock state
│
└── ui/
    ├── desktop/
    │   ├── desktop_screen.dart       # Root Stack — assembles all layers
    │   ├── desktop_background.dart   # Background image / gradient widget
    │   ├── desktop_icon_grid.dart    # Grid layout + jiggle-mode drag-reorder
    │   └── desktop_icon.dart         # Single VPS icon (state-reflecting glow)
    │
    ├── taskbar/
    │   ├── taskbar.dart              # Main taskbar widget
    │   ├── taskbar_window_button.dart # Per-window button (center section)
    │   ├── system_tray.dart          # Clock, connection count, settings
    │   └── start_menu.dart           # Glassmorphic slide-up panel
    │
    ├── windows/
    │   ├── window_frame.dart         # Generic draggable/resizable container + title bar
    │   ├── window_title_bar.dart     # Title, icon, minimize/close buttons
    │   ├── resize_handle.dart        # Bottom-right corner 20×20dp drag target
    │   │
    │   ├── dashboard/
    │   │   ├── dashboard_window.dart
    │   │   ├── cpu_gauge.dart        # Arc gauge + sparkline (CustomPainter)
    │   │   ├── ram_bar.dart
    │   │   ├── disk_bars.dart
    │   │   └── network_chart.dart
    │   │
    │   ├── terminal/
    │   │   ├── terminal_window.dart  # TerminalView + keyboard toolbar
    │   │   └── mobile_keyboard_toolbar.dart
    │   │
    │   ├── file_manager/
    │   │   ├── file_manager_window.dart
    │   │   ├── file_entry_tile.dart
    │   │   └── transfer_progress_panel.dart
    │   │
    │   └── docker/
    │       ├── docker_window.dart    # TabBar: Containers + Images
    │       ├── container_list_tile.dart
    │       └── docker_action_buttons.dart
    │
    ├── settings/
    │   ├── settings_screen.dart
    │   ├── add_vps_screen.dart       # Add / Edit VPS form
    │   └── key_generation_screen.dart
    │
    ├── lock/
    │   └── lock_screen.dart          # Biometric auth frosted overlay
    │
    └── common/
        ├── glass_container.dart      # Reusable BackdropFilter + glassmorphism container
        ├── aether_icons.dart         # Custom icon definitions
        ├── sparkline.dart            # CustomPainter for sparkline chart
        └── gauge_arc.dart            # CustomPainter for arc gauge
```

---

## 6. Concurrency Model

### 6.1 SSH Polling — Dart Async (No Isolate Needed)

`dartssh2` is pure Dart. All SSH I/O is non-blocking via Dart's event loop. `Timer.periodic` + `await client.execute()` suspends on I/O without blocking the UI thread. This is safe for polling intervals ≥ 5 seconds.

**Exception:** SSH key generation **must** run in an `Isolate` — Ed25519 keygen is CPU-intensive:
```dart
final keypair = await Isolate.run(
  () => SSHKeyPair.generate(SSHKeyType.ed25519),
);
```

### 6.2 StreamController for Stat Delivery

`DashboardNotifier` maintains a `StreamController<ServerStats>.broadcast()` internally. The polling timer pushes parsed stats to the stream. Widgets consume via `StreamBuilder` or `ref.listen`. This decouples the polling cadence from the widget rebuild cadence.

### 6.3 Window Drag — Local State First, Provider on Commit

`GestureDetector.onPanUpdate` fires at ~60fps. Calling `windowManagerProvider.notifier.moveWindow()` on every event causes 60 state mutations/second → 60 full `Stack` rebuilds/second → jank.

**Solution:** Track position locally during drag, commit to provider only on `onPanEnd`:

```dart
// In ConsumerStatefulWidget state for WindowFrame
Offset _localOffset = Offset.zero;
bool _isDragging = false;

GestureDetector(
  onPanStart: (_) => setState(() { _isDragging = true; }),
  onPanUpdate: (d) => setState(() { _localOffset += d.delta; }),
  onPanEnd: (_) {
    ref.read(windowManagerProvider.notifier)
        .moveWindow(widget.windowId, _localOffset, screenSize, taskbarHeight);
    setState(() { _isDragging = false; _localOffset = Offset.zero; });
  },
)
// The Positioned widget reads:
// _isDragging ? (persistedOffset + _localOffset) : persistedOffset
```

---

## 7. Security Architecture

### 7.1 Credential Storage

All secrets use `flutter_secure_storage`. Storage keys per VPS:

| Key | Content |
|-----|---------|
| `ssh_privkey_<vpsId>` | PEM-encoded private key |
| `ssh_password_<vpsId>` | Plaintext password (protected by OS Keychain/Keystore) |
| `ssh_passphrase_<vpsId>` | Key passphrase (if key is passphrase-protected) |

`CredentialService` owns all access:

```dart
class CredentialService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    lOptions: LinuxOptions(),  // libsecret / gnome-keyring / KWallet
  );

  Future<void> storePrivateKey(String vpsId, String pem) =>
      _storage.write(key: 'ssh_privkey_$vpsId', value: pem);

  Future<String?> loadPrivateKey(String vpsId) =>
      _storage.read(key: 'ssh_privkey_$vpsId');

  Future<void> deleteAllCredentials(String vpsId) => Future.wait([
    _storage.delete(key: 'ssh_privkey_$vpsId'),
    _storage.delete(key: 'ssh_password_$vpsId'),
    _storage.delete(key: 'ssh_passphrase_$vpsId'),
  ]);
}
```

**Never stored in:** `SharedPreferences`, Hive, Isar, SQLite, any plaintext file.

### 7.2 Biometric Lock Flow

```dart
class BiometricService {
  Future<bool> authenticate({String reason = 'Unlock Aether'}) async {
    final auth = LocalAuthentication();
    if (!await auth.canCheckBiometrics) return true; // skip if not enrolled
    return auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(biometricOnly: false),
    );
  }
}
```

`AppLifecycleListener` in `app.dart`:
- `AppLifecycleState.paused` → start lock timer (default 60s)
- `AppLifecycleState.resumed` → if timer expired → set `authProvider.locked = true`
- `locked == true` → `LockScreen` overlay (Layer 5 in Stack) renders over everything
- SSH connections remain alive during lock — only UI access is gated

---

## 8. Platform-Specific Requirements

### Android
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```
- `flutter_secure_storage`: requires `minSdk 23` (Android 6)
- `local_auth`: requires `minSdk 23`

### iOS
```xml
<!-- ios/Runner/Info.plist -->
<key>NSFaceIDUsageDescription</key>
<string>Aether uses Face ID to protect your SSH credentials.</string>
```
- No special entitlements for outbound TCP (SSH)
- Keychain accessibility: `first_unlock` (accessible after first device unlock)

### Linux
- `flutter_secure_storage` on Linux uses the **secret-service D-Bus API** (gnome-keyring or KWallet-compatible)
- Build dependency: `libsecret-1-dev` must be installed on the build machine
- `local_auth` has limited Linux support as of 2026 — fallback: PIN entry dialog backed by `flutter_secure_storage`
- File drag-and-drop: use `super_drag_and_drop` package for OS-level file drops onto the File Manager window
- `CMakeLists.txt` may require `pkg_check_modules(SECRET libsecret-1)` linkage for `flutter_secure_storage`
