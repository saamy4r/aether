# Aether — Coding Standards & Rules
Version 1.0

These rules are **non-negotiable**. They exist because the combination of SSH channel multiplexing, floating window management, and real-time polling creates resource leak patterns that are not caught by the Dart analyzer. Every rule below addresses a specific failure mode that has been explicitly designed against.

---

## 1. SSH Channel Lifecycle Rules

### SSH-01: Every SSHSession MUST be closed

Every `SSHSession` opened **must** have a corresponding `close()` call. An unclosed session holds an open SSH channel on the server, consuming server memory, and may prevent new channel opens if the server's channel limit is reached.

**Required pattern — store reference, close in `ref.onDispose`:**
```dart
class TerminalNotifier extends _$TerminalNotifier {
  SSHSession? _session;
  StreamSubscription? _stdoutSub;

  Future<void> _openSession(SSHClient client) async {
    _session = await client.shell(pty: ...);
    _stdoutSub = _session!.stdout.listen(...);
  }

  @override
  SomeState build(String windowId) {
    ref.onDispose(() {
      _stdoutSub?.cancel();
      _session?.close();
      _session = null;
    });
    // ...
  }
}
```

**Banned pattern — session opened without storing the reference:**
```dart
// BANNED — session leaks if dispose runs before close
await client.shell(...).then((s) { /* use s but never store it */ });
```

---

### SSH-02: Exec sessions must have an enforced timeout

Every `SSHSession` opened for polling via `client.execute()` must have a maximum lifetime. If the server hangs without sending stdout EOF, the channel stays open indefinitely.

```dart
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
          session.close();  // force-close the hung channel
          throw TimeoutException('SSH exec timed out: $command');
        });
    await session.done;
    return utf8.decode(bytes.expand((e) => e).toList());
  } finally {
    session.close();  // belt-and-suspenders: always runs
  }
}
```

---

### SSH-03: SSHClient is a shared resource — only VpsConnectionNotifier may close it

`SSHClient.close()` may only be called from `VpsConnectionNotifier`. No other class, notifier, or widget may call it. Violations cause every open channel (all terminals, SFTP, polling sessions) to drop simultaneously.

Enforcement: `SSHClient` is **never** passed directly to child providers. Child providers read it via:
```dart
final conn = ref.watch(vpsConnectionProvider(vpsId));
final client = conn.valueOrNull?.client;
```
This makes ownership explicit — the Notifier holds the reference, not the caller.

---

### SSH-04: SftpClient must close before its owning SSHClient

`FileManagerNotifier.dispose()` must close `SftpClient` **before** `VpsConnectionNotifier` closes the `SSHClient`. Some server implementations send a protocol error if `SftpClient` is abandoned.

`VpsConnectionNotifier._disconnect()` waits 200ms after notifying dependents to close before calling `client.close()`. This is the grace period for child resources to finalize.

---

### SSH-05: No SSH operations inside widget `build()` methods

`build()` is synchronous. SSH is async. Never initiate SSH calls inside `build()`. All SSH operations are triggered from:
- Notifier methods (in response to user actions)
- `Timer.periodic` callbacks (in Notifiers)

Widgets only **read** provider state — they never initiate SSH operations directly.

---

### SSH-06: LANG=C prefix on all SSH commands — defined in SshCommands constants

Every SSH exec command **must** start with `LANG=C `. Locales that use comma decimal separators (e.g., `de_DE`, `fr_FR`) break every numeric parser in the app.

All command strings are defined as constants in `lib/core/constants/ssh_commands.dart`. **Never inline a command string in a Notifier or widget.**

```dart
// lib/core/constants/ssh_commands.dart
abstract final class SshCommands {
  static const String cpuMemLoad =
      'LANG=C top -bn1 | head -5; '
      'LANG=C free -b; '
      'LANG=C cat /proc/uptime; '
      'LANG=C cat /proc/loadavg';

  static const String diskUsage =
      'LANG=C df -B1 -x tmpfs -x devtmpfs -x overlay';

  static const String networkSample =
      'LANG=C cat /proc/net/dev; sleep 1; LANG=C cat /proc/net/dev';

  static const String processCount =
      'LANG=C ps aux --no-headers | wc -l';

  static const String dockerContainers =
      'LANG=C docker ps -a --format '
      '"{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"';

  static const String dockerImages =
      'LANG=C docker images --format '
      '"{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"';

  static const String dockerDetect =
      'which docker && docker --version 2>/dev/null';
}
```

