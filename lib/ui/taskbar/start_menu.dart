import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/constants/strings.dart';
import '../../core/models/window_state.dart';
import '../../core/services/credential_service.dart';
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
  String? _selectedVpsId;
  String? _expandedVpsId;     // vpsId whose inline actions are showing
  String? _expandedMenuLabel; // menu item label whose inline actions are showing

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

                  // VPS list with connect/disconnect
                  if (vpsList.isNotEmpty) ...[
                    const _SectionLabel('Servers'),
                    ...vpsList.map((v) {
                      final conn = ref.watch(vpsConnectionProvider(v.id));
                      final isConnected = conn.valueOrNull?.isConnected == true;
                      final isConnecting = conn.isLoading;
                      final isExpanded = _expandedVpsId == v.id;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() {
                              _expandedVpsId = isExpanded ? null : null;
                              if (isConnected) _selectedVpsId = v.id;
                            }),
                            onLongPress: () => setState(() =>
                                _expandedVpsId = isExpanded ? null : v.id),
                            onSecondaryTap: () => setState(() =>
                                _expandedVpsId = isExpanded ? null : v.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.circle,
                                      size: 7,
                                      color: isConnected
                                          ? AetherColors.accentTeal
                                          : isConnecting
                                              ? AetherColors.accentYellow
                                              : AetherColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      v.label,
                                      style: TextStyle(
                                        color: isConnected
                                            ? AetherColors.textPrimary
                                            : AetherColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  if (isConnecting)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: AetherColors.accent),
                                    )
                                  else if (isConnected)
                                    GestureDetector(
                                      onTap: () => ref
                                          .read(vpsConnectionProvider(v.id).notifier)
                                          .disconnect(),
                                      child: const Icon(Icons.link_off,
                                          size: 14,
                                          color: AetherColors.textSecondary),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: () => ref
                                          .read(vpsConnectionProvider(v.id).notifier)
                                          .connect(),
                                      child: const Icon(Icons.link,
                                          size: 14, color: AetherColors.accent),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (isExpanded) ...[
                            _InlineAction(
                              icon: Icons.delete_outline,
                              label: 'Delete VPS',
                              color: AetherColors.accentRed,
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    backgroundColor: AetherColors.surfaceDeep,
                                    title: const Text('Delete VPS',
                                        style: TextStyle(color: AetherColors.textPrimary)),
                                    content: Text(
                                      'Are you sure you want to delete "${v.label}"? This cannot be undone.',
                                      style: const TextStyle(color: AetherColors.textSecondary),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel',
                                            style: TextStyle(color: AetherColors.textSecondary)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete',
                                            style: TextStyle(color: AetherColors.accentRed)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                setState(() => _expandedVpsId = null);
                                await ref.read(vpsConnectionProvider(v.id).notifier).disconnect();
                                await ref.read(vpsListProvider.notifier).remove(v.id);
                                await CredentialService().deleteAllCredentials(v.id);
                                widget.onClose();
                              },
                            ),
                          ],
                        ],
                      );
                    }),
                    const Divider(color: AetherColors.glassBorder, height: 1),
                  ],

                  // VPS selector for tools (connected only)
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
                    const Divider(color: AetherColors.glassBorder, height: 1),
                  ],

                  // System section
                  const _SectionLabel('System'),
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
      WindowType.dockerLogs  => 'Logs',
      WindowType.dockerShell => 'Shell',
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
