import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart' hide TerminalState;
import '../core/constants/ssh_commands.dart';
import 'terminal_provider.dart';
import 'vps_connection_provider.dart';

class DockerLogsNotifier extends FamilyNotifier<TerminalState,
    ({String windowId, String containerId, String vpsId})> {
  SSHSession? _session;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;

  @override
  TerminalState build(
      ({String windowId, String containerId, String vpsId}) arg) {
    ref.onDispose(_cleanup);
    final terminal = Terminal(maxLines: 5000);
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
      _session = await client.execute(SshCommands.dockerLogs(arg.containerId));

      _stdoutSub = _session!.stdout.listen(
        (data) => terminal.write(utf8.decode(data, allowMalformed: true)),
        onDone: () => terminal.write('\r\n[Log stream ended]\r\n'),
      );
      _stderrSub = _session!.stderr.listen(
        (data) => terminal.write(utf8.decode(data, allowMalformed: true)),
      );

      state = TerminalState(terminal: terminal, status: TerminalStatus.connected);
    } catch (e) {
      state = TerminalState(
        terminal: terminal,
        status: TerminalStatus.error,
        errorMessage: 'Failed to stream logs: $e',
      );
    }
  }

  void _cleanup() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _session?.close();
    _session = null;
  }
}

final dockerLogsProvider = NotifierProvider.family<DockerLogsNotifier,
    TerminalState, ({String windowId, String containerId, String vpsId})>(
  DockerLogsNotifier.new,
);