---

## 2. Memory Leak Prevention

### MEM-01: Timer.periodic always cancelled via ref.onDispose

Any Notifier that creates a `Timer.periodic` **must** cancel it using `ref.onDispose`. This is guaranteed to run even if the provider auto-disposes before a manual dispose is called.

```dart
// CORRECT
@override
Future<ServerStats> build(String vpsId) async {
  final timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  ref.onDispose(timer.cancel);
  return _poll();
}
```

```dart
// BANNED — timer is never cancelled
Timer.periodic(const Duration(seconds: 5), (_) => _poll());
```

---

### MEM-02: StreamController always closed in ref.onDispose

Any Notifier that creates a `StreamController` must close it. Unclosed controllers hold references to all listeners.

```dart
final _statsController = StreamController<ServerStats>.broadcast();
ref.onDispose(_statsController.close);
```

---

### MEM-03: StreamSubscription from session.stdout.listen() must be stored and cancelled

```dart
StreamSubscription? _stdoutSub;

void _wireStreams(SSHSession session, Terminal terminal) {
  _stdoutSub = session.stdout.listen(
    (data) => terminal.write(String.fromCharCodes(data)),
    onDone: _handleSessionClosed,
  );
}

// In ref.onDispose:
ref.onDispose(() {
  _stdoutSub?.cancel();
  _stdoutSub = null;
});
```

---

### MEM-04: xterm Terminal model owned by Notifier, not widget State

The `xterm` `Terminal` (data model) and `TerminalView` (rendering widget) have **separate lifecycles**. The `Terminal` model is owned by `TerminalNotifier`. The widget receives it via the provider.

If a terminal window is minimized, `TerminalView` is removed from the widget tree, but the `Terminal` model and `SSHSession` remain alive in the Notifier. Do **not** store `Terminal` in widget `State`.

---

## 3. Window Management Rules

### WM-01: Z-index values are monotonically increasing — never reset or compacted

Z-index values are never reused. When a window is focused: `newZ = max(all current zIndexes) + 1`. Values grow without bound over a session. This is intentional — integer overflow is not a practical concern.

**Never "normalize" z-indexes** by reassigning `1, 2, 3, ...`. Doing so causes a simultaneous rebuild of every window in the `Stack`.

---

### WM-02: Window drag position is local-first — provider updated only on panEnd

`GestureDetector.onPanUpdate` fires at ~60fps. Calling `windowManagerProvider` on every event causes 60 state mutations/second and 60 full `Stack` rebuilds/second.

**Required pattern:**
```dart
// In ConsumerStatefulWidget (WindowFrame)
Offset _localDelta = Offset.zero;
bool _isDragging = false;

// onPanStart:  setState(() { _isDragging = true; })
// onPanUpdate: setState(() { _localDelta += detail.delta; })
// onPanEnd:    ref.read(windowManagerProvider.notifier)
//                  .moveWindow(windowId, _localDelta, screen, taskbarH);
//              setState(() { _isDragging = false; _localDelta = Offset.zero; })

// Positioned widget reads:
// left: _isDragging ? (w.x + _localDelta.dx) : w.x
// top:  _isDragging ? (w.y + _localDelta.dy) : w.y
```

---

### WM-03: Window bounds clamping must account for taskbar height

```dart
static Offset clampWindowPosition({
  required Offset position,
  required Size windowSize,
  required Size screenSize,
  required double taskbarHeight,
}) {
  return Offset(
    position.dx.clamp(0.0, screenSize.width - windowSize.width),
    position.dy.clamp(0.0, screenSize.height - taskbarHeight - windowSize.height),
  );
}
```

