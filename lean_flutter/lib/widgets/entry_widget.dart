import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../theme/app_theme.dart';

/// Entry widget with ASCII checkbox support
/// Displays: □ for todo, ☑ for done
class EntryWidget extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onToggleTodo;

  const EntryWidget({super.key, required this.entry, this.onToggleTodo});

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return '◷ just now';
    } else if (diff.inMinutes < 60) {
      return '◷ ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '◷ ${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return '◷ yesterday';
    } else if (diff.inDays < 30) {
      return '◷ ${diff.inDays} days ago';
    } else {
      return '◷ ${DateFormat('MMM d').format(dt)}';
    }
  }

  String _getDisplayContent() {
    // Remove #todo and #done tags from display
    return entry.content
        .replaceAll('#todo', '')
        .replaceAll('#done', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isTodo = entry.isTodo;
    final isDone = entry.isDone;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content with optional todo checkbox
            if (isTodo)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Todo checkbox
                  GestureDetector(
                    onTap: onToggleTodo,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: Text(
                        isDone ? '☑' : '□',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDone ? AppTheme.accentGreen : AppTheme.darkTextSecondary,
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SelectableText(
                      _getDisplayContent(),
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.darkTextPrimary,
                        height: 1.5,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              )
            else
              // Regular content (no checkbox)
              SelectableText(
                entry.content,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.darkTextPrimary,
                  height: 1.5,
                ),
              ),

            // AI Badges (pill-shaped)
            if (_hasAnyBadges())
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Emotion badge
                    if (entry.emotion != null && entry.emotion!.isNotEmpty)
                      AiBadge(
                        label: entry.emotion!,
                        type: AiBadgeType.mood,
                      ),

                    // Theme badges
                    ...entry.themes.map((theme) => AiBadge(
                          label: theme,
                          type: AiBadgeType.theme,
                        )),

                    // People badges
                    ...entry.people.map((person) => AiBadge(
                          label: person,
                          type: AiBadgeType.people,
                        )),

                    // Urgency badge
                    if (entry.urgency != 'none')
                      AiBadge(
                        label: entry.urgency,
                        type: _getUrgencyBadgeType(entry.urgency),
                      ),
                  ],
                ),
              ),

            // Timestamp
            const SizedBox(height: 4),
            Text(
              _formatTime(entry.createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasAnyBadges() {
    return (entry.emotion != null && entry.emotion!.isNotEmpty) ||
        entry.themes.isNotEmpty ||
        entry.people.isNotEmpty ||
        entry.urgency != 'none';
  }

  AiBadgeType _getUrgencyBadgeType(String urgency) {
    switch (urgency) {
      case 'low':
        return AiBadgeType.urgencyLow;
      case 'medium':
        return AiBadgeType.urgencyMedium;
      case 'high':
        return AiBadgeType.urgencyHigh;
      default:
        return AiBadgeType.urgencyLow;
    }
  }
}
