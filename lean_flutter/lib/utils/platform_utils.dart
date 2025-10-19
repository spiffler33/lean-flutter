import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform-specific utilities
/// Handles iOS vs Android differences for native feel
class PlatformUtils {
  /// Check if running on iOS (not available on web)
  static bool get isIOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Check if running on Android (not available on web)
  static bool get isAndroid {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Check if running on mobile (iOS or Android)
  static bool get isMobile {
    return isIOS || isAndroid;
  }

  /// Light haptic feedback (iOS only)
  /// Use for: Button taps, checkbox toggles, successful actions
  static Future<void> lightImpact() async {
    if (!isIOS) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Ignore haptic errors
    }
  }

  /// Medium haptic feedback (iOS only)
  /// Use for: Swipe actions, entry edits, theme changes
  static Future<void> mediumImpact() async {
    if (!isIOS) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Ignore haptic errors
    }
  }

  /// Heavy haptic feedback (iOS only)
  /// Use for: Entry deletion, important confirmations
  static Future<void> heavyImpact() async {
    if (!isIOS) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Ignore haptic errors
    }
  }

  /// Selection feedback (iOS only)
  /// Use for: Selection changes, filter toggles
  static Future<void> selectionClick() async {
    if (!isIOS) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      // Ignore haptic errors
    }
  }

  /// Vibration feedback (Android only)
  /// Use for: Errors, important alerts
  static Future<void> vibrate() async {
    if (!isAndroid) return;
    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      // Ignore haptic errors
    }
  }
}
