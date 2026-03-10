import 'dart:async';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/vps_model.dart';
import '../core/services/credential_service.dart';
import '../core/services/ssh_key_service.dart';
import '../core/constants/strings.dart';
import 'vps_list_provider.dart';

const _kAutoConnectKey = 'aether_auto_connect_ids';

enum ConnectionStatus { disconnected, connecting, connected, error }

class VpsConnectionState {
  const VpsConnectionState({
    required this.status,
    this.client,
    this.errorMessage,
  });

  final ConnectionStatus status;
  final SSHClient? client;
  final String? errorMessage;

  bool get isConnected => status == ConnectionStatus.connected;
}

class VpsConnectionNotifier
    extends FamilyAsyncNotifier<VpsConnectionState, String> {
  SSHClient? _client;
  final _credentials = CredentialService();

  @override
  Future<VpsConnectionState> build(String arg) async {
    ref.onDispose(_disconnect);
    return const VpsConnectionState(status: ConnectionStatus.disconnected);
  }

  Future<void> connect() async {
    final vpsList = ref.read(vpsListProvider);
    final vps = vpsList.firstWhere((v) => v.id == arg);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _doConnect(vps));
  }

  Future<VpsConnectionState> _doConnect(VpsModel vps) async {
    try {
      final socket = await SSHSocket.connect(
        vps.host,
        vps.port,
        timeout: const Duration(seconds: 15),
      );

      List<SSHKeyPair>? identities;
      String? password;

      if (vps.authMethod == AuthMethod.key) {
        final pem = await _credentials.loadPrivateKey(vps.id);
        if (pem == null) throw Exception('No SSH key stored for this VPS.');
        final passphrase = await _credentials.loadPassphrase(vps.id);
        final keypair = SshKeyService.parsePem(pem, passphrase: passphrase);
        if (keypair == null) throw Exception('Failed to parse SSH key.');
        identities = [keypair];
      } else {
        password = await _credentials.loadPassword(vps.id);
        if (password == null) throw Exception('No password stored for this VPS.');
      }

      final passwordCopy = password;
      _client = SSHClient(
        socket,
        username: vps.username,
        identities: identities,
        onPasswordRequest: passwordCopy != null ? () => passwordCopy : null,
        disableHostkeyVerification: true,
      );

      await _client!.authenticated;
      // Persist this vpsId so it auto-reconnects on next launch
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_kAutoConnectKey) ?? [];
      if (!ids.contains(arg)) {
        await prefs.setStringList(_kAutoConnectKey, [...ids, arg]);
      }
      return VpsConnectionState(
        status: ConnectionStatus.connected,
        client: _client,
      );
    } on SocketException {
      return const VpsConnectionState(
        status: ConnectionStatus.error,
        errorMessage: AetherStrings.networkError,
      );
    } on TimeoutException {
      return const VpsConnectionState(
        status: ConnectionStatus.error,
        errorMessage: AetherStrings.connectTimeout,
      );
    } on SSHAuthFailError {
      return const VpsConnectionState(
        status: ConnectionStatus.error,
        errorMessage: AetherStrings.authFailed,
      );
    } on SSHAuthAbortError {
      return const VpsConnectionState(
        status: ConnectionStatus.error,
        errorMessage: AetherStrings.authFailed,
      );
    } catch (e) {
      return VpsConnectionState(
        status: ConnectionStatus.error,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  Future<void> disconnect() async {
    _disconnect();
    // Remove from auto-connect list when user explicitly disconnects
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kAutoConnectKey) ?? [];
    await prefs.setStringList(_kAutoConnectKey, ids.where((id) => id != arg).toList());
    state = const AsyncValue.data(
      VpsConnectionState(status: ConnectionStatus.disconnected),
    );
  }

  void _disconnect() {
    _client?.close();
    _client = null;
  }

  SSHClient? get client => _client;

  Future<String> exec(
    String command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final c = _client;
    if (c == null) throw StateError('Not connected');
    final session = await c.execute(command);
    try {
      final chunks = await session.stdout
          .toList()
          .timeout(timeout, onTimeout: () {
        session.close();
        throw TimeoutException('SSH exec timed out');
      });
      await session.done;
      return String.fromCharCodes(chunks.expand((e) => e));
    } finally {
      session.close();
    }
  }
}

final vpsConnectionProvider = AsyncNotifierProvider.family<
    VpsConnectionNotifier, VpsConnectionState, String>(
  VpsConnectionNotifier.new,
);

/// Runs once on startup — reconnects any VPS that was connected before the app closed.
final autoConnectProvider = FutureProvider<void>((ref) async {
  // Wait for the VPS list to load first
  final vpsList = ref.watch(vpsListProvider);
  if (vpsList.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList(_kAutoConnectKey) ?? [];

  for (final id in ids) {
    // Only reconnect if this VPS still exists in the list
    if (vpsList.any((v) => v.id == id)) {
      ref.read(vpsConnectionProvider(id).notifier).connect();
    }
  }
});
