import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final wallpaperProvider =
    NotifierProvider<WallpaperNotifier, Map<String, String>>(
  WallpaperNotifier.new,
);

/// Stores per-VPS wallpaper file paths.
/// Key = vpsId, Value = absolute file path to the chosen image.
class WallpaperNotifier extends Notifier<Map<String, String>> {
  static const _key = 'aether_wallpapers';

  @override
  Map<String, String> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final decoded = Map<String, String>.from(jsonDecode(raw) as Map);
      state = decoded;
    }
  }

  Future<void> setWallpaper(String vpsId, String path) async {
    state = {...state, vpsId: path};
    await _persist();
  }

  Future<void> removeWallpaper(String vpsId) async {
    state = Map.of(state)..remove(vpsId);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state));
  }
}
