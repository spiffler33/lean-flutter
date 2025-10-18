import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../theme/app_theme.dart';

/// Export modal matching original PWA design
/// Features: date range, tag filter, markdown/write.as formats, copy to clipboard
class ExportModal extends StatefulWidget {
  final List<Entry> entries;

  const ExportModal({
    super.key,
    required this.entries,
  });

  @override
  State<ExportModal> createState() => _ExportModalState();
}

class _ExportModalState extends State<ExportModal> {
  String _dateRange = 'all';
  String _tagFilter = '';
  bool _includeTimestamps = true;
  String _format = 'markdown';

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _getFilteredEntries();
    final exportContent = _generateExportContent(filteredEntries);

    return Dialog(
      backgroundColor: AppTheme.darkEntryBackground,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.darkBorderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Export Entries',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppTheme.darkTextSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range Selector
                    Row(
                      children: [
                        const SizedBox(
                          width: 100,
                          child: Text(
                            'Date Range:',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _dateRange,
                            dropdownColor: AppTheme.darkInputBackground,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkTextPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppTheme.darkInputBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: AppTheme.darkBorderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All time'),
                              ),
                              DropdownMenuItem(
                                value: 'day',
                                child: Text('Last 24 hours'),
                              ),
                              DropdownMenuItem(
                                value: 'week',
                                child: Text('Last 7 days'),
                              ),
                              DropdownMenuItem(
                                value: 'month',
                                child: Text('Last 30 days'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _dateRange = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Tag Filter
                    Row(
                      children: [
                        const SizedBox(
                          width: 100,
                          child: Text(
                            'Filter by tag:',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                _tagFilter = value;
                              });
                            },
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkTextPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g., #work (optional)',
                              hintStyle: const TextStyle(
                                color: AppTheme.darkTextSecondary,
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: AppTheme.darkInputBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: AppTheme.darkBorderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Include Timestamps Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _includeTimestamps,
                          onChanged: (value) {
                            setState(() {
                              _includeTimestamps = value!;
                            });
                          },
                          activeColor: AppTheme.accentGreen,
                        ),
                        const Text(
                          'Include timestamps',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.darkTextPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Format Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _format = 'markdown';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _format == 'markdown'
                                  ? AppTheme.accentGreen
                                  : AppTheme.darkInputBackground,
                              foregroundColor: _format == 'markdown'
                                  ? Colors.black
                                  : AppTheme.darkTextPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(
                                  color: _format == 'markdown'
                                      ? AppTheme.accentGreen
                                      : AppTheme.darkBorderColor,
                                ),
                              ),
                            ),
                            child: const Text('Markdown'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _format = 'writeas';
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _format == 'writeas'
                                  ? AppTheme.accentGreen
                                  : AppTheme.darkInputBackground,
                              foregroundColor: _format == 'writeas'
                                  ? Colors.black
                                  : AppTheme.darkTextPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(
                                  color: _format == 'writeas'
                                      ? AppTheme.accentGreen
                                      : AppTheme.darkBorderColor,
                                ),
                              ),
                            ),
                            child: const Text('write.as'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Export Content Preview
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkInputBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.darkBorderColor,
                          ),
                        ),
                        child: SelectableText(
                          exportContent,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.darkTextPrimary,
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.darkBorderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: AppTheme.darkTextSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _copyToClipboard(exportContent),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Copy to Clipboard'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filter entries by date range and tag
  List<Entry> _getFilteredEntries() {
    var filtered = List<Entry>.from(widget.entries);

    // Filter by date range
    final now = DateTime.now();
    switch (_dateRange) {
      case 'day':
        final yesterday = now.subtract(const Duration(hours: 24));
        filtered = filtered.where((e) => e.createdAt.isAfter(yesterday)).toList();
        break;
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered.where((e) => e.createdAt.isAfter(weekAgo)).toList();
        break;
      case 'month':
        final monthAgo = now.subtract(const Duration(days: 30));
        filtered = filtered.where((e) => e.createdAt.isAfter(monthAgo)).toList();
        break;
      case 'all':
      default:
        // No date filtering
        break;
    }

    // Filter by tag
    if (_tagFilter.isNotEmpty) {
      final tag = _tagFilter.trim().toLowerCase();
      filtered = filtered.where((e) => e.content.toLowerCase().contains(tag)).toList();
    }

    return filtered;
  }

  /// Generate export content based on format
  String _generateExportContent(List<Entry> entries) {
    if (entries.isEmpty) {
      return 'No entries to export.';
    }

    if (_format == 'writeas') {
      return _generateWriteAsFormat(entries);
    } else {
      return _generateMarkdownFormat(entries);
    }
  }

  /// Generate Markdown format
  String _generateMarkdownFormat(List<Entry> entries) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    for (final entry in entries.reversed) {
      if (_includeTimestamps) {
        buffer.writeln('**${dateFormat.format(entry.createdAt)}**');
        buffer.writeln();
      }
      buffer.writeln(entry.content);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Generate write.as format (plain text with minimal formatting)
  String _generateWriteAsFormat(List<Entry> entries) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('MMM d, yyyy');

    for (final entry in entries.reversed) {
      if (_includeTimestamps) {
        buffer.writeln(dateFormat.format(entry.createdAt));
        buffer.writeln();
      }
      buffer.writeln(entry.content);
      buffer.writeln();
      buffer.writeln('• • •');
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Copy export content to clipboard
  Future<void> _copyToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard!'),
          backgroundColor: AppTheme.accentGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
