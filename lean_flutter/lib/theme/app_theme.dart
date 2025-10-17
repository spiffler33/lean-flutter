import 'package:flutter/material.dart';

/// All 5 themes extracted EXACTLY from lean.css
/// Dark (default), Matrix, Paper, Midnight, Mono
enum LeanTheme {
  dark,
  matrix,
  paper,
  midnight,
  mono,
}

class AppTheme {
  // Dark Mode Colors (default theme)
  static const Color darkBackground = Color(0xFF111111);
  static const Color darkEntryBackground = Color(0xFF1A1A1A);
  static const Color darkInputBackground = Color(0xFF262626);
  static const Color darkBorderColor = Color(0xFF404040);
  static const Color darkTextPrimary = Color(0xFFE4E4E7);
  static const Color darkTextSecondary = Color(0xFF71717A);

  // Matrix Theme Colors (from lean.css lines 31-117)
  static const Color matrixBackground = Color(0xFF000000);
  static const Color matrixText = Color(0xFF00FF41);
  static const Color matrixCardBg = Color(0xFF0A0A0A);

  // Paper Theme Colors (from lean.css lines 119-203)
  static const Color paperBackground = Color(0xFFFAF8F1);
  static const Color paperText = Color(0xFF5C4B3A);
  static const Color paperCardBg = Color(0xFFFFFFFF);
  static const Color paperBorder = Color(0xFFD4C4B0);
  static const Color paperAccent = Color(0xFFA0896F);

  // Midnight Theme Colors (from lean.css lines 205-282)
  static const Color midnightBackground = Color(0xFF0F0F23);
  static const Color midnightText = Color(0xFFC9D1D9);
  static const Color midnightCardBg = Color(0xFF161B22);
  static const Color midnightBorder = Color(0xFF30363D);
  static const Color midnightAccent = Color(0xFF58A6FF);

  // Mono Theme Colors (from lean.css lines 283-366)
  static const Color monoBackground = Color(0xFFFFFFFF);
  static const Color monoText = Color(0xFF000000);
  static const Color monoCardBg = Color(0xFFFFFFFF);

  // AI Badge Colors (dark mode)
  static const Color badgeMoodBg = Color.fromRGBO(16, 185, 129, 0.2);
  static const Color badgeMoodText = Color(0xFF34D399);
  static const Color badgeMoodBorder = Color.fromRGBO(16, 185, 129, 0.3);

  static const Color badgeThemeBg = Color.fromRGBO(59, 130, 246, 0.2);
  static const Color badgeThemeText = Color(0xFF60A5FA);
  static const Color badgeThemeBorder = Color.fromRGBO(59, 130, 246, 0.3);

  static const Color badgePeopleBg = Color.fromRGBO(245, 158, 11, 0.2);
  static const Color badgePeopleText = Color(0xFFFBBF24);
  static const Color badgePeopleBorder = Color.fromRGBO(245, 158, 11, 0.3);

  static const Color badgeUrgencyLowBg = Color.fromRGBO(156, 163, 175, 0.2);
  static const Color badgeUrgencyLowText = Color(0xFFD1D5DB);
  static const Color badgeUrgencyLowBorder = Color.fromRGBO(156, 163, 175, 0.3);

  static const Color badgeUrgencyMediumBg = Color.fromRGBO(251, 191, 36, 0.2);
  static const Color badgeUrgencyMediumText = Color(0xFFFCD34D);
  static const Color badgeUrgencyMediumBorder = Color.fromRGBO(251, 191, 36, 0.3);

  static const Color badgeUrgencyHighBg = Color.fromRGBO(239, 68, 68, 0.2);
  static const Color badgeUrgencyHighText = Color(0xFFF87171);
  static const Color badgeUrgencyHighBorder = Color.fromRGBO(239, 68, 68, 0.3);

  // Primary accent
  static const Color accentGreen = Color(0xFF4CAF50);

  /// Get theme by enum
  static ThemeData getTheme(LeanTheme theme) {
    switch (theme) {
      case LeanTheme.dark:
        return darkTheme();
      case LeanTheme.matrix:
        return matrixTheme();
      case LeanTheme.paper:
        return paperTheme();
      case LeanTheme.midnight:
        return midnightTheme();
      case LeanTheme.mono:
        return monoTheme();
    }
  }

  /// DARK THEME (default)
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
      cardTheme: const CardThemeData(
        color: darkEntryBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        margin: EdgeInsets.zero,
      ),
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
    );
  }

  /// MATRIX THEME
  static ThemeData matrixTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'SF Mono, Monaco, Cascadia Code, Roboto Mono, monospace',
      scaffoldBackgroundColor: matrixBackground,
      colorScheme: const ColorScheme.dark(
        primary: matrixText,
        secondary: matrixText,
        surface: matrixCardBg,
        background: matrixBackground,
      ),
      cardTheme: CardThemeData(
        color: matrixCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: matrixText.withOpacity(0.2), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 16,
          color: matrixText,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: matrixText,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: matrixText,
        ),
      ),
    );
  }

  /// PAPER THEME
  static ThemeData paperTheme() {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Charter, Georgia, Cambria, Times New Roman, serif',
      scaffoldBackgroundColor: paperBackground,
      colorScheme: const ColorScheme.light(
        primary: paperAccent,
        secondary: paperText,
        surface: paperCardBg,
        background: paperBackground,
      ),
      cardTheme: CardThemeData(
        color: paperCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        shadowColor: paperText.withOpacity(0.1),
        margin: EdgeInsets.zero,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 16,
          color: paperText,
          height: 1.7,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: paperText,
          height: 1.7,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: Color(0xFF998675),
        ),
      ),
    );
  }

  /// MIDNIGHT THEME
  static ThemeData midnightTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: '-apple-system, BlinkMacSystemFont, SF Pro Text',
      scaffoldBackgroundColor: midnightBackground,
      colorScheme: const ColorScheme.dark(
        primary: midnightAccent,
        secondary: Color(0xFF8B949E),
        surface: midnightCardBg,
        background: midnightBackground,
      ),
      cardTheme: CardThemeData(
        color: midnightCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 16,
          color: midnightText,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: midnightText,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: Color(0xFF8B949E),
        ),
      ),
    );
  }

  /// MONO THEME
  static ThemeData monoTheme() {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: '-apple-system, BlinkMacSystemFont, SF Pro Text',
      scaffoldBackgroundColor: monoBackground,
      colorScheme: const ColorScheme.light(
        primary: monoText,
        secondary: monoText,
        surface: monoCardBg,
        background: monoBackground,
      ),
      cardTheme: CardThemeData(
        color: monoCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: const BorderSide(color: monoText, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 16,
          color: monoText,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: monoText,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: monoText,
        ),
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
