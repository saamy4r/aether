import 'package:flutter/foundation.dart';

@immutable
class CpuStats {
  const CpuStats({required this.usagePercent, required this.loadAvg});
  final double usagePercent;
  final List<double> loadAvg; // [1m, 5m, 15m]
}

@immutable
class MemStats {
  const MemStats({
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
  });
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;

  double get usagePercent =>
      totalBytes == 0 ? 0 : (usedBytes / totalBytes) * 100;
}

@immutable
class DiskMount {
  const DiskMount({
    required this.mountPoint,
    required this.totalBytes,
    required this.usedBytes,
    required this.filesystem,
  });
  final String mountPoint;
  final int totalBytes;
  final int usedBytes;
  final String filesystem;

  double get usagePercent =>
      totalBytes == 0 ? 0 : (usedBytes / totalBytes) * 100;
}

@immutable
class NetworkStats {
  const NetworkStats({
    required this.rxBytesPerSec,
    required this.txBytesPerSec,
    required this.interface_,
  });
  final double rxBytesPerSec;
  final double txBytesPerSec;
  final String interface_;
}

@immutable
class ServerStats {
  const ServerStats({
    required this.cpu,
    required this.mem,
    required this.disks,
    required this.network,
    required this.uptimeSeconds,
    required this.processCount,
    required this.timestamp,
  });
  final CpuStats cpu;
  final MemStats mem;
  final List<DiskMount> disks;
  final NetworkStats? network;
  final double uptimeSeconds;
  final int processCount;
  final DateTime timestamp;

  String get uptimeFormatted {
    final days = (uptimeSeconds / 86400).floor();
    final hours = ((uptimeSeconds % 86400) / 3600).floor();
    final minutes = ((uptimeSeconds % 3600) / 60).floor();
    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
