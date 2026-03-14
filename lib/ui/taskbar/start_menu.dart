import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/strings.dart';
import '../../core/models/window_state.dart';
import '../../providers/active_desktop_provider.dart';
import '../../providers/ui_settings_provider.dart';
import '../../providers/vps_connection_provider.dart';
import '../../providers/vps_list_provider.dart';
import '../../providers/window_manager_provider.dart';
import '../common/glass_container.dart';
import '../settings/add_vps_screen.dart';

const _uuid = Uuid();

class StartMenu extends ConsumerStatefulWidget {
  const StartMenu({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  ConsumerState<StartMenu> createState() => _StartMenuState();
}

class _StartMenuState extends ConsumerState<StartMenu> {
  String? _expandedMenuLabel; // menu item label whose inline actions are showing

  @override
  Widget build(BuildContext context) {
    final vpsList = ref.watch(vpsListProvider);

    return Align(
      alignment: Alignment.bottomLeft,
      child: SizedBox(
          width: AetherDimensions.startMenuWidth,
          child: GlassContainer(
            blurSigma: AetherGlass.startMenuBlur,
            borderRadius: AetherGlass.startMenuRadius,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Header
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        Icon(Icons.blur_on, color: AetherColors.accent, size: 18),
                        SizedBox(width: 8),
                        Text('Aether',
                            style: TextStyle(
                                color: AetherColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Divider(color: AetherColors.glassBorder, height: 1),

                  // Tools section
                  if (vpsList.isNotEmpty) ...[
                    const _SectionLabel('Tools'),
                    _MenuItem(
                      icon: Icons.terminal,
                      label: AetherStrings.terminal,
                      expanded: _expandedMenuLabel == AetherStrings.terminal,
                      onTap: () => _open(context, WindowType.terminal),
                      onLongPress: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.terminal ? null : AetherStrings.terminal),
                      onSecondaryTap: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.terminal ? null : AetherStrings.terminal),
                    ),
                    _MenuItem(
                      icon: Icons.folder,
                      label: AetherStrings.fileManager,
                      expanded: _expandedMenuLabel == AetherStrings.fileManager,
                      onTap: () => _open(context, WindowType.fileManager),
                      onLongPress: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.fileManager ? null : AetherStrings.fileManager),
                      onSecondaryTap: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.fileManager ? null : AetherStrings.fileManager),
                    ),
                    _MenuItem(
                      icon: Icons.smart_toy,
                      label: AetherStrings.dockerManager,
                      expanded: _expandedMenuLabel == AetherStrings.dockerManager,
                      onTap: () => _open(context, WindowType.docker),
                      onLongPress: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.dockerManager ? null : AetherStrings.dockerManager),
                      onSecondaryTap: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.dockerManager ? null : AetherStrings.dockerManager),
                    ),
                    _MenuItem(
                      icon: Icons.security,
                      label: AetherStrings.firewallManager,
                      expanded: _expandedMenuLabel == AetherStrings.firewallManager,
                      onTap: () => _open(context, WindowType.firewall),
                      onLongPress: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.firewallManager ? null : AetherStrings.firewallManager),
                      onSecondaryTap: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.firewallManager ? null : AetherStrings.firewallManager),
                    ),
                    _MenuItem(
                      icon: Icons.settings_applications,
                      label: AetherStrings.serviceManager,
                      expanded: _expandedMenuLabel == AetherStrings.serviceManager,
                      onTap: () => _open(context, WindowType.serviceManager),
                      onLongPress: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.serviceManager ? null : AetherStrings.serviceManager),
                      onSecondaryTap: () => setState(() => _expandedMenuLabel =
                          _expandedMenuLabel == AetherStrings.serviceManager ? null : AetherStrings.serviceManager),
                    ),
                    const Divider(color: AetherColors.glassBorder, height: 1),
                  ],

                  // System section
                  const _SectionLabel('System'),
                  _MenuItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Servers',
                    expanded: _expandedMenuLabel == 'Servers',
                    onTap: () {
                      widget.onClose();
                      ref.read(activeDesktopProvider.notifier).state = null;
                    },
                    onLongPress: () => setState(() => _expandedMenuLabel =
                        _expandedMenuLabel == 'Servers' ? null : 'Servers'),
                    onSecondaryTap: () => setState(() => _expandedMenuLabel =
                        _expandedMenuLabel == 'Servers' ? null : 'Servers'),
                  ),
                  _MenuItem(
                    icon: ref.watch(fullscreenProvider)
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    label: ref.watch(fullscreenProvider)
                        ? 'Exit Fullscreen'
                        : 'Fullscreen',
                    expanded: _expandedMenuLabel == 'Fullscreen',
                    onTap: () {
                      ref.read(fullscreenProvider.notifier).toggle();
                      widget.onClose();
                    },
                    onLongPress: () => setState(() => _expandedMenuLabel =
                        _expandedMenuLabel == 'Fullscreen' ? null : 'Fullscreen'),
                    onSecondaryTap: () => setState(() => _expandedMenuLabel =
                        _expandedMenuLabel == 'Fullscreen' ? null : 'Fullscreen'),
                  ),
                  _MenuItem(
                    icon: Icons.add,
                    label: AetherStrings.addVps,
                    expanded: _expandedMenuLabel == AetherStrings.addVps,
                    onTap: () {
                      widget.onClose();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddVpsScreen()),
                      );
                    },
                    onLongPress: () => setState(() => _expandedMenuLabel =
                        _expandedMenuLabel == AetherStrings.addVps ? null : AetherStrings.addVps),
                    onSecondaryTap: () => setState(() => _expandedMenuLabel =
                        _expandedMenuLabel == AetherStrings.addVps ? null : AetherStrings.addVps),
                  ),
                  _MenuItem(
                    icon: Icons.link_off,
                    label: AetherStrings.disconnectAll,
                    expanded: _expandedMenuLabel == AetherStrings.disconnectAll,
                    onTap: () {
                      final vps = ref.read(vpsListProvider);
                      for (final v in vps) {
                        ref
                            .read(vpsConnectionProvider(v.id).notifier)
                            .disconnect();
                      }
                      widget.onClose();
                    },
                    onLongPress: () => setState(() => _expandedMenuLabel =
                        _expandedMenuLabel == AetherStrings.disconnectAll ? null : AetherStrings.disconnectAll),
                    onSecondaryTap: () => setState(() => _expandedMenuLabel =
                        _expandedMenuLabel == AetherStrings.disconnectAll ? null : AetherStrings.disconnectAll),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          ),
        ),
    );
  }

  void _open(BuildContext context, WindowType type) {
    widget.onClose();
    final activeVpsId = ref.read(activeDesktopProvider);
    if (activeVpsId == null) return;
    final screen = MediaQuery.sizeOf(context);
    final windowId = type == WindowType.terminal
        ? _uuid.v4()
        : '${activeVpsId}_${type.name}';
    final vps = ref.read(vpsListProvider).firstWhere((v) => v.id == activeVpsId);
    final title = switch (type) {
      WindowType.terminal    => 'Terminal — ${vps.label}',
      WindowType.fileManager => 'Files — ${vps.label}',
      WindowType.docker      => 'Docker — ${vps.label}',
      WindowType.dashboard   => 'Dashboard — ${vps.label}',
      WindowType.dockerLogs  => 'Logs',
      WindowType.dockerShell => 'Shell',
      WindowType.firewall        => 'Firewall — ${vps.label}',
      WindowType.serviceManager  => 'Services — ${vps.label}',
    };
    ref.read(windowManagerProvider.notifier).openWindow(
      WindowManagerNotifier.makeWindow(
        windowId: windowId,
        vpsId: activeVpsId,
        type: type,
        title: title,
        screen: screen,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Text(label,
          style: const TextStyle(
              color: AetherColors.textSecondary, fontSize: 10)),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.expanded = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onSecondaryTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 14, color: AetherColors.accent),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        color: AetherColors.textPrimary, fontSize: 13)),
              ],
            ),
          ),
        ),
        if (expanded)
          const _InlineAction(
            icon: Icons.hourglass_empty,
            label: 'No actions yet',
            color: AetherColors.textSecondary,
          ),
      ],
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.icon,
    required this.label,
    this.color = AetherColors.textPrimary,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AetherColors.glassBase,
        padding: const EdgeInsets.fromLTRB(32, 7, 12, 7),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
