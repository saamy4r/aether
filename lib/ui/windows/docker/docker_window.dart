import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/docker_container.dart';
import '../../../core/constants/ssh_commands.dart';
import '../../../providers/docker_provider.dart';

class DockerWindowContent extends ConsumerWidget {
  const DockerWindowContent({super.key, required this.vpsId});
  final String vpsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dockerProvider(vpsId));

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AetherColors.accent),
      );
    }

    if (!state.isAvailable) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined,
                  size: 32, color: AetherColors.textSecondary),
              SizedBox(height: 8),
              Text(
                AetherStrings.dockerNotFound,
                style: TextStyle(color: AetherColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Containers'), Tab(text: 'Images')],
            labelColor: AetherColors.accent,
            unselectedLabelColor: AetherColors.textSecondary,
            indicatorColor: AetherColors.accent,
            labelStyle: TextStyle(fontSize: 12),
            tabAlignment: TabAlignment.start,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ContainersTab(vpsId: vpsId, state: state),
                _ImagesTab(images: state.images),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContainersTab extends ConsumerWidget {
  const _ContainersTab({required this.vpsId, required this.state});
  final String vpsId;
  final DockerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.containers.isEmpty) {
      return const Center(
        child: Text('No containers',
            style: TextStyle(color: AetherColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: state.containers.length,
      itemBuilder: (_, i) => _ContainerTile(
        container: state.containers[i],
        vpsId: vpsId,
      ),
    );
  }
}

class _ContainerTile extends ConsumerWidget {
  const _ContainerTile({required this.container, required this.vpsId});
  final DockerContainer container;
  final String vpsId;

  Color get _statusColor => switch (container.status) {
    ContainerStatus.running => AetherColors.accentGreen,
    ContainerStatus.paused  => AetherColors.accentYellow,
    ContainerStatus.exited  => AetherColors.accentRed,
    ContainerStatus.unknown => AetherColors.textSecondary,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dockerProvider(vpsId).notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(container.name,
                    style: const TextStyle(
                        color: AetherColors.textPrimary, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                Text(container.image,
                    style: const TextStyle(
                        color: AetherColors.textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Action buttons
          if (container.status == ContainerStatus.running)
            _ActionIcon(
              icon: Icons.stop,
              color: AetherColors.accentRed,
              onTap: () => notifier.containerAction(
                container.id, SshCommands.dockerStop(container.id)),
            )
          else
            _ActionIcon(
              icon: Icons.play_arrow,
              color: AetherColors.accentGreen,
              onTap: () => notifier.containerAction(
                container.id, SshCommands.dockerStart(container.id)),
            ),
          _ActionIcon(
            icon: Icons.refresh,
            color: AetherColors.accent,
            onTap: () => notifier.containerAction(
              container.id, SshCommands.dockerRestart(container.id)),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _ImagesTab extends StatelessWidget {
  const _ImagesTab({required this.images});
  final List<DockerImage> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const Center(
        child: Text('No images',
            style: TextStyle(color: AetherColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: images.length,
      itemBuilder: (_, i) {
        final img = images[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.layers, size: 14, color: AetherColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${img.repository}:${img.tag}',
                    style: const TextStyle(
                        color: AetherColors.textPrimary, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(img.size,
                  style: const TextStyle(
                      color: AetherColors.textSecondary, fontSize: 10)),
            ],
          ),
        );
      },
    );
  }
}
