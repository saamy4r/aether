import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' hide TerminalState;
import '../../../core/constants/colors.dart';
import '../../../providers/docker_logs_provider.dart';
import '../../../providers/docker_shell_provider.dart';
import '../../../providers/terminal_provider.dart';

// ── Docker Logs Window ────────────────────────────────────────────────────────

class DockerLogsWindowContent extends ConsumerStatefulWidget {
  const DockerLogsWindowContent({
    super.key,
    required this.windowId,
    required this.containerId,
    required this.vpsId,
  });

  final String windowId;
  final String containerId;
  final String vpsId;

  @override
  ConsumerState<DockerLogsWindowContent> createState() =>
      _DockerLogsWindowContentState();
}

class _DockerLogsWindowContentState
    extends ConsumerState<DockerLogsWindowContent> {
  static const double _minFontSize = 6;
  static const double _maxFontSize = 32;
  double _fontSize = 13;
  double _scaleStart = 13;

  void _zoom(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!HardwareKeyboard.instance.isControlPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd) {
      _zoom(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      _zoom(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final key = (
      windowId: widget.windowId,
      containerId: widget.containerId,
      vpsId: widget.vpsId,
    );
    final state = ref.watch(dockerLogsProvider(key));

    return _TerminalScaffold(
      state: state,
      fontSize: _fontSize,
      scaleStart: _scaleStart,
      readOnly: true,
      onZoom: _zoom,
      onScaleStart: (s) => _scaleStart = _fontSize,
      onScaleUpdate: (s) {
        if (s.pointerCount < 2) return;
        setState(() {
          _fontSize = (_scaleStart * s.scale).clamp(_minFontSize, _maxFontSize);
        });
      },
      onKeyEvent: _handleKeyEvent,
    );
  }
}

// ── Docker Shell Window ───────────────────────────────────────────────────────

class DockerShellWindowContent extends ConsumerStatefulWidget {
  const DockerShellWindowContent({
    super.key,
    required this.windowId,
    required this.containerId,
    required this.vpsId,
  });

  final String windowId;
  final String containerId;
  final String vpsId;

  @override
  ConsumerState<DockerShellWindowContent> createState() =>
      _DockerShellWindowContentState();
}

class _DockerShellWindowContentState
    extends ConsumerState<DockerShellWindowContent> {
  static const double _minFontSize = 6;
  static const double _maxFontSize = 32;
  double _fontSize = 14;
  double _scaleStart = 14;

  void _zoom(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!HardwareKeyboard.instance.isControlPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd) {
      _zoom(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      _zoom(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final key = (
      windowId: widget.windowId,
      containerId: widget.containerId,
      vpsId: widget.vpsId,
    );
    final state = ref.watch(dockerShellProvider(key));

    return Column(
      children: [
        Expanded(
          child: _TerminalScaffold(
            state: state,
            fontSize: _fontSize,
            scaleStart: _scaleStart,
            readOnly: false,
            onZoom: _zoom,
            onScaleStart: (s) => _scaleStart = _fontSize,
            onScaleUpdate: (s) {
              if (s.pointerCount < 2) return;
              setState(() {
                _fontSize =
                    (_scaleStart * s.scale).clamp(_minFontSize, _maxFontSize);
              });
            },
            onKeyEvent: _handleKeyEvent,
          ),
        ),
        _MobileKeyboardToolbar(terminal: state.terminal),
      ],
    );
  }
}

// ── Shared scaffold ───────────────────────────────────────────────────────────

class _TerminalScaffold extends StatelessWidget {
  const _TerminalScaffold({
    required this.state,
    required this.fontSize,
    required this.scaleStart,
    required this.readOnly,
    required this.onZoom,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onKeyEvent,
  });

  final TerminalState state;
  final double fontSize;
  final double scaleStart;
  final bool readOnly;
  final void Function(double) onZoom;
  final void Function(ScaleStartDetails) onScaleStart;
  final void Function(ScaleUpdateDetails) onScaleUpdate;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final terminalView = Focus(
      onKeyEvent: onKeyEvent,
      child: TerminalView(
        state.terminal,
        theme: _aetherTerminalTheme,
        textStyle: TerminalStyle(fontSize: fontSize),
        autofocus: !readOnly,
        backgroundOpacity: 0,
        readOnly: readOnly,
        onSecondaryTapDown: (_, __) {},
      ),
    );

    return Column(
      children: [
        if (state.status == TerminalStatus.error)
          Container(
            color: AetherColors.accentRed.withOpacity(0.15),
            padding: const EdgeInsets.all(8),
            child: Text(
              state.errorMessage ?? 'Connection error',
              style:
                  const TextStyle(color: AetherColors.accentRed, fontSize: 11),
            ),
          ),
        if (state.status == TerminalStatus.connecting)
          const LinearProgressIndicator(
            backgroundColor: AetherColors.glassBase,
            valueColor: AlwaysStoppedAnimation(AetherColors.accent),
            minHeight: 2,
          ),
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onScaleStart: onScaleStart,
                onScaleUpdate: onScaleUpdate,
                child: terminalView,
              ),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent &&
                        HardwareKeyboard.instance.isControlPressed) {
                      onZoom(event.scrollDelta.dy < 0 ? 1 : -1);
                    }
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _aetherTerminalTheme = TerminalTheme(
  cursor: Color(0xFFFFFFFF),
  selection: Color(0x443DAEE9),
  foreground: Color(0xFFEFF0F1),
  background: Color(0x00000000),
  black: Color(0xFF1B2333),
  red: Color(0xFFE74C3C),
  green: Color(0xFF27AE60),
  yellow: Color(0xFFF39C12),
  blue: Color(0xFF3DAEE9),
  magenta: Color(0xFF9B59B6),
  cyan: Color(0xFF1ABC9C),
  white: Color(0xFFEFF0F1),
  brightBlack: Color(0xFF7F8C8D),
  brightRed: Color(0xFFFF6B6B),
  brightGreen: Color(0xFF2ECC71),
  brightYellow: Color(0xFFF1C40F),
  brightBlue: Color(0xFF5DADE2),
  brightMagenta: Color(0xFFBB8FCE),
  brightCyan: Color(0xFF1BE2BA),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFF3DAEE9),
  searchHitBackgroundCurrent: Color(0xFF1ABC9C),
  searchHitForeground: Color(0xFF1B2333),
);

class _MobileKeyboardToolbar extends StatelessWidget {
  const _MobileKeyboardToolbar({required this.terminal});
  final Terminal terminal;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width > 600) return const SizedBox.shrink();
    return Container(
      height: 36,
      color: AetherColors.surfaceDeep,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Key('Tab', () => terminal.keyInput(TerminalKey.tab)),
            _Key('Esc', () => terminal.keyInput(TerminalKey.escape)),
            _Key('↑', () => terminal.keyInput(TerminalKey.arrowUp)),
            _Key('↓', () => terminal.keyInput(TerminalKey.arrowDown)),
            _Key('←', () => terminal.keyInput(TerminalKey.arrowLeft)),
            _Key('→', () => terminal.keyInput(TerminalKey.arrowRight)),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: double.infinity,
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: AetherColors.textPrimary,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
