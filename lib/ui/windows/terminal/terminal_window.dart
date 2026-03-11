import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../../core/constants/colors.dart';
import '../../../providers/terminal_provider.dart';
import '../../../providers/window_manager_provider.dart';

class TerminalWindowContent extends ConsumerStatefulWidget {
  const TerminalWindowContent({
    super.key,
    required this.windowId,
    required this.vpsId,
  });

  final String windowId;
  final String vpsId;

  @override
  ConsumerState<TerminalWindowContent> createState() =>
      _TerminalWindowContentState();
}

class _TerminalWindowContentState extends ConsumerState<TerminalWindowContent> {
  static const double _minFontSize = 6;
  static const double _maxFontSize = 32;
  static const double _defaultFontSize = 14;

  double _fontSize = _defaultFontSize;
  double _scaleStart = _defaultFontSize;

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
    final state = ref.watch(
      terminalProvider((windowId: widget.windowId, vpsId: widget.vpsId)),
    );

    // Auto-close window when the shell session ends (e.g. user typed 'exit')
    ref.listen(
      terminalProvider((windowId: widget.windowId, vpsId: widget.vpsId)),
      (_, next) {
        if (next.status == TerminalStatus.disconnected) {
          ref.read(windowManagerProvider.notifier).closeWindow(widget.windowId);
        }
      },
    );

    final terminalView = Focus(
      onKeyEvent: _handleKeyEvent,
      child: TerminalView(
        state.terminal,
        theme: _aetherTerminalTheme,
        textStyle: TerminalStyle(fontSize: _fontSize),
        autofocus: true,
        backgroundOpacity: 0,
        keyboardType: TextInputType.visiblePassword,
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
              style: const TextStyle(
                  color: AetherColors.accentRed, fontSize: 11),
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
              // Pinch-to-zoom on mobile
              GestureDetector(
                onScaleStart: (_) => _scaleStart = _fontSize,
                onScaleUpdate: (details) {
                  if (details.pointerCount < 2) return;
                  setState(() {
                    _fontSize = (_scaleStart * details.scale)
                        .clamp(_minFontSize, _maxFontSize);
                  });
                },
                child: terminalView,
              ),
              // Ctrl+scroll zoom overlay — positioned on top so it catches
              // scroll events before TerminalView consumes them
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent &&
                        HardwareKeyboard.instance.isControlPressed) {
                      _zoom(event.scrollDelta.dy < 0 ? 1 : -1);
                    }
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        _MobileKeyboardToolbar(terminal: state.terminal),
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
    // Only show on mobile
    if (MediaQuery.sizeOf(context).width > 600) return const SizedBox.shrink();
    return Container(
      height: 36,
      color: AetherColors.surfaceDeep,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Key('Tab',  () => terminal.keyInput(TerminalKey.tab)),
            _Key('Esc',  () => terminal.keyInput(TerminalKey.escape)),
            _Key('Ctrl', () => terminal.keyInput(TerminalKey.controlLeft)),
            _Key('↑',    () => terminal.keyInput(TerminalKey.arrowUp)),
            _Key('↓',    () => terminal.keyInput(TerminalKey.arrowDown)),
            _Key('←',    () => terminal.keyInput(TerminalKey.arrowLeft)),
            _Key('→',    () => terminal.keyInput(TerminalKey.arrowRight)),
            _Key('Home', () => terminal.keyInput(TerminalKey.home)),
            _Key('End',  () => terminal.keyInput(TerminalKey.end)),
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
