import 'package:flutter/material.dart';

/// Duolingo Dark Mode Color System
/// Authentic color palette inspired by Duolingo's dark design language,
/// featuring deep slate midnight backgrounds, chunky borders, and vibrant playful accents.
class AppColors {
  // Background & Surfaces (Midnight Slate)
  static const Color background = Color(0xFF131F24); // Deep dark background
  static const Color surface = Color(0xFF202F36); // Duolingo dark card surface
  static const Color surfaceVariant = Color(
    0xFF18252D,
  ); // Darker inner surface / chips
  static const Color surfaceElevated = Color(
    0xFF2B3D47,
  ); // Lighter elevated interactive surface
  static const Color border = Color(0xFF2B3D47); // 2px border slate
  static const Color borderDark = Color(0xFF182228); // 3D bottom bevel / shadow

  // Typography (Cairo Dark Mode)
  static const Color textPrimary = Color(
    0xFFFFFFFF,
  ); // Pure white for crisp contrast
  static const Color textSecondary = Color(
    0xFF8B9EAA,
  ); // Slate blue/grey secondary
  static const Color textMuted = Color(
    0xFF5B6E7A,
  ); // Darker slate muted / placeholders

  // Duolingo Signature Green (Primary - Feather / Duo Green)
  static const Color primary = Color(0xFF58CC02); // Iconic Duo Green
  static const Color primaryDark = Color(
    0xFF58A700,
  ); // 3D bottom bevel (darker shade)
  static const Color primaryLight = Color(0xFF7BE127); // Highlight green

  // Duolingo Signature Blue (Secondary - Sky Blue)
  static const Color secondary = Color(0xFF1CB0F6); // Duo Sky Blue
  static const Color secondaryDark = Color(0xFF1899D6); // 3D bottom bevel
  static const Color secondaryLight = Color(0xFF40C4FF); // Sky highlight

  // Duolingo Signature Purple / Amethyst (Accent - Gem / Crown)
  static const Color accent = Color(0xFFCE82FF); // Duo Gem Amethyst
  static const Color accentDark = Color(0xFFA560DB); // 3D bottom bevel
  static const Color accentLight = Color(0xFFE2B2FF); // Gem highlight

  // Duolingo Gold / XP / Crowns (Warning)
  static const Color warning = Color(0xFFFFC800); // Duo Golden Crown / Star
  static const Color warningDark = Color(0xFFE5A500); // 3D bottom bevel
  static const Color warningLight = Color(0xFF332910); // Dark badge container

  // Duolingo Streak Flame (Orange)
  static const Color orange = Color(0xFFFF9600); // Duo Streak Flame
  static const Color orangeDark = Color(0xFFE58600); // 3D bottom bevel
  static const Color orangeLight = Color(0xFF382512); // Dark badge container

  // Duolingo Heart Red (Error / Absent / Minus)
  static const Color error = Color(0xFFFF4B4B); // Duo Heart Red
  static const Color errorDark = Color(0xFFEA2B2B); // 3D bottom bevel
  static const Color errorLight = Color(0xFF371B1E); // Dark badge container

  // Status & Badges
  static const Color success = Color(0xFF58CC02);
  static const Color successLight = Color(0xFF16331C); // Dark badge container
  static const Color info = Color(0xFF1CB0F6);
  static const Color infoLight = Color(0xFF132B3A); // Dark badge container

  // Gamification & Evaluations
  static const Color bonus = Color(0xFFFFC800); // Gold bonus
  static const Color minus = Color(0xFFFF4B4B); // Red minus

  // Attendance Badges
  static const Color present = Color(0xFF58CC02); // Green present
  static const Color absent = Color(0xFFFF4B4B); // Red absent
  static const Color late = Color(0xFFFF9600); // Orange late
}
