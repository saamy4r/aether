import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/parsers/stats_parser.dart';

const _fixture = '''
top - 12:00:01 up 10 days,  3:04,  1 user,  load average: 0.52, 0.58, 0.59
Tasks: 123 total,   1 running, 122 sleeping,   0 stopped,   0 zombie
%Cpu(s):  2.3 us, 30.0 sy,  0.0 ni, 60.2 id,  7.0 wa,  0.0 hi,  0.5 si,  0.0 st
MiB Mem :   3931.2 total,    241.6 free,   1268.5 used,   2421.1 buff/cache
MiB Swap:      0.0 total,      0.0 free,      0.0 used.   2394.5 avail Mem
              total        used        free      shared  buff/cache   available
Mem:     4122181632  1330204672   253321216    12345678  2538655744  2510456832
Swap:             0           0           0
878123.45 1745632.10
0.52 0.58 0.59 2/345 12345
''';

void main() {
  group('StatsParser.parseCpuMemLoad', () {
    test('CPU usage is 100 - idle, not just user time', () {
      final r = StatsParser.parseCpuMemLoad(_fixture);
      // idle = 60.2 → busy = 39.8 (would be 2.3 if only "us" was counted)
      expect(r.cpu.usagePercent, closeTo(39.8, 0.001));
    });

    test('old top format "95.5%id" is handled', () {
      const oldTop =
          'Cpu(s):  2.3%us,  1.0%sy,  0.0%ni, 95.5%id,  1.2%wa,  0.0%hi\n';
      final r = StatsParser.parseCpuMemLoad(oldTop);
      expect(r.cpu.usagePercent, closeTo(4.5, 0.001));
    });

    test('memory totals from free -b', () {
      final r = StatsParser.parseCpuMemLoad(_fixture);
      expect(r.mem.totalBytes, 4122181632);
      expect(r.mem.usedBytes, 1330204672);
      expect(r.mem.availableBytes, 2510456832);
    });

    test('free without available column leaves availableBytes 0', () {
      const noAvail = 'Mem:  4122181632  1330204672  253321216\n';
      final r = StatsParser.parseCpuMemLoad(noAvail);
      expect(r.mem.totalBytes, 4122181632);
      expect(r.mem.availableBytes, 0);
    });

    test('uptime, loadavg and process count', () {
      final r = StatsParser.parseCpuMemLoad(_fixture);
      expect(r.uptime, closeTo(878123.45, 0.001));
      expect(r.cpu.loadAvg, [0.52, 0.58, 0.59]);
      expect(r.processCount, 345);
    });

    test('empty output returns zeroed stats', () {
      final r = StatsParser.parseCpuMemLoad('');
      expect(r.cpu.usagePercent, 0);
      expect(r.mem.totalBytes, 0);
      expect(r.uptime, 0);
    });
  });
}
