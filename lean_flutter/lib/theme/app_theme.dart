import 'package:flutter/material.dart';

/// Exact theme from original PWA
/// Extracted from lean.css (lines 754-985)
class AppTheme {
  // Dark Mode Colors (from @media prefers-color-scheme: dark)
  static const Color darkBackground = Color(0xFF111111);
  static const Color darkEntryBackground = Color(0xFF1A1A1A);
  static const Color darkInputBackground = Color(0xFF262626);
  static const Color darkBorderColor = Color(0xFF404040);
  static const Color darkTextPrimary = Color(0xFFE4E4E7);
  static const Color darkTextSecondary = Color(0xFF71717A);

  // AI Badge Colors (from lines 942-984)
  // Mood/Emotion (green)
  static const Color badgeMoodBg = Color.fromRGBO(16, 185, 129, 0.2);
  static const Color badgeMoodText = Color(0xFF34D399);
  static const Color badgeMoodBorder = Color.fromRGBO(16, 185, 129, 0.3);

  // Theme (blue)
  static const Color badgeThemeBg = Color.fromRGBO(59, 130, 246, 0.2);
  static const Color badgeThemeText = Color(0xFF60A5FA);
  static const Color badgeThemeBorder = Color.fromRGBO(59, 130, 246, 0.3);

  // People (orange)
  static const Color badgePeopleBg = Color.fromRGBO(245, 158, 11, 0.2);
  static const Color badgePeopleText = Color(0xFFFBBF24);
  static const Color badgePeopleBorder = Color.fromRGBO(245, 158, 11, 0.3);

  // Urgency Low (gray)
  static const Color badgeUrgencyLowBg = Color.fromRGBO(156, 163, 175, 0.2);
  static const Color badgeUrgencyLowText = Color(0xFFD1D5DB);
  static const Color badgeUrgencyLowBorder = Color.fromRGBO(156, 163, 175, 0.3);

  // Urgency Medium (yellow)
  static const Color badgeUrgencyMediumBg = Color.fromRGBO(251, 191, 36, 0.2);
  static const Color badgeUrgencyMediumText = Color(0xFFFCD34D);
  static const Color badgeUrgencyMediumBorder = Color.fromRGBO(251, 191, 36, 0.3);

  // Urgency High (red)
  static const Color badgeUrgencyHighBg = Color.fromRGBO(239, 68, 68, 0.2);
  static const Color badgeUrgencyHighText = Color(0xFFF87171);
  static const Color badgeUrgencyHighBorder = Color.fromRGBO(239, 68, 68, 0.3);

  // Primary accent (green)
  static const Color accentGreen = Color(0xFF4CAF50);

  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: '-apple-system, BlinkMacSystemFont, SF Pro Text',
      scaffoldBackgroundColor: darkBackground,

      colorScheme: const ColorScheme.dark(
        primary: accentGreen,
        secondary: darkTextSecondary,
        surface: darkEntryBackground,
        background: darkBackground,
      ),

      // Card theme for entries
      cardTheme: const CardThemeData(
        color: darkEntryBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        margin: EdgeInsets.zero,
      ),

      // Text theme
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 16,
          color: darkTextPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: darkTextPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: darkTextSecondary,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputBackground,
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: darkBorderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: darkBorderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: accentGreen, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

/// Widget for AI enrichment badges (pill-shaped)
class AiBadge extends StatelessWidget {
  final String label;
  final AiBadgeType type;

  const AiBadge({super.key, required this.label, required this.type});

  @override
  Widget build(BuildContext context) {
    Color bgColor, textColor, borderColor;

    switch (type) {
      case AiBadgeType.mood:
        bgColor = AppTheme.badgeMoodBg;
        textColor = AppTheme.badgeMoodText;
        borderColor = AppTheme.badgeMoodBorder;
        break;
      case AiBadgeType.theme:
        bgColor = AppTheme.badgeThemeBg;
        textColor = AppTheme.badgeThemeText;
        borderColor = AppTheme.badgeThemeBorder;
        break;
      case AiBadgeType.people:
        bgColor = AppTheme.badgePeopleBg;
        textColor = AppTheme.badgePeopleText;
        borderColor = AppTheme.badgePeopleBorder;
        break;
      case AiBadgeType.urgencyLow:
        bgColor = AppTheme.badgeUrgencyLowBg;
        textColor = AppTheme.badgeUrgencyLowText;
        borderColor = AppTheme.badgeUrgencyLowBorder;
        break;
      case AiBadgeType.urgencyMedium:
        bgColor = AppTheme.badgeUrgencyMediumBg;
        textColor = AppTheme.badgeUrgencyMediumText;
        borderColor = AppTheme.badgeUrgencyMediumBorder;
        break;
      case AiBadgeType.urgencyHigh:
        bgColor = AppTheme.badgeUrgencyHighBg;
        textColor = AppTheme.badgeUrgencyHighText;
        borderColor = AppTheme.badgeUrgencyHighBorder;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12), // Pill shape
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

enum AiBadgeType {
  mood,
  theme,
  people,
  urgencyLow,
  urgencyMedium,
  urgencyHigh,
}
