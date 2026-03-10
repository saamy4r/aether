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

  factory VpsModel.fromJson(Map<String, dynamic> json) => VpsModel(
    id: json['id'] as String,
    label: json['label'] as String,
    host: json['host'] as String,
    port: json['port'] as int,
    username: json['username'] as String,
    authMethod: AuthMethod.values.byName(json['authMethod'] as String),
    iconX: (json['iconX'] as num?)?.toDouble(),
    iconY: (json['iconY'] as num?)?.toDouble(),
  );
}
