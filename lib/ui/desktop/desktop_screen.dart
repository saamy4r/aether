import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/models/vps_model.dart';
import '../../core/models/window_state.dart';
import '../../providers/active_desktop_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ui_settings_provider.dart';
import '../../providers/vps_connection_provider.dart';
import '../../providers/vps_list_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../providers/window_manager_provider.dart';
import '../lock/lock_screen.dart';
import '../settings/add_vps_screen.dart';
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

    final vpsList = ref.watch(vpsListProvider);
    final locked = ref.watch(authProvider);
    final fullscreen = ref.watch(fullscreenProvider);
    final activeVpsId = ref.watch(activeDesktopProvider);

    return Scaffold(
      backgroundColor: AetherColors.background,
      body: SafeArea(
        top: !fullscreen,
        bottom: false,
        child: Stack(
          children: [
            // State 1 — No VPS added yet
            if (vpsList.isEmpty) ...[
              const DesktopWallpaper(),
              _NoVpsPrompt(),
            ]
            // State 2 — VPS(es) added but none entered
            else if (activeVpsId == null) ...[
              const DesktopWallpaper(),
              _VpsLobby(),
            ]
            // State 3 — Active VPS desktop
            else ...[
              _ActiveDesktop(vpsId: activeVpsId),
            ],

            // Lock screen always on top when locked
            if (locked) const LockScreen(),
          ],
        ),
      ),
    );
  }
}

// ─── State 1: No VPS prompt ────────────────────────────────────────────────

class _NoVpsPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddVpsScreen()),
          ),
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
                    'Tap here to add your first server',
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
      ),
    );
  }
}

// ─── State 2: VPS Lobby ────────────────────────────────────────────────────

