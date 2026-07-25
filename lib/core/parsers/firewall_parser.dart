import '../models/firewall_models.dart';

abstract final class FirewallParser {
  // ── Port scan (ss or netstat) ───────────────────────────────────────────────

  static List<PortEntry> parsePortScan(String output) {
    // Detect format: ss header starts with 'Netid'; netstat has 'Proto'.
    // (Both headers contain 'State', so that word cannot distinguish them.)
    if (output.contains('Proto') && !output.contains('Netid')) {
      return _parseNetstat(output);
    }
    return _parseSs(output);
  }

  // ss -tulpn output:
  //   Netid  State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port  Process
  //   tcp    LISTEN  0       128     0.0.0.0:22          0.0.0.0:*          users:(("sshd",pid=1234,fd=3))
  // Match lines that have LISTEN state
  static final _ssListenRe = RegExp(
    r'^(tcp|udp)\s+LISTEN\s+\d+\s+\d+\s+(\S+)\s+\S+(?:\s+users:\(\("([^"]+)")?',
    multiLine: true,
    caseSensitive: false,
  );

  // ss shows udp as UNCONN, not LISTEN
  static final _ssUdpRe = RegExp(
    r'^udp\s+UNCONN\s+\d+\s+\d+\s+(\S+)\s+\S+(?:\s+users:\(\("([^"]+)")?',
    multiLine: true,
    caseSensitive: false,
  );

  static List<PortEntry> _parseSs(String output) {
    final results = <PortEntry>[];
    final seen = <String>{};

    for (final m in _ssListenRe.allMatches(output)) {
      final proto = m.group(1)!.toLowerCase();
      final localAddr = m.group(2)!;
      final process = m.group(3) ?? '';

      final (address, port) = _splitAddress(localAddr);
      if (port == null) continue;

      final key = '$proto:$port';
      if (seen.contains(key)) continue;
      seen.add(key);

      results.add(PortEntry(
        proto: proto,
        address: address,
        port: port,
        process: process,
        ufwStatus: UfwPortStatus.unknown,
      ));
    }

    for (final m in _ssUdpRe.allMatches(output)) {
      final localAddr = m.group(1)!;
      final process = m.group(2) ?? '';
      final (address, port) = _splitAddress(localAddr);
      if (port == null) continue;
      final key = 'udp:$port';
      if (seen.contains(key)) continue;
      seen.add(key);
      results.add(PortEntry(
        proto: 'udp',
        address: address,
        port: port,
        process: process,
        ufwStatus: UfwPortStatus.unknown,
      ));
    }

    results.sort((a, b) => a.port.compareTo(b.port));
    return results;
  }

  // netstat -tulpn output:
  //   Proto  Recv-Q  Send-Q  Local Address    Foreign Address  State   PID/Program name
  //   tcp    0       0       0.0.0.0:22       0.0.0.0:*        LISTEN  1234/sshd
  //   tcp6   0       0       :::80            :::*             LISTEN  5678/nginx
  // tcp rows carry a LISTEN state; process may be '1234/name' or '-'
  // (without root)
  static final _netstatTcpRe = RegExp(
    r'^(tcp\d?)\s+\d+\s+\d+\s+(\S+)\s+\S+\s+LISTEN(?:\s+(\S+))?\s*$',
    multiLine: true,
    caseSensitive: false,
  );

  // udp rows have an empty State column
  static final _netstatUdpRe = RegExp(
    r'^(udp\d?)\s+\d+\s+\d+\s+(\S+)\s+\S+\s+(\S+)?\s*$',
    multiLine: true,
    caseSensitive: false,
  );

