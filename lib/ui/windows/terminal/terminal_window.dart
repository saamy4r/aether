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
  final TerminalController _controller = TerminalController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    });
  }

  String? _getSelectedText(Terminal terminal) {
    final selection = _controller.selection;
    if (selection == null) return null;
    final text = terminal.buffer.getText(selection).trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _copy(Terminal terminal) async {
    final text = _getSelectedText(terminal);
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    _controller.clearSelection();
  }

  Future<void> _paste(Terminal terminal) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      terminal.paste(text);
    }
  }

  void _showContextMenu(BuildContext context, Offset position, Terminal terminal) {
    final hasSelection = _getSelectedText(terminal) != null;
    showMenu<_MenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx + 1, position.dy + 1,
      ),
      color: const Color(0xFF1E2A3A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x33FFFFFF)),
      ),
      items: [
        PopupMenuItem(
          value: _MenuAction.copy,
          enabled: hasSelection,
          child: _MenuEntry(
            icon: Icons.copy_rounded,
            label: 'Copy',
            shortcut: 'Ctrl+C',
            enabled: hasSelection,
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.paste,
          child: _MenuEntry(
            icon: Icons.paste_rounded,
            label: 'Paste',
            shortcut: 'Ctrl+V',
            enabled: true,
          ),
        ),
      ],
    ).then((action) {
      if (action == _MenuAction.copy) _copy(terminal);
      if (action == _MenuAction.paste) _paste(terminal);
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (!ctrl) return KeyEventResult.ignored;

    // Ctrl+= / Ctrl++ → zoom in
    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd) {
      _zoom(1);
      return KeyEventResult.handled;
    }
    // Ctrl+- → zoom out
    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      _zoom(-1);
      return KeyEventResult.handled;
    }
    // Ctrl+C → copy selection if any, otherwise let xterm send SIGINT
    if (event.logicalKey == LogicalKeyboardKey.keyC) {
      final state = ref.read(
        terminalProvider((windowId: widget.windowId, vpsId: widget.vpsId)),
      );
      final text = _getSelectedText(state.terminal);
      if (text != null) {
        _copy(state.terminal);
        return KeyEventResult.handled;
      }
    }
    // Ctrl+V → paste
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      final state = ref.read(
        terminalProvider((windowId: widget.windowId, vpsId: widget.vpsId)),
      );
      _paste(state.terminal);
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
        controller: _controller,
        theme: _aetherTerminalTheme,
        textStyle: TerminalStyle(fontSize: _fontSize),
        autofocus: true,
        backgroundOpacity: 0,
        keyboardType: TextInputType.visiblePassword,
        onSecondaryTapDown: (details, __) {
          _showContextMenu(context, details.globalPosition, state.terminal);
        },
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
              // Pinch-to-zoom on mobile; long-press for context menu
              GestureDetector(
                onScaleStart: (_) => _scaleStart = _fontSize,
                onScaleUpdate: (details) {
                  if (details.pointerCount < 2) return;
                  setState(() {
                    _fontSize = (_scaleStart * details.scale)
                        .clamp(_minFontSize, _maxFontSize);
                  });
                },
                onLongPressStart: (details) {
                  _showContextMenu(
                      context, details.globalPosition, state.terminal);
                },
                child: terminalView,
              ),
              // Ctrl+scroll zoom overlay
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
        _MobileKeyboardToolbar(
          terminal: state.terminal,
          onPaste: () => _paste(state.terminal),
        ),
      ],
    );
  }
}

enum _MenuAction { copy, paste }

class _MenuEntry extends StatelessWidget {
  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.enabled,
  });
  final IconData icon;
  final String label;
  final String shortcut;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AetherColors.textPrimary : AetherColors.textSecondary;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(color: color, fontSize: 13)),
        ),
        Text(shortcut,
            style: TextStyle(
                color: AetherColors.textSecondary,
                fontSize: 11)),
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
  const _MobileKeyboardToolbar({
    required this.terminal,
    required this.onPaste,
  });
  final Terminal terminal;
  final VoidCallback onPaste;

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
            _Key('Tab',   () => terminal.keyInput(TerminalKey.tab)),
            _Key('Esc',   () => terminal.keyInput(TerminalKey.escape)),
            _Key('Ctrl',  () => terminal.keyInput(TerminalKey.controlLeft)),
            _Key('↑',     () => terminal.keyInput(TerminalKey.arrowUp)),
            _Key('↓',     () => terminal.keyInput(TerminalKey.arrowDown)),
            _Key('←',     () => terminal.keyInput(TerminalKey.arrowLeft)),
            _Key('→',     () => terminal.keyInput(TerminalKey.arrowRight)),
            _Key('Home',  () => terminal.keyInput(TerminalKey.home)),
            _Key('End',   () => terminal.keyInput(TerminalKey.end)),
            _Key('Paste', onPaste),
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
