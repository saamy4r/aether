import 'package:flutter/material.dart';

abstract final class AetherColors {
  static const Color background   = Color(0xFF1B2333);
  static const Color surfaceDeep  = Color(0xFF232D3F);

  static const Color accent       = Color(0xFF3DAEE9);
  static const Color accentTeal   = Color(0xFF1ABC9C);
  static const Color accentGreen  = Color(0xFF27AE60);
  static const Color accentRed    = Color(0xFFE74C3C);
  static const Color accentYellow = Color(0xFFF39C12);

  static const Color glassBase    = Color(0x14FFFFFF);
  static const Color glassBorder  = Color(0x33FFFFFF);
  static const Color glassHover   = Color(0x1FFFFFFF);
  static const Color taskbarBase  = Color(0xCC0D1B2A);
  static const Color titleBarBase = Color(0x26000000);

  static const Color textPrimary   = Color(0xFFEFF0F1);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textAccent    = Color(0xFF3DAEE9);
}

abstract final class AetherGlass {
  static const double windowBlur    = 24.0;
  static const double taskbarBlur   = 20.0;
  static const double startMenuBlur = 28.0;
  static const double lockBlur      = 40.0;

  static const double windowRadius    = 12.0;
  static const double startMenuRadius = 16.0;
  static const double buttonRadius    = 8.0;
  static const double taskbarRadius   = 0.0;

  static const double borderWidth = 1.0;
}
