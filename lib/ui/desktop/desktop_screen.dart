import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/models/window_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ui_settings_provider.dart';
import '../../providers/vps_connection_provider.dart';
import '../../providers/vps_list_provider.dart';
import '../../providers/window_manager_provider.dart';
import '../lock/lock_screen.dart';
import '../taskbar/taskbar.dart';
import '../windows/window_frame.dart';
import '../common/glass_container.dart';
import 'app_launcher_icon.dart';
import 'desktop_wallpaper.dart';
import 'vps_stats_widget.dart';

class DesktopScreen extends ConsumerWidget {
  const DesktopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger auto-reconnect on startup
    ref.watch(autoConnectProvider);

    final windows = ref.watch(windowManagerProvider);
    final vpsList = ref.watch(vpsListProvider);
    final locked = ref.watch(authProvider);
    final fullscreen = ref.watch(fullscreenProvider);

    final anyConnected = vpsList.any((v) =>
        ref.watch(vpsConnectionProvider(v.id)).valueOrNull?.isConnected == true);

    final sorted = [...windows]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Scaffold(
      backgroundColor: AetherColors.background,
      body: SafeArea(
        top: !fullscreen,
        bottom: false,
        child: Stack(
        children: [
          // Layer 0 — Wallpaper
          const DesktopWallpaper(),

          // Layer 1 — App launcher icons or login prompt
          if (anyConnected)
            Positioned(
              left: 16,
              top: 16,
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
                ],
              ),
            )
          else
            const _LoginPrompt(),

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
      ),
    );
  }
}


class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      bottom: AetherDimensions.taskbarHeight,
      child: Center(
        child: GlassContainer(
          borderRadius: 20,
          blurSigma: 24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 48,
                  color: AetherColors.accent.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Login to your VPS',
                  style: TextStyle(
                    color: AetherColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open the start menu to add or connect\nto a server.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AetherColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
