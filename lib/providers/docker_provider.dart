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

  static const Object _keep = Object();

  DockerState copyWith({
    List<DockerContainer>? containers,
    List<DockerImage>? images,
    bool? isAvailable,
    bool? isLoading,
    Object? errorMessage = _keep,
  }) => DockerState(
    containers: containers ?? this.containers,
    images: images ?? this.images,
    isAvailable: isAvailable ?? this.isAvailable,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: identical(errorMessage, _keep)
        ? this.errorMessage
        : errorMessage as String?,
  );
}

class DockerNotifier extends FamilyNotifier<DockerState, String> {
  Timer? _timer;
  bool _refreshing = false;

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
      final detectOut =
          await notifier.exec(SshCommands.dockerDetect, checkExitCode: false);
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
    final conn = ref.read(vpsConnectionProvider(vpsId));
    if (_refreshing || conn.valueOrNull?.isConnected != true) return;
    _refreshing = true;
    final notifier = ref.read(vpsConnectionProvider(vpsId).notifier);
    try {
      final out = await notifier.exec(SshCommands.dockerOverview);
      final sections = out.split(SshCommands.sectionSplit);
      state = state.copyWith(
        containers: DockerParser.parseContainers(sections.first),
        images: DockerParser.parseImages(
            sections.length > 1 ? sections[1] : ''),
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Refresh failed: $e',
      );
    } finally {
      _refreshing = false;
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
