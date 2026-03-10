import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/biometric_service.dart';

class AuthNotifier extends Notifier<bool> {
  final _bio = BiometricService();

  @override
  bool build() => false; // false = unlocked

  void lock() => state = true;

  Future<bool> unlock() async {
    final ok = await _bio.authenticate(reason: 'Unlock Aether');
    if (ok) state = false;
    return ok;
  }
}

/// true = locked
final authProvider = NotifierProvider<AuthNotifier, bool>(AuthNotifier.new);
