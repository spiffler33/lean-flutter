import 'package:flutter/material.dart';
import '../models/entry.dart';
import '../widgets/export_modal.dart';
import 'entry_provider.dart';

/// Command handler for /commands like /help, /search, /today, etc.
/// Matches original PWA implementation exactly
class CommandHandler {
  final EntryProvider provider;
  final BuildContext context;

  CommandHandler(this.provider, this.context);

  /// Check if content is a command and execute it
  /// Returns true if command was executed, false if regular entry
  Future<bool> handleCommand(String content) async {
    final trimmed = content.trim();

    // Command mapping
    if (trimmed == '/help') {
      await _handleHelp();
      return true;
    }

    if (trimmed == '/today') {
      await _handleToday();
      return true;
    }

    if (trimmed == '/yesterday') {
      await _handleYesterday();
      return true;
    }

    if (trimmed == '/week') {
      await _handleWeek();
      return true;
    }

    if (trimmed.startsWith('/search')) {
      await _handleSearch(trimmed);
      return true;
    }

    if (trimmed == '/clear') {
      await _handleClear();
      return true;
    }

    if (trimmed == '/stats') {
      await _handleStats();
      return true;
    }

    if (trimmed == '/export') {
      await _handleExport();
      return true;
    }

    if (trimmed == '/essay') {
      _handleEssay();
      return true;
    }

    if (trimmed == '/idea') {
      _handleIdea();
      return true;
    }

    if (trimmed.startsWith('/theme')) {
      await _handleTheme(trimmed);
      return true;
    }

    return false;
  }

  // ============ Command Handlers ============

  /// /help - Show help dialog with all commands
  Future<void> _handleHelp() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Commands',
          style: TextStyle(
            color: Color(0xFFE4E4E7),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection('Search & Filter'),
              _buildHelpCommand('◎ /search term', 'Search entries'),
              _buildHelpCommand('▦ /today', 'Today\'s entries'),
              _buildHelpCommand('≈ /yesterday', 'Yesterday\'s entries'),
              _buildHelpCommand('▤ /week', 'Last 7 days'),
              _buildHelpCommand('▨ /clear', 'Clear view'),

              const SizedBox(height: 12),
              _buildHelpSection('Actions'),
              _buildHelpCommand('▨ /export', 'Export as markdown'),
              _buildHelpCommand('▊ /stats', 'View statistics'),
              _buildHelpCommand('◆ /theme [name]', 'Change theme'),

              const SizedBox(height: 12),
              _buildHelpSection('Templates'),
              _buildHelpCommand('✎ /essay', 'Essay template'),
              _buildHelpCommand('▪ /idea', 'Idea template'),

              const SizedBox(height: 12),
              _buildHelpSection('Todos'),
              _buildHelpCommand('#todo', 'Creates checkbox'),
              _buildHelpCommand('Click □', 'Mark as done'),

              const SizedBox(height: 12),
              _buildHelpSection('Keyboard'),
              _buildHelpCommand('↑', 'Edit last entry (when input empty)'),
              _buildHelpCommand('Esc', 'Clear/close'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFE4E4E7),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHelpCommand(String command, String description) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              command,
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// /today - Show today's entries
  Future<void> _handleToday() async {
    final todayEntries = await provider.getTodayEntries();
    provider.setFilteredEntries(todayEntries, 'today\'s entries');

    if (!context.mounted) return;
    _showNotification('Showing today\'s entries');
  }

  /// /yesterday - Show yesterday's entries
  Future<void> _handleYesterday() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStart = DateTime(yesterday.year, yesterday.month, yesterday.day);
    final todayStart = DateTime.now();
    final today = DateTime(todayStart.year, todayStart.month, todayStart.day);

    final entries = provider.entries.where((entry) {
      return entry.createdAt.isAfter(yesterdayStart) &&
             entry.createdAt.isBefore(today);
    }).toList();

    provider.setFilteredEntries(entries, 'yesterday\'s entries');

    if (!context.mounted) return;
    _showNotification('Showing yesterday\'s entries');
  }

  /// /week - Show last 7 days
  Future<void> _handleWeek() async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final entries = provider.entries.where((entry) {
      return entry.createdAt.isAfter(weekAgo);
    }).toList();

    provider.setFilteredEntries(entries, 'last 7 days');

    if (!context.mounted) return;
    _showNotification('Showing last 7 days');
  }

  /// /search [term] - Search entries by content or tags
  Future<void> _handleSearch(String command) async {
    final searchTerm = command.substring(7).trim(); // Remove '/search'

    if (searchTerm.isEmpty) {
      // Just show all entries
      provider.clearFilter();
      _showNotification('Showing all entries');
      return;
    }

    final results = await provider.searchEntries(searchTerm);
    provider.setFilteredEntries(results, 'search: $searchTerm');

    if (!context.mounted) return;
    _showNotification('Found ${results.length} results');
  }

  /// /clear - Clear current view and filters
  Future<void> _handleClear() async {
    provider.clearFilter();
    _showNotification('View cleared');
  }

  /// /stats - Show statistics modal
  Future<void> _handleStats() async {
    final totalEntries = await provider.getEntryCount();
    final todayEntries = await provider.getTodayEntries();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          '▊ Stats',
          style: TextStyle(
            color: Color(0xFFE4E4E7),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Entries', '$totalEntries'),
            _buildStatRow('Today', '${todayEntries.length}'),
            const SizedBox(height: 12),
            const Text(
              'More stats coming soon!',
              style: TextStyle(
                color: Color(0xFF71717A),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE4E4E7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// /export - Show export dialog
  Future<void> _handleExport() async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => ExportModal(entries: provider.entries),
    );
  }

  /// /essay - Insert essay template
  void _handleEssay() {
    // This will be handled in HomeScreen to populate input
    _showNotification('Essay template inserted');
  }

  /// /idea - Insert idea template
  void _handleIdea() {
    // This will be handled in HomeScreen to populate input
    _showNotification('Idea template inserted');
  }

  /// /theme [name] - Change theme
  Future<void> _handleTheme(String command) async {
    final parts = command.split(' ');
    if (parts.length < 2) {
      _showThemeInfo();
      return;
    }

    final themeName = parts[1].toLowerCase();
    final validThemes = ['dark', 'matrix', 'paper', 'midnight', 'mono'];

    if (validThemes.contains(themeName)) {
      _showNotification('Theme: $themeName (theming system coming soon!)');
    } else {
      _showThemeInfo();
    }
  }

  void _showThemeInfo() {
    _showNotification('Available themes: dark, matrix, paper, midnight, mono');
  }

  void _showNotification(String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A1A),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Template getters for /essay and /idea
  static String get essayTemplate => '''# [Title Here]

*[One-line hook that captures the essence]*

## The Problem
[What's broken? What tension exists? Why should anyone care?]

## The Insight
[The key realization. What you see that others don't]

## The Evidence
[Examples, data, observations that support your insight]

## The Implications
[What changes if this is true? What should we do differently?]

## The Takeaway
[One memorable line that captures the transformation]

---
#essay #draft''';

  static String get ideaTemplate => '''[Title]

[Describe the idea]

Next step: [Action]

#idea''';
}
