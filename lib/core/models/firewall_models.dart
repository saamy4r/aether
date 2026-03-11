import 'package:flutter/foundation.dart';

enum UfwPortStatus { allowed, denied, unknown }

enum UfwEnabled { active, inactive, unknown }

@immutable
class PortEntry {
  const PortEntry({
    required this.proto,
    required this.address,
    required this.port,
    required this.process,
    required this.ufwStatus,
    this.ufwRuleNumber,
  });

  final String proto;         // 'tcp' | 'udp'
  final String address;       // '0.0.0.0:22', '*:80', ':::443'
  final int port;
  final String process;       // 'sshd', 'nginx', '' if unknown
  final UfwPortStatus ufwStatus;
  final int? ufwRuleNumber;   // rule number for `ufw delete N`

  PortEntry copyWith({UfwPortStatus? ufwStatus, int? ufwRuleNumber}) => PortEntry(
    proto: proto,
    address: address,
    port: port,
    process: process,
    ufwStatus: ufwStatus ?? this.ufwStatus,
    ufwRuleNumber: ufwRuleNumber ?? this.ufwRuleNumber,
  );
}

@immutable
class UfwRule {
  const UfwRule({
    required this.number,
    required this.to,
    required this.action,
    required this.from,
  });

  final int number;
  final String to;      // e.g. '22/tcp', '80/tcp', 'Nginx Full'
  final String action;  // 'ALLOW', 'DENY', 'LIMIT'
  final String from;    // 'Anywhere', specific IP
}

class FirewallState {
  const FirewallState({
    this.ports = const [],
    this.rules = const [],
    this.ufwAvailable = false,
    this.ufwEnabled = UfwEnabled.unknown,
    this.isLoading = true,
    this.errorMessage,
  });

  final List<PortEntry> ports;
  final List<UfwRule> rules;
  final bool ufwAvailable;
  final UfwEnabled ufwEnabled;
  final bool isLoading;
  final String? errorMessage;

  bool get isActive => ufwEnabled == UfwEnabled.active;

  FirewallState copyWith({
    List<PortEntry>? ports,
    List<UfwRule>? rules,
    bool? ufwAvailable,
    UfwEnabled? ufwEnabled,
    bool? isLoading,
    Object? errorMessage = _keep,
  }) => FirewallState(
    ports: ports ?? this.ports,
    rules: rules ?? this.rules,
    ufwAvailable: ufwAvailable ?? this.ufwAvailable,
    ufwEnabled: ufwEnabled ?? this.ufwEnabled,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: identical(errorMessage, _keep)
        ? this.errorMessage
        : errorMessage as String?,
  );

  static const Object _keep = Object();
}