  static List<PortEntry> _parseNetstat(String output) {
    final results = <PortEntry>[];
    final seen = <String>{};

    void addMatch(RegExpMatch m) {
      var proto = m.group(1)!.toLowerCase();
      // Normalize tcp6/udp6 → tcp/udp
      if (proto == 'tcp6') proto = 'tcp';
      if (proto == 'udp6') proto = 'udp';

      final localAddr = m.group(2)!;
      // Last column is 'pid/program' or '-'
      final pidProg = m.group(3) ?? '';
      final slash = pidProg.indexOf('/');
      final process = slash == -1 ? '' : pidProg.substring(slash + 1);

      final (address, port) = _splitAddress(localAddr);
      if (port == null) return;

      final key = '$proto:$port';
      if (seen.contains(key)) return;
      seen.add(key);

      results.add(PortEntry(
        proto: proto,
        address: address,
        port: port,
        process: process,
        ufwStatus: UfwPortStatus.unknown,
      ));
    }

    _netstatTcpRe.allMatches(output).forEach(addMatch);
    _netstatUdpRe.allMatches(output).forEach(addMatch);

    results.sort((a, b) => a.port.compareTo(b.port));
    return results;
  }

  /// Split '0.0.0.0:22', '*:80', '[::]:443', ':::22' → (address, port)
  static (String, int?) _splitAddress(String localAddr) {
    // IPv6 bracket form: [::1]:22
    if (localAddr.startsWith('[')) {
      final idx = localAddr.lastIndexOf(':');
      if (idx == -1) return (localAddr, null);
      final portStr = localAddr.substring(idx + 1);
      final port = int.tryParse(portStr);
      return (localAddr.substring(0, idx), port);
    }
    // ss uses ':::22' for IPv6 any-address
    if (localAddr.startsWith(':::')) {
      final port = int.tryParse(localAddr.substring(3));
      return (':::', port);
    }
    // Standard 'host:port'
    final idx = localAddr.lastIndexOf(':');
    if (idx == -1) return (localAddr, null);
    final portStr = localAddr.substring(idx + 1);
    final port = int.tryParse(portStr);
    return (localAddr.substring(0, idx), port);
  }

  // ── UFW status numbered ────────────────────────────────────────────────────

  // Pattern: [ 1] 22/tcp                     ALLOW IN    Anywhere
  //          [ 2] 80/tcp                     ALLOW IN    Anywhere
  //          [ 3] Nginx Full                 ALLOW IN    Anywhere
  static final _ufwRuleRe = RegExp(
    r'\[\s*(\d+)\]\s+(.+?)\s{2,}(ALLOW|DENY|LIMIT)\s+(?:IN\s+|OUT\s+)?(\S+.*)',
    multiLine: true,
    caseSensitive: false,
  );

  static ({List<UfwRule> rules, UfwEnabled enabled}) parseUfwStatus(
      String raw) {
    UfwEnabled enabled = UfwEnabled.unknown;
    if (raw.contains('Status: active')) {
      enabled = UfwEnabled.active;
    } else if (raw.contains('Status: inactive')) {
      enabled = UfwEnabled.inactive;
    }

    final rules = <UfwRule>[];

    for (final m in _ufwRuleRe.allMatches(raw)) {
      final number = int.tryParse(m.group(1)!.trim());
      if (number == null) continue;
      rules.add(UfwRule(
        number: number,
        to: m.group(2)!.trim(),
        action: m.group(3)!.trim().toUpperCase(),
        from: m.group(4)!.trim(),
      ));
    }

    return (rules: rules, enabled: enabled);
  }

  // ── Correlate ports ↔ UFW rules ────────────────────────────────────────────

  static List<PortEntry> correlate(
      List<PortEntry> ports, List<UfwRule> rules) {
    return ports.map((p) {
      // Find a matching rule: rule.to contains our port number
      // e.g. '22/tcp', '22', 'OpenSSH' (we check port number string)
      final portStr = p.port.toString();

      UfwRule? match;
      for (final r in rules) {
        // Match if rule.to starts with port or 'port/proto'
        if (r.to == portStr ||
            r.to.startsWith('$portStr/') ||
            r.to.startsWith('$portStr ')) {
          match = r;
          break;
        }
      }

      if (match == null) return p;

      final status = match.action == 'ALLOW' || match.action == 'LIMIT'
          ? UfwPortStatus.allowed
          : UfwPortStatus.denied;

      return p.copyWith(ufwStatus: status, ufwRuleNumber: match.number);
    }).toList();
  }
}
