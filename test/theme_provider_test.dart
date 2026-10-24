import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:axiom/core/theme/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts in dark mode and supports switching to light mode', () async {
    final themeProvider = ThemeProvider();

    expect(themeProvider.themeMode, ThemeMode.dark);

    await themeProvider.setDarkMode(false);

    expect(themeProvider.themeMode, ThemeMode.light);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('axiom.theme.dark'), isFalse);
    themeProvider.dispose();
  });

  test('restores the saved light theme', () async {
    SharedPreferences.setMockInitialValues({'axiom.theme.dark': false});
    final themeProvider = ThemeProvider();

    await Future<void>.delayed(Duration.zero);

    expect(themeProvider.themeMode, ThemeMode.light);
    themeProvider.dispose();
  });
}