`taskbarHeight` comes from `AetherDimensions.taskbarHeight`. Never hardcode the value at the call site.

---

### WM-04: closeWindow() triggers autoDispose → SSH cleanup chain

When `windowManagerProvider.closeWindow(windowId)` is called:
1. `WindowState` is removed from the list
2. The window's widget is removed from the `Stack`
3. Its child provider (e.g., `terminalProvider(windowId)`) auto-disposes
4. Riverpod's `ref.onDispose` callbacks run — SSH sessions, timers, and subscriptions are cleaned up

**Therefore:** All window-level providers **must** use `@riverpod` (which generates `autoDispose` variants). Using `@Riverpod(keepAlive: true)` on window providers is **banned**.

---

### WM-05: SftpClient keyed by vpsId — terminal sessions keyed by windowId

- `fileManagerProvider` uses **`vpsId`** as its family key. Only one `SftpClient` per host at a time. Multiple File Manager windows for the same host share the same provider instance and `SftpClient`.
- `terminalProvider` uses **`windowId`** (UUID) as its family key. Each terminal window has independent `SSHSession` and `Terminal` state.

The `windowId` is the unique identifier for the window **container**. The `vpsId` is the server identity. These are not interchangeable as provider keys.

---

## 4. Flutter Widget Rules

### FW-01: const constructors on all static leaf widgets

Any widget with no runtime-variable parameters must be declared `const`. This applies to: glassmorphism containers with fixed values, static icon definitions, dividers, and static text labels. The analyzer rule `prefer_const_constructors` is enabled.

---

### FW-02: Extract widgets at 60-line threshold — as classes, not methods

Any `build()` method exceeding 60 lines **must** be refactored into named private `StatelessWidget` or `ConsumerWidget` classes.

```dart
// PREFERRED — separate class, cacheable widget identity across rebuilds
class _DiskBarsSection extends StatelessWidget {
  const _DiskBarsSection({required this.mounts});
  final List<DiskMount> mounts;
  @override Widget build(BuildContext context) { ... }
}

// BANNED for complex subtrees — method widgets lose identity caching
Widget _buildDiskBars(List<DiskMount> mounts) { ... }
```

Exception: single-expression factory methods for trivial widgets are acceptable:
```dart
Widget _buildDivider() => const Divider(color: AetherColors.glassBorder);
```

---

### FW-03: No setState for SSH-triggered state changes — use Riverpod

`setState` is reserved for **local, transient UI state only**: drag position, hover state, animation progress, focus ring visibility.

SSH operations triggered by user gestures (e.g., tap "Restart" on a Docker container) go through the Riverpod notifier — never through `setState`.

---

### FW-04: ConsumerWidget and WidgetRef exclusively — no Provider.of or context.watch

The project uses `flutter_riverpod` exclusively. `Provider.of<T>(context)` and `context.watch` (from the `provider` package) are banned. Use:
- `ConsumerWidget.build(context, ref)` for stateless widgets needing provider access
- `ConsumerStatefulWidget` for widgets needing both local state and provider access
- `Consumer(builder: (context, ref, child) => ...)` for partial-rebuild optimization inside large widgets

---

### FW-05: ConsumerStatefulWidget for widgets needing both local state and providers

When a widget needs local `State` (for drag, animation) AND must read/watch providers, use `ConsumerStatefulWidget`. Do **not** nest `Consumer` inside a `StatefulWidget` — it adds an unnecessary extra widget to the tree.

```dart
// CORRECT
class WindowFrame extends ConsumerStatefulWidget { ... }
class _WindowFrameState extends ConsumerState<WindowFrame> {
  Offset _localDelta = Offset.zero;  // local state for drag
  // ref is available directly in ConsumerState
}

// DISCOURAGED for this pattern
class WindowFrame extends StatefulWidget { ... }
class _WindowFrameState extends State<WindowFrame> {
  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (ctx, ref, _) { ... }); // extra widget node
  }
}
```

---

## 5. Glassmorphism Constants

All glassmorphism visual parameters are centralized. **Never hardcode blur, opacity, border radius, or color values inline.**

