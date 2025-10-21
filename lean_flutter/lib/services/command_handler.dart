import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../models/user_fact.dart';
import '../models/event.dart';
import '../widgets/export_modal.dart';
import '../providers/theme_provider.dart';
import '../theme/theme_colors.dart';
import 'entry_provider.dart';
import 'user_fact_service.dart';
import 'event_extraction_service.dart';
import 'supabase_service.dart';
// import '../commands/patterns_command.dart'; // TODO: Implement patterns command

/// Command handler for /commands like /help, /search, /today, etc.
/// Matches original PWA implementation exactly
class CommandHandler {
  final EntryProvider provider;
  final BuildContext context;
  final UserFactService _userFactService = UserFactService();

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

    if (trimmed.startsWith('/context')) {
      await _handleContext(trimmed);
      return true;
    }

    if (trimmed == '/patterns') {
      await _handlePatterns();
      return true;
    }

    if (trimmed.startsWith('/events')) {
      await _handleEvents(trimmed);
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
              _buildHelpSection('Intelligence'),
              _buildHelpCommand('◉ /context', 'Manage user facts'),
              _buildHelpCommand('◉ /context add', 'Add a fact'),
              _buildHelpCommand('◉ /context remove', 'Remove a fact'),
              _buildHelpCommand('◉ /context clear', 'Clear all facts'),
              _buildHelpCommand('◈ /patterns', 'Analyze your patterns'),
              _buildHelpCommand('◈ /events', 'View extracted events'),

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

  /// /clear - Clear current view (PWA: clears displayed entries, shows time divider)
  Future<void> _handleClear() async {
    provider.clearView(); // Clear displayed entries (matching PWA behavior)
    _showNotification('View cleared');
  }

  /// /stats - Show comprehensive statistics modal (matches PWA)
  Future<void> _handleStats() async {
    final entries = provider.entries;

    if (entries.isEmpty) {
      _showNotification('No entries yet. Start writing!');
      return;
    }

    if (!context.mounted) return;

    // Calculate all stats
    final stats = _calculateStats(entries);
    final statsDisplay = _formatStatsDisplay(stats);

    await showDialog(
      context: context,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final colors = themeProvider.colors;

          return AlertDialog(
            backgroundColor: colors.modalBackground,
            title: Text(
              'STATS',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Text(
                  statsDisplay,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: colors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(color: colors.accent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Calculate statistics from entries (matches PWA calculateStats)
  Map<String, dynamic> _calculateStats(List<Entry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));

    // Counts
    final todayCount = entries.where((e) => e.createdAt.isAfter(today)).length;
    final weekCount = entries.where((e) => e.createdAt.isAfter(weekAgo)).length;
    final monthCount = entries.where((e) => e.createdAt.isAfter(monthAgo)).length;

    // Words
    final totalWords = entries.fold<int>(0, (sum, e) => sum + e.content.split(RegExp(r'\s+')).length);
    final avgWords = entries.isNotEmpty ? (totalWords / entries.length).round() : 0;

    // Activity for last 7 days
    final activity7days = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final count = entries.where((e) => e.createdAt.isAfter(day) && e.createdAt.isBefore(nextDay)).length;
      activity7days.add({
        'day': _getDayName(day),
        'count': count,
      });
    }

    // Top tags
    final tagCounts = <String, int>{};
    for (final entry in entries) {
      final tags = RegExp(r'#(\w+)').allMatches(entry.content);
      for (final match in tags) {
        final tag = match.group(0)!;
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Tags = topTags.take(5).toList();

    // 30-day heatmap
    final heatmap = <int>[];
    for (int i = 29; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final count = entries.where((e) => e.createdAt.isAfter(day) && e.createdAt.isBefore(nextDay)).length;
      heatmap.add(count);
    }

    // Streak calculation
    int currentStreak = 0;
    int longestStreak = 0;
    var checkDate = DateTime(today.year, today.month, today.day);

    while (true) {
      final nextDay = checkDate.add(const Duration(days: 1));
      final hasEntry = entries.any((e) => e.createdAt.isAfter(checkDate) && e.createdAt.isBefore(nextDay));
      if (hasEntry) {
        currentStreak++;
        longestStreak = longestStreak > currentStreak ? longestStreak : currentStreak;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Best day
    final dayCounts = <String, int>{};
    for (final entry in entries) {
      final dayKey = '${entry.createdAt.year}-${entry.createdAt.month}-${entry.createdAt.day}';
      dayCounts[dayKey] = (dayCounts[dayKey] ?? 0) + 1;
    }
    final bestDayEntry = dayCounts.entries.isEmpty
        ? null
        : dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final bestDay = bestDayEntry != null ? '${bestDayEntry.value} entries' : '0 entries';

    // Trend
    final weekAvg = weekCount / 7;
    final monthAvg = monthCount / 30;
    final trend = weekAvg > monthAvg ? '▲ Up' : '▼ Down';

    return {
      'total_entries': entries.length,
      'today_count': todayCount,
      'week_count': weekCount,
      'month_count': monthCount,
      'total_words': totalWords,
      'daily_avg': avgWords,
      'best_day': bestDay,
      'activity_7days': activity7days,
      'top_tags': top5Tags,
      'heatmap': heatmap,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'trend': trend,
    };
  }

  String _getDayName(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  /// Format stats display (matches PWA formatStatsDisplay)
  String _formatStatsDisplay(Map<String, dynamic> data) {
    String fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    // Activity bars
    final activity7days = data['activity_7days'] as List<Map<String, dynamic>>;
    final maxCount = activity7days.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);
    final activityBars = activity7days.map((d) {
      final count = d['count'] as int;
      final barLength = maxCount > 0 ? (count / maxCount * 20).round() : 0;
      final bar = barLength > 0 ? '█' * barLength : '▁';
      return '   ${d['day']} $bar ($count)';
    }).join('\n');

    // Heatmap
    const heatChars = ['□','▤','▥','▦','▧','▨','▩','█'];
    final heatmapData = data['heatmap'] as List<int>;
    final maxHeat = heatmapData.isEmpty ? 0 : heatmapData.reduce((a, b) => a > b ? a : b);
    final heatmap = heatmapData.map((count) {
      if (count == 0) return heatChars[0];
      final level = ((count / (maxHeat > 0 ? maxHeat : 1)) * 7).ceil().clamp(0, 7);
      return heatChars[level];
    }).join('');

    // Top tags
    final topTags = data['top_tags'] as List<MapEntry<String, int>>;
    final maxTagCount = topTags.isEmpty ? 0 : topTags.first.value;
    const nums = ['①','②','③','④','⑤'];
    final tagBars = topTags.isEmpty
        ? '   No tags yet'
        : topTags.asMap().entries.map((entry) {
            final i = entry.key;
            final tag = entry.value;
            final num = i < nums.length ? nums[i] : '•';
            final barLength = maxTagCount > 0 ? (tag.value / maxTagCount * 12).round() : 0;
            final bar = barLength > 0 ? '█' * barLength : '';
            final tagName = tag.key.padRight(10);
            return '   $num $tagName $bar (${tag.value})';
          }).join('\n');

    // Streak arrows
    final currentStreak = data['current_streak'] as int;
    final longestStreak = data['longest_streak'] as int;
    final streakArrows = currentStreak > 0 ? '▲' * (currentStreak.clamp(0, 10)) : '';

    return '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Your Thought Patterns
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

STREAK
   Current Streak: $streakArrows $currentStreak day${currentStreak != 1 ? 's' : ''}
   Longest Streak: ★ $longestStreak day${longestStreak != 1 ? 's' : ''}

STATS OVERVIEW
   Entries ··········· ${fmt(data['total_entries'])}
   Today ············· ${data['today_count']}
   This Week ········· ${data['week_count']}
   This Month ········ ${data['month_count']}
   Total Words ······· ${fmt(data['total_words'])}
   Daily Average ····· ${data['daily_avg']}
   Best Day ·········· ${data['best_day']}

ACTIVITY (Last 7 days)
$activityBars

TOP TAGS
$tagBars

30-DAY HEATMAP
   Last 30 days: $heatmap

TREND
   Productivity: ${data['trend']} this week
''';
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

  /// /theme [name] - Change theme (matches PWA handleTheme lines 649-665)
  Future<void> _handleTheme(String command) async {
    final parts = command.split(' ');

    // No theme name provided - show current theme and options
    if (parts.length < 2) {
      await _showThemeInfo();
      return;
    }

    final themeName = parts[1].toLowerCase();

    // Check if theme is valid (matches line 655 of main.ts)
    if (LeanThemes.validThemes.contains(themeName)) {
      // Get theme provider and apply theme (matches applyTheme function)
      final themeProvider = context.read<ThemeProvider>();
      await themeProvider.applyTheme(themeName);
      _showNotification('Theme switched to $themeName');
    } else {
      // Invalid theme - show available options
      await _showThemeOptions();
    }
  }

  /// Show current theme and options (matches showThemeInfo from main.ts)
  Future<void> _showThemeInfo() async {
    final themeProvider = context.read<ThemeProvider>();

    if (!context.mounted) return;

    // Show current theme info like PWA
    await showDialog(
      context: context,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final colors = themeProvider.colors;

          return AlertDialog(
            backgroundColor: colors.modalBackground,
            title: Text(
              '▪ Current theme: ${themeProvider.currentTheme}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Available themes:',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildThemeOption(colors, 'minimal', 'Clean and minimal (default)'),
                  _buildThemeOption(colors, 'matrix', 'Green phosphor terminal'),
                  _buildThemeOption(colors, 'paper', 'Warm paper-like colors'),
                  _buildThemeOption(colors, 'midnight', 'Deep blues and purples'),
                  _buildThemeOption(colors, 'mono', 'Pure black and white'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(color: colors.accent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show theme options (matches showThemeOptions from main.ts)
  Future<void> _showThemeOptions() async {
    await _showThemeInfo(); // Same dialog
  }

  Widget _buildThemeOption(ThemeColors colors, String name, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: colors.textPrimary),
          children: [
            TextSpan(
              text: '/theme $name',
              style: TextStyle(
                color: colors.accent,
                fontFamily: 'monospace',
              ),
            ),
            TextSpan(
              text: ' - $description',
              style: TextStyle(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// /patterns - Analyze enrichment patterns
  Future<void> _handlePatterns() async {
    // TODO: Implement patterns command
    _showNotification('Pattern analysis coming soon!');
    return;

    /* Commented out until PatternsCommand is implemented
    try {
      // Get pattern analysis
      final patternsCommand = PatternsCommand.instance;
      final htmlContent = await patternsCommand.execute();

      if (!context.mounted) return;

    */
  }

  // TODO: Implement _buildPatternsContent when PatternsCommand is ready
  /*
  Widget _buildPatternsContent(String htmlContent, ThemeColors colors) {
    // For now, parse the HTML and display as rich text
    // Remove HTML tags for simple display (later we can enhance this)
    final cleanText = htmlContent
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&')
        .trim();

    return Text(
      cleanText,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: colors.textPrimary,
        height: 1.5,
      ),
    );
  }
  */

  /// /events - View extracted events from entries
  Future<void> _handleEvents(String command) async {
    final parts = command.split(RegExp(r'\s+'));

    // Check if Supabase is available
    final supabase = SupabaseService.instance;
    if (!supabase.isAuthenticated) {
      _showNotification('Events require cloud sync. Please sign in.');
      return;
    }

    try {
      // Create event extraction service
      final eventService = EventExtractionService(supabase.client);

      // Just "/events" - show recent events
      if (parts.length == 1) {
        await _showRecentEvents(eventService);
        return;
      }

      // Handle sub-commands
      final subcommand = parts[1].toLowerCase();
      switch (subcommand) {
        case 'stats':
          await _showEventStats(eventService);
          break;
        case 'validate':
          await _showUnvalidatedEvents(eventService);
          break;
        default:
          _showNotification('Unknown events command. Try /events, /events stats, or /events validate');
      }
    } catch (e, stackTrace) {
      print('Error in _handleEvents: $e');
      print('Stack trace: $stackTrace');
      _showNotification('Failed to fetch events: ${e.toString()}');
    }
  }

  /// Show recent events
  Future<void> _showRecentEvents(EventExtractionService eventService) async {
    try {
      final userId = SupabaseService.instance.userId;
      if (userId == null) {
        _showNotification('Please sign in to view events');
        return;
      }

      print('Fetching events for user: $userId');

      // Use the service method to get recent events
      final events = await eventService.getRecentEvents(userId, limit: 20);

      print('Retrieved ${events.length} events');

      if (events.isEmpty) {
        _showNotification('No events extracted yet. Create some entries like "ran 5km" or "spent \$50"');
        return;
      }

    // Show events in a modal
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final colors = themeProvider.colors;

            return AlertDialog(
              backgroundColor: colors.modalBackground,
              title: Text(
                'EXTRACTED EVENTS',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: events.map((event) => _buildEventDisplay(event, colors)).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: TextStyle(color: colors.accent),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
    } catch (e, stackTrace) {
      print('Error in _showRecentEvents: $e');
      print('Stack trace: $stackTrace');
      _showNotification('Error displaying events: ${e.toString()}');
    }
  }

  /// Build display for a single event
  Widget _buildEventDisplay(Event event, ThemeColors colors) {
    final icon = _getEventIcon(event.type);
    final metricsText = _formatEventMetrics(event);
    final confidenceText = '${(event.confidence * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.textSecondary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${event.type.value}${event.subtype != null ? " (${event.subtype})" : ""}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: event.confidence >= 0.85
                      ? colors.accent.withOpacity(0.2)
                      : colors.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  confidenceText,
                  style: TextStyle(
                    color: event.confidence >= 0.85
                        ? colors.accent
                        : colors.textSecondary,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          if (metricsText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              metricsText,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (event.context.people != null && event.context.people!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'With: ${event.context.people!.join(", ")}',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getEventIcon(EventType type) {
    switch (type) {
      case EventType.exercise:
        return '🏃';
      case EventType.spend:
        return '💰';
      case EventType.sleep:
        return '😴';
      case EventType.meeting:
        return '👥';
      case EventType.consumption:
        return '🍽️';
      case EventType.health:
        return '❤️';
    }
  }

  String _formatEventMetrics(Event event) {
    final parts = <String>[];
    final m = event.metrics;

    if (m.distanceKm != null) parts.add('${m.distanceKm}km');
    if (m.durationMin != null) parts.add('${m.durationMin}min');
    if (m.amount != null) parts.add('\$${m.amount}');
    if (m.hoursSlept != null) parts.add('${m.hoursSlept}hrs');

    return parts.join(' • ');
  }

  /// Show event statistics
  Future<void> _showEventStats(EventExtractionService eventService) async {
    final userId = SupabaseService.instance.userId;
    if (userId == null) return;

    final stats = await eventService.getEventStats(userId);
    final statsList = stats['stats'] as List<dynamic>;

    if (statsList.isEmpty) {
      _showNotification('No event statistics available yet');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('EVENT STATISTICS (Last 30 Days)');
    buffer.writeln('=' * 30);

    for (final stat in statsList) {
      final type = stat['event_type'] as String;
      final count = stat['total_count'] as int;
      final metrics = stat['avg_metrics'] as Map<String, dynamic>;

      buffer.writeln('\n${type.toUpperCase()}:');
      buffer.writeln('  Total: $count events');

      if (metrics['avg_distance_km'] != null && metrics['avg_distance_km'] > 0) {
        buffer.writeln('  Avg Distance: ${metrics['avg_distance_km'].toStringAsFixed(1)}km');
        buffer.writeln('  Total Distance: ${metrics['total_distance_km'].toStringAsFixed(1)}km');
      }
      if (metrics['avg_amount'] != null && metrics['avg_amount'] > 0) {
        buffer.writeln('  Avg Spend: \$${metrics['avg_amount'].toStringAsFixed(2)}');
        buffer.writeln('  Total Spend: \$${metrics['total_amount'].toStringAsFixed(2)}');
      }
      if (metrics['avg_duration_min'] != null && metrics['avg_duration_min'] > 0) {
        buffer.writeln('  Avg Duration: ${metrics['avg_duration_min'].toStringAsFixed(0)}min');
      }
    }

    _showNotification(buffer.toString());
  }

  /// Show unvalidated events for confirmation
  Future<void> _showUnvalidatedEvents(EventExtractionService eventService) async {
    final userId = SupabaseService.instance.userId;
    if (userId == null) return;

    final events = await eventService.getUnvalidatedEvents(userId);

    if (events.isEmpty) {
      _showNotification('No events need validation');
      return;
    }

    _showNotification('Found ${events.length} unvalidated events. Validation UI coming soon!');
  }

  /// /context - Manage user facts for intelligence enrichment
  Future<void> _handleContext(String command) async {
    final parts = command.split(RegExp(r'\s+'));

    // Just "/context" - show all facts
    if (parts.length == 1) {
      await _showContextFacts();
      return;
    }

    final subCommand = parts[1].toLowerCase();

    switch (subCommand) {
      case 'add':
        if (parts.length < 3) {
          _showNotification('Usage: /context add [fact]');
          return;
        }
        // Join the rest as the fact text
        final fact = parts.sublist(2).join(' ').trim();
        await _addContextFact(fact);
        break;

      case 'list':
        await _showContextFacts();
        break;

      case 'remove':
        if (parts.length < 3) {
          _showNotification('Usage: /context remove [id]');
          return;
        }
        final id = parts[2];
        await _removeContextFact(id);
        break;

      case 'clear':
        await _clearAllContextFacts();
        break;

      default:
        _showNotification('Unknown context command. Use: add, list, remove, clear');
    }
  }

  /// Add a new context fact
  Future<void> _addContextFact(String factText) async {
    if (factText.isEmpty) {
      _showNotification('Fact cannot be empty');
      return;
    }

    // Try to infer category from the fact text
    String category = 'personal'; // default

    final lowerFact = factText.toLowerCase();
    if (lowerFact.contains('work') ||
        lowerFact.contains('job') ||
        lowerFact.contains('company') ||
        lowerFact.contains('manager') ||
        lowerFact.contains('team')) {
      category = 'work';
    } else if (lowerFact.contains('live') ||
               lowerFact.contains('location') ||
               lowerFact.contains('city') ||
               lowerFact.contains('country')) {
      category = 'location';
    } else if (RegExp(r'\b[A-Z][a-z]+\b').hasMatch(factText)) {
      // Has capitalized names - might be about people
      category = 'people';
    }

    try {
      final fact = await _userFactService.addFact(
        category: category,
        fact: factText,
      );

      _showNotification('✓ Added context ($category): ${fact.fact.length > 30 ? fact.fact.substring(0, 30) + '...' : fact.fact}');
    } catch (e) {
      _showNotification('Failed to add context fact');
      print('Error adding fact: $e');
    }
  }

  /// Show all context facts
  Future<void> _showContextFacts() async {
    final formattedFacts = await _userFactService.getFormattedFacts();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final colors = themeProvider.colors;

          return AlertDialog(
            backgroundColor: colors.modalBackground,
            title: Text(
              'CONTEXT',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
              child: SingleChildScrollView(
                child: Text(
                  formattedFacts,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: colors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(color: colors.accent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Remove a context fact by ID
  Future<void> _removeContextFact(String factId) async {
    try {
      // Check if this is a partial ID (first 8 chars)
      final facts = await _userFactService.getAllFacts();

      UserFact? targetFact;
      for (final fact in facts) {
        if (fact.id.startsWith(factId)) {
          targetFact = fact;
          break;
        }
      }

      if (targetFact == null) {
        _showNotification('Context fact not found');
        return;
      }

      await _userFactService.removeFact(targetFact.id);
      _showNotification('✓ Removed context fact');
    } catch (e) {
      _showNotification('Failed to remove context fact');
      print('Error removing fact: $e');
    }
  }

  /// Clear all context facts
  Future<void> _clearAllContextFacts() async {
    if (!context.mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final colors = themeProvider.colors;

          return AlertDialog(
            backgroundColor: colors.modalBackground,
            title: Text(
              'Clear All Context?',
              style: TextStyle(color: colors.textPrimary),
            ),
            content: Text(
              'This will remove all your context facts. This action cannot be undone.',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Clear All',
                  style: TextStyle(color: colors.accent),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed ?? false) {
      try {
        await _userFactService.clearAllFacts();
        _showNotification('✓ Cleared all context facts');
      } catch (e) {
        _showNotification('Failed to clear context facts');
        print('Error clearing facts: $e');
      }
    }
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
