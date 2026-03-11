import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'vps_connection_provider.dart';

enum TerminalStatus { connecting, connected, disconnected, error }

class TerminalState {
  const TerminalState({
    required this.terminal,
    required this.status,
    this.errorMessage,
  });
  final Terminal terminal;
  final TerminalStatus status;
  final String? errorMessage;
}

// windowId -> vpsId
class TerminalNotifier
    extends FamilyNotifier<TerminalState, ({String windowId, String vpsId})> {
  SSHSession? _session;
  StreamSubscription? _stdoutSub;

  @override
  TerminalState build(({String windowId, String vpsId}) arg) {
    ref.onDispose(_cleanup);
    final terminal = Terminal();
    _connect(terminal);
    return TerminalState(
      terminal: terminal,
      status: TerminalStatus.connecting,
    );
  }

  Future<void> _connect(Terminal terminal) async {
    final connState = ref.read(vpsConnectionProvider(arg.vpsId));
    final client = connState.valueOrNull?.client;
    if (client == null) {
      state = TerminalState(
        terminal: state.terminal,
        status: TerminalStatus.error,
        errorMessage: 'Not connected to VPS.',
      );
      return;
    }
    try {
      _session = await client.shell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: 80,
          height: 24,
        ),
      );

      _stdoutSub = _session!.stdout.listen(
        (data) => terminal.write(utf8.decode(data, allowMalformed: true)),
        onDone: _onSessionDone,
      );

      terminal.onOutput = (data) {
        _session?.stdin.add(Uint8List.fromList(utf8.encode(data)));
      };

      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        _session?.resizeTerminal(width, height, pixelWidth, pixelHeight);
      };

      // Request a thin beam cursor (DECSCUSR 6 = steady bar)
      terminal.write('\x1b[6 q');

      state = TerminalState(
        terminal: terminal,
        status: TerminalStatus.connected,
      );
    } catch (e) {
      state = TerminalState(
        terminal: terminal,
        status: TerminalStatus.error,
        errorMessage: 'Failed to open shell: $e',
      );
    }
  }

  void _onSessionDone() {
    state.terminal.write('\r\n[Connection closed]\r\n');
    state = TerminalState(
      terminal: state.terminal,
      status: TerminalStatus.disconnected,
    );
  }

  void resize(int cols, int rows) {
    _session?.resizeTerminal(cols, rows);
  }

  Future<void> reconnect() async {
    _cleanup();
    final terminal = state.terminal;
    state = TerminalState(terminal: terminal, status: TerminalStatus.connecting);
    await _connect(terminal);
  }

  void _cleanup() {
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _session?.close();
    _session = null;
  }
}

final terminalProvider = NotifierProvider.family<TerminalNotifier,
    TerminalState, ({String windowId, String vpsId})>(
  TerminalNotifier.new,
);
