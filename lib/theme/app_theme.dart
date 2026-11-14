import 'package:flutter/material.dart';

const gold = Color(0xFFC9A45C);
const cream = Color(0xFFF5EFE5);
const muted = Color(0xFFAAA19A);
const card = Color(0xFF171315);
const burgundy = Color(0xFF541B2A);
const ink = Color(0xFF090809);
const borderGold = Color(0xFF493925);

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
    ).copyWith(
      primary: gold,
      onPrimary: ink,
      secondary: burgundy,
      onSecondary: cream,
      surface: card,
      onSurface: cream,
      outline: borderGold,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        foregroundColor: cream,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: ink,
          disabledBackgroundColor: const Color(0xFF39332A),
          disabledForegroundColor: muted,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: borderGold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGold),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGold),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: const TextStyle(color: cream),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: borderGold.withOpacity(.55),
    );
  }
}
