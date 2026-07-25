import 'package:flutter/foundation.dart';

enum AuthMethod { key, password }

@immutable
class VpsModel {
  const VpsModel({
    required this.id,
    required this.label,
    required this.host,
    required this.port,
    required this.username,
    required this.authMethod,
    this.iconX,
    this.iconY,
  });

  final String id;
  final String label;
  final String host;
  final int port;
  final String username;
  final AuthMethod authMethod;
  final double? iconX;
  final double? iconY;

  VpsModel copyWith({
    String? label,
    String? host,
    int? port,
    String? username,
    AuthMethod? authMethod,
    double? iconX,
    double? iconY,
  }) => VpsModel(
    id: id,
    label: label ?? this.label,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    authMethod: authMethod ?? this.authMethod,
    iconX: iconX ?? this.iconX,
    iconY: iconY ?? this.iconY,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'host': host,
    'port': port,
    'username': username,
    'authMethod': authMethod.name,
    'iconX': iconX,
    'iconY': iconY,
  };

  /// Tolerant of malformed stored JSON so one corrupt entry can't crash the
  /// whole list load. An entry with no usable id should be discarded by the
  /// caller.
  factory VpsModel.fromJson(Map<String, dynamic> json) => VpsModel(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    host: json['host']?.toString() ?? '',
    port: switch (json['port']) {
      final int p => p,
      final String s => int.tryParse(s) ?? 22,
      _ => 22,
    },
    username: json['username']?.toString() ?? '',
    authMethod: AuthMethod.values.asNameMap()[json['authMethod']] ??
        AuthMethod.key,
    iconX: (json['iconX'] as num?)?.toDouble(),
    iconY: (json['iconY'] as num?)?.toDouble(),
  );
}
