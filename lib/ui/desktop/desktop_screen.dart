import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/models/window_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vps_list_provider.dart';
import '../../providers/window_manager_provider.dart';
import '../lock/lock_screen.dart';
import '../taskbar/taskbar.dart';
import '../windows/window_frame.dart';
import 'app_launcher_icon.dart';
import 'vps_stats_widget.dart';

class DesktopScreen extends ConsumerWidget {
  const DesktopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(windowManagerProvider);
    final vpsList = ref.watch(vpsListProvider);
    final locked  = ref.watch(authProvider);

    final sorted = [...windows]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Scaffold(
      backgroundColor: AetherColors.background,
      body: Stack(
        children: [
          // Layer 0 — Background gradient
          const _DesktopBackground(),

          // Layer 1 — App launcher icons (bottom-left column)
          Positioned(
            left: 16,
            bottom: AetherDimensions.taskbarHeight + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                AppLauncherIcon(
                  icon: Icons.terminal,
                  label: 'Terminal',
                  windowType: WindowType.terminal,
                ),
                SizedBox(height: AetherDimensions.iconSpacing),
                AppLauncherIcon(
                  icon: Icons.folder,
                  label: 'Files',
                  windowType: WindowType.fileManager,
                ),
                SizedBox(height: AetherDimensions.iconSpacing),
                AppLauncherIcon(
                  icon: Icons.smart_toy,
                  label: 'Docker',
                  windowType: WindowType.docker,
                ),
              ],
            ),
          ),

          // Layer 2 — VPS live stats widgets (top-right area)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: vpsList
                  .map((vps) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: VpsStatsWidget(vps: vps),
                      ))
                  .toList(),
            ),
          ),

          // Layer 3 — Floating windows (z-index sorted)
          ...sorted
              .where((w) => !w.isMinimized)
              .map((w) => WindowFrame(windowState: w)),

          // Layer 4 — Taskbar (always on top)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Taskbar(),
          ),

          // Layer 5 — Lock screen overlay
          if (locked) const LockScreen(),
        ],
      ),
    );
  }
}

class _DesktopBackground extends StatelessWidget {
  const _DesktopBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.4,
          colors: [
            Color(0xFF1E2D45),
            AetherColors.background,
            Color(0xFF0D1520),
          ],
        ),
      ),
    );
  }
}
