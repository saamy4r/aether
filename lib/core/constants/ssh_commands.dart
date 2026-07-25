import '../utils/shell_escape.dart';

abstract final class SshCommands {
  static const String cpuMemLoad =
      'LANG=C top -bn1 | head -5; '
      'LANG=C free -b; '
      'LANG=C cat /proc/uptime; '
      'LANG=C cat /proc/loadavg';

  static const String diskUsage =
      'LANG=C df -PB1 -x tmpfs -x devtmpfs -x overlay';

  static const String networkSample =
      'LANG=C cat /proc/net/dev; sleep 1; LANG=C cat /proc/net/dev';

  /// Marker echoed between batched commands so output can be split per section.
  static const String sectionSplit = '___AETHER_SECTION___';

  /// Stats + network sample in a single round trip.
  static const String dashboardSample =
      '$cpuMemLoad; echo $sectionSplit; $networkSample';

  static const String processCount =
      'LANG=C ps aux --no-headers | wc -l';

  static const String dockerContainers =
      'LANG=C docker ps -a --format '
      '"{{.ID}}\\t{{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}"';

  static const String dockerImages =
      'LANG=C docker images --format '
      '"{{.Repository}}\\t{{.Tag}}\\t{{.ID}}\\t{{.Size}}"';

  static const String dockerDetect =
      'which docker && docker --version 2>/dev/null';

  /// Containers + images in a single round trip.
  static const String dockerOverview =
      '$dockerContainers; echo $sectionSplit; $dockerImages';

  static String dockerStart(String id)   => 'docker start ${shQuote(id)}';
  static String dockerStop(String id)    => 'docker stop ${shQuote(id)}';
  static String dockerRestart(String id) => 'docker restart ${shQuote(id)}';
  static String dockerPause(String id)   => 'docker pause ${shQuote(id)}';
  static String dockerUnpause(String id) => 'docker unpause ${shQuote(id)}';
  static String dockerRemove(String id)  => 'docker rm -f ${shQuote(id)}';
  static String dockerLogs(String id)    =>
      'docker logs --follow --tail=100 ${shQuote(id)}';
  static const String dockerImagePrune   = 'docker image prune -f';

  // ── Services (systemctl) ────────────────────────────────────────────────────
  static const String systemctlDetect = 'which systemctl 2>/dev/null';
  static const String systemctlListServices =
      'LANG=C systemctl list-units --type=service --all --no-pager --no-legend';
  static String serviceStart(String name)   =>
      'sudo systemctl start ${shQuote(name)}';
  static String serviceStop(String name)    =>
      'sudo systemctl stop ${shQuote(name)}';
  static String serviceRestart(String name) =>
      'sudo systemctl restart ${shQuote(name)}';
  static String serviceReload(String name)  =>
      'sudo systemctl reload ${shQuote(name)}';
  static String serviceEnable(String name)  =>
      'sudo systemctl enable ${shQuote(name)}';
  static String serviceDisable(String name) =>
      'sudo systemctl disable ${shQuote(name)}';

  // ── Firewall (UFW) ──────────────────────────────────────────────────────────
  static const String ufwDetect = 'which ufw 2>/dev/null';
  static const String portScan  =
      'LANG=C ss -tulpn 2>/dev/null || LANG=C netstat -tulpn 2>/dev/null';
  static const String ufwStatus  = 'sudo LANG=C ufw status numbered';
  static const String ufwEnable  = 'sudo ufw --force enable';
  static const String ufwDisable = 'sudo ufw disable';
  static const String ufwReload  = 'sudo ufw reload';
  static String ufwAllow(int port, String proto) => 'sudo ufw allow $port/$proto';
  static String ufwDeny(int port, String proto)  => 'sudo ufw deny $port/$proto';
  static String ufwDeleteRule(int n)             => 'sudo ufw --force delete $n';
}