```dart
// lib/core/constants/colors.dart

abstract final class AetherColors {
  // Background & surfaces
  static const Color background   = Color(0xFF1B2333);  // Dark blue-grey desktop
  static const Color surfaceDeep  = Color(0xFF232D3F);  // Elevated surface

  // Accent palette
  static const Color accent       = Color(0xFF3DAEE9);  // Breeze Blue — primary accent
  static const Color accentTeal   = Color(0xFF1ABC9C);  // Teal — connected state
  static const Color accentGreen  = Color(0xFF27AE60);  // Running / healthy
  static const Color accentRed    = Color(0xFFE74C3C);  // Error / stopped
  static const Color accentYellow = Color(0xFFF39C12);  // Warning / paused

  // Glassmorphism layers
  static const Color glassBase    = Color(0x14FFFFFF);  // white  8% — window background
  static const Color glassBorder  = Color(0x33FFFFFF);  // white 20% — window border
  static const Color glassHover   = Color(0x1FFFFFFF);  // white 12% — hover state
  static const Color taskbarBase  = Color(0x1A0D1B2A);  // dark  10% — taskbar fill
  static const Color titleBarBase = Color(0x26000000);  // black 15% — title bar gradient

  // Text
  static const Color textPrimary   = Color(0xFFEFF0F1);  // near-white primary text
  static const Color textSecondary = Color(0xFF7F8C8D);  // muted secondary text
  static const Color textAccent    = Color(0xFF3DAEE9);  // accent-colored labels
}

abstract final class AetherGlass {
  // Blur sigma values (ImageFilter.blur sigmaX/sigmaY)
  static const double windowBlur    = 24.0;  // Floating window backdrop
  static const double taskbarBlur   = 20.0;  // Taskbar
  static const double startMenuBlur = 28.0;  // Start menu panel (more frosted)
  static const double lockBlur      = 40.0;  // Lock screen overlay

  // Border radius
  static const double windowRadius    = 12.0;
  static const double startMenuRadius = 16.0;
  static const double buttonRadius    = 8.0;
  static const double taskbarRadius   = 0.0;  // Full-width, no rounding

  // Border stroke
  static const double borderWidth = 1.0;
}
```

**Canonical `GlassContainer` widget:**
```dart
// lib/ui/common/glass_container.dart
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blurSigma = AetherGlass.windowBlur,
    this.borderRadius = AetherGlass.windowRadius,
  });

  final Widget child;
  final double blurSigma;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: AetherColors.glassBase,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AetherColors.glassBorder,
              width: AetherGlass.borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

---

## 6. Error Handling Rules

### ERR-01: SSH error classification happens in VpsConnectionNotifier — not in the UI

All SSH error taxonomy is centralized:

| Exception | User-facing message |
|-----------|---------------------|
| `SocketException` | "Cannot reach server. Check your network." |
| `TimeoutException` | "Connection timed out." |
| `SSHAuthFailException` | "Authentication failed. Check your credentials." |
| `SSHHandshakeException` | "Connection security error." |
| `SSHChannelOpenFailException` | "Server refused to open a channel." |
| `Exception` (generic) | "Unexpected error: `${e.toString()}`" |

UI widgets read the error string from provider state and display it. They **never** catch SSH exceptions directly.

---

### ERR-02: Polling errors use exponential backoff — 3 retries then halt

A single polling failure (timeout, channel error) does **not** set the window to an error state immediately:

```
Cycle 1 failure → retry at normal 5s interval
Cycle 2 failure → retry at 10s
Cycle 3 failure → retry at 20s
Cycle 4+ failure → set dashboard state to PollingError, cancel Timer
                   AND notify vpsConnectionProvider to attempt reconnect
