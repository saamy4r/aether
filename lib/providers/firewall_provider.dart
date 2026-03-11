import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/ssh_commands.dart';
import '../core/models/firewall_models.dart';
import '../core/parsers/firewall_parser.dart';
import 'vps_connection_provider.dart';

class FirewallNotifier extends FamilyNotifier<FirewallState, String> {
  String get vpsId => arg;

  @override
  FirewallState build(String arg) {
    _detectAndLoad();
    return const FirewallState();
  }

  Future<String> _exec(String cmd) =>
      ref.read(vpsConnectionProvider(vpsId).notifier).exec(cmd);

  Future<void> _detectAndLoad() async {
    try {
      final which = await _exec(SshCommands.ufwDetect);
      if (which.trim().isEmpty) {
        state = state.copyWith(ufwAvailable: false, isLoading: false);
        return;
      }
      state = state.copyWith(ufwAvailable: true);
      await _refresh();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Detection failed: $e',
      );
    }
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        _exec(SshCommands.portScan),
        _exec(SshCommands.ufwStatus),
      ]);
      final portOut = results[0];
      final ufwOut = results[1];

      final ports = FirewallParser.parsePortScan(portOut);
      final (:rules, :enabled) = FirewallParser.parseUfwStatus(ufwOut);
      final correlated = FirewallParser.correlate(ports, rules);

      state = FirewallState(
        ports: correlated,
        rules: rules,
        ufwAvailable: true,
        ufwEnabled: enabled,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _action(String cmd) async {
    try {
      await _exec(cmd);
      await _refresh();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> allowPort(int port, String proto) =>
      _action(SshCommands.ufwAllow(port, proto));

  Future<void> denyPort(int port, String proto) =>
      _action(SshCommands.ufwDeny(port, proto));

  Future<void> deleteRule(int ruleNumber) =>
      _action(SshCommands.ufwDeleteRule(ruleNumber));

  Future<void> enableUfw()  => _action(SshCommands.ufwEnable);
  Future<void> disableUfw() => _action(SshCommands.ufwDisable);
  Future<void> reloadUfw()  => _action(SshCommands.ufwReload);

  void refresh() => _refresh();
}

final firewallProvider =
    NotifierProvider.family<FirewallNotifier, FirewallState, String>(
  FirewallNotifier.new,
);
