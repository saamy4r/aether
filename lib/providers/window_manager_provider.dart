import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/window_state.dart';
import '../core/constants/dimensions.dart';

class WindowManagerNotifier extends Notifier<List<WindowState>> {
  @override
  List<WindowState> build() => [];

  int get _nextZ =>
      state.isEmpty ? 1 : state.map((w) => w.zIndex).reduce(max) + 1;

  void openWindow(WindowState window) {
    // terminal, dockerLogs, dockerShell allow multiple instances
    const multiInstance = {WindowType.terminal, WindowType.dockerLogs, WindowType.dockerShell};
    if (!multiInstance.contains(window.type)) {
      final existing = state.where(
        (w) => w.type == window.type && w.vpsId == window.vpsId,
      );
      if (existing.isNotEmpty) {
        focusWindow(existing.first.windowId);
        return;
      }
    }
    state = [...state, window.copyWith(zIndex: _nextZ)];
  }

  void focusWindow(String windowId) {
    state = state.map((w) {
      return w.windowId == windowId ? w.copyWith(zIndex: _nextZ) : w;
    }).toList();
  }

  void moveWindow(
    String windowId,
    Offset delta,
    Size screen,
    double taskbarHeight,
  ) {
    state = state.map((w) {
      if (w.windowId != windowId) return w;
      return w.copyWith(
        x: (w.x + delta.dx).clamp(
            0.0, (screen.width - w.width).clamp(0.0, double.infinity)),
        y: (w.y + delta.dy).clamp(
            0.0, (screen.height - taskbarHeight - w.height).clamp(0.0, double.infinity)),
      );
    }).toList();
  }

  void resizeWindow(
    String windowId,
    double dw,
    double dh,
    double minW,
    double minH, [
    double maxW = double.infinity,
    double maxH = double.infinity,
  ]) {
    state = state.map((w) {
      if (w.windowId != windowId) return w;
      return w.copyWith(
        width: (w.width + dw).clamp(minW, maxW),
        height: (w.height + dh).clamp(minH, maxH),
      );
    }).toList();
  }

  void minimizeWindow(String windowId) {
    state = state
        .map((w) => w.windowId == windowId ? w.copyWith(isMinimized: true) : w)
        .toList();
  }

  void restoreWindow(String windowId) {
    state = state.map((w) {
      return w.windowId == windowId
          ? w.copyWith(isMinimized: false, zIndex: _nextZ)
          : w;
    }).toList();
  }

  void closeWindow(String windowId) {
    state = state.where((w) => w.windowId != windowId).toList();
  }

  void closeAllForVps(String vpsId) {
    state = state.where((w) => w.vpsId != vpsId).toList();
  }

  /// Helper to build a default WindowState for a given type.
  static WindowState makeWindow({
    required String windowId,
    required String vpsId,
    required WindowType type,
    required String title,
    required Size screen,
    String? containerId,
  }) {
    final (w, h) = switch (type) {
      WindowType.dashboard   => (AetherDimensions.dashboardW,   AetherDimensions.dashboardH),
      WindowType.terminal    => (AetherDimensions.terminalW,    AetherDimensions.terminalH),
      WindowType.fileManager => (AetherDimensions.fileManagerW, AetherDimensions.fileManagerH),
      WindowType.docker      => (AetherDimensions.dockerW,      AetherDimensions.dockerH),
      WindowType.dockerLogs  => (AetherDimensions.dockerLogsW,  AetherDimensions.dockerLogsH),
      WindowType.dockerShell => (AetherDimensions.dockerShellW, AetherDimensions.dockerShellH),
      WindowType.firewall        => (AetherDimensions.firewallW,        AetherDimensions.firewallH),
      WindowType.serviceManager  => (AetherDimensions.serviceManagerW,  AetherDimensions.serviceManagerH),
      WindowType.settings        => (AetherDimensions.settingsW,        AetherDimensions.settingsH),
    };
    return WindowState(
      windowId: windowId,
      vpsId: vpsId,
      type: type,
      x: (screen.width - w) / 2 < 0 ? 0 : (screen.width - w) / 2,
      y: (screen.height - h - AetherDimensions.taskbarHeight) / 2 < 0
          ? 0
          : (screen.height - h - AetherDimensions.taskbarHeight) / 2,
      width: w.clamp(0.0, screen.width),
      height: h.clamp(0.0, screen.height - AetherDimensions.taskbarHeight),
      zIndex: 1,
      title: title,
      containerId: containerId,
    );
  }
}

final windowManagerProvider =
    NotifierProvider<WindowManagerNotifier, List<WindowState>>(
  WindowManagerNotifier.new,
);
