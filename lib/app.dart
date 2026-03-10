import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/colors.dart';
import 'providers/auth_provider.dart';
import 'ui/desktop/desktop_screen.dart';

class AetherApp extends ConsumerStatefulWidget {
  const AetherApp({super.key});

  @override
  ConsumerState<AetherApp> createState() => _AetherAppState();
}

class _AetherAppState extends ConsumerState<AetherApp>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;
  static const _lockAfter = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null &&
          DateTime.now().difference(_pausedAt!) >= _lockAfter) {
        ref.read(authProvider.notifier).lock();
      }
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aether',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const DesktopScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AetherColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AetherColors.accent,
        secondary: AetherColors.accentTeal,
        surface: AetherColors.surfaceDeep,
        error: AetherColors.accentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AetherColors.surfaceDeep,
        foregroundColor: AetherColors.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AetherColors.textPrimary),
        bodySmall: TextStyle(color: AetherColors.textSecondary),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AetherColors.glassBase,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AetherColors.accent,
          foregroundColor: AetherColors.background,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AetherColors.accent),
      ),
      dividerColor: AetherColors.glassBorder,
      iconTheme: const IconThemeData(color: AetherColors.textSecondary),
    );
  }
}
