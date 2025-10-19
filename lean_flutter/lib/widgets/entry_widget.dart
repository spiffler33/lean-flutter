import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/platform_utils.dart';

/// Entry widget with ASCII checkbox support
/// Displays: □ for todo, ☑ for done
/// Includes edit/delete actions on hover
class EntryWidget extends StatefulWidget {
  final Entry entry;
  final bool shouldStartEditing;
  final VoidCallback? onToggleTodo;
  final Function(Entry)? onEdit;
  final VoidCallback? onCancelEdit;
  final Function(Entry)? onDelete;

  const EntryWidget({
    super.key,
    required this.entry,
    this.shouldStartEditing = false,
    this.onToggleTodo,
    this.onEdit,
    this.onCancelEdit,
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
    _isEditing = widget.shouldStartEditing;
  }

  @override
  void didUpdateWidget(EntryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Enter edit mode when shouldStartEditing becomes true
    if (widget.shouldStartEditing && !oldWidget.shouldStartEditing) {
      setState(() {
        _isEditing = true;
        _editController.text = widget.entry.content;
      });
    }
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
    widget.onCancelEdit?.call();
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

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.colors;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: Container(
            width: double.infinity,  // CRITICAL: Match input box width
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colors.entryBackground,
              borderRadius: BorderRadius.circular(colors.borderRadius),
              border: Border(
                bottom: BorderSide(
                  color: colors.entryBorder.withOpacity(0.05),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),  // PWA: 14px 16px
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colors.textPrimary,
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
                              color: colors.accent,
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6), // PWA: margin-bottom: 6px
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Todo checkbox with 48x48pt touch target
                              InkWell(
                                onTap: () {
                                  PlatformUtils.lightImpact();
                                  widget.onToggleTodo?.call();
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  // Expanded touch area (48x48pt minimum)
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    isDone ? '☑' : '□',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: isDone ? colors.todoCheckbox : colors.textSecondary,
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
                                    color: colors.textPrimary,
                                    height: 1.5,  // PWA: 1.5
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!_isEditing)
                        // Regular content (no checkbox) - PWA: margin-bottom: 6px
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),  // PWA: 6px
                          child: SelectableText(
                            widget.entry.content,
                            style: TextStyle(
                              fontSize: 16,
                              color: colors.textPrimary,
                              height: 1.5,  // PWA: 1.5
                            ),
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
                              // Mood badge (AI-detected emotion)
                              if (widget.entry.mood != null && widget.entry.mood!.isNotEmpty)
                                AiBadge(
                                  label: widget.entry.mood!,
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
                      // (spacing handled by content padding-bottom: 6px or badges padding-bottom: 4px)
                      if (!_isEditing)
                        Text(
                          _formatTime(widget.entry.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Hover actions (edit/delete) - positioned in top right
                if (_isHovering && !_isEditing)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit button with 48x48pt touch target
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: _startEdit,
                          color: colors.textSecondary,
                          padding: const EdgeInsets.all(12), // 48x48pt minimum
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          tooltip: 'Edit',
                        ),
                        // Delete button with 48x48pt touch target
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () => widget.onDelete?.call(widget.entry),
                          color: colors.textSecondary,
                          padding: const EdgeInsets.all(12), // 48x48pt minimum
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasAnyBadges() {
    return (widget.entry.mood != null && widget.entry.mood!.isNotEmpty) ||
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
