import 'package:flutter/material.dart';

abstract final class CallColors {
  static const background = Color(0xFF111827);
  static const surface = Color(0xFF1F2937);
  static const onBackground = Color(0xFFF9FAFB);
  static const muted = Color(0xFF9CA3AF);
  static const accent = Color(0xFF34D399);
  static const danger = Color(0xFFEF4444);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CallColors.accent,
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
