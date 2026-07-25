import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/models/docker_container.dart';
import 'package:aether/core/parsers/docker_parser.dart';

void main() {
  group('DockerParser.parseContainers', () {
    test('parses TSV rows including names with spaces', () {
      const out =
          'abc123\tmy web app\tnginx:latest\tUp 2 hours\t0.0.0.0:80->80/tcp\n'
          'def456\tdb\tpostgres:16\tExited (0) 3 days ago\t\n';
      final containers = DockerParser.parseContainers(out);
      expect(containers.length, 2);
      expect(containers[0].name, 'my web app');
      expect(containers[0].status, ContainerStatus.running);
      expect(containers[0].ports, '0.0.0.0:80->80/tcp');
      expect(containers[1].status, ContainerStatus.exited);
    });

    test('paused container ("Up ... (Paused)") is detected as paused', () {
      const out = 'abc\tapp\timg\tUp 2 hours (Paused)\t\n';
      final c = DockerParser.parseContainers(out).single;
      expect(c.status, ContainerStatus.paused);
    });

    test('empty output and non-TSV noise are skipped', () {
      expect(DockerParser.parseContainers(''), isEmpty);
      expect(DockerParser.parseContainers('some warning line\n'), isEmpty);
    });
  });

  group('DockerParser.parseImages', () {
    test('parses image rows', () {
      const out = 'nginx\tlatest\tsha1234\t187MB\n'
          'postgres\t16\tsha5678\t432MB\n';
      final images = DockerParser.parseImages(out);
      expect(images.length, 2);
      expect(images[0].repository, 'nginx');
      expect(images[1].size, '432MB');
    });
  });

  group('DockerParser.isDockerAvailable', () {
    test('detects docker from version output', () {
      expect(
        DockerParser.isDockerAvailable(
            '/usr/bin/docker\nDocker version 27.0.3, build abc\n'),
        isTrue,
      );
      expect(DockerParser.isDockerAvailable(''), isFalse);
      expect(DockerParser.isDockerAvailable('command not found'), isFalse);
    });
  });
}
