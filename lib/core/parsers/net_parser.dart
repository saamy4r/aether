import '../models/server_stats.dart';

class NetParser {
  /// Parses two snapshots of /proc/net/dev separated by 1 second.
  /// Returns NetworkStats for the most active non-loopback interface.
  static NetworkStats? parseDelta(String output) {
    final halves = output.split('\n\n');
    if (halves.length < 2) {
      // Try splitting by the repeated header
      final lines = output.split('\n');
      final headerIndices = <int>[];
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('Inter-|') || lines[i].contains('face |')) {
          headerIndices.add(i);
        }
      }
      if (headerIndices.length < 2) return null;
      final first  = lines.sublist(0, headerIndices[1]).join('\n');
      final second = lines.sublist(headerIndices[1]).join('\n');
      return _computeDelta(first, second);
    }
    return _computeDelta(halves[0], halves[1]);
  }

  static Map<String, ({int rx, int tx})> _parseSnapshot(String block) {
    final result = <String, ({int rx, int tx})>{};
    for (final line in block.split('\n')) {
      if (!line.contains(':')) continue;
      final colonIdx = line.indexOf(':');
      final iface = line.substring(0, colonIdx).trim();
      final parts = line.substring(colonIdx + 1).trim().split(RegExp(r'\s+'));
      if (parts.length < 10) continue;
      final rx = int.tryParse(parts[0]) ?? 0;
      final tx = int.tryParse(parts[8]) ?? 0;
      result[iface] = (rx: rx, tx: tx);
    }
    return result;
  }

  static NetworkStats? _computeDelta(String first, String second) {
    final s1 = _parseSnapshot(first);
    final s2 = _parseSnapshot(second);

    NetworkStats? best;
    double bestTotal = 0;

    for (final iface in s2.keys) {
      if (iface == 'lo') continue;
      final before = s1[iface];
      final after  = s2[iface];
      if (before == null || after == null) continue;

      final rx = (after.rx - before.rx).clamp(0, 1 << 32).toDouble();
      final tx = (after.tx - before.tx).clamp(0, 1 << 32).toDouble();
      if (rx + tx > bestTotal) {
        bestTotal = rx + tx;
        best = NetworkStats(
          rxBytesPerSec: rx,
          txBytesPerSec: tx,
          interface_: iface,
        );
      }
    }
    return best;
  }
}
