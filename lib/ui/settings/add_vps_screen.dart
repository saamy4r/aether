import 'dart:async';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/models/vps_model.dart';
import '../../core/services/credential_service.dart';
import '../../core/services/ssh_key_service.dart';
import '../../providers/vps_connection_provider.dart';
import '../../providers/vps_list_provider.dart';

const _uuid = Uuid();

class AddVpsScreen extends ConsumerStatefulWidget {
  const AddVpsScreen({super.key, this.vpsToEdit});
  final VpsModel? vpsToEdit;

  @override
  ConsumerState<AddVpsScreen> createState() => _AddVpsScreenState();
}

class _AddVpsScreenState extends ConsumerState<AddVpsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl    = TextEditingController();
  final _hostCtrl     = TextEditingController();
  final _portCtrl     = TextEditingController(text: '22');
  final _userCtrl     = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _keyCtrl      = TextEditingController();

  AuthMethod _authMethod = AuthMethod.key;
  bool _obscurePass = true;
  bool _isTesting = false;
  bool _isGeneratingKey = false;
  String? _testResult;
  String? _publicKey;

  final _credentials = CredentialService();

  @override
  void initState() {
    super.initState();
    if (widget.vpsToEdit != null) {
      final v = widget.vpsToEdit!;
      _labelCtrl.text = v.label;
      _hostCtrl.text  = v.host;
      _portCtrl.text  = v.port.toString();
      _userCtrl.text  = v.username;
      _authMethod     = v.authMethod;
      _loadExistingCredentials(v.id);
    }
  }

  Future<void> _loadExistingCredentials(String vpsId) async {
    if (_authMethod == AuthMethod.key) {
      final key = await _credentials.loadPrivateKey(vpsId);
      if (key != null) _keyCtrl.text = key;
    } else {
      final pass = await _credentials.loadPassword(vpsId);
      if (pass != null) _passwordCtrl.text = pass;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passwordCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vpsToEdit != null;

    return Scaffold(
      backgroundColor: AetherColors.background,
      appBar: AppBar(
        backgroundColor: AetherColors.surfaceDeep,
        foregroundColor: AetherColors.textPrimary,
        title: Text(isEdit ? AetherStrings.editVps : AetherStrings.addVps),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Field(ctrl: _labelCtrl, label: 'Label', hint: 'My VPS',
                validator: _required),
            const SizedBox(height: 12),
            _Field(ctrl: _hostCtrl, label: 'Host / IP',
                hint: '192.168.1.1 or vps.example.com',
                validator: _required),
            const SizedBox(height: 12),
            _Field(
              ctrl: _portCtrl,
              label: 'Port',
              hint: '22',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 65535) {
                  return 'Enter a valid port (1–65535)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _Field(ctrl: _userCtrl, label: 'Username', hint: 'root',
                validator: _required),
            const SizedBox(height: 16),

            // Auth method toggle
            Row(
              children: [
                const Text('Auth method',
                    style: TextStyle(color: AetherColors.textSecondary)),
                const Spacer(),
                SegmentedButton<AuthMethod>(
                  segments: const [
                    ButtonSegment(
                        value: AuthMethod.key, label: Text('SSH Key')),
                    ButtonSegment(
                        value: AuthMethod.password, label: Text('Password')),
                  ],
                  selected: {_authMethod},
                  onSelectionChanged: (s) =>
                      setState(() => _authMethod = s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AetherColors.accent.withOpacity(0.3);
                      }
                      return AetherColors.glassBase;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_authMethod == AuthMethod.key) ...[
              _Field(
                ctrl: _keyCtrl,
                label: 'Private Key (PEM)',
                hint: '-----BEGIN OPENSSH PRIVATE KEY-----',
                maxLines: 5,
                validator: _required,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _isGeneratingKey ? null : _generateKey,
                    icon: _isGeneratingKey
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.vpn_key, size: 14),
                    label: const Text('Generate Ed25519 key',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              if (_publicKey != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AetherColors.accentTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AetherColors.accentTeal.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Public key — copy to ~/.ssh/authorized_keys:',
                          style: TextStyle(
                              color: AetherColors.textSecondary,
                              fontSize: 10)),
                      const SizedBox(height: 4),
                      SelectableText(
                        _publicKey!,
                        style: const TextStyle(
                            color: AetherColors.textPrimary,
                            fontSize: 10,
                            fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _publicKey!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text(AetherStrings.copyPublicKey)),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 12),
                        label: const Text('Copy',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePass,
                style: const TextStyle(color: AetherColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle:
                      const TextStyle(color: AetherColors.textSecondary),
                  enabledBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: AetherColors.glassBorder),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AetherColors.accent),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePass
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 16,
                        color: AetherColors.textSecondary),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: _required,
              ),
            ],

            const SizedBox(height: 20),

            // Test connection
            if (_testResult != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult!.startsWith('✓')
                        ? AetherColors.accentGreen
                        : AetherColors.accentRed,
                    fontSize: 13,
                  ),
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isTesting ? null : _testConnection,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AetherColors.accent,
                      side: const BorderSide(color: AetherColors.accent),
                    ),
                    child: _isTesting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AetherColors.accent))
                        : const Text(AetherStrings.testConnection),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AetherColors.accent,
                      foregroundColor: AetherColors.background,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),

            if (widget.vpsToEdit != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _delete,
                child: const Text('Delete VPS',
                    style: TextStyle(color: AetherColors.accentRed)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateKey() async {
    setState(() => _isGeneratingKey = true);
    try {
      final result = await SshKeyService.generateEd25519();
      setState(() {
        _keyCtrl.text = result.privateKeyPem;
        _publicKey = result.publicKeyOpenSsh;
      });
    } finally {
      setState(() => _isGeneratingKey = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    SSHClient? client;
    try {
      final socket = await SSHSocket.connect(
        _hostCtrl.text.trim(),
        int.parse(_portCtrl.text.trim()),
        timeout: const Duration(seconds: 15),
      );

      List<SSHKeyPair>? identities;
      String? password;

      if (_authMethod == AuthMethod.key) {
        final keypair = SshKeyService.parsePem(_keyCtrl.text.trim());
        if (keypair == null) throw Exception('Failed to parse SSH key.');
        identities = [keypair];
      } else {
        password = _passwordCtrl.text;
      }

      final passwordCopy = password;
      client = SSHClient(
        socket,
        username: _userCtrl.text.trim(),
        identities: identities,
        onPasswordRequest: passwordCopy != null ? () => passwordCopy : null,
        disableHostkeyVerification: true,
      );

      await client.authenticated;
      setState(() => _testResult = '✓ Connection successful');
    } on SocketException {
      setState(() => _testResult = '✗ Cannot reach server. Check your network.');
    } on TimeoutException {
      setState(() => _testResult = '✗ Connection timed out.');
    } on SSHAuthFailError {
      setState(() => _testResult = '✗ Authentication failed. Check credentials.');
    } on SSHAuthAbortError {
      setState(() => _testResult = '✗ Authentication aborted.');
    } catch (e) {
      setState(() => _testResult = '✗ $e');
    } finally {
      client?.close();
      setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.vpsToEdit?.id ?? _uuid.v4();
    final vps = _buildVpsModel(id);
    await _storeCredentials(id);

    if (widget.vpsToEdit != null) {
      await ref.read(vpsListProvider.notifier).update(vps);
    } else {
      await ref.read(vpsListProvider.notifier).add(vps);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final id = widget.vpsToEdit!.id;
    await ref.read(vpsConnectionProvider(id).notifier).disconnect();
    await ref.read(vpsListProvider.notifier).remove(id);
    await _credentials.deleteAllCredentials(id);
    if (mounted) Navigator.pop(context);
  }

  VpsModel _buildVpsModel(String id) => VpsModel(
    id: id,
    label: _labelCtrl.text.trim(),
    host: _hostCtrl.text.trim(),
    port: int.parse(_portCtrl.text.trim()),
    username: _userCtrl.text.trim(),
    authMethod: _authMethod,
  );

  Future<void> _storeCredentials(String id) async {
    if (_authMethod == AuthMethod.key) {
      await _credentials.storePrivateKey(id, _keyCtrl.text.trim());
    } else {
      await _credentials.storePassword(id, _passwordCtrl.text);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: AetherColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(color: AetherColors.textSecondary, fontSize: 12),
        hintStyle:
            const TextStyle(color: AetherColors.textSecondary, fontSize: 12),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AetherColors.glassBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AetherColors.accent),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AetherColors.accentRed),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AetherColors.accentRed),
        ),
      ),
    );
  }
}
