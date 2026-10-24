import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6E61E4);
  static const Color primaryLight = Color(0xFFB3AAFF);
  static const Color primaryDark = Color(0xFF4D42B9);

  static const Color secondary = Color(0xFF3BC8B4);
  static const Color secondaryLight = Color(0xFF7BE0D1);
  static const Color secondaryDark = Color(0xFF228E82);

  static const Color accent = secondary;
  static const Color accentLight = secondaryLight;
  static const Color accentDark = secondaryDark;

  static const Color background = Color(0xFF0C1018);
  static const Color surface = Color(0xFF151B26);
  static const Color surfaceLight = Color(0xFF202838);
  static const Color outline = Color(0xFF303A4B);

  static const Color lightBackground = Color(0xFFF5F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF171C27);
  static const Color lightTextSecondary = Color(0xFF626B7A);

  static const Color darkBackground = background;
  static const Color darkSurface = surface;
  static const Color darkText = Color(0xFFF4F5FA);
  static const Color darkTextSecondary = Color(0xFFA4ADBC);

  static const Color textPrimary = darkText;
  static const Color textSecondary = darkTextSecondary;
  static const Color textTertiary = Color(0xFF687386);

  static const Color success = Color(0xFF43C99A);
  static const Color error = Color(0xFFE76F79);
  static const Color warning = Color(0xFFE7B860);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, primary],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primaryLight],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, Color(0xFF0A0A14)],
  );
}
