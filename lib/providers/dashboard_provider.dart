import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/server_stats.dart';
import '../core/constants/ssh_commands.dart';
import '../core/parsers/stats_parser.dart';
import '../core/parsers/df_parser.dart';
import '../core/parsers/net_parser.dart';
import 'vps_connection_provider.dart';

class DashboardState {
  const DashboardState({
    this.stats,
    this.cpuHistory = const [],
    this.errorMessage,
    this.isPolling = false,
  });
  final ServerStats? stats;
  final List<double> cpuHistory; // last 60 readings
  final String? errorMessage;
  final bool isPolling;

  DashboardState copyWith({
    ServerStats? stats,
    List<double>? cpuHistory,
    String? errorMessage,
    bool? isPolling,
  }) => DashboardState(
    stats: stats ?? this.stats,
    cpuHistory: cpuHistory ?? this.cpuHistory,
    errorMessage: errorMessage,
    isPolling: isPolling ?? this.isPolling,
  );
}

class DashboardNotifier extends FamilyNotifier<DashboardState, String> {
  Timer? _pollTimer;
  Timer? _diskTimer;
  int _consecutiveFailures = 0;
  List<DiskMount>? _lastDisks;

  String get vpsId => arg;

  @override
  DashboardState build(String arg) {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _diskTimer?.cancel();
    });
    _startPolling();
    return const DashboardState(isPolling: true);
  }

  void _startPolling() {
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    _pollDisk();
    _diskTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollDisk());
  }

  Future<void> _poll() async {
    final conn = ref.read(vpsConnectionProvider(vpsId));
    final notifier = ref.read(vpsConnectionProvider(vpsId).notifier);
    if (!conn.valueOrNull!.isConnected) return;

    try {
      final [cpuOut, netOut] = await Future.wait([
        notifier.exec(SshCommands.cpuMemLoad),
        notifier.exec(SshCommands.networkSample, timeout: const Duration(seconds: 12)),
      ]);

      final parsed = StatsParser.parseCpuMemLoad(cpuOut);
      final net = NetParser.parseDelta(netOut);

      final history = [
        ...state.cpuHistory,
        parsed.cpu.usagePercent,
      ];
      if (history.length > 60) history.removeAt(0);

      final stats = ServerStats(
        cpu: parsed.cpu,
        mem: parsed.mem,
        disks: _lastDisks ?? [],
        network: net,
        uptimeSeconds: parsed.uptime,
        processCount: parsed.processCount,
        timestamp: DateTime.now(),
      );

      _consecutiveFailures = 0;
      state = state.copyWith(
        stats: stats,
        cpuHistory: history,
        errorMessage: null,
      );
    } catch (e) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 3) {
        _pollTimer?.cancel();
        state = state.copyWith(
          errorMessage: 'Polling failed after 3 attempts. Tap to retry.',
          isPolling: false,
        );
      }
    }
  }

  Future<void> _pollDisk() async {
    final notifier = ref.read(vpsConnectionProvider(vpsId).notifier);
    try {
      final out = await notifier.exec(SshCommands.diskUsage);
      _lastDisks = DfParser.parse(out);
    } catch (_) {}
  }

  void retry() {
    _consecutiveFailures = 0;
    state = state.copyWith(isPolling: true, errorMessage: null);
    _startPolling();
  }
}

final dashboardProvider =
    NotifierProvider.family<DashboardNotifier, DashboardState, String>(
  DashboardNotifier.new,
);
