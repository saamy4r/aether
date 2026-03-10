import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/models/window_state.dart';
import '../../providers/vps_connection_provider.dart';
import '../../providers/vps_list_provider.dart';
import '../../providers/window_manager_provider.dart';

const _uuid = Uuid();

class AppLauncherIcon extends ConsumerWidget {
  const AppLauncherIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.windowType,
  });

  final IconData icon;
  final String label;
  final WindowType windowType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _launch(context, ref),
      child: SizedBox(
        width: AetherDimensions.iconSize + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AetherDimensions.iconSize,
              height: AetherDimensions.iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AetherColors.surfaceDeep,
                border: Border.all(
                  color: AetherColors.glassBorder,
                  width: 1.5,
                ),
              ),
              child: Icon(icon,
                  color: AetherColors.textPrimary, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AetherColors.textPrimary,
                fontSize: AetherDimensions.iconLabelSize,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _launch(BuildContext context, WidgetRef ref) {
    // Find the first connected VPS
    final vpsList = ref.read(vpsListProvider);
    final connectedVps = vpsList.firstWhere(
      (v) =>
          ref.read(vpsConnectionProvider(v.id)).valueOrNull?.isConnected ==
          true,
      orElse: () => vpsList.isEmpty ? throw StateError('No VPS') : vpsList.first,
    );

    final screen = MediaQuery.sizeOf(context);
    final windowId = windowType == WindowType.terminal
        ? _uuid.v4()
        : '${connectedVps.id}_${windowType.name}';

    final title = switch (windowType) {
      WindowType.terminal    => 'Terminal — ${connectedVps.label}',
      WindowType.fileManager => 'Files — ${connectedVps.label}',
      WindowType.docker      => 'Docker — ${connectedVps.label}',
      WindowType.dashboard   => 'Dashboard — ${connectedVps.label}',
    };

    ref.read(windowManagerProvider.notifier).openWindow(
      WindowManagerNotifier.makeWindow(
        windowId: windowId,
        vpsId: connectedVps.id,
        type: windowType,
        title: title,
        screen: screen,
      ),
    );
  }
}