```

`DashboardNotifier` tracks consecutive failure count. After 3 consecutive failures, the `SSHClient` is assumed broken.

---

### ERR-03: SFTP errors show a SnackBar — the File Manager window never auto-closes

All SFTP operations are wrapped in `try/catch`. On error, show a `SnackBar` with a human-readable message derived from the SFTP status code:

| `SftpStatusCode` | Message |
|------------------|---------|
| `permissionDenied` | "Permission denied" |
| `noSuchFile` | "File not found" |
| `failure` | "Server-side error" |
| other | "SFTP error: `${code.name}`" |

The File Manager remains open and returns to the last successful directory listing. It is **never** closed automatically due to an SFTP error.

---

### ERR-04: Terminal session disconnect is reported in-band

When a terminal `SSHSession` closes (user ran `exit`, server killed the session, or network dropped), display in the terminal output:

```
[Connection closed]
```

Rendered in `AetherColors.accentYellow`. The window stays open so the user can read the last output. A "Reconnect" button appears in the window's title bar to re-open a new PTY session on the same VPS.

---

### ERR-05: All user-facing strings defined in AetherStrings constants

No inline hardcoded error or UI strings anywhere in the codebase. All strings live in `lib/core/constants/strings.dart`:

```dart
abstract final class AetherStrings {
  static const String connectTimeout    = 'Connection timed out.';
  static const String authFailed        = 'Authentication failed. Check your credentials.';
  static const String sftpPermDenied    = 'Permission denied.';
  static const String terminalClosed    = '[Connection closed]';
  static const String dockerNotFound    = 'Docker not detected on this host.';
  // ... etc.
}
```

---

## 7. File, Folder, and Code Conventions

### Naming
- **Files:** `snake_case.dart` — always. No camelCase filenames.
- **Classes:** `PascalCase`. One primary public class per file. Filename matches the class: `TerminalWindow` → `terminal_window.dart`.
- **Providers:** File name matches provider: `vpsConnectionProvider` → `vps_connection_provider.dart`.
- **Enums:** `PascalCase` type, `camelCase` values. Defined at the bottom of the model file that uses them, not in a catch-all `enums.dart`.
- **Constants:** Grouped in `abstract final class` with only `static const` members.

### Provider Family Keys
Provider family parameters are **always `String` (UUID v4)** generated at object creation. Never use `int` indexes or model objects as family keys — objects break equality checks on rebuild, and int indexes are fragile when list order changes.

```dart
// CORRECT
final vpsId = const Uuid().v4();  // stable UUID stored with the model
ref.watch(vpsConnectionProvider(vpsId));

// BANNED
ref.watch(vpsConnectionProvider(0));     // int index — fragile
ref.watch(vpsConnectionProvider(vps));   // object — breaks equality
```

### Import Order
Enforced by `analysis_options.yaml` via `directives_ordering` lint:
1. `dart:` imports
2. `package:flutter/` imports
3. Third-party `package:` imports (`dartssh2`, `riverpod`, `xterm`, etc.)
4. Own package `package:aether/` imports (use package path, not relative, for cross-directory imports)
5. Relative imports only for files in the **same directory**

### Generated Files
- `*.g.dart` files (from `riverpod_generator`) are **committed to git**
- Never manually edit `*.g.dart` files
- Every file using `@riverpod` annotation must have `part 'filename.g.dart';` at the top

### Test File Mirroring
- `lib/path/to/file.dart` → `test/path/to/file_test.dart`
- Mirror the `lib/` directory structure exactly in `test/`
- **Parser classes must have unit tests** — they are the most critical logic in the app, are pure Dart (no SSH needed), and are tested with captured real command output stored in `test/fixtures/*.txt`

### Build Order Recommendation
Implement in this sequence to minimize blocked work:
1. `CredentialService` + `BiometricService` — security foundation
2. `VpsListNotifier` + `AddVpsScreen` — can save/load VPS configs
3. `VpsConnectionNotifier` — can actually connect via SSH
4. `WindowManagerNotifier` + `WindowFrame` — can open/move/close empty windows
5. Parsers (`stats_parser`, `df_parser`, `net_parser`) + unit tests against fixtures
6. `DashboardNotifier` + Dashboard window — first live data
7. `TerminalNotifier` + Terminal window — most-used feature
8. `FileManagerNotifier` + File Manager window
9. `DockerNotifier` + Docker Manager window
