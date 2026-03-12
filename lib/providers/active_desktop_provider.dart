import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which VPS desktop is currently "entered".
/// null = VPS lobby (no desktop active)
/// non-null = vpsId of the active desktop
final activeDesktopProvider = StateProvider<String?>((ref) => null);
