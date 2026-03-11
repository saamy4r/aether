import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/models/window_state.dart';
import '../../providers/window_manager_provider.dart';

class TaskbarWindowButton extends ConsumerWidget {
  const TaskbarWindowButton({super.key, required this.window});
  final WindowState window;

  IconData get _icon => switch (window.type) {
    WindowType.dashboard   => Icons.monitor_heart,
    WindowType.terminal    => Icons.terminal,
    WindowType.fileManager => Icons.folder,
    WindowType.docker      => Icons.smart_toy,
    WindowType.dockerLogs  => Icons.article,
    WindowType.dockerShell => Icons.terminal,
    WindowType.firewall    => Icons.security,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allWindows = ref.watch(windowManagerProvider);
    final isActive = allWindows
        .where((w) => !w.isMinimized)
        .fold<int>(0, (max, w) => w.zIndex > max ? w.zIndex : max) == window.zIndex;

    return GestureDetector(
      onTap: () {
        if (window.isMinimized) {
          ref.read(windowManagerProvider.notifier).restoreWindow(window.windowId);
        } else {
          ref.read(windowManagerProvider.notifier).focusWindow(window.windowId);
        }
      },
      child: Container(
        width: AetherDimensions.taskbarButtonWidth,
        height: AetherDimensions.taskbarHeight,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AetherColors.accent.withOpacity(0.2)
              : AetherColors.glassBase,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? AetherColors.accent.withOpacity(0.5)
                : AetherColors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 12,
                color: isActive ? AetherColors.accent : AetherColors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                window.title.length > 10
                    ? '${window.title.substring(0, 10)}…'
                    : window.title,
                style: TextStyle(
                  color: isActive
                      ? AetherColors.textPrimary
                      : AetherColors.textSecondary,
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
