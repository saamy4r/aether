import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fullscreenProvider = StateNotifierProvider<FullscreenNotifier, bool>(
  (_) => FullscreenNotifier(),
);

class FullscreenNotifier extends StateNotifier<bool> {
  FullscreenNotifier() : super(false);

  void toggle() {
    state = !state;
    _apply();
  }

  void _apply() {
    if (state) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [], // hide all system bars
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values, // restore all system bars
      );
    }
  }
}
