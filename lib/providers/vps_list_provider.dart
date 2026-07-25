import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/vps_model.dart';

const _kVpsListKey = 'aether_vps_list';

class VpsListNotifier extends Notifier<List<VpsModel>> {
  @override
  List<VpsModel> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kVpsListKey) ?? [];
    // Skip corrupt entries instead of letting one crash the whole list.
    state = raw
        .map((s) {
          try {
            final vps =
                VpsModel.fromJson(jsonDecode(s) as Map<String, dynamic>);
            return vps.id.isEmpty ? null : vps;
          } catch (_) {
            return null;
          }
        })
        .whereType<VpsModel>()
        .toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kVpsListKey,
      state.map((v) => jsonEncode(v.toJson())).toList(),
    );
  }

  Future<void> add(VpsModel vps) async {
    state = [...state, vps];
    await _persist();
  }

  Future<void> update(VpsModel vps) async {
    state = state.map((v) => v.id == vps.id ? vps : v).toList();
    await _persist();
  }

  Future<void> remove(String vpsId) async {
    state = state.where((v) => v.id != vpsId).toList();
    await _persist();
  }

  Future<void> updateIconPosition(String vpsId, double x, double y) async {
    state = state
        .map((v) => v.id == vpsId ? v.copyWith(iconX: x, iconY: y) : v)
        .toList();
    await _persist();
  }
}

final vpsListProvider =
    NotifierProvider<VpsListNotifier, List<VpsModel>>(VpsListNotifier.new);
