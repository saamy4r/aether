import 'package:flutter/foundation.dart';

enum WindowType { dashboard, terminal, fileManager, docker, dockerLogs, dockerShell, firewall }

@immutable
class WindowState {
  const WindowState({
    required this.windowId,
    required this.vpsId,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
    this.isMinimized = false,
    this.title = '',
    this.containerId,
  });

  final String windowId;
  final String vpsId;
  final WindowType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final int zIndex;
  final bool isMinimized;
  final String title;
  final String? containerId;

  WindowState copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    bool? isMinimized,
    String? title,
  }) => WindowState(
    windowId: windowId,
    vpsId: vpsId,
    type: type,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    zIndex: zIndex ?? this.zIndex,
    isMinimized: isMinimized ?? this.isMinimized,
    title: title ?? this.title,
    containerId: containerId,
  );
}
