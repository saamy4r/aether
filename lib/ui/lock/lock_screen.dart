import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';

class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: AetherGlass.lockBlur,
        sigmaY: AetherGlass.lockBlur,
      ),
      child: Container(
        color: AetherColors.background.withOpacity(0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock,
                  size: 48, color: AetherColors.textSecondary),
              const SizedBox(height: 16),
              const Text('Aether is locked',
                  style: TextStyle(
                      color: AetherColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w300)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).unlock(),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AetherColors.accent,
                  foregroundColor: AetherColors.background,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
