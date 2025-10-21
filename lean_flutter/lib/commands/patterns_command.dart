import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/enrichment.dart';
import '../models/pattern_insights.dart';
import '../services/supabase_service.dart';

/// Command to analyze enrichment patterns over the last 30 days
class PatternsCommand {
  static PatternsCommand? _instance;
  final SupabaseService? _supabase;

  static PatternsCommand get instance {
    _instance ??= PatternsCommand._();
    return _instance!;
  }

  PatternsCommand._() : _supabase = SupabaseService.instance;

  /// Execute the patterns command and return HTML formatted insights
  Future<String> execute() async {
    try {
      // Check if user is authenticated
      if (!(_supabase?.isAuthenticated ?? false)) {
        return _formatError('Not connected to cloud. Sign in to see your patterns.');
      }

      // Fetch enrichments from the last 30 days
      final insights = await _analyzePatterns();

      // Return formatted HTML
      return insights.toHtml();
    } catch (e) {
      print('Error executing patterns command: $e');
      return _formatError('Failed to analyze patterns. Please try again.');
    }
  }

  /// Analyze patterns from enrichments
  Future<PatternInsights> _analyzePatterns() async {
    // Define the period (last 30 days)
    final now = DateTime.now();
    final periodStart = now.subtract(const Duration(days: 30));

    // Fetch enrichments from Supabase for the period
    final enrichments = await _fetchEnrichmentsForPeriod(periodStart, now);

    // Analyze emotional rhythms by time of day
    final emotionalRhythms = _analyzeEmotionalRhythms(enrichments);

    // Analyze people patterns
    final peoplePatterns = _analyzePeoplePatterns(enrichments);

    // Analyze theme distribution
    final themeDistribution = _analyzeThemeDistribution(enrichments);

    // Analyze temporal patterns (entry frequency by hour)
    final temporalPatterns = _analyzeTemporalPatterns(enrichments);

    // Analyze urgency distribution
    final urgencyTrends = _analyzeUrgencyTrends(enrichments);

    return PatternInsights(
      emotionalRhythms: emotionalRhythms,
      peoplePatterns: peoplePatterns,
      themeDistribution: themeDistribution,
      temporalPatterns: temporalPatterns,
      urgencyTrends: urgencyTrends,
      periodStart: periodStart,
      periodEnd: now,
      totalEntries: enrichments.length,
    );
  }

