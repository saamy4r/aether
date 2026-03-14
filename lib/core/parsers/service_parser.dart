import '../models/service_model.dart';

abstract final class ServiceParser {
  static bool isAvailable(String output) => output.trim().isNotEmpty;

  /// Parses output of:
  ///   systemctl list-units --type=service --all --no-pager --no-legend
  ///
  /// Each line looks like:
  ///   ssh.service    loaded active running OpenSSH server daemon
  /// Fields: unit, load, active, sub, description (rest of line)
  static List<ServiceModel> parseList(String output) {
    final result = <ServiceModel>[];
    for (final raw in output.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // Split into at most 5 parts: unit load active sub description
      final parts = line.splitWithLimit(5);
      if (parts.length < 4) continue;

      final name        = parts[0];
      final loadState   = parts[1];
      final activeRaw   = parts[2];
      final subRaw      = parts[3];
      final description = parts.length >= 5 ? parts[4] : '';

      // Skip lines that don't look like service units
      if (!name.endsWith('.service')) continue;

      result.add(ServiceModel(
        name:        name,
        loadState:   loadState,
        activeState: _parseActive(activeRaw),
        subState:    _parseSub(subRaw),
        description: description,
      ));
    }
    return result;
  }

  static ServiceActiveState _parseActive(String s) => switch (s) {
    'active'       => ServiceActiveState.active,
    'inactive'     => ServiceActiveState.inactive,
    'activating'   => ServiceActiveState.activating,
    'deactivating' => ServiceActiveState.deactivating,
    'failed'       => ServiceActiveState.failed,
    _              => ServiceActiveState.unknown,
  };

  static ServiceSubState _parseSub(String s) => switch (s) {
    'running' => ServiceSubState.running,
    'dead'    => ServiceSubState.dead,
    'exited'  => ServiceSubState.exited,
    'waiting' => ServiceSubState.waiting,
    'stop'    => ServiceSubState.stop,
    'failed'  => ServiceSubState.failed,
    _         => ServiceSubState.unknown,
  };
}

extension on String {
  /// Split by whitespace into at most [limit] parts.
  List<String> splitWithLimit(int limit) {
    final parts = <String>[];
    var remaining = trimLeft();
    while (parts.length < limit - 1 && remaining.isNotEmpty) {
      final idx = remaining.indexOf(RegExp(r'\s'));
      if (idx == -1) break;
      parts.add(remaining.substring(0, idx));
      remaining = remaining.substring(idx).trimLeft();
    }
    if (remaining.isNotEmpty) parts.add(remaining);
    return parts;
  }
}
