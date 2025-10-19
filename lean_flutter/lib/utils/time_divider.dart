import 'package:intl/intl.dart';

/// Utility class for time divider formatting (matching PWA exactly)
class TimeDivider {
  /// Format divider text exactly like PWA
  /// Example: "Sunday, December 15, 3:42pm"
  static String formatDividerText(DateTime now) {
    final dayName = DateFormat('EEEE').format(now); // Sunday, Monday, etc.
    final monthDay = DateFormat('MMMM d').format(now); // December 15
    final time = DateFormat('h:mma').format(now).toLowerCase(); // 3:42pm

    return '$dayName, $monthDay, $time';
  }

  /// Create divider element with padded text
  /// Example: "━━ Sunday, December 15, 3:42pm ━━"
  /// Uses minimal padding for mobile-friendly display
  static String createDividerElement(DateTime now) {
    final text = formatDividerText(now);

    // Use minimal padding (just 2-3 hyphens) for mobile-friendly display
    const padding = 2;
    final leftLine = '━' * padding;
    final rightLine = '━' * padding;

    return '$leftLine $text $rightLine';
  }
}
