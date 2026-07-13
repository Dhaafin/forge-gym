import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0F0F12);
  static const Color surface = Color(0xFF18181C);
  static const Color primary = Color(0xFFCCFF00); // Volt / Lime Neon
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8F8F9B);
  static const Color cardBg = Color(0xFF1E1E24);
  static const Color error = Color(0xFFFF3B30);

  static ThemeData get darkTheme {
    // Base Poppins text theme seeded from dark color
    final poppinsBase = GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    );

    // Playfair Display headline styles
    final playfairHeadlineLarge = GoogleFonts.playfairDisplay(
      color: textPrimary,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    );

    final playfairHeadlineMedium = GoogleFonts.playfairDisplay(
      color: textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    );

    final playfairHeadlineSmall = GoogleFonts.playfairDisplay(
      color: textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );

    final playfairTitleLarge = GoogleFonts.playfairDisplay(
      color: textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );

    // Merged text theme: Poppins for body/label/display, Playfair for headlines/titles
    final textTheme = poppinsBase.copyWith(
      headlineLarge: playfairHeadlineLarge,
      headlineMedium: playfairHeadlineMedium,
      headlineSmall: playfairHeadlineSmall,
      titleLarge: playfairTitleLarge,
      bodyLarge: GoogleFonts.poppins(
        color: textPrimary,
        fontSize: 16,
      ),
      bodyMedium: GoogleFonts.poppins(
        color: textSecondary,
        fontSize: 14,
      ),
      bodySmall: GoogleFonts.poppins(
        color: textSecondary,
        fontSize: 12,
      ),
      labelLarge: GoogleFonts.poppins(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: primary,
        onPrimary: Colors.black,
        error: error,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surface),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
