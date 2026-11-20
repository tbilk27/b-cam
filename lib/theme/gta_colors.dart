import 'package:flutter/material.dart';

/// GTA VI / Vice City inspired color palette
class GtaColors {
  GtaColors._();

  // Primary Neon Accents
  static const Color neonPink = Color(0xFFFF2A85);
  static const Color hotPink = Color(0xFFFF007F);
  static const Color electricCyan = Color(0xFF00F0FF);
  static const Color neonPurple = Color(0xFF9D00FF);
  static const Color sunsetOrange = Color(0xFFFF6A00);
  static const Color sunsetYellow = Color(0xFFFFD200);

  // Background and Surfaces (Deep Cyber Night)
  static const Color bgDark = Color(0xFF090814);
  static const Color bgSurface = Color(0xFF121024);
  static const Color bgCard = Color(0xFF1B1834);
  static const Color bgCardHover = Color(0xFF242045);
  static const Color borderSubtle = Color(0xFF2C2754);
  static const Color borderGlow = Color(0x66FF2A85);

  // Status & Telemetry
  static const Color statusOnline = Color(0xFF00FFA3);
  static const Color statusConnecting = Color(0xFFFFB800);
  static const Color statusOffline = Color(0xFFFF3366);
  static const Color statusWarning = Color(0xFFFF7700);
  static const Color recRed = Color(0xFFFF0055);

  // Gradients
  static const LinearGradient viceSunsetGradient = LinearGradient(
    colors: [neonPink, sunsetOrange, sunsetYellow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonCyanPinkGradient = LinearGradient(
    colors: [electricCyan, neonPink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFF191632),
      Color(0xFF110F24),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient radarGradient = RadialGradient(
    colors: [
      Color(0x33FF2A85),
      Color(0x1000F0FF),
      Colors.transparent,
    ],
    radius: 0.85,
  );
}
