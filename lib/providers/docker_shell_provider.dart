import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' hide TerminalState;
import '../core/utils/shell_escape.dart';
import 'terminal_provider.dart';
import 'vps_connection_provider.dart';

class DockerShellNotifier extends FamilyNotifier<TerminalState,
    ({String windowId, String containerId, String vpsId})> {
  SSHSession? _session;
  StreamSubscription? _stdoutSub;

  @override
  TerminalState build(
      ({String windowId, String containerId, String vpsId}) arg) {
    ref.onDispose(_cleanup);
    final terminal = Terminal();
    _connect(terminal);
    return TerminalState(terminal: terminal, status: TerminalStatus.connecting);
  }

  Future<void> _connect(Terminal terminal) async {
    final client =
        ref.read(vpsConnectionProvider(arg.vpsId)).valueOrNull?.client;
    if (client == null) {
      state = TerminalState(
        terminal: terminal,
        status: TerminalStatus.error,
        errorMessage: 'Not connected to VPS.',
      );
      return;
    }
    try {
      _session = await client.shell(
        pty: SSHPtyConfig(type: 'xterm-256color', width: 80, height: 24),
      );

      _stdoutSub = _session!.stdout.listen(
        (data) => terminal.write(utf8.decode(data, allowMalformed: true)),
        onDone: _onDone,
      );

      terminal.onOutput = (data) {
        _session?.stdin.add(Uint8List.fromList(utf8.encode(data)));
      };

      terminal.onResize = (w, h, pw, ph) {
        _session?.resizeTerminal(w, h, pw, ph);
      };

      // Send docker exec command; try bash first, fall back to sh
      final id = shQuote(arg.containerId);
      _session!.stdin.add(utf8.encode(
        'docker exec -it $id /bin/bash 2>/dev/null || docker exec -it $id /bin/sh\n',
      ));

      state = TerminalState(terminal: terminal, status: TerminalStatus.connected);
    } catch (e) {
      state = TerminalState(
        terminal: terminal,
        status: TerminalStatus.error,
        errorMessage: 'Failed to open shell: $e',
      );
    }
  }

  void _onDone() {
    state.terminal.write('\r\n[Shell closed]\r\n');
    state = TerminalState(
      terminal: state.terminal,
      status: TerminalStatus.disconnected,
    );
  }

  void _cleanup() {
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _session?.close();
    _session = null;
  }
}

final dockerShellProvider = NotifierProvider.family<DockerShellNotifier,
    TerminalState, ({String windowId, String containerId, String vpsId})>(
  DockerShellNotifier.new,
);
