import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../providers/vps_connection_provider.dart';
import '../../providers/vps_list_provider.dart';
import '../../providers/window_manager_provider.dart';
import 'start_menu.dart';
import 'taskbar_window_button.dart';

class Taskbar extends ConsumerStatefulWidget {
  const Taskbar({super.key});

  @override
  ConsumerState<Taskbar> createState() => _TaskbarState();
}

class _TaskbarState extends ConsumerState<Taskbar> {
  bool _startMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    final windows = ref.watch(windowManagerProvider);
    final vpsList = ref.watch(vpsListProvider);

    final connectedCount = vpsList.where((v) {
      final conn = ref.watch(vpsConnectionProvider(v.id));
      return conn.valueOrNull?.isConnected == true;
    }).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_startMenuOpen)
          StartMenu(
            onClose: () => setState(() => _startMenuOpen = false),
          ),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AetherGlass.taskbarBlur,
              sigmaY: AetherGlass.taskbarBlur,
            ),
            child: Container(
              height: AetherDimensions.taskbarHeight +
                  MediaQuery.of(context).padding.bottom,
              decoration: BoxDecoration(
                color: AetherColors.taskbarBase,
                border: const Border(
                  top: BorderSide(
                    color: AetherColors.glassBorder,
                    width: AetherGlass.borderWidth,
                  ),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                children: [
                  // Start Menu button
                  _StartButton(
                    isOpen: _startMenuOpen,
                    onTap: () =>
                        setState(() => _startMenuOpen = !_startMenuOpen),
                  ),
                  // Window buttons (center)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: windows
                            .map((w) => TaskbarWindowButton(window: w))
                            .toList(),
                      ),
                    ),
                  ),
                  // System tray
                  _SystemTray(connectedCount: connectedCount),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.isOpen, required this.onTap});
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: AetherDimensions.taskbarHeight,
        alignment: Alignment.center,
        decoration: isOpen
            ? BoxDecoration(color: AetherColors.accent.withOpacity(0.2))
            : null,
        child: Icon(
          Icons.blur_on,
          color: isOpen ? AetherColors.accent : AetherColors.textPrimary,
          size: 22,
        ),
      ),
    );
  }
}

class _SystemTray extends StatelessWidget {
  const _SystemTray({required this.connectedCount});
  final int connectedCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connectedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AetherColors.accentTeal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AetherColors.accentTeal.withOpacity(0.5)),
              ),
              child: Text(
                '$connectedCount',
                style: const TextStyle(
                    color: AetherColors.accentTeal, fontSize: 11),
              ),
            ),
          const SizedBox(width: 8),
          _Clock(),
        ],
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 30)),
      builder: (_, __) {
        final now = DateTime.now();
        final h = now.hour.toString().padLeft(2, '0');
        final m = now.minute.toString().padLeft(2, '0');
        return Text('$h:$m',
            style: const TextStyle(
                color: AetherColors.textPrimary, fontSize: 12));
      },
    );
  }
}
