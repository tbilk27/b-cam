import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class BCamTheme {
  // Sober, executive dark surveillance palette (Windows 11 Fluent 2 style)
  static const Color darkBackground = Color(0xFF1B1B1F);
  static const Color darkSurface = Color(0xFF242429);
  static const Color darkCard = Color(0xFF2B2B32);
  static const Color darkCardElevated = Color(0xFF32323A);
  static const Color darkBorder = Color(0xFF3E3E47);
  static const Color darkBorderSubtle = Color(0xFF303038);

  // Sober Accent Colors
  static const Color accentBlue = Color(0xFF0078D4);
  static const Color accentLightBlue = Color(0xFF4CC2FF);
  static const Color accentTeal = Color(0xFF008272);
  static const Color textPrimary = Color(0xFFF3F3F3);
  static const Color textSecondary = Color(0xFFA1A1A6);
  static const Color textTertiary = Color(0xFF71717A);

  // Status Colors (Subdued, executive)
  static const Color statusOnline = Color(0xFF107C41);
  static const Color statusOnlineGlow = Color(0xFF28A745);
  static const Color statusOffline = Color(0xFFD83B01);
  static const Color statusWarning = Color(0xFFFFB900);

  /// Brand colors for camera manufacturers in sober surveillance styling
  static const Color intelbrasBrand = Color(0xFF0E7036);
  static const Color yooseeBrand = Color(0xFF0078D4);
  static const Color hikvisionBrand = Color(0xFFB3261E);
  static const Color tapoBrand = Color(0xFF0288D1);
  static const Color genericBrand = Color(0xFF5C6BC0);

  /// Builds the dark FluentThemeData
  static FluentThemeData darkTheme() {
    return FluentThemeData(
      brightness: Brightness.dark,
      accentColor: Colors.blue,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      typography: Typography.raw(
        titleLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        title: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        subtitle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        body: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        caption: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: textTertiary,
        ),
      ),
    );
  }
}
