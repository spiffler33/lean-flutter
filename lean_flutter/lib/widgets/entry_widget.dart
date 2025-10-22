import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../models/enrichment.dart';
import '../providers/theme_provider.dart';
import '../services/enrichment_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_colors.dart';
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
  Enrichment? _enrichment;
  Timer? _enrichmentTimer;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.entry.content);
    _isEditing = widget.shouldStartEditing;
    _loadEnrichment();

    // Poll for enrichment updates every 2 seconds
    // Keep polling until we have a complete/failed enrichment
    _enrichmentTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      // Poll if:
      // - No enrichment yet (might be queued)
      // - Enrichment is processing
      // - Enrichment is pending
      if (_enrichment == null ||
          _enrichment!.isPending ||
          _enrichment!.isProcessing) {
        _loadEnrichment();
      }
    });
  }

  Future<void> _loadEnrichment() async {
    if (widget.entry.id != null) {
      final enrichment = await EnrichmentService.instance.getEnrichmentForEntry(widget.entry.id!);
      if (mounted) {
        // Log for debugging
        if (enrichment != null) {
          print('📊 Entry ${widget.entry.id} enrichment status: ${enrichment.processingStatus}');
        }

        setState(() {
          _enrichment = enrichment;
        });

        // Stop polling if enrichment is complete or failed
        if (enrichment != null && (enrichment.isComplete || enrichment.isFailed)) {
          print('🛑 Stopping enrichment polling for entry ${widget.entry.id}');
          _enrichmentTimer?.cancel();
        }
      }
    }
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

    // Reload enrichment if entry ID changed
    if (widget.entry.id != oldWidget.entry.id) {
      _loadEnrichment();
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _enrichmentTimer?.cancel();
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
    // Compare local times (device time)
    final now = DateTime.now();
    final diff = now.difference(dt);

    // Debug logging for timestamp issues
    if (widget.entry.content.contains('woke up') || widget.entry.content.contains('chalo')) {
      print('⏰ DEBUG _formatTime for "${widget.entry.content.substring(0, widget.entry.content.length > 30 ? 30 : widget.entry.content.length)}..."');
      print('   Entry ID: ${widget.entry.id}');
      print('   Entry createdAt: ${dt.toIso8601String()} (isUtc: ${dt.isUtc})');
      print('   Now: ${now.toIso8601String()} (isUtc: ${now.isUtc})');
      print('   Difference: ${diff.inSeconds}s / ${diff.inMinutes}m / ${diff.inHours}h');
      print('   Will display: ${diff.inSeconds < 10 ? "just now" : diff.inMinutes < 60 ? "${diff.inMinutes}m ago" : "${diff.inHours}h ago"}');
    }

    if (diff.inSeconds < 10) {
      return '◷ just now';
    } else if (diff.inSeconds < 60) {
      return '◷ ${diff.inSeconds}s ago';
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

  Widget _buildEnrichmentIndicator(ThemeColors colors) {
    if (_enrichment == null) return const SizedBox.shrink();

    // Choose icon and color based on status
    IconData icon;
    Color color;
    String tooltip;

    if (_enrichment!.isProcessing) {
      icon = Icons.bolt; // Lightning bolt for processing
      color = colors.accent;
      tooltip = 'Enriching...';
    } else if (_enrichment!.isComplete) {
      icon = Icons.check_circle_outline; // Check for complete
      color = Colors.green.withOpacity(0.7);
      tooltip = 'AI enriched';
    } else if (_enrichment!.isFailed) {
      icon = Icons.error_outline; // Error icon
      color = Colors.red.withOpacity(0.7);
      tooltip = 'Enrichment failed';
    } else {
      icon = Icons.hourglass_empty; // Pending
      color = colors.textSecondary;
      tooltip = 'Pending enrichment';
    }

    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
    );
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
                      if (!_isEditing && (_hasAnyBadges() || _hasEnrichmentBadges()))
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              // Show enrichment data if available (priority over entry data)
                              if (_enrichment != null && _enrichment!.isComplete) ...[
                                // Enriched emotion
                                if (_enrichment!.emotion != null)
                                  AiBadge(
                                    label: _enrichment!.emotion!,
                                    type: AiBadgeType.mood,
                                  ),
                                // Enriched themes
                                ..._enrichment!.themes.map((theme) => AiBadge(
                                      label: theme,
                                      type: AiBadgeType.theme,
                                    )),
                                // Enriched people
                                ..._enrichment!.people.map((person) => AiBadge(
                                      label: person['name'] ?? 'Unknown',
                                      type: AiBadgeType.people,
                                    )),
                                // Enriched urgency
                                if (_enrichment!.urgency != 'none')
                                  AiBadge(
                                    label: _enrichment!.urgency,
                                    type: _getUrgencyBadgeType(_enrichment!.urgency),
                                  ),
                              ] else ...[
                                // Fall back to entry data if no enrichment
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
                            ],
                          ),
                        ),

                      // Timestamp and enrichment status - only show if not editing
                      // (spacing handled by content padding-bottom: 6px or badges padding-bottom: 4px)
                      if (!_isEditing)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(widget.entry.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                            // Enrichment status indicator
                            if (_enrichment != null) ...[
                              const SizedBox(width: 8),
                              _buildEnrichmentIndicator(colors),
                            ],
                          ],
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

  bool _hasEnrichmentBadges() {
    if (_enrichment == null || !_enrichment!.isComplete) return false;

    return (_enrichment!.emotion != null) ||
        _enrichment!.themes.isNotEmpty ||
        _enrichment!.people.isNotEmpty ||
        _enrichment!.urgency != 'none';
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
