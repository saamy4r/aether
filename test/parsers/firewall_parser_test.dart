import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/models/firewall_models.dart';
import 'package:aether/core/parsers/firewall_parser.dart';

const _ssOutput = '''
Netid  State   Recv-Q  Send-Q   Local Address:Port   Peer Address:Port  Process
tcp    LISTEN  0       128      0.0.0.0:22           0.0.0.0:*          users:(("sshd",pid=1234,fd=3))
tcp    LISTEN  0       511      [::]:80              [::]:*             users:(("nginx",pid=5678,fd=6))
udp    UNCONN  0       0        0.0.0.0:68           0.0.0.0:*          users:(("dhclient",pid=910,fd=6))
''';

const _netstatOutput = '''
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1234/sshd
tcp6       0      0 :::80                   :::*                    LISTEN      5678/nginx
tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN      -
udp        0      0 0.0.0.0:68              0.0.0.0:*                           910/dhclient
''';

const _ufwOutput = '''
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 80/tcp                     ALLOW IN    Anywhere
[ 3] 443                        DENY IN     10.0.0.0/8
''';

void main() {
  group('parsePortScan — ss format', () {
    test('parses tcp LISTEN and udp UNCONN with process names', () {
      final ports = FirewallParser.parsePortScan(_ssOutput);
      expect(ports.map((p) => p.port).toList(), [22, 68, 80]);
      final ssh = ports.firstWhere((p) => p.port == 22);
      expect(ssh.proto, 'tcp');
      expect(ssh.process, 'sshd');
      final dhcp = ports.firstWhere((p) => p.port == 68);
      expect(dhcp.proto, 'udp');
      expect(dhcp.process, 'dhclient');
    });
  });

  group('parsePortScan — netstat format', () {
    test('netstat output is not misrouted to the ss parser', () {
      // netstat headers contain the word 'State' too — must still be
      // detected as netstat.
      final ports = FirewallParser.parsePortScan(_netstatOutput);
      expect(ports, isNotEmpty);
    });

    test('parses tcp, tcp6 and rows without process (-)', () {
      final ports = FirewallParser.parsePortScan(_netstatOutput);
      expect(ports.map((p) => p.port).toSet(), {22, 80, 3306, 68});
      final nginx = ports.firstWhere((p) => p.port == 80);
      expect(nginx.proto, 'tcp'); // tcp6 normalized
      expect(nginx.process, 'nginx');
      final mysql = ports.firstWhere((p) => p.port == 3306);
      expect(mysql.process, '');
    });

    test('udp rows (empty State column) are included', () {
      final ports = FirewallParser.parsePortScan(_netstatOutput);
      final udp = ports.where((p) => p.proto == 'udp').toList();
      expect(udp.length, 1);
      expect(udp.single.port, 68);
      expect(udp.single.process, 'dhclient');
    });
  });

  group('parseUfwStatus', () {
    test('parses status and numbered rules', () {
      final (:rules, :enabled) = FirewallParser.parseUfwStatus(_ufwOutput);
      expect(enabled, UfwEnabled.active);
      expect(rules.length, 3);
      expect(rules[0].number, 1);
      expect(rules[0].to, '22/tcp');
      expect(rules[0].action, 'ALLOW');
      expect(rules[2].action, 'DENY');
      expect(rules[2].from, '10.0.0.0/8');
    });

    test('inactive status', () {
      final (:rules, :enabled) =
          FirewallParser.parseUfwStatus('Status: inactive\n');
      expect(enabled, UfwEnabled.inactive);
      expect(rules, isEmpty);
    });

    test('empty output is unknown', () {
      final (:enabled, rules: _) = FirewallParser.parseUfwStatus('');
      expect(enabled, UfwEnabled.unknown);
    });
  });

  group('correlate', () {
    test('marks scanned ports allowed/denied from rules', () {
      final ports = FirewallParser.parsePortScan(_ssOutput);
      final (:rules, enabled: _) = FirewallParser.parseUfwStatus(_ufwOutput);
      final correlated = FirewallParser.correlate(ports, rules);
      final ssh = correlated.firstWhere((p) => p.port == 22);
      expect(ssh.ufwStatus, UfwPortStatus.allowed);
      expect(ssh.ufwRuleNumber, 1);
      final dhcp = correlated.firstWhere((p) => p.port == 68);
      expect(dhcp.ufwStatus, UfwPortStatus.unknown);
    });
  });
}
