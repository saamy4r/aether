import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/parsers/net_parser.dart';

String _snapshot({required int rx, required int tx}) => '''
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo:  100000     500    0    0    0     0          0         0   100000     500    0    0    0     0       0          0
  eth0: $rx    9000    0    0    0     0          0         0  $tx    8000    0    0    0     0       0          0
''';

void main() {
  group('NetParser.parseDelta', () {
    test('computes per-second delta for most active interface', () {
      final out =
          _snapshot(rx: 1000000, tx: 2000000) + _snapshot(rx: 1500000, tx: 2250000);
      final net = NetParser.parseDelta(out);
      expect(net, isNotNull);
      expect(net!.interface_, 'eth0');
      expect(net.rxBytesPerSec, 500000);
      expect(net.txBytesPerSec, 250000);
    });

    test('counter reset clamps to zero instead of huge negative', () {
      final out =
          _snapshot(rx: 5000000, tx: 5000000) + _snapshot(rx: 1000, tx: 2000);
      final net = NetParser.parseDelta(out);
      expect(net, isNotNull);
      expect(net!.rxBytesPerSec, 0);
      expect(net.txBytesPerSec, 0);
    });

    test('loopback is ignored', () {
      final out = _snapshot(rx: 100, tx: 100) + _snapshot(rx: 100, tx: 100);
      final net = NetParser.parseDelta(out);
      // eth0 delta is 0, but lo must never be picked
      expect(net?.interface_, isNot('lo'));
    });

    test('single snapshot returns null', () {
      expect(NetParser.parseDelta(_snapshot(rx: 1, tx: 1)), isNull);
    });

    test('empty output returns null', () {
      expect(NetParser.parseDelta(''), isNull);
    });
  });
}
