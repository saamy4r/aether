import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/docker_container.dart';
import '../core/constants/ssh_commands.dart';
import '../core/parsers/docker_parser.dart';
import 'vps_connection_provider.dart';

class DockerState {
  const DockerState({
    this.containers = const [],
    this.images = const [],
    this.isAvailable = false,
    this.isLoading = true,
    this.errorMessage,
  });
  final List<DockerContainer> containers;
  final List<DockerImage> images;
  final bool isAvailable;
  final bool isLoading;
  final String? errorMessage;

  DockerState copyWith({
    List<DockerContainer>? containers,
    List<DockerImage>? images,
    bool? isAvailable,
    bool? isLoading,
    String? errorMessage,
  }) => DockerState(
    containers: containers ?? this.containers,
    images: images ?? this.images,
    isAvailable: isAvailable ?? this.isAvailable,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage,
  );
}

class DockerNotifier extends FamilyNotifier<DockerState, String> {
  Timer? _timer;

  String get vpsId => arg;

  @override
  DockerState build(String arg) {
    ref.onDispose(() => _timer?.cancel());
    _detectAndLoad();
    return const DockerState();
  }

  Future<void> _detectAndLoad() async {
    final notifier = ref.read(vpsConnectionProvider(vpsId).notifier);
    try {
      final detectOut = await notifier.exec(SshCommands.dockerDetect);
      if (!DockerParser.isDockerAvailable(detectOut)) {
        state = state.copyWith(isAvailable: false, isLoading: false);
        return;
      }
      state = state.copyWith(isAvailable: true);
      await _refresh();
      _timer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _refresh(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to detect Docker: $e',
      );
    }
  }

  Future<void> _refresh() async {
    final notifier = ref.read(vpsConnectionProvider(vpsId).notifier);
    try {
      final [containersOut, imagesOut] = await Future.wait([
        notifier.exec(SshCommands.dockerContainers),
        notifier.exec(SshCommands.dockerImages),
      ]);
      state = state.copyWith(
        containers: DockerParser.parseContainers(containersOut),
        images: DockerParser.parseImages(imagesOut),
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Refresh failed: $e',
      );
    }
  }

  Future<void> containerAction(String containerId, String command) async {
    final notifier = ref.read(vpsConnectionProvider(vpsId).notifier);
    try {
      await notifier.exec(command);
      await _refresh();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Action failed: $e');
    }
  }

  Future<void> pauseContainer(String id) =>
      containerAction(id, SshCommands.dockerPause(id));

  Future<void> unpauseContainer(String id) =>
      containerAction(id, SshCommands.dockerUnpause(id));

  Future<void> pruneImages() async {
    final notifier = ref.read(vpsConnectionProvider(vpsId).notifier);
    try {
      await notifier.exec(SshCommands.dockerImagePrune);
      await _refresh();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Prune failed: $e');
    }
  }

  void refresh() => _refresh();
}

final dockerProvider =
    NotifierProvider.family<DockerNotifier, DockerState, String>(
  DockerNotifier.new,
);
