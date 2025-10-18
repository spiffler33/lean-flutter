import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../theme/app_theme.dart';

/// Entry widget with ASCII checkbox support
/// Displays: □ for todo, ☑ for done
/// Includes edit/delete actions on hover
class EntryWidget extends StatefulWidget {
  final Entry entry;
  final VoidCallback? onToggleTodo;
  final Function(Entry)? onEdit;
  final Function(Entry)? onDelete;

  const EntryWidget({
    super.key,
    required this.entry,
    this.onToggleTodo,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<EntryWidget> createState() => _EntryWidgetState();
}

class _EntryWidgetState extends State<EntryWidget> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.entry.content);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _isEditing = true;
      _editController.text = widget.entry.content;
    });
  }

  void _saveEdit() {
    final newContent = _editController.text.trim();
    if (newContent.isNotEmpty && newContent != widget.entry.content) {
      final updatedEntry = widget.entry.copyWith(content: newContent);
      widget.onEdit?.call(updatedEntry);
    }
    setState(() {
      _isEditing = false;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _editController.text = widget.entry.content;
    });
  }

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
    return widget.entry.content
        .replaceAll('#todo', '')
        .replaceAll('#done', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isTodo = widget.entry.isTodo;
    final isDone = widget.entry.isDone;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Editing state
                  if (_isEditing)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _editController,
                            autofocus: true,
                            maxLines: null,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.darkTextPrimary,
                              height: 1.5,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _saveEdit(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, size: 20),
                          onPressed: _saveEdit,
                          color: AppTheme.accentGreen,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: _cancelEdit,
                          color: Colors.red,
                        ),
                      ],
                    )
                  // Normal content display
                  else if (isTodo)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Todo checkbox
                  GestureDetector(
                    onTap: widget.onToggleTodo,
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
            else if (!_isEditing)
              // Regular content (no checkbox)
              SelectableText(
                widget.entry.content,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.darkTextPrimary,
                  height: 1.5,
                ),
              ),

                  // AI Badges (pill-shaped)  - only show if not editing
                  if (!_isEditing && _hasAnyBadges())
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Emotion badge
                          if (widget.entry.emotion != null && widget.entry.emotion!.isNotEmpty)
                            AiBadge(
                              label: widget.entry.emotion!,
                              type: AiBadgeType.mood,
                            ),

                          // Theme badges
                          ...widget.entry.themes.map((theme) => AiBadge(
                                label: theme,
                                type: AiBadgeType.theme,
                              )),

                          // People badges
                          ...widget.entry.people.map((person) => AiBadge(
                                label: person,
                                type: AiBadgeType.people,
                              )),

                          // Urgency badge
                          if (widget.entry.urgency != 'none')
                            AiBadge(
                              label: widget.entry.urgency,
                              type: _getUrgencyBadgeType(widget.entry.urgency),
                            ),
                        ],
                      ),
                    ),

                  // Timestamp - only show if not editing
                  if (!_isEditing) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(widget.entry.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Hover actions (edit/delete) - positioned in top right
            if (_isHovering && !_isEditing)
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: _startEdit,
                      color: AppTheme.darkTextSecondary,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => widget.onDelete?.call(widget.entry),
                      color: AppTheme.darkTextSecondary,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasAnyBadges() {
    return (widget.entry.emotion != null && widget.entry.emotion!.isNotEmpty) ||
        widget.entry.themes.isNotEmpty ||
        widget.entry.people.isNotEmpty ||
        widget.entry.urgency != 'none';
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
