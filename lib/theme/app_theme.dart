import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CruizrTheme {
  // ActivePulse Color Palette
  static const Color background = Color(0xFFFDF6F5); // Light Pink Background
  static const Color surface = Color(0xFFF5EBE9); // Peach/Beige for inputs
  static const Color primaryDark = Color(0xFF4A3438); // Dark Brown (Text/Buttons)
  static const Color accentPink = Color(0xFFD97D84); // Accent Pink/Red
  static const Color textPrimary = Color(0xFF4A3438); // Dark Brown
  static const Color textSecondary = Color(0xFF8D7B7D); // Muted Brown/Grey
  static const Color border = Color(0xFFE0D4D4); // Light Border

  // Keep compatibility aliases if needed, or refactor usages
  static const Color primaryMint = primaryDark; // Alias for backward compatibility
  
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        surface: surface,
        primary: primaryDark,
        secondary: accentPink,
        onSurface: textPrimary,
        outline: border,
      ),
      textTheme: TextTheme(
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontStyle: FontStyle.italic,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.lato(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.lato(
          color: textSecondary.withOpacity(0.7),
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.lato(
          color: textSecondary,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryDark, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          side: BorderSide.none,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
