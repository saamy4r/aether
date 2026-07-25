import 'package:flutter/foundation.dart';

enum ContainerStatus { running, paused, exited, unknown }

@immutable
class DockerContainer {
  const DockerContainer({
    required this.id,
    required this.name,
    required this.image,
    required this.status,
    required this.statusRaw,
    required this.ports,
  });

  final String id;
  final String name;
  final String image;
  final ContainerStatus status;
  final String statusRaw;
  final String ports;

  factory DockerContainer.fromTsv(String line) {
    final parts = line.split('\t');
    final statusRaw = parts.length > 3 ? parts[3] : '';
    ContainerStatus status;
    // Paused shows as "Up 2 hours (Paused)" — check before the Up prefix
    if (statusRaw.contains('(Paused)')) {
      status = ContainerStatus.paused;
    } else if (statusRaw.startsWith('Up')) {
      status = ContainerStatus.running;
    } else if (statusRaw.startsWith('Exited')) {
      status = ContainerStatus.exited;
    } else {
      status = ContainerStatus.unknown;
    }
    return DockerContainer(
      id: parts.isNotEmpty ? parts[0] : '',
      name: parts.length > 1 ? parts[1] : '',
      image: parts.length > 2 ? parts[2] : '',
      status: status,
      statusRaw: statusRaw,
      ports: parts.length > 4 ? parts[4] : '',
    );
  }
}

@immutable
class DockerImage {
  const DockerImage({
    required this.repository,
    required this.tag,
    required this.id,
    required this.size,
  });

  final String repository;
  final String tag;
  final String id;
  final String size;

  factory DockerImage.fromTsv(String line) {
    final parts = line.split('\t');
    return DockerImage(
      repository: parts.isNotEmpty ? parts[0] : '',
      tag: parts.length > 1 ? parts[1] : '',
      id: parts.length > 2 ? parts[2] : '',
      size: parts.length > 3 ? parts[3] : '',
    );
  }
}
