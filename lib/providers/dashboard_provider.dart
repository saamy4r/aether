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

  static const Object _keep = Object();

  DashboardState copyWith({
    ServerStats? stats,
    List<double>? cpuHistory,
    Object? errorMessage = _keep,
    bool? isPolling,
  }) => DashboardState(
    stats: stats ?? this.stats,
    cpuHistory: cpuHistory ?? this.cpuHistory,
    errorMessage: identical(errorMessage, _keep)
        ? this.errorMessage
        : errorMessage as String?,
    isPolling: isPolling ?? this.isPolling,
  );
}

class DashboardNotifier extends FamilyNotifier<DashboardState, String> {
  Timer? _pollTimer;
  Timer? _diskTimer;
  bool _polling = false;
  bool _diskPolling = false;
  int _consecutiveFailures = 0;
  List<DiskMount>? _lastDisks;

  String get vpsId => arg;

  @override
  DashboardState build(String arg) {
    ref.onDispose(_stopPolling);
    _startPolling();
    return const DashboardState(isPolling: true);
  }

  void _startPolling() {
    _stopPolling();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    _pollDisk();
    _diskTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _pollDisk());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _diskTimer?.cancel();
    _diskTimer = null;
  }

  bool get _isConnected =>
      ref.read(vpsConnectionProvider(vpsId)).valueOrNull?.isConnected ?? false;

  Future<void> _poll() async {
    if (_polling || !_isConnected) return;
    _polling = true;
    try {
      final notifier = ref.read(vpsConnectionProvider(vpsId).notifier);
      final out = await notifier.exec(
        SshCommands.dashboardSample,
        timeout: const Duration(seconds: 12),
      );
      final sections = out.split(SshCommands.sectionSplit);
      final parsed = StatsParser.parseCpuMemLoad(sections.first);
      final net =
          sections.length > 1 ? NetParser.parseDelta(sections[1]) : null;

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
        _stopPolling();
        state = state.copyWith(
          errorMessage: 'Polling failed after 3 attempts. Tap to retry.',
          isPolling: false,
        );
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollDisk() async {
    if (_diskPolling || !_isConnected) return;
    _diskPolling = true;
    try {
      final notifier = ref.read(vpsConnectionProvider(vpsId).notifier);
      final out = await notifier.exec(SshCommands.diskUsage);
      _lastDisks = DfParser.parse(out);
    } catch (_) {
    } finally {
      _diskPolling = false;
    }
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