  /// Fetch enrichments from Supabase for the given period
  Future<List<Enrichment>> _fetchEnrichmentsForPeriod(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final response = await _supabase!.client
          .from('enrichments')
          .select()
          .eq('user_id', _supabase!.userId ?? '')
          .eq('processing_status', 'complete')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Enrichment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching enrichments: $e');
      return [];
    }
  }

  /// Analyze emotional patterns by time of day
  Map<String, EmotionPattern> _analyzeEmotionalRhythms(
    List<Enrichment> enrichments,
  ) {
    final rhythms = <String, EmotionPattern>{};

    // Define time periods
    final periods = {
      'morning': (5, 11), // 5am-11am
      'afternoon': (12, 16), // 12pm-4pm
      'evening': (17, 20), // 5pm-8pm
      'night': (21, 4), // 9pm-4am (wraps around)
    };

    for (final entry in periods.entries) {
      final periodName = entry.key;
      final (startHour, endHour) = entry.value;

      // Filter enrichments for this time period
      final periodEnrichments = enrichments.where((e) {
        // Convert from UTC to local time
        final localTime = e.createdAt.toLocal();
        final hour = localTime.hour;
        if (startHour > endHour) {
          // Night period (wraps around midnight)
          return hour >= startHour || hour <= endHour;
        } else {
          return hour >= startHour && hour <= endHour;
        }
      }).toList();

      if (periodEnrichments.isEmpty) continue;

      // Count emotions
      final emotionCounts = <String, int>{};
      for (final enrichment in periodEnrichments) {
        if (enrichment.emotion != null) {
          emotionCounts[enrichment.emotion!] =
              (emotionCounts[enrichment.emotion!] ?? 0) + 1;
        }
      }

      // Convert to percentages and sort
      final total = periodEnrichments.length;
      final topEmotions = <String, double>{};

      emotionCounts.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..take(3)
          ..forEach((entry) {
            topEmotions[entry.key] = entry.value / total;
          });

      rhythms[periodName] = EmotionPattern(
        topEmotions: topEmotions,
        entryCount: total,
      );
    }

    return rhythms;
  }

  /// Analyze patterns for people mentioned
  List<PersonPattern> _analyzePeoplePatterns(List<Enrichment> enrichments) {
    final personData = <String, _PersonData>{};

    for (final enrichment in enrichments) {
      for (final person in enrichment.people) {
        final name = person['name'] as String? ?? 'Unknown';
        final sentiment = person['sentiment'] as String? ?? 'neutral';

        if (!personData.containsKey(name)) {
          personData[name] = _PersonData();
        }

        final data = personData[name]!;
        data.mentions++;

        // Track emotions when this person is mentioned
        if (enrichment.emotion != null) {
          data.emotions[enrichment.emotion!] =
              (data.emotions[enrichment.emotion!] ?? 0) + 1;
        }

        // Track themes when this person is mentioned
        for (final theme in enrichment.themes) {
          data.themes[theme] = (data.themes[theme] ?? 0) + 1;
        }

        // Track sentiment
        if (sentiment == 'positive') {
          data.positiveCount++;
        } else if (sentiment == 'negative') {
          data.negativeCount++;
        }
      }
    }

    // Convert to PersonPattern objects
    final patterns = <PersonPattern>[];

    for (final entry in personData.entries) {
      final name = entry.key;
      final data = entry.value;

      // Find dominant emotion
      String? dominantEmotion;
      if (data.emotions.isNotEmpty) {
        final sorted = data.emotions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        dominantEmotion = sorted.first.key;
      }

      // Find common themes
      final commonThemes = <String>[];
      if (data.themes.isNotEmpty) {
        final sorted = data.themes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        commonThemes.addAll(sorted.take(2).map((e) => e.key));
      }

      // Calculate sentiment score
      double sentimentScore = 0.0;
      if (data.mentions > 0) {
        sentimentScore = (data.positiveCount - data.negativeCount) / data.mentions;
      }

      patterns.add(PersonPattern(
        name: name,
        mentions: data.mentions,
        commonThemes: commonThemes,
        dominantEmotion: dominantEmotion,
        sentimentScore: sentimentScore,
      ));
    }

    // Sort by mentions (descending)
    patterns.sort((a, b) => b.mentions.compareTo(a.mentions));

    return patterns;
  }

  /// Analyze distribution of themes
  Map<String, double> _analyzeThemeDistribution(List<Enrichment> enrichments) {
    final themeCounts = <String, int>{};
    int totalThemeOccurrences = 0;

    for (final enrichment in enrichments) {
      for (final theme in enrichment.themes) {
        themeCounts[theme] = (themeCounts[theme] ?? 0) + 1;
        totalThemeOccurrences++;
      }
    }

    // Convert to percentages
    final distribution = <String, double>{};
    for (final entry in themeCounts.entries) {
      distribution[entry.key] = entry.value / totalThemeOccurrences;
    }

    return distribution;
  }

  /// Analyze temporal patterns (entry frequency by hour)
  Map<String, int> _analyzeTemporalPatterns(List<Enrichment> enrichments) {
    final hourCounts = <String, int>{};

    for (final enrichment in enrichments) {
      // Convert from UTC to local time
      final localTime = enrichment.createdAt.toLocal();
      final hour = localTime.hour.toString();
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    return hourCounts;
  }

  /// Analyze urgency distribution
  UrgencyDistribution _analyzeUrgencyTrends(List<Enrichment> enrichments) {
    int highCount = 0;
    int mediumCount = 0;
    int lowCount = 0;
    int noneCount = 0;

    for (final enrichment in enrichments) {
      switch (enrichment.urgency) {
        case 'high':
          highCount++;
          break;
        case 'medium':
          mediumCount++;
          break;
        case 'low':
          lowCount++;
          break;
        case 'none':
        default:
          noneCount++;
          break;
      }
    }

    return UrgencyDistribution(
      highCount: highCount,
      mediumCount: mediumCount,
      lowCount: lowCount,
      noneCount: noneCount,
    );
  }

  /// Format error message as HTML
  String _formatError(String message) {
    return '''
<div class="patterns-container" style="font-family: monospace;">
  <p style="color: #EF4444;">$message</p>
</div>
''';
  }
}

/// Helper class to accumulate person data
class _PersonData {
  int mentions = 0;
  int positiveCount = 0;
  int negativeCount = 0;
  final Map<String, int> emotions = {};
  final Map<String, int> themes = {};
}