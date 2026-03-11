import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/strings.dart';
import '../../../core/models/docker_container.dart';
import '../../../core/constants/ssh_commands.dart';
import '../../../core/models/window_state.dart';
import '../../../providers/docker_provider.dart';
import '../../../providers/window_manager_provider.dart';

const _uuid = Uuid();

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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.smart_toy_outlined,
                  size: 48, color: AetherColors.textSecondary),
              const SizedBox(height: 12),
              const Text(
                AetherStrings.dockerNotFound,
                style: TextStyle(
                    color: AetherColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AetherColors.glassBase,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AetherColors.glassBorder),
                ),
                child: const Text(
                  'curl -fsSL https://get.docker.com | sh',
                  style: TextStyle(
                    color: AetherColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
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
          if (state.errorMessage != null)
            Container(
              color: AetherColors.accentRed.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      size: 12, color: AetherColors.accentRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                          color: AetherColors.accentRed, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
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
                _ImagesTab(vpsId: vpsId, state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Containers Tab ────────────────────────────────────────────────────────────

class _ContainersTab extends StatelessWidget {
  const _ContainersTab({required this.vpsId, required this.state});
  final String vpsId;
  final DockerState state;

  @override
  Widget build(BuildContext context) {
    if (state.containers.isEmpty) {
      return const Center(
        child: Text('No containers',
            style: TextStyle(color: AetherColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: state.containers.length,
      separatorBuilder: (_, __) =>
          const Divider(color: AetherColors.glassBorder, height: 1),
      itemBuilder: (ctx, i) =>
          _ContainerCard(container: state.containers[i], vpsId: vpsId),
    );
  }
}

class _ContainerCard extends ConsumerWidget {
  const _ContainerCard({required this.container, required this.vpsId});
  final DockerContainer container;
  final String vpsId;

  Color get _statusColor => switch (container.status) {
        ContainerStatus.running => AetherColors.accentGreen,
        ContainerStatus.paused => AetherColors.accentYellow,
        ContainerStatus.exited => AetherColors.accentRed,
        ContainerStatus.unknown => AetherColors.textSecondary,
      };

  bool get _isRunning => container.status == ContainerStatus.running;
  bool get _isPaused => container.status == ContainerStatus.paused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dockerProvider(vpsId).notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status dot
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  container.name,
                  style: const TextStyle(
                      color: AetherColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  container.image,
                  style: const TextStyle(
                      color: AetherColors.textSecondary, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
                if (container.ports.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    container.ports,
                    style: const TextStyle(
                        color: AetherColors.accent, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  container.statusRaw,
                  style: const TextStyle(
                      color: AetherColors.textSecondary, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Start / Stop
              if (_isRunning)
                _ActionIcon(
                  icon: Icons.stop_rounded,
                  color: AetherColors.accentRed,
                  tooltip: 'Stop',
                  onTap: () => notifier.containerAction(
                      container.id, SshCommands.dockerStop(container.id)),
                )
              else
                _ActionIcon(
                  icon: Icons.play_arrow_rounded,
                  color: AetherColors.accentGreen,
                  tooltip: 'Start',
                  onTap: () => notifier.containerAction(
                      container.id, SshCommands.dockerStart(container.id)),
                ),
              // Restart
              _ActionIcon(
                icon: Icons.refresh_rounded,
                color: AetherColors.accent,
                tooltip: 'Restart',
                onTap: () => notifier.containerAction(
                    container.id, SshCommands.dockerRestart(container.id)),
              ),
              // Pause / Unpause
              if (_isRunning)
                _ActionIcon(
                  icon: Icons.pause_rounded,
                  color: AetherColors.accentYellow,
                  tooltip: 'Pause',
                  onTap: () => notifier.pauseContainer(container.id),
                )
              else if (_isPaused)
                _ActionIcon(
                  icon: Icons.play_circle_outline_rounded,
                  color: AetherColors.accentYellow,
                  tooltip: 'Unpause',
                  onTap: () => notifier.unpauseContainer(container.id),
                ),
              // Logs
              _ActionIcon(
                icon: Icons.article_outlined,
                color: AetherColors.textSecondary,
                tooltip: 'Logs',
                onTap: () => _openLogs(context, ref),
              ),
              // Shell
              _ActionIcon(
                icon: Icons.terminal,
                color: AetherColors.textSecondary,
                tooltip: 'Shell',
                onTap: () => _openShell(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openLogs(BuildContext context, WidgetRef ref) {
    final windowId = _uuid.v4();
    final screen = MediaQuery.sizeOf(context);
    ref.read(windowManagerProvider.notifier).openWindow(
          WindowManagerNotifier.makeWindow(
            windowId: windowId,
            vpsId: vpsId,
            type: WindowType.dockerLogs,
            title: 'Logs — ${container.name}',
            screen: screen,
            containerId: container.id,
          ),
        );
  }

  void _openShell(BuildContext context, WidgetRef ref) {
    final windowId = _uuid.v4();
    final screen = MediaQuery.sizeOf(context);
    ref.read(windowManagerProvider.notifier).openWindow(
          WindowManagerNotifier.makeWindow(
            windowId: windowId,
            vpsId: vpsId,
            type: WindowType.dockerShell,
            title: 'Shell — ${container.name}',
            screen: screen,
            containerId: container.id,
          ),
        );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip = '',
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ── Images Tab ────────────────────────────────────────────────────────────────

class _ImagesTab extends ConsumerWidget {
  const _ImagesTab({required this.vpsId, required this.state});
  final String vpsId;
  final DockerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Prune button
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AetherColors.accentRed,
                side: const BorderSide(color: AetherColors.accentRed),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              icon: const Icon(Icons.delete_sweep_outlined, size: 14),
              label: const Text('Prune Unused Images'),
              onPressed: () => _confirmPrune(context, ref),
            ),
          ),
        ),
        const Divider(color: AetherColors.glassBorder, height: 1),
        if (state.images.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No images',
                  style: TextStyle(color: AetherColors.textSecondary)),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: state.images.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AetherColors.glassBorder, height: 1),
              itemBuilder: (_, i) {
                final img = state.images[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.layers_outlined,
                          size: 14, color: AetherColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${img.repository}:${img.tag}',
                              style: const TextStyle(
                                  color: AetherColors.textPrimary,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              img.id,
                              style: const TextStyle(
                                  color: AetherColors.textSecondary,
                                  fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        img.size,
                        style: const TextStyle(
                            color: AetherColors.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _confirmPrune(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AetherColors.surfaceDeep,
        title: const Text('Prune Images',
            style: TextStyle(color: AetherColors.textPrimary)),
        content: const Text(
          'Remove all unused Docker images? This cannot be undone.',
          style: TextStyle(color: AetherColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AetherColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Prune',
                style: TextStyle(color: AetherColors.accentRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(dockerProvider(vpsId).notifier).pruneImages();
    }
  }
}
