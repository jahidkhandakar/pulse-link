import 'package:flutter/material.dart';

class AppThemeMode {
  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static void toggle() {
    final current = mode.value;
    if (current == ThemeMode.dark) {
      mode.value = ThemeMode.light;
    } else {
      mode.value = ThemeMode.dark;
    }
  }

  static void setSystem() => mode.value = ThemeMode.system;
}
