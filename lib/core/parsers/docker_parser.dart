import '../models/docker_container.dart';

class DockerParser {
  static List<DockerContainer> parseContainers(String output) {
    return output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.contains('\t'))
        .map(DockerContainer.fromTsv)
        .toList();
  }

  static List<DockerImage> parseImages(String output) {
    return output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.contains('\t'))
        .map(DockerImage.fromTsv)
        .toList();
  }

  static bool isDockerAvailable(String output) =>
      output.trim().isNotEmpty && output.contains('Docker version');
}
