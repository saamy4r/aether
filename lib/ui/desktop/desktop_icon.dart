import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/models/vps_model.dart';
import '../../core/models/window_state.dart';
import '../../providers/vps_connection_provider.dart';
import '../../providers/window_manager_provider.dart';
import '../settings/add_vps_screen.dart';

class DesktopIcon extends ConsumerStatefulWidget {
  const DesktopIcon({super.key, required this.vps});
  final VpsModel vps;

  @override
  ConsumerState<DesktopIcon> createState() => _DesktopIconState();
}

class _DesktopIconState extends ConsumerState<DesktopIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connAsync = ref.watch(vpsConnectionProvider(widget.vps.id));
    final status = connAsync.valueOrNull?.status ?? ConnectionStatus.disconnected;

    Color glowColor;
    bool isPulsing = false;
    switch (status) {
      case ConnectionStatus.connected:
        glowColor = AetherColors.accentTeal;
      case ConnectionStatus.connecting:
        glowColor = AetherColors.accent;
        isPulsing = true;
      case ConnectionStatus.error:
        glowColor = AetherColors.accentRed;
      case ConnectionStatus.disconnected:
        glowColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: () {
        if (status == ConnectionStatus.connected) {
          _openDashboard(context);
        } else if (status == ConnectionStatus.disconnected ||
            status == ConnectionStatus.error) {
          ref.read(vpsConnectionProvider(widget.vps.id).notifier).connect();
        }
      },
      onLongPress: () => _showContextMenu(context),
      child: SizedBox(
        width: AetherDimensions.iconSize + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) {
                final opacity = isPulsing
                    ? 0.3 + _pulseCtrl.value * 0.5
                    : (glowColor == Colors.transparent ? 0.0 : 0.6);
                return Container(
                  width: AetherDimensions.iconSize,
                  height: AetherDimensions.iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AetherColors.surfaceDeep,
                    boxShadow: glowColor != Colors.transparent
                        ? [
                            BoxShadow(
                              color: glowColor.withOpacity(opacity),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: glowColor != Colors.transparent
                          ? glowColor.withOpacity(0.6)
                          : AetherColors.glassBorder,
                      width: 1.5,
                    ),
                  ),
                  child: child,
                );
              },
              child: const Icon(
                Icons.dns,
                color: AetherColors.textPrimary,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.vps.label,
              style: const TextStyle(
                color: AetherColors.textPrimary,
                fontSize: AetherDimensions.iconLabelSize,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _openDashboard(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final windowId = '${widget.vps.id}_dashboard';
    ref.read(windowManagerProvider.notifier).openWindow(
      WindowManagerNotifier.makeWindow(
        windowId: windowId,
        vpsId: widget.vps.id,
        type: WindowType.dashboard,
        title: 'Dashboard — ${widget.vps.label}',
        screen: screen,
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final status =
        ref.read(vpsConnectionProvider(widget.vps.id)).valueOrNull?.status;
    showModalBottomSheet(
      context: context,
      backgroundColor: AetherColors.surfaceDeep,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AetherColors.accent),
              title: const Text('Edit',
                  style: TextStyle(color: AetherColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddVpsScreen(vpsToEdit: widget.vps),
                  ),
                );
              },
            ),
            if (status == ConnectionStatus.connected)
              ListTile(
                leading:
                    const Icon(Icons.link_off, color: AetherColors.accentYellow),
                title: const Text('Disconnect',
                    style: TextStyle(color: AetherColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(vpsConnectionProvider(widget.vps.id).notifier)
                      .disconnect();
                },
              ),
          ],
        ),
      ),
    );
  }
}