class _VpsLobby extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpsList = ref.watch(vpsListProvider);

    return Positioned.fill(
      // One shared blur pass for all (non-overlapping) lobby cards.
      child: BackdropGroup(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Your Servers',
                style: TextStyle(
                  color: AetherColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Cards wrap into multiple rows/columns based on available width
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: vpsList
                    .map((vps) => _LobbyVpsCard(vps: vps))
                    .toList(),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddVpsScreen()),
                ),
                child: GlassContainer(
                  borderRadius: 12,
                  blurSigma: 20,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: AetherColors.accent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Add Server',
                          style: TextStyle(
                            color: AetherColors.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LobbyVpsCard extends ConsumerWidget {
  const _LobbyVpsCard({required this.vps});
  final VpsModel vps;

  void _showCardMenu(BuildContext context, WidgetRef ref) {
    showMenu<_CardAction>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 0, 0, 0),
      color: const Color(0xFF1E2A3A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AetherColors.glassBorder),
      ),
      items: [
        PopupMenuItem(
          value: _CardAction.edit,
          child: Row(
            children: [
              const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AetherColors.accent,
              ),
              const SizedBox(width: 10),
              Text(
                'Edit',
                style: const TextStyle(
                  color: AetherColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: _CardAction.delete,
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                size: 16,
                color: AetherColors.accentRed,
              ),
              const SizedBox(width: 10),
              Text(
                'Delete',
                style: const TextStyle(
                  color: AetherColors.accentRed,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((action) async {
      if (!context.mounted) return;
      if (action == _CardAction.edit) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddVpsScreen(vpsToEdit: vps)),
        );
      } else if (action == _CardAction.delete) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E2A3A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AetherColors.glassBorder),
            ),
            title: const Text(
              'Delete server?',
              style: TextStyle(color: AetherColors.textPrimary, fontSize: 15),
            ),
            content: Text(
              'Remove "${vps.label}" from Aether? This cannot be undone.',
              style: const TextStyle(
                color: AetherColors.textSecondary,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AetherColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AetherColors.accentRed),
                ),
              ),
            ],
          ),
        );
        if (confirm == true) {
          ref.read(vpsConnectionProvider(vps.id).notifier).disconnect();
          ref.read(vpsListProvider.notifier).remove(vps.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(vpsConnectionProvider(vps.id));
    final isConnected = conn.valueOrNull?.isConnected == true;
    final isConnecting = conn.isLoading;
    final isError = conn.valueOrNull?.status == ConnectionStatus.error;
    final errorMsg = conn.valueOrNull?.errorMessage;

    if (isConnected) {
      return GestureDetector(
        onLongPress: () => _showCardMenu(context, ref),
        onSecondaryTap: () => _showCardMenu(context, ref),
        child: VpsStatsWidget(
          vps: vps,
          onTap: () => ref.read(activeDesktopProvider.notifier).state = vps.id,
        ),
      );
    }

    // Determine status badge
    final Color statusColor;
    final String statusLabel;
    if (isConnecting) {
      statusColor = AetherColors.accentYellow;
      statusLabel = 'Connecting…';
    } else if (isError) {
      statusColor = AetherColors.accentRed;
      statusLabel = 'Error';
    } else {
      statusColor = AetherColors.textSecondary;
      statusLabel = 'Not connected';
    }

    return GestureDetector(
      onTap: isConnecting
          ? null
          : () => ref.read(vpsConnectionProvider(vps.id).notifier).connect(),
      onLongPress: () => _showCardMenu(context, ref),
      onSecondaryTap: () => _showCardMenu(context, ref),
      child: GlassContainer(
        borderRadius: 16,
        blurSigma: 20,
        child: SizedBox(
          width: 200,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 7, color: statusColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        vps.label,
                        style: const TextStyle(
                          color: AetherColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  vps.host,
                  style: const TextStyle(
                    color: AetherColors.textSecondary,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isError
                        ? AetherColors.accentRed.withValues(alpha: 0.1)
                        : AetherColors.glassBase,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isError
                          ? AetherColors.accentRed.withValues(alpha: 0.4)
                          : AetherColors.glassBorder,
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 10),
                  ),
                ),
                // Show error detail so user knows what went wrong
                if (isError && errorMsg != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    errorMsg,
                    style: const TextStyle(
                      color: AetherColors.accentRed,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (!isConnecting) ...[
                  const SizedBox(height: 8),
                  Text(
                    isError ? 'Tap to retry' : 'Tap to connect',
                    style: const TextStyle(
                      color: AetherColors.accent,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _CardAction { edit, delete }

// Curated cool-toned hues so all procedural wallpapers look like space scenes
const _wallpaperHues = [
  200.0, // blue
  220.0, // blue-violet
  170.0, // teal-green
  260.0, // purple
  280.0, // violet
  190.0, // teal
  230.0, // azure
  245.0, // indigo
  210.0, // sky blue
  160.0, // green-teal
];

// ─── State 3: Active VPS Desktop ──────────────────────────────────────────

class _ActiveDesktop extends ConsumerWidget {
  const _ActiveDesktop({required this.vpsId});
  final String vpsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpsList = ref.watch(vpsListProvider);
    final vps = vpsList.where((v) => v.id == vpsId).firstOrNull;

    // VPS was deleted while this desktop was active — return to lobby
    if (vps == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(activeDesktopProvider.notifier).state = null;
      });
      return const SizedBox.shrink();
    }

    final windows = ref.watch(windowManagerProvider);
    final wallpapers = ref.watch(wallpaperProvider);

    final sorted = windows.where((w) => w.vpsId == vpsId).toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final seed = vpsId.hashCode.abs();
    final accentHue = _wallpaperHues[seed % _wallpaperHues.length];
    final imagePath = wallpapers[vpsId];

    return Stack(
      children: [
        // Layer 0 — Wallpaper + long-press (mobile) / right-click (desktop) menu
        GestureDetector(
          onLongPressStart: (d) => _showDesktopMenu(
            context,
            ref,
            d.globalPosition,
            imagePath != null,
          ),
          onSecondaryTapDown: (d) => _showDesktopMenu(
            context,
            ref,
            d.globalPosition,
            imagePath != null,
          ),
          child: DesktopWallpaper(
            seed: seed,
            accentHue: accentHue,
            imagePath: imagePath,
          ),
        ),

        // Layer 1 — App launcher icons (scoped to this VPS)
        Positioned(
          left: 16,
          top: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLauncherIcon(
                icon: Icons.terminal,
                label: 'Terminal',
                windowType: WindowType.terminal,
                vpsId: vpsId,
              ),
              const SizedBox(height: AetherDimensions.iconSpacing),
              AppLauncherIcon(
                icon: Icons.folder,
                label: 'Files',
                windowType: WindowType.fileManager,
                vpsId: vpsId,
              ),
            ],
          ),
        ),

        // Layer 2 — Live stats widget for this VPS (top-right)
        Positioned(top: 16, right: 16, child: VpsStatsWidget(vps: vps)),

        // Layer 3 — Floating windows (this VPS only, z-sorted)
        ...sorted
            .where((w) => !w.isMinimized)
            .map((w) => WindowFrame(key: ValueKey(w.windowId), windowState: w)),

        // Layer 4 — Taskbar (with scoped window buttons)
        const Positioned(bottom: 0, left: 0, right: 0, child: Taskbar()),
      ],
    );
  }

  void _showDesktopMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
    bool hasCustomWallpaper,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (_) => _DesktopContextMenu(
        vpsId: vpsId,
        position: position,
        screenSize: MediaQuery.sizeOf(context),
        hasCustomWallpaper: hasCustomWallpaper,
      ),
    );
  }
}

// ─── Desktop right-click / long-press context menu ───────────────────────

class _DesktopContextMenu extends ConsumerWidget {
  const _DesktopContextMenu({
    required this.vpsId,
    required this.position,
    required this.screenSize,
    required this.hasCustomWallpaper,
  });

  final String vpsId;
  final Offset position;
  final Size screenSize;
  final bool hasCustomWallpaper;

  static const _menuWidth = 220.0;
  static const _itemHeight = 40.0;
  static const _vertPad = 6.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = 2 + (hasCustomWallpaper ? 1 : 0);
    final menuHeight = itemCount * _itemHeight + _vertPad * 2;

    // Clamp so menu never goes off-screen
    final left = (position.dx).clamp(8.0, screenSize.width - _menuWidth - 8);
    final top = (position.dy).clamp(8.0, screenSize.height - menuHeight - 8);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: _menuWidth,
          child: Material(
            color: Colors.transparent,
            child: GlassContainer(
              borderRadius: 12,
              blurSigma: 28,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: _vertPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ContextItem(
                      icon: Icons.note_add_outlined,
                      label: 'New File',
                      onTap: () {
                        Navigator.pop(context);
                        final vpsList = ref.read(vpsListProvider);
                        final vps = vpsList.firstWhere((v) => v.id == vpsId);
                        ref
                            .read(windowManagerProvider.notifier)
                            .openWindow(
                              WindowManagerNotifier.makeWindow(
                                windowId:
                                    '${vpsId}_${WindowType.fileManager.name}',
                                vpsId: vpsId,
                                type: WindowType.fileManager,
                                title: 'Files — ${vps.label}',
                                screen: screenSize,
                              ),
                            );
                      },
                    ),
                    const Divider(color: AetherColors.glassBorder, height: 1),
                    _ContextItem(
                      icon: Icons.image_outlined,
                      label: 'Set Background',
                      onTap: () async {
                        // Capture notifier before pop — ref invalid after dispose
                        final notifier = ref.read(wallpaperProvider.notifier);
                        Navigator.pop(context);
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                        );
                        final path = result?.files.single.path;
                        if (path != null) notifier.setWallpaper(vpsId, path);
                      },
                    ),
                    if (hasCustomWallpaper) ...[
                      const Divider(color: AetherColors.glassBorder, height: 1),
                      _ContextItem(
                        icon: Icons.refresh,
                        label: 'Reset Background',
                        color: AetherColors.textSecondary,
                        onTap: () {
                          ref
                              .read(wallpaperProvider.notifier)
                              .removeWallpaper(vpsId);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextItem extends StatelessWidget {
  const _ContextItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AetherColors.textPrimary,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AetherColors.accent, size: 16),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
