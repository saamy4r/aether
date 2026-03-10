import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/strings.dart';
import '../../core/models/window_state.dart';
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
  String? _selectedVpsId;

  @override
  Widget build(BuildContext context) {
    final vpsList = ref.watch(vpsListProvider);
    final connected = vpsList.where((v) {
      final conn = ref.watch(vpsConnectionProvider(v.id));
      return conn.valueOrNull?.isConnected == true;
    }).toList();

    if (_selectedVpsId == null && connected.isNotEmpty) {
      _selectedVpsId = connected.first.id;
    }

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: 0,
          bottom: AetherDimensions.taskbarHeight,
        ),
        child: SizedBox(
          width: AetherDimensions.startMenuWidth,
          child: GlassContainer(
            blurSigma: AetherGlass.startMenuBlur,
            borderRadius: AetherGlass.startMenuRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: AetherDimensions.startMenuMaxHeight,
              ),
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

                  // VPS selector
                  if (connected.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: DropdownButton<String>(
                        value: _selectedVpsId,
                        dropdownColor: AetherColors.surfaceDeep,
                        style: const TextStyle(
                            color: AetherColors.textPrimary, fontSize: 12),
                        underline: const SizedBox.shrink(),
                        isExpanded: true,
                        items: connected
                            .map((v) => DropdownMenuItem(
                                  value: v.id,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.circle,
                                          size: 8,
                                          color: AetherColors.accentTeal),
                                      const SizedBox(width: 6),
                                      Text(v.label),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (id) =>
                            setState(() => _selectedVpsId = id),
                      ),
                    ),
                    const Divider(color: AetherColors.glassBorder, height: 1),
                  ],

                  // Tools section
                  if (_selectedVpsId != null) ...[
                    const _SectionLabel('Tools'),
                    _MenuItem(
                      icon: Icons.terminal,
                      label: AetherStrings.terminal,
                      onTap: () => _open(context, WindowType.terminal),
                    ),
                    _MenuItem(
                      icon: Icons.folder,
                      label: AetherStrings.fileManager,
                      onTap: () => _open(context, WindowType.fileManager),
                    ),
                    _MenuItem(
                      icon: Icons.smart_toy,
                      label: AetherStrings.dockerManager,
                      onTap: () => _open(context, WindowType.docker),
                    ),
                    const Divider(color: AetherColors.glassBorder, height: 1),
                  ],

                  // System section
                  const _SectionLabel('System'),
                  _MenuItem(
                    icon: Icons.add,
                    label: AetherStrings.addVps,
                    onTap: () {
                      widget.onClose();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddVpsScreen()),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.link_off,
                    label: AetherStrings.disconnectAll,
                    onTap: () {
                      final vps = ref.read(vpsListProvider);
                      for (final v in vps) {
                        ref
                            .read(vpsConnectionProvider(v.id).notifier)
                            .disconnect();
                      }
                      widget.onClose();
                    },
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
    if (_selectedVpsId == null) return;
    final screen = MediaQuery.sizeOf(context);
    final windowId = type == WindowType.terminal
        ? _uuid.v4()
        : '${_selectedVpsId}_${type.name}';
    final vps = ref.read(vpsListProvider).firstWhere((v) => v.id == _selectedVpsId);
    final title = switch (type) {
      WindowType.terminal    => 'Terminal — ${vps.label}',
      WindowType.fileManager => 'Files — ${vps.label}',
      WindowType.docker      => 'Docker — ${vps.label}',
      WindowType.dashboard   => 'Dashboard — ${vps.label}',
    };
    ref.read(windowManagerProvider.notifier).openWindow(
      WindowManagerNotifier.makeWindow(
        windowId: windowId,
        vpsId: _selectedVpsId!,
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
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
    );
  }
}
