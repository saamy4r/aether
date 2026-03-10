abstract final class SshCommands {
  static const String cpuMemLoad =
      'LANG=C top -bn1 | head -5; '
      'LANG=C free -b; '
      'LANG=C cat /proc/uptime; '
      'LANG=C cat /proc/loadavg';

  static const String diskUsage =
      'LANG=C df -B1 -x tmpfs -x devtmpfs -x overlay';

  static const String networkSample =
      'LANG=C cat /proc/net/dev; sleep 1; LANG=C cat /proc/net/dev';

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

  static String dockerStart(String id)   => 'docker start $id';
  static String dockerStop(String id)    => 'docker stop $id';
  static String dockerRestart(String id) => 'docker restart $id';
  static String dockerRemove(String id)  => 'docker rm -f $id';
  static String dockerLogs(String id)    => 'docker logs --follow --tail=100 $id';
}
