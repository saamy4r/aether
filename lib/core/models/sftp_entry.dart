import 'package:flutter/foundation.dart';

@immutable
class SftpEntry {
  const SftpEntry({
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.permissions,
    required this.modifyTime,
  });

  final String name;
  final bool isDirectory;
  final int size;
  final int permissions;
  final DateTime modifyTime;

  String get permissionsString {
    final type = isDirectory ? 'd' : '-';
    final bits = [
      (permissions >> 8) & 1, (permissions >> 7) & 1, (permissions >> 6) & 1,
      (permissions >> 5) & 1, (permissions >> 4) & 1, (permissions >> 3) & 1,
      (permissions >> 2) & 1, (permissions >> 1) & 1, permissions & 1,
    ];
    final chars = bits.asMap().entries.map((e) {
      if (e.value == 0) return '-';
      return switch (e.key % 3) { 0 => 'r', 1 => 'w', _ => 'x' };
    }).join();
    return '$type$chars';
  }

  String get sizeFormatted {
    if (isDirectory) return '--';
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}K';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)}M';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}G';
  }
}
