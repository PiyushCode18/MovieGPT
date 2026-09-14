import 'package:flutter/material.dart';

/// Central design system for the MovieGPT app.
/// Colors, gradients and typography are derived from the design screens.
class AppTheme {
  // Color Tokens
  static const Color bgDark = Color(0xFF0D0D0D);
  static const Color cardDark = Color(0xFF131313);
  static const Color cardLow = Color(0xFF1C1B1B);
  static const Color cardMid = Color(0xFF201F1F);
  static const Color cardBorder = Color(0xFF2A2A2A);

  static const Color primaryRed = Color(0xFFE50914);
  static const Color primaryViolet = Color(0xFF8B5CF6);
  static const Color primaryPink = Color(0xFFD946EF);
  static const Color aiPurple = Color(0xFF7701D0);
  static const Color aiAzure = Color(0xFF426AE2);
  static const Color neonCyan = Color(0xFF06B6D4);
  static const Color goldAccent = Color(0xFFF59E0B);

  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Linear Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRed, aiPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aiGradient = LinearGradient(
    colors: [aiPurple, aiAzure],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Color(0x66131313), Color(0xFF0D0D0D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get darkTheme {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
    );
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: aiPurple,
        tertiary: aiAzure,
        surface: cardDark,
        onSurface: textPrimary,
      ),
      primaryColor: primaryRed,
      scaffoldBackgroundColor: bgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: primaryRed,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}

