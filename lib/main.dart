import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
       defaultTargetPlatform == TargetPlatform.macOS ||
       defaultTargetPlatform == TargetPlatform.windows)) {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('Aether');

    // Flutter bundles assets at data/flutter_assets/ relative to the binary
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final iconPath = '$exeDir/data/flutter_assets/assets/icon/icon.png';
    if (File(iconPath).existsSync()) {
      await windowManager.setIcon(iconPath);
    }
  }
  runApp(const ProviderScope(child: AetherApp()));
}
