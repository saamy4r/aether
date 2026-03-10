import 'package:local_auth/local_auth.dart';

class BiometricService {
  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Unlock Aether'}) async {
    try {
      final available = await isAvailable();
      if (!available) return true;
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (_) {
      return false;
    }
  }
}
