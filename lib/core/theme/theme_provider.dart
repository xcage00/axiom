import 'package:flutter/material.dart';
import 'colors.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // Light Theme
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AxiomColors.accent,
      scaffoldBackgroundColor: AxiomColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AxiomColors.accent,
        secondary: AxiomColors.accentLight,
        surface: AxiomColors.lightSurface,
        background: AxiomColors.lightBackground,
        error: AxiomColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AxiomColors.lightBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AxiomColors.lightText,
        ),
        iconTheme: IconThemeData(color: AxiomColors.lightText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AxiomColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AxiomColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      useMaterial3: true,
    );
  }

  // Dark Theme
  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AxiomColors.accent,
      scaffoldBackgroundColor: AxiomColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AxiomColors.accent,
        secondary: AxiomColors.accentLight,
        surface: AxiomColors.darkSurface,
         background: AxiomColors.darkBackground,
        error: AxiomColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AxiomColors.darkBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AxiomColors.darkText,
        ),
        iconTheme: IconThemeData(color: AxiomColors.darkText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AxiomColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AxiomColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      useMaterial3: true,
    );
  }
}