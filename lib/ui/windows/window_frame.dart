import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/models/window_state.dart';
import '../../providers/window_manager_provider.dart';
import '../common/glass_container.dart';
import 'window_title_bar.dart';
import 'dashboard/dashboard_window.dart';
import 'terminal/terminal_window.dart';
import 'file_manager/file_manager_window.dart';
import 'docker/docker_window.dart';
import 'docker/docker_logs_window.dart';
import 'firewall/firewall_window.dart';
import 'services/service_manager_window.dart';

class WindowFrame extends ConsumerStatefulWidget {
  const WindowFrame({super.key, required this.windowState});
  final WindowState windowState;

  @override
  ConsumerState<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends ConsumerState<WindowFrame> {
  Offset _dragDelta = Offset.zero;
  bool _isDragging = false;
  bool _bodyDragEnabled = false;
  bool _isMaximized = false;
  // Saved geometry before maximize
  double? _savedX, _savedY, _savedW, _savedH;

  WindowState get ws => widget.windowState;

  (double minW, double minH) get _minSize => switch (ws.type) {
    WindowType.dashboard   => (AetherDimensions.dashboardMinW,   AetherDimensions.dashboardMinH),
    WindowType.terminal    => (AetherDimensions.terminalMinW,    AetherDimensions.terminalMinH),
    WindowType.fileManager => (AetherDimensions.fileManagerMinW, AetherDimensions.fileManagerMinH),
    WindowType.docker      => (AetherDimensions.dockerMinW,      AetherDimensions.dockerMinH),
    WindowType.dockerLogs  => (AetherDimensions.dockerLogsMinW,  AetherDimensions.dockerLogsMinH),
    WindowType.dockerShell => (AetherDimensions.dockerShellMinW, AetherDimensions.dockerShellMinH),
    WindowType.firewall        => (AetherDimensions.firewallMinW,        AetherDimensions.firewallMinH),
    WindowType.serviceManager  => (AetherDimensions.serviceManagerMinW,  AetherDimensions.serviceManagerMinH),
  };

  IconData get _icon => switch (ws.type) {
    WindowType.dashboard   => Icons.monitor_heart,
    WindowType.terminal    => Icons.terminal,
    WindowType.fileManager => Icons.folder,
    WindowType.docker      => Icons.smart_toy,
    WindowType.dockerLogs  => Icons.article,
    WindowType.dockerShell => Icons.terminal,
    WindowType.firewall        => Icons.security,
    WindowType.serviceManager  => Icons.settings_applications,
  };

  void _toggleMaximize(Size screen) {
    if (_isMaximized) {
      ref.read(windowManagerProvider.notifier).moveWindow(
        ws.windowId,
        Offset((_savedX ?? 0) - ws.x, (_savedY ?? 0) - ws.y),
        screen,
        AetherDimensions.taskbarHeight,
      );
      ref.read(windowManagerProvider.notifier).resizeWindow(
        ws.windowId,
        (_savedW ?? ws.width) - ws.width,
        (_savedH ?? ws.height) - ws.height,
        0, 0,
      );
      setState(() => _isMaximized = false);
    } else {
      _savedX = ws.x;
      _savedY = ws.y;
      _savedW = ws.width;
      _savedH = ws.height;
      ref.read(windowManagerProvider.notifier).moveWindow(
        ws.windowId,
        Offset(-ws.x, -ws.y),
        screen,
        AetherDimensions.taskbarHeight,
      );
      ref.read(windowManagerProvider.notifier).resizeWindow(
        ws.windowId,
        screen.width - ws.width,
        screen.height - AetherDimensions.taskbarHeight - ws.height,
        0, 0,
      );
      setState(() => _isMaximized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final x = _isDragging ? (ws.x + _dragDelta.dx) : ws.x;
    final y = _isDragging ? (ws.y + _dragDelta.dy) : ws.y;

    void onPanStart(_) => setState(() => _isDragging = true);
    void onPanUpdate(DragUpdateDetails d) =>
        setState(() => _dragDelta += d.delta);
    void onPanEnd(DragEndDetails _) {
      ref.read(windowManagerProvider.notifier).moveWindow(
        ws.windowId,
        _dragDelta,
        screen,
        AetherDimensions.taskbarHeight,
      );
      setState(() {
        _isDragging = false;
        _dragDelta = Offset.zero;
        _bodyDragEnabled = false;
      });
    }

    return Positioned(
      left: x,
      top: y,
      width: ws.width,
      height: ws.height,
      child: GestureDetector(
        onTap: () {
          ref.read(windowManagerProvider.notifier).focusWindow(ws.windowId);
          if (_bodyDragEnabled) setState(() => _bodyDragEnabled = false);
        },
        onDoubleTap: () => setState(() => _bodyDragEnabled = true),
        onPanStart: _bodyDragEnabled ? onPanStart : null,
        onPanUpdate: _bodyDragEnabled ? onPanUpdate : null,
        onPanEnd: _bodyDragEnabled ? onPanEnd : null,
        child: GlassContainer(
          child: Column(
            children: [
              // Title bar — always draggable
              GestureDetector(
                onPanStart: onPanStart,
                onPanUpdate: onPanUpdate,
                onPanEnd: onPanEnd,
                child: WindowTitleBar(
                  title: ws.title,
                  icon: _icon,
                  dragging: _bodyDragEnabled,
                  onMinimize: () => ref
                      .read(windowManagerProvider.notifier)
                      .minimizeWindow(ws.windowId),
                  onMaximize: () => _toggleMaximize(screen),
                  onClose: () => ref
                      .read(windowManagerProvider.notifier)
                      .closeWindow(ws.windowId),
                ),
              ),
              // Window content
              Expanded(child: _buildContent()),
              // Resize handle
              Align(
                alignment: Alignment.bottomRight,
                child: _ResizeHandle(windowId: ws.windowId, minSize: _minSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() => switch (ws.type) {
    WindowType.dashboard   => DashboardWindow(vpsId: ws.vpsId),
    WindowType.terminal    => TerminalWindowContent(
        windowId: ws.windowId, vpsId: ws.vpsId),
    WindowType.fileManager => FileManagerWindowContent(vpsId: ws.vpsId),
    WindowType.docker      => DockerWindowContent(vpsId: ws.vpsId),
    WindowType.dockerLogs  => DockerLogsWindowContent(
        windowId: ws.windowId,
        containerId: ws.containerId!,
        vpsId: ws.vpsId),
    WindowType.dockerShell => DockerShellWindowContent(
        windowId: ws.windowId,
        containerId: ws.containerId!,
        vpsId: ws.vpsId),
    WindowType.firewall        => FirewallWindowContent(vpsId: ws.vpsId),
    WindowType.serviceManager  => ServiceManagerWindowContent(vpsId: ws.vpsId),
  };
}

class _ResizeHandle extends ConsumerStatefulWidget {
  const _ResizeHandle({required this.windowId, required this.minSize});
  final String windowId;
  final (double, double) minSize;

  @override
  ConsumerState<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends ConsumerState<_ResizeHandle> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        final (minW, minH) = widget.minSize;
        ref.read(windowManagerProvider.notifier).resizeWindow(
          widget.windowId,
          d.delta.dx,
          d.delta.dy,
          minW,
          minH,
        );
      },
      child: Container(
        width: AetherDimensions.resizeHandleSize,
        height: AetherDimensions.resizeHandleSize,
        alignment: Alignment.bottomRight,
        child: const Icon(
          Icons.drag_handle,
          size: 12,
          color: AetherColors.textSecondary,
        ),
      ),
    );
  }
}
