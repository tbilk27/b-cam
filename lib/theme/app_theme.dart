import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'gta_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GtaColors.bgDark,
      primaryColor: GtaColors.neonPink,
      colorScheme: const ColorScheme.dark(
        primary: GtaColors.neonPink,
        secondary: GtaColors.electricCyan,
        surface: GtaColors.bgSurface,
        onSurface: Colors.white,
        error: GtaColors.statusOffline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: GtaColors.bgDark.withOpacity(0.9),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
        iconTheme: const IconThemeData(color: GtaColors.neonPink),
      ),
      cardTheme: CardThemeData(
        color: GtaColors.bgCard,
        elevation: 4,
        shadowColor: GtaColors.neonPink.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GtaColors.borderSubtle, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GtaColors.bgSurface,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
        prefixIconColor: GtaColors.neonPink,
        suffixIconColor: GtaColors.electricCyan,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GtaColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GtaColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GtaColors.neonPink, width: 2),
        ),
      ),
      textTheme: textTheme.apply(
        bodyColor: Colors.white.withOpacity(0.9),
        displayColor: Colors.white,
      ),
    );
  }
}
