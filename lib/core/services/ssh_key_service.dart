import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as nacl;

class SshKeyService {
  /// Generates an Ed25519 keypair in an Isolate (CPU-intensive).
  /// Returns [privateKeyPem, publicKeyOpenSsh].
  static Future<({String privateKeyPem, String publicKeyOpenSsh})>
      generateEd25519() async {
    return Isolate.run(() {
      final signingKey = nacl.SigningKey.generate();
      final privateKeyBytes = Uint8List.fromList(signingKey.asTypedList);
      final publicKeyBytes = Uint8List.fromList(signingKey.verifyKey.asTypedList);

      // Construct OpenSSH PEM manually
      final keypair = OpenSSHEd25519KeyPair(publicKeyBytes, privateKeyBytes, '');
      final pem = keypair.toPem();

      // Construct authorized_keys format: "ssh-ed25519 BASE64KEY"
      final pubOpenSsh = _toOpenSshPublicKey(publicKeyBytes);

      return (privateKeyPem: pem, publicKeyOpenSsh: pubOpenSsh);
    });
  }

  static String _toOpenSshPublicKey(Uint8List publicKeyBytes) {
    // SSH wire format: [4-byte len][type string][4-byte len][32-byte key]
    const keyType = 'ssh-ed25519';
    final typeBytes = utf8.encode(keyType);
    final wire = BytesBuilder()
      ..add(_uint32be(typeBytes.length))
      ..add(typeBytes)
      ..add(_uint32be(publicKeyBytes.length))
      ..add(publicKeyBytes);
    final b64 = base64.encode(wire.toBytes());
    return '$keyType $b64';
  }

  static Uint8List _uint32be(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.big);

  /// Parses a PEM string into SSHKeyPair. Returns null on failure.
  static SSHKeyPair? parsePem(String pem, {String? passphrase}) {
    try {
      final pairs = SSHKeyPair.fromPem(pem, passphrase);
      return pairs.isNotEmpty ? pairs.first : null;
    } catch (_) {
      return null;
    }
  }
}
