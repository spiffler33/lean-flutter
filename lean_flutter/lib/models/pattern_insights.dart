/// Pattern insights model for analyzing user enrichment data
class PatternInsights {
  /// Emotional patterns by time periods
  final Map<String, EmotionPattern> emotionalRhythms;

  /// People mentioned and their patterns
  final List<PersonPattern> peoplePatterns;

  /// Distribution of themes as percentages
  final Map<String, double> themeDistribution;

  /// Entry counts by hour (0-23)
  final Map<String, int> temporalPatterns;

  /// Urgency distribution
  final UrgencyDistribution urgencyTrends;

  /// Period analyzed
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Total entries in period
  final int totalEntries;

  PatternInsights({
    required this.emotionalRhythms,
    required this.peoplePatterns,
    required this.themeDistribution,
    required this.temporalPatterns,
    required this.urgencyTrends,
    required this.periodStart,
    required this.periodEnd,
    required this.totalEntries,
  });

  /// Check if we have enough data for meaningful patterns
  bool get hasEnoughData => totalEntries >= 10;

  /// Convert to HTML display format
  String toHtml() {
    final buffer = StringBuffer();

    // Container
    buffer.writeln('<div class="patterns-container" style="font-family: monospace;">');

    // Header with period info
    buffer.writeln('<h3 style="color: #4CAF50; margin-bottom: 16px;">');
    buffer.writeln('Your patterns (${_formatPeriod()})');
    buffer.writeln('</h3>');

    // Show warning if not enough data
    if (!hasEnoughData) {
      buffer.writeln('<p style="color: #71717A; font-style: italic;">');
      buffer.writeln('Note: Patterns are preliminary (only $totalEntries entries). Keep writing for deeper insights.');
      buffer.writeln('</p>');
    }

    // Emotional Rhythms
    if (emotionalRhythms.isNotEmpty) {
      buffer.writeln('<section style="margin-bottom: 20px;">');
      buffer.writeln('<h4 style="color: #E4E4E7; margin-bottom: 8px;">Emotional Rhythms</h4>');

      emotionalRhythms.forEach((period, pattern) {
        if (pattern.topEmotions.isNotEmpty) {
          buffer.writeln('<div style="color: #A1A1AA; margin-left: 8px;">');
          buffer.write('$period: ');

          // Format top emotions with percentages
          final emotions = pattern.topEmotions.entries.take(2).map((e) {
            final percentage = (e.value * 100).toStringAsFixed(0);
            return '${e.key} ($percentage%)';
          }).join(', ');

          buffer.writeln(emotions);
          buffer.writeln('</div>');
        }
      });

      buffer.writeln('</section>');
    }

    // People & Context
    if (peoplePatterns.isNotEmpty) {
      buffer.writeln('<section style="margin-bottom: 20px;">');
      buffer.writeln('<h4 style="color: #E4E4E7; margin-bottom: 8px;">People & Context</h4>');

      for (final person in peoplePatterns.take(5)) {
        buffer.writeln('<div style="color: #A1A1AA; margin-left: 8px;">');
        buffer.write('${person.name} - ${person.mentions} mention');
        buffer.write(person.mentions > 1 ? 's' : '');

        if (person.commonThemes.isNotEmpty) {
          buffer.write(', mostly ${person.commonThemes.first}');
        }

        if (person.dominantEmotion != null && person.dominantEmotion != 'neutral') {
          buffer.write(' + ${person.dominantEmotion}');
        }

        buffer.writeln('</div>');
      }

      buffer.writeln('</section>');
    }

    // Theme Distribution
    if (themeDistribution.isNotEmpty) {
      buffer.writeln('<section style="margin-bottom: 20px;">');
      buffer.writeln('<h4 style="color: #E4E4E7; margin-bottom: 8px;">Your Focus</h4>');
      buffer.writeln('<div style="color: #A1A1AA; margin-left: 8px;">');

      final sortedThemes = themeDistribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final themeStrings = sortedThemes.map((e) {
        final percentage = (e.value * 100).toStringAsFixed(0);
        return '${e.key}: $percentage%';
      }).join(' | ');

      buffer.writeln(themeStrings);
      buffer.writeln('</div>');
      buffer.writeln('</section>');
    }

    // Peak Activity Times
    if (temporalPatterns.isNotEmpty) {
      buffer.writeln('<section style="margin-bottom: 20px;">');
      buffer.writeln('<h4 style="color: #E4E4E7; margin-bottom: 8px;">Peak Activity</h4>');
      buffer.writeln('<div style="color: #A1A1AA; margin-left: 8px;">');

      // Find top 3 most active hours
      final sortedHours = temporalPatterns.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (sortedHours.isNotEmpty) {
        final topHours = sortedHours.take(3).map((e) {
          final hour = int.parse(e.key);
          return _formatHour(hour);
        }).join(', ');

        buffer.writeln('Most active: $topHours');
      }

      buffer.writeln('</div>');
      buffer.writeln('</section>');
    }

    // Urgency Distribution
    if (urgencyTrends.hasData) {
      buffer.writeln('<section style="margin-bottom: 20px;">');
      buffer.writeln('<h4 style="color: #E4E4E7; margin-bottom: 8px;">Urgency Patterns</h4>');
      buffer.writeln('<div style="color: #A1A1AA; margin-left: 8px;">');

      final high = (urgencyTrends.highPercentage * 100).toStringAsFixed(0);
      final medium = (urgencyTrends.mediumPercentage * 100).toStringAsFixed(0);
      final low = (urgencyTrends.lowPercentage * 100).toStringAsFixed(0);

      buffer.writeln('high: $high% | medium: $medium% | low: $low%');
      buffer.writeln('</div>');
      buffer.writeln('</section>');
    }

    buffer.writeln('</div>');

    return buffer.toString();
  }

  String _formatPeriod() {
    final days = periodEnd.difference(periodStart).inDays;
    if (days <= 7) return 'last week';
    if (days <= 14) return 'last 2 weeks';
    if (days <= 30) return 'last 30 days';
    return 'last $days days';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12am';
    if (hour < 12) return '${hour}am';
    if (hour == 12) return '12pm';
    return '${hour - 12}pm';
  }
}

/// Emotional pattern for a time period
class EmotionPattern {
  /// Map of emotion to frequency (0.0 - 1.0)
  final Map<String, double> topEmotions;

  /// Total entries in this period
  final int entryCount;

  EmotionPattern({
    required this.topEmotions,
    required this.entryCount,
  });
}

/// Pattern for a person mentioned in entries
class PersonPattern {
  final String name;
  final int mentions;
  final List<String> commonThemes;
  final String? dominantEmotion;
  final double sentimentScore; // -1.0 to 1.0

  PersonPattern({
    required this.name,
    required this.mentions,
    required this.commonThemes,
    this.dominantEmotion,
    this.sentimentScore = 0.0,
  });
}

/// Distribution of urgency levels
class UrgencyDistribution {
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final int noneCount;

  UrgencyDistribution({
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.noneCount,
  });

  int get total => highCount + mediumCount + lowCount + noneCount;

  double get highPercentage => total > 0 ? highCount / total : 0.0;
  double get mediumPercentage => total > 0 ? mediumCount / total : 0.0;
  double get lowPercentage => total > 0 ? lowCount / total : 0.0;
  double get nonePercentage => total > 0 ? noneCount / total : 0.0;

  bool get hasData => total > 0;
}