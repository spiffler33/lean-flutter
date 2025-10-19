import 'package:flutter/material.dart';

/// EXACT theme colors from PWA lean.css
/// These are the EXACT hex values from the CSS file
class ThemeColors {
  // Background colors
  final Color background;
  // Input container background
  final Color inputContainer;
  // Input field background
  final Color inputBackground;
  // Input border color
  final Color inputBorder;
  // Entry/card background
  final Color entryBackground;
  // Entry border color (for some themes)
  final Color entryBorder;
  // Primary text color
  final Color textPrimary;
  // Secondary/meta text color
  final Color textSecondary;
  // Tag color
  final Color tagColor;
  // Accent color (green, blue, etc based on theme)
  final Color accent;
  // Logo color
  final Color logoColor;
  // Border radius (0 for mono, 8-12 for others)
  final double borderRadius;
  // Border width (2 for mono, 1 for others)
  final double borderWidth;
  // Focus shadow color
  final Color focusShadow;
  // Modal background
  final Color modalBackground;
  // Todo checkbox color
  final Color todoCheckbox;
  // Time divider color
  final Color timeDivider;

  const ThemeColors({
    required this.background,
    required this.inputContainer,
    required this.inputBackground,
    required this.inputBorder,
    required this.entryBackground,
    required this.entryBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.tagColor,
    required this.accent,
    required this.logoColor,
    required this.borderRadius,
    required this.borderWidth,
    required this.focusShadow,
    required this.modalBackground,
    required this.todoCheckbox,
    required this.timeDivider,
  });
}

/// EXACT theme definitions from PWA
class LeanThemes {
  /// Theme: Minimal (default) - matches PWA default styles
  static const ThemeColors minimal = ThemeColors(
    background: Color(0xFF111111), // #111
    inputContainer: Color(0xFF1A1A1A), // #1a1a1a
    inputBackground: Color(0xFF262626), // #262626
    inputBorder: Color(0xFF404040), // #404040
    entryBackground: Color(0xFF1A1A1A), // #1a1a1a
    entryBorder: Color(0xFF2A2A2A), // slight border
    textPrimary: Color(0xFFE4E4E7), // #e4e4e7
    textSecondary: Color(0xFF71717A), // #71717a
    tagColor: Color(0xFF4CAF50), // #4caf50
    accent: Color(0xFF4CAF50), // #4caf50
    logoColor: Color(0xFF4CAF50), // #4caf50
    borderRadius: 8.0,
    borderWidth: 1.0,
    focusShadow: Color(0x334CAF50), // rgba(76, 175, 80, 0.2)
    modalBackground: Color(0xFF1A1A1A),
    todoCheckbox: Color(0xFF4CAF50),
    timeDivider: Color(0xFF71717A),
  );

  /// Theme: Matrix - green phosphor terminal
  static const ThemeColors matrix = ThemeColors(
    background: Color(0xFF000000), // #000000
    inputContainer: Color(0xFF0A0A0A), // #0a0a0a
    inputBackground: Color(0xFF000000), // #000
    inputBorder: Color(0xFF00FF41), // #00ff41
    entryBackground: Color(0xFF0A0A0A), // #0a0a0a
    entryBorder: Color(0x3300FF41), // #00ff4133
    textPrimary: Color(0xFF00FF41), // #00ff41
    textSecondary: Color(0xFF00FF41), // #00ff41
    tagColor: Color(0xFF00FFAA), // #00ffaa
    accent: Color(0xFF00FF41), // #00ff41
    logoColor: Color(0xFF00FF41), // #00ff41
    borderRadius: 8.0,
    borderWidth: 1.0,
    focusShadow: Color(0x3300FF41), // rgba(0, 255, 65, 0.2)
    modalBackground: Color(0xFF0A0A0A),
    todoCheckbox: Color(0xFF00FF41),
    timeDivider: Color(0xFF00FF41),
  );

  /// Theme: Paper - warm paper-like colors
  static const ThemeColors paper = ThemeColors(
    background: Color(0xFFFAF8F1), // #faf8f1
    inputContainer: Color(0xFFFFFFFF), // #ffffff
    inputBackground: Color(0xFFFFFFFF), // #ffffff
    inputBorder: Color(0xFFD4C4B0), // #d4c4b0
    entryBackground: Color(0xFFFFFFFF), // #ffffff
    entryBorder: Color(0xFFE8DDD2), // slight border
    textPrimary: Color(0xFF5C4B3A), // #5c4b3a
    textSecondary: Color(0xFF998675), // #998675
    tagColor: Color(0xFF7A6150), // #7a6150
    accent: Color(0xFF8B7355), // #8b7355
    logoColor: Color(0xFF8B7355), // #8b7355
    borderRadius: 8.0,
    borderWidth: 1.0,
    focusShadow: Color(0x1AA0896F), // rgba(160, 137, 111, 0.1)
    modalBackground: Color(0xFFFFFFFF),
    todoCheckbox: Color(0xFF8B7355),
    timeDivider: Color(0xFFA0896F),
  );

  /// Theme: Midnight - deep blues and purples
  static const ThemeColors midnight = ThemeColors(
    background: Color(0xFF0F0F23), // #0f0f23
    inputContainer: Color(0xFF161B22), // #161b22
    inputBackground: Color(0xFF0D1117), // #0d1117
    inputBorder: Color(0xFF30363D), // #30363d
    entryBackground: Color(0xFF161B22), // #161b22
    entryBorder: Color(0xFF21262D), // slight border
    textPrimary: Color(0xFFC9D1D9), // #c9d1d9
    textSecondary: Color(0xFF8B949E), // #8b949e
    tagColor: Color(0xFF79C0FF), // #79c0ff
    accent: Color(0xFF58A6FF), // #58a6ff
    logoColor: Color(0xFF58A6FF), // #58a6ff
    borderRadius: 8.0,
    borderWidth: 1.0,
    focusShadow: Color(0x3358A6FF), // rgba(88, 166, 255, 0.2)
    modalBackground: Color(0xFF161B22),
    todoCheckbox: Color(0xFF58A6FF),
    timeDivider: Color(0xFF8B949E),
  );

  /// Theme: Mono - pure black and white
  static const ThemeColors mono = ThemeColors(
    background: Color(0xFFFFFFFF), // #ffffff
    inputContainer: Color(0xFFFFFFFF), // #ffffff
    inputBackground: Color(0xFFFFFFFF), // #ffffff
    inputBorder: Color(0xFF000000), // #000000
    entryBackground: Color(0xFFFFFFFF), // #ffffff
    entryBorder: Color(0xFF000000), // #000000
    textPrimary: Color(0xFF000000), // #000000
    textSecondary: Color(0xFF000000), // #000000
    tagColor: Color(0xFF000000), // #000000
    accent: Color(0xFF000000), // #000000
    logoColor: Color(0xFF000000), // #000000
    borderRadius: 0.0, // No rounded corners!
    borderWidth: 2.0, // 2px solid borders!
    focusShadow: Colors.transparent, // No shadow
    modalBackground: Color(0xFFFFFFFF),
    todoCheckbox: Color(0xFF000000),
    timeDivider: Color(0xFF000000),
  );

  /// Get theme by name
  static ThemeColors getTheme(String themeName) {
    switch (themeName) {
      case 'matrix':
        return matrix;
      case 'paper':
        return paper;
      case 'midnight':
        return midnight;
      case 'mono':
        return mono;
      case 'minimal':
      default:
        return minimal;
    }
  }

  /// Get all valid theme names (matches PWA validThemes array)
  static const List<String> validThemes = ['minimal', 'matrix', 'paper', 'midnight', 'mono'];
}