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
  // Live drag/resize deltas. Pointer moves only update these notifiers, so a
  // drag re-positions the window via the ListenableBuilder below without
  // rebuilding the frame subtree (glass blur + window content) every frame.
  // The result is committed to windowManagerProvider once, on pan end.
  final _dragDelta = ValueNotifier<Offset>(Offset.zero);
  final _resizeDelta = ValueNotifier<Offset>(Offset.zero);
  bool _bodyDragEnabled = false;
  bool _isMaximized = false;
  // Saved geometry before maximize
  double? _savedX, _savedY, _savedW, _savedH;

  WindowState get ws => widget.windowState;

  @override
  void dispose() {
    _dragDelta.dispose();
    _resizeDelta.dispose();
    super.dispose();
  }

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
    final (minW, minH) = _minSize;
    final maxW = screen.width;
    final maxH = screen.height - AetherDimensions.taskbarHeight;

    void onPanUpdate(DragUpdateDetails d) =>
        _dragDelta.value += d.delta;
    void onPanEnd(DragEndDetails _) {
      ref.read(windowManagerProvider.notifier).moveWindow(
        ws.windowId,
        _dragDelta.value,
        screen,
        AetherDimensions.taskbarHeight,
      );
      _dragDelta.value = Offset.zero;
      if (_bodyDragEnabled) setState(() => _bodyDragEnabled = false);
    }

    void onResizeUpdate(Offset d) {
      // Keep the live size inside [min, max] so the accumulated delta never
      // builds up an invisible overshoot.
      final v = _resizeDelta.value + d;
      final w = (ws.width + v.dx).clamp(minW, maxW);
      final h = (ws.height + v.dy).clamp(minH, maxH);
      _resizeDelta.value = Offset(w - ws.width, h - ws.height);
    }

    void onResizeEnd() {
      ref.read(windowManagerProvider.notifier).resizeWindow(
        ws.windowId,
        _resizeDelta.value.dx,
        _resizeDelta.value.dy,
        minW,
        minH,
        maxW,
        maxH,
      );
      _resizeDelta.value = Offset.zero;
    }

    final frame = GestureDetector(
      onTap: () {
        ref.read(windowManagerProvider.notifier).focusWindow(ws.windowId);
        if (_bodyDragEnabled) setState(() => _bodyDragEnabled = false);
      },
      onDoubleTap: () => setState(() => _bodyDragEnabled = true),
      onPanUpdate: _bodyDragEnabled ? onPanUpdate : null,
      onPanEnd: _bodyDragEnabled ? onPanEnd : null,
      child: GlassContainer(
        child: Column(
          children: [
            // Title bar — always draggable
            GestureDetector(
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
            // Window content — isolated so the glass layer repainting during
            // drag doesn't force the content to repaint too.
            Expanded(child: RepaintBoundary(child: _buildContent())),
            // Resize handle
            Align(
              alignment: Alignment.bottomRight,
              child: _ResizeHandle(
                onResize: onResizeUpdate,
                onResizeEnd: onResizeEnd,
              ),
            ),
          ],
        ),
      ),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([_dragDelta, _resizeDelta]),
      child: frame,
      builder: (context, child) => Positioned(
        left: ws.x + _dragDelta.value.dx,
        top: ws.y + _dragDelta.value.dy,
        width: (ws.width + _resizeDelta.value.dx).clamp(minW, maxW),
        height: (ws.height + _resizeDelta.value.dy).clamp(minH, maxH),
        child: child!,
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

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onResize, required this.onResizeEnd});
  final void Function(Offset delta) onResize;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) => onResize(d.delta),
      onPanEnd: (_) => onResizeEnd(),
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
