import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const gold = Color(0xFFC9A45C);
const cream = Color(0xFFF5EFE5);
const muted = Color(0xFF9D978E);
const card = Color(0xFF171615);

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark();
    return ThemeData(
        brightness: Brightness.dark,
        // خط Tajawal الرسمي للدار (نفس خط الموقع) عبر حزمة google_fonts.
        fontFamily: 'Tajawal',
        textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0B0B),
          foregroundColor: cream,
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: card,
          hintStyle: const TextStyle(color: muted),
          labelStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: gold),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: const Color(0xFF17130B),
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: const CardThemeData(
          color: card,
          elevation: 0,
        ),
        useMaterial3: true,
      );
  }
}
