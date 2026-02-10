import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color creamBackground = Color(0xFFF5F5F0);
  static const Color darkText = Color(0xFF1A1A1A);
  static const Color gridLine = Color(0xFFEAEAEA); // Very subtle
  static const Color foodOrange = Color(0xFFFF4500);
  static const Color snakeskin = Color(0xFF1A1A1A); // Dark squares
  static const Color containerBorder = Color(0xFFE0E0E0);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creamBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkText,
        background: creamBackground,
        surface: creamBackground,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceMono(
          fontSize: 60,
          fontWeight: FontWeight.bold,
          color: darkText,
          height: 1.0,
        ),
        labelSmall: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: darkText.withOpacity(0.4),
        ),
        bodyMedium: GoogleFonts.spaceMono(
          color: darkText,
          fontSize: 14,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
          color: darkText.withOpacity(0.6),
        ),
      ),
    );
  }
}
