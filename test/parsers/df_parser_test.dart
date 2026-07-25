import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/parsers/df_parser.dart';

void main() {
  group('DfParser.parse', () {
    test('normal -P output', () {
      const out = '''
Filesystem     1-blocks        Used  Available Capacity Mounted on
/dev/vda1    42006183936 12006183936 28000000000      30% /
/dev/vdb1    10726932480  5726932480  5000000000      54% /data
''';
      final mounts = DfParser.parse(out);
      expect(mounts.length, 2);
      // Sorted by usage descending → /data (54%) first
      expect(mounts.first.mountPoint, '/data');
      expect(mounts.first.totalBytes, 10726932480);
      expect(mounts.first.usedBytes, 5726932480);
      expect(mounts[1].filesystem, '/dev/vda1');
    });

    test('long device name stays on one line with -P', () {
      const out = '''
Filesystem     1-blocks        Used  Available Capacity Mounted on
/dev/mapper/very-long-volume-group-name-lv 42006183936 12006183936 28000000000 30% /
''';
      final mounts = DfParser.parse(out);
      expect(mounts.length, 1);
      expect(mounts.first.filesystem,
          '/dev/mapper/very-long-volume-group-name-lv');
      expect(mounts.first.mountPoint, '/');
    });

    test('mount point containing spaces is preserved', () {
      const out = '''
Filesystem 1-blocks Used Available Capacity Mounted on
/dev/sdb1 1000 500 500 50% /mnt/My Disk
''';
      final mounts = DfParser.parse(out);
      expect(mounts.single.mountPoint, '/mnt/My Disk');
    });

    test('pseudo filesystems and headers are skipped', () {
      const out = '''
Filesystem 1-blocks Used Available Capacity Mounted on
sysfs 0 0 0 0% /sys/kernel
proc 0 0 0 0% /proc
''';
      expect(DfParser.parse(out), isEmpty);
    });

    test('empty output', () {
      expect(DfParser.parse(''), isEmpty);
    });
  });
}
