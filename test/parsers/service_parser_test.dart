import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/models/service_model.dart';
import 'package:aether/core/parsers/service_parser.dart';

void main() {
  group('ServiceParser.parseList', () {
    test('parses units and keeps multi-word descriptions intact', () {
      const out = '''
ssh.service        loaded active   running OpenSSH server daemon
nginx.service      loaded active   running A high performance web server and a reverse proxy server
cron.service       loaded inactive dead    Regular background program processing daemon
broken.service     not-found failed failed broken.service
''';
      final services = ServiceParser.parseList(out);
      expect(services.length, 4);
      expect(services[0].name, 'ssh.service');
      expect(services[0].activeState, ServiceActiveState.active);
      expect(services[0].subState, ServiceSubState.running);
      expect(services[1].description,
          'A high performance web server and a reverse proxy server');
      expect(services[2].activeState, ServiceActiveState.inactive);
      expect(services[2].subState, ServiceSubState.dead);
      expect(services[3].activeState, ServiceActiveState.failed);
    });

    test('non-service units and noise are skipped', () {
      const out = '''
dev-sda1.device  loaded active plugged  /dev/sda1
tmp.mount        loaded active mounted  Temporary Directory /tmp
''';
      expect(ServiceParser.parseList(out), isEmpty);
    });

    test('empty output', () {
      expect(ServiceParser.parseList(''), isEmpty);
    });
  });

  group('ServiceParser.isAvailable', () {
    test('based on which output', () {
      expect(ServiceParser.isAvailable('/usr/bin/systemctl\n'), isTrue);
      expect(ServiceParser.isAvailable('  \n'), isFalse);
    });
  });
}
