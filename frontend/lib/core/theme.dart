import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryGold = Color(0xFFFFD700);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color darkBackground = Color(0xFF0A0E14);
  static const Color cardGrey = Color(0xFF1C1F26);
  static const Color textWhite = Color(0xFFF5F5F5);
  static const Color textDim = Color(0xFFA0A0A0);
  static const Color errorRed = Color(0xFFFF5252);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryGold,
    scaffoldBackgroundColor: darkBackground,
    cardColor: cardGrey,
    textTheme: GoogleFonts.outfitTextTheme(
      const TextTheme(
        headlineLarge: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 32),
        headlineMedium: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 24),
        bodyLarge: TextStyle(color: textWhite, fontSize: 16),
        bodyMedium: TextStyle(color: textDim, fontSize: 14),
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryGold,
      secondary: accentCyan,
      surface: darkBackground,
      onSurface: textWhite,
      error: errorRed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGold,
        foregroundColor: darkBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  );
}
