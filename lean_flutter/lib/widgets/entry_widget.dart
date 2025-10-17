import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';

/// Entry widget with ASCII checkbox support
/// Displays: □ for todo, ☑ for done
class EntryWidget extends StatelessWidget {
  final Entry entry;

  const EntryWidget({super.key, required this.entry});

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

  @override
  Widget build(BuildContext context) {
    final isTodo = entry.isTodo;
    final isDone = entry.isDone;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content with checkbox for todos
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ASCII checkbox for todos
                if (isTodo)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      isDone ? '☑' : '□',
                      style: TextStyle(
                        fontSize: 18,
                        color: isDone ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),

                // Content
                Expanded(
                  child: Text(
                    entry.content,
                    style: TextStyle(
                      fontSize: 16,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.grey : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Metadata row
            Row(
              children: [
                // Timestamp
                Text(
                  _formatTime(entry.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(width: 12),

                // Emotion indicator
                if (entry.emotion != null && entry.emotion!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '[${entry.emotion}]',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),

                const SizedBox(width: 6),

                // Urgency indicator (if medium/high)
                if (entry.urgency == 'medium' || entry.urgency == 'high')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: entry.urgency == 'high' ? Colors.red[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '[!${entry.urgency}]',
                      style: TextStyle(
                        fontSize: 11,
                        color: entry.urgency == 'high' ? Colors.red[700] : Colors.orange[700],
                      ),
                    ),
                  ),

                const Spacer(),

                // Actions count
                if (entry.actions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '[!${entry.actions.length}]',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
