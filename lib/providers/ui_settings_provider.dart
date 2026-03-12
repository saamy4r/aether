import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

final fullscreenProvider = StateNotifierProvider<FullscreenNotifier, bool>(
  (_) => FullscreenNotifier(),
);

class FullscreenNotifier extends StateNotifier<bool> {
  FullscreenNotifier() : super(false);

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
       defaultTargetPlatform == TargetPlatform.macOS ||
       defaultTargetPlatform == TargetPlatform.windows);

  void toggle() {
    state = !state;
    _apply();
  }

  Future<void> _apply() async {
    if (_isDesktop) {
      await windowManager.setFullScreen(state);
    } else {
      if (state) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [],
        );
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      }
    }
  }
}
