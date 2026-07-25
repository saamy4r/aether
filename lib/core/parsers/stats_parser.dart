import '../models/server_stats.dart';

class StatsParser {
  // Both "95.5 id" (procps-ng) and "95.5%id" (older top) formats
  static final _cpuIdleRe = RegExp(r'([\d.]+)[%\s]+id');
  static final _cpuUserRe = RegExp(r'([\d.]+)[%\s]+us');
  static final _uptimeRe = RegExp(r'^\d+\.\d+\s+\d+\.\d+$');
  static final _loadRe = RegExp(r'^[\d.]+\s+[\d.]+\s+[\d.]+\s+\d+/\d+');
  static final _wsRe = RegExp(r'\s+');

  /// Parses combined output of:
  /// top -bn1 | head -5; free -b; cat /proc/uptime; cat /proc/loadavg
  static ({CpuStats cpu, MemStats mem, double uptime, int processCount})
      parseCpuMemLoad(String output) {
    double cpuUsage = 0;
    List<double> loadAvg = [0, 0, 0];
    int memTotal = 0, memUsed = 0, memAvail = 0;
    double uptime = 0;
    int processCount = 0;

    for (final line in output.split('\n')) {
      final trimmed = line.trim();

      // CPU from top: "%Cpu(s):  2.3 us,  1.0 sy, ... 95.5 id, ..."
      // Busy = 100 - idle, so system/iowait/steal time is counted too.
      if (trimmed.contains('Cpu(s)')) {
        final idMatch = _cpuIdleRe.firstMatch(trimmed);
        if (idMatch != null) {
          final idle = double.tryParse(idMatch.group(1)!);
          if (idle != null) cpuUsage = (100 - idle).clamp(0, 100);
        } else {
          // Fallback: user time only
          final usMatch = _cpuUserRe.firstMatch(trimmed);
          if (usMatch != null) {
            cpuUsage = double.tryParse(usMatch.group(1)!) ?? 0;
          }
        }
      }

      // Memory from free -b: "Mem: total used free ..."
      if (trimmed.startsWith('Mem:')) {
        final parts = trimmed.split(_wsRe);
        if (parts.length >= 3) {
          memTotal = int.tryParse(parts[1]) ?? 0;
          memUsed  = int.tryParse(parts[2]) ?? 0;
          if (parts.length >= 7) {
            memAvail = int.tryParse(parts[6]) ?? 0;
          }
        }
      }

      // Uptime from /proc/uptime: "12345.67 23456.78"
      if (_uptimeRe.hasMatch(trimmed)) {
        uptime = double.tryParse(trimmed.split(' ').first) ?? 0;
      }

      // Load average from /proc/loadavg: "0.10 0.15 0.20 1/234 5678"
      if (_loadRe.hasMatch(trimmed)) {
        final parts = trimmed.split(_wsRe);
        loadAvg = [
          double.tryParse(parts[0]) ?? 0,
          double.tryParse(parts[1]) ?? 0,
          double.tryParse(parts[2]) ?? 0,
        ];
        // Process count from "X/Y" field
        if (parts.length > 3) {
          final countParts = parts[3].split('/');
          processCount = int.tryParse(countParts.last) ?? 0;
        }
      }
    }

    return (
      cpu: CpuStats(usagePercent: cpuUsage, loadAvg: loadAvg),
      mem: MemStats(
        totalBytes: memTotal,
        usedBytes: memUsed,
        availableBytes: memAvail,
      ),
      uptime: uptime,
      processCount: processCount,
    );
  }
}
