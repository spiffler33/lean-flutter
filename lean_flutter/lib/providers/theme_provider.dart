import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_colors.dart';

/// Theme provider that matches PWA implementation exactly
/// Uses shared_preferences (like localStorage) with key 'lean-theme'
/// Default theme is 'minimal' just like PWA
class ThemeProvider extends ChangeNotifier {
  // Current theme name (matches state.currentTheme from main.ts)
  String _currentTheme = 'minimal';

  // Storage key (matches localStorage.getItem('lean-theme') from main.ts)
  static const String _storageKey = 'lean-theme';

  String get currentTheme => _currentTheme;
  ThemeColors get colors => LeanThemes.getTheme(_currentTheme);

  ThemeProvider() {
    _loadTheme();
  }

  /// Load theme from storage (matches line 36 of main.ts)
  /// currentTheme: localStorage.getItem('lean-theme') || 'minimal'
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_storageKey);

      if (savedTheme != null && LeanThemes.validThemes.contains(savedTheme)) {
        _currentTheme = savedTheme;
        notifyListeners();
      }
    } catch (e) {
      // Keep default 'minimal' theme if loading fails
      debugPrint('Failed to load theme: $e');
    }
  }

  /// Apply theme (matches applyTheme function from main.ts lines 1142-1147)
  /// Removes old theme class, adds new one, saves to localStorage
  Future<void> applyTheme(String themeName) async {
    // Validate theme name (matches line 655 of main.ts)
    if (!LeanThemes.validThemes.contains(themeName)) {
      debugPrint('Invalid theme: $themeName');
      return;
    }

    // Update current theme
    _currentTheme = themeName;

    // Save to storage (matches localStorage.setItem('lean-theme', theme))
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, themeName);
    } catch (e) {
      debugPrint('Failed to save theme: $e');
    }

    // Notify listeners to rebuild UI
    notifyListeners();
  }
}