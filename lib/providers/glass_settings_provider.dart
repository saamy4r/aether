import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/colors.dart';

const _kOpacityKey = 'aether_glass_opacity';
const _kBlurKey = 'aether_glass_blur';
const _kDarkKey = 'aether_glass_dark';

@immutable
class GlassSettings {
  const GlassSettings({
    this.opacity = defaultOpacity,
    this.blur = defaultBlur,
    this.darkGlass = false,
  });

  // 0x14 alpha of AetherColors.glassBase ≈ 8%
  static const double defaultOpacity = 0.08;
  static const double defaultBlur = AetherGlass.windowBlur;

  static const double minOpacity = 0.02;
  static const double maxOpacity = 1.0;
  static const double maxBlur = 40.0;

  /// Background opacity of window glass (higher = more solid).
  final double opacity;

  /// Backdrop blur sigma for window glass.
  final double blur;

  /// Tint windows with a dark surface instead of white — much more readable
  /// on light wallpapers.
  final bool darkGlass;

  /// The glass tint applied to floating window bodies.
  Color get windowColor => darkGlass
      ? AetherColors.surfaceDeep.withValues(alpha: opacity)
      : Colors.white.withValues(alpha: opacity);

  GlassSettings copyWith({double? opacity, double? blur, bool? darkGlass}) =>
      GlassSettings(
        opacity: opacity ?? this.opacity,
        blur: blur ?? this.blur,
        darkGlass: darkGlass ?? this.darkGlass,
      );
}

class GlassSettingsNotifier extends Notifier<GlassSettings> {
  @override
  GlassSettings build() {
    _load();
    return const GlassSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = GlassSettings(
      opacity: (prefs.getDouble(_kOpacityKey) ?? GlassSettings.defaultOpacity)
          .clamp(GlassSettings.minOpacity, GlassSettings.maxOpacity),
      blur: (prefs.getDouble(_kBlurKey) ?? GlassSettings.defaultBlur)
          .clamp(0.0, GlassSettings.maxBlur),
      darkGlass: prefs.getBool(_kDarkKey) ?? false,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kOpacityKey, state.opacity);
    await prefs.setDouble(_kBlurKey, state.blur);
    await prefs.setBool(_kDarkKey, state.darkGlass);
  }

  /// [persist] false gives a live preview while a slider is dragged;
  /// call again with true (the default) on drag end to save.
  void setOpacity(double v, {bool persist = true}) {
    state = state.copyWith(
        opacity: v.clamp(GlassSettings.minOpacity, GlassSettings.maxOpacity));
    if (persist) _persist();
  }

  void setBlur(double v, {bool persist = true}) {
    state = state.copyWith(blur: v.clamp(0.0, GlassSettings.maxBlur));
    if (persist) _persist();
  }

  void setDarkGlass(bool v) {
    state = state.copyWith(darkGlass: v);
    _persist();
  }

  void reset() {
    state = const GlassSettings();
    _persist();
  }
}

final glassSettingsProvider =
    NotifierProvider<GlassSettingsNotifier, GlassSettings>(
  GlassSettingsNotifier.new,
);
