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
  /// Example: "━━━━━ Sunday, December 15, 3:42pm ━━━━━"
  static String createDividerElement(DateTime now) {
    final text = formatDividerText(now);
    final textLength = text.length;
    const totalWidth = 50;
    final paddingLength = (totalWidth - textLength - 2) ~/ 2;
    final padding = paddingLength > 3 ? paddingLength : 3;

    final leftLine = '━' * padding;
    final rightLine = '━' * padding;

    return '$leftLine $text $rightLine';
  }
}
