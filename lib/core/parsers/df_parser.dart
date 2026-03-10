import '../models/server_stats.dart';

class DfParser {
  /// Parses output of: df -B1 -x tmpfs -x devtmpfs -x overlay
  static List<DiskMount> parse(String output) {
    final mounts = <DiskMount>[];
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('Filesystem')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 6) continue;

      final totalBytes = int.tryParse(parts[1]) ?? 0;
      final usedBytes  = int.tryParse(parts[2]) ?? 0;
      final mountPoint = parts[5];

      // Skip pseudo-filesystems that slipped through
      if (mountPoint.startsWith('/sys') || mountPoint.startsWith('/proc')) {
        continue;
      }

      mounts.add(DiskMount(
        filesystem: parts[0],
        totalBytes: totalBytes,
        usedBytes: usedBytes,
        mountPoint: mountPoint,
      ));
    }
    // Sort by usage descending
    mounts.sort((a, b) => b.usagePercent.compareTo(a.usagePercent));
    return mounts;
  }
}
