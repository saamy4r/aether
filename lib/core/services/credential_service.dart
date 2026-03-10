import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static String _keyKey(String vpsId)        => 'ssh_privkey_$vpsId';
  static String _passwordKey(String vpsId)   => 'ssh_password_$vpsId';
  static String _passphraseKey(String vpsId) => 'ssh_passphrase_$vpsId';

  Future<void> storePrivateKey(String vpsId, String pem) =>
      _storage.write(key: _keyKey(vpsId), value: pem);

  Future<String?> loadPrivateKey(String vpsId) =>
      _storage.read(key: _keyKey(vpsId));

  Future<void> storePassword(String vpsId, String password) =>
      _storage.write(key: _passwordKey(vpsId), value: password);

  Future<String?> loadPassword(String vpsId) =>
      _storage.read(key: _passwordKey(vpsId));

  Future<void> storePassphrase(String vpsId, String passphrase) =>
      _storage.write(key: _passphraseKey(vpsId), value: passphrase);

  Future<String?> loadPassphrase(String vpsId) =>
      _storage.read(key: _passphraseKey(vpsId));

  Future<void> deleteAllCredentials(String vpsId) => Future.wait([
    _storage.delete(key: _keyKey(vpsId)),
    _storage.delete(key: _passwordKey(vpsId)),
    _storage.delete(key: _passphraseKey(vpsId)),
  ]);
}
