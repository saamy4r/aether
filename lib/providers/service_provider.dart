import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/ssh_commands.dart';
import '../core/models/service_model.dart';
import '../core/parsers/service_parser.dart';
import 'vps_connection_provider.dart';

class ServiceNotifier extends FamilyNotifier<ServiceState, String> {
  String get vpsId => arg;

  @override
  ServiceState build(String arg) {
    _detectAndLoad();
    return const ServiceState();
  }

  Future<String> _exec(String cmd, {bool checkExitCode = true}) =>
      ref
          .read(vpsConnectionProvider(vpsId).notifier)
          .exec(cmd, checkExitCode: checkExitCode);

  Future<void> _detectAndLoad() async {
    try {
      final which =
          await _exec(SshCommands.systemctlDetect, checkExitCode: false);
      if (!ServiceParser.isAvailable(which)) {
        state = state.copyWith(isAvailable: false, isLoading: false);
        return;
      }
      state = state.copyWith(isAvailable: true);
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
      final output = await _exec(SshCommands.systemctlListServices);
      final services = ServiceParser.parseList(output);
      state = ServiceState(
        services: services,
        isAvailable: true,
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

  Future<void> startService(String name)   => _action(SshCommands.serviceStart(name));
  Future<void> stopService(String name)    => _action(SshCommands.serviceStop(name));
  Future<void> restartService(String name) => _action(SshCommands.serviceRestart(name));
  Future<void> reloadService(String name)  => _action(SshCommands.serviceReload(name));
  Future<void> enableService(String name)  => _action(SshCommands.serviceEnable(name));
  Future<void> disableService(String name) => _action(SshCommands.serviceDisable(name));

  void refresh() => _refresh();
}

final serviceProvider =
    NotifierProvider.family<ServiceNotifier, ServiceState, String>(
  ServiceNotifier.new,
);
