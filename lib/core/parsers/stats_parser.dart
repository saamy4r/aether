import '../models/server_stats.dart';

class StatsParser {
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

      // CPU from top: "%Cpu(s):  2.3 us, ..."
      if (trimmed.startsWith('%Cpu(s)')) {
        final usMatch = RegExp(r'([\d.]+)\s+us').firstMatch(trimmed);
        if (usMatch != null) {
          cpuUsage = double.tryParse(usMatch.group(1)!) ?? 0;
        }
      }

      // Memory from free -b: "Mem: total used free ..."
      if (trimmed.startsWith('Mem:')) {
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          memTotal = int.tryParse(parts[1]) ?? 0;
          memUsed  = int.tryParse(parts[2]) ?? 0;
          if (parts.length >= 7) {
            memAvail = int.tryParse(parts[6]) ?? 0;
          }
        }
      }

      // Uptime from /proc/uptime: "12345.67 23456.78"
      if (RegExp(r'^\d+\.\d+\s+\d+\.\d+$').hasMatch(trimmed)) {
        uptime = double.tryParse(trimmed.split(' ').first) ?? 0;
      }

      // Load average from /proc/loadavg: "0.10 0.15 0.20 1/234 5678"
      if (RegExp(r'^[\d.]+\s+[\d.]+\s+[\d.]+\s+\d+/\d+').hasMatch(trimmed)) {
        final parts = trimmed.split(RegExp(r'\s+'));
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
