import '../models/server_stats.dart';

class DfParser {
  static final _wsRe = RegExp(r'\s+');

  /// Parses output of: df -PB1 -x tmpfs -x devtmpfs -x overlay
  /// (-P keeps long device names on one line, POSIX column layout)
  static List<DiskMount> parse(String output) {
    final mounts = <DiskMount>[];
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('Filesystem')) continue;
      final parts = trimmed.split(_wsRe);
      if (parts.length < 6) continue;

      final totalBytes = int.tryParse(parts[1]) ?? 0;
      final usedBytes  = int.tryParse(parts[2]) ?? 0;
      // Mount points may contain spaces — everything after column 5 is the path
      final mountPoint = parts.sublist(5).join(' ');

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
