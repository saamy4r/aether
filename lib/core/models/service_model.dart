import 'package:flutter/foundation.dart';

enum ServiceActiveState { active, inactive, activating, deactivating, failed, unknown }

enum ServiceSubState { running, dead, exited, waiting, stop, failed, unknown }

@immutable
class ServiceModel {
  const ServiceModel({
    required this.name,
    required this.loadState,
    required this.activeState,
    required this.subState,
    required this.description,
  });

  final String name;
  final String loadState;
  final ServiceActiveState activeState;
  final ServiceSubState subState;
  final String description;

  bool get isRunning => activeState == ServiceActiveState.active && subState == ServiceSubState.running;
  bool get isFailed  => activeState == ServiceActiveState.failed;
  bool get isInactive => activeState == ServiceActiveState.inactive;
}

@immutable
class ServiceState {
  const ServiceState({
    this.services = const [],
    this.isAvailable = true,
    this.isLoading = true,
    this.errorMessage,
  });

  final List<ServiceModel> services;
  final bool isAvailable;
  final bool isLoading;
  final String? errorMessage;

  static const Object _keep = Object();

  ServiceState copyWith({
    List<ServiceModel>? services,
    bool? isAvailable,
    bool? isLoading,
    Object? errorMessage = _keep,
  }) => ServiceState(
    services:     services     ?? this.services,
    isAvailable:  isAvailable  ?? this.isAvailable,
    isLoading:    isLoading    ?? this.isLoading,
    errorMessage: identical(errorMessage, _keep)
        ? this.errorMessage
        : errorMessage as String?,
  );
}
