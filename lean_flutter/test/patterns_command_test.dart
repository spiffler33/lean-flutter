import 'package:flutter_test/flutter_test.dart';
import 'package:lean_flutter/models/enrichment.dart';
import 'package:lean_flutter/models/pattern_insights.dart';

void main() {
  group('PatternsCommand Tests', () {
    test('Pattern insights model formats HTML correctly', () {
      // Create sample enrichments based on requirements
      final now = DateTime.now();

      // Create pattern insights with test data
      final insights = PatternInsights(
        emotionalRhythms: {
          'morning': EmotionPattern(
            topEmotions: {'anxious': 0.45, 'focused': 0.30},
            entryCount: 20,
          ),
          'evening': EmotionPattern(
            topEmotions: {'contemplative': 0.50, 'tired': 0.35},
            entryCount: 15,
          ),
        },
        peoplePatterns: [
          PersonPattern(
            name: 'Sarah',
            mentions: 12,
            commonThemes: ['work'],
            dominantEmotion: 'frustrated',
            sentimentScore: -0.3,
          ),
          PersonPattern(
            name: 'Mike',
            mentions: 8,
            commonThemes: ['work'],
            dominantEmotion: 'anxious',
            sentimentScore: -0.1,
          ),
        ],
        themeDistribution: {
          'work': 0.45,
          'personal': 0.30,
          'health': 0.25,
        },
        temporalPatterns: {
          '9': 15,
          '14': 12,
          '20': 8,
        },
        urgencyTrends: UrgencyDistribution(
          highCount: 15,
          mediumCount: 10,
          lowCount: 5,
          noneCount: 0,
        ),
        periodStart: now.subtract(const Duration(days: 30)),
        periodEnd: now,
        totalEntries: 30,
      );

      // Generate HTML
      final html = insights.toHtml();

      // Verify HTML contains expected sections
      expect(html, contains('Your patterns'));
      expect(html, contains('Emotional Rhythms'));
      expect(html, contains('morning: anxious (45%), focused (30%)'));
      expect(html, contains('evening: contemplative (50%), tired (35%)'));

      expect(html, contains('People & Context'));
      expect(html, contains('Sarah - 12 mentions, mostly work + frustrated'));
      expect(html, contains('Mike - 8 mentions, mostly work + anxious'));

      expect(html, contains('Your Focus'));
      expect(html, contains('work: 45%'));
      expect(html, contains('personal: 30%'));
      expect(html, contains('health: 25%'));

      expect(html, contains('Peak Activity'));
      expect(html, contains('Urgency Patterns'));
      expect(html, contains('high: 50% | medium: 33% | low: 17%'));
    });

    test('Pattern insights with minimal data shows warning', () {
      final insights = PatternInsights(
        emotionalRhythms: {},
        peoplePatterns: [],
        themeDistribution: {},
        temporalPatterns: {},
        urgencyTrends: UrgencyDistribution(
          highCount: 0,
          mediumCount: 0,
          lowCount: 0,
          noneCount: 0,
        ),
        periodStart: DateTime.now().subtract(const Duration(days: 30)),
        periodEnd: DateTime.now(),
        totalEntries: 3,
      );

      final html = insights.toHtml();

      // Should show preliminary patterns warning
      expect(html, contains('Note: Patterns are preliminary (only 3 entries)'));
    });

    test('EmotionPattern calculates correctly', () {
      final pattern = EmotionPattern(
        topEmotions: {
          'anxious': 0.4,
          'focused': 0.3,
          'tired': 0.2,
        },
        entryCount: 10,
      );

      expect(pattern.topEmotions['anxious'], 0.4);
      expect(pattern.topEmotions['focused'], 0.3);
      expect(pattern.topEmotions['tired'], 0.2);
      expect(pattern.entryCount, 10);
    });

    test('PersonPattern stores correct attributes', () {
      final person = PersonPattern(
        name: 'Alice',
        mentions: 5,
        commonThemes: ['work', 'personal'],
        dominantEmotion: 'positive',
        sentimentScore: 0.6,
      );

      expect(person.name, 'Alice');
      expect(person.mentions, 5);
      expect(person.commonThemes, ['work', 'personal']);
      expect(person.dominantEmotion, 'positive');
      expect(person.sentimentScore, 0.6);
    });

    test('UrgencyDistribution calculates percentages correctly', () {
      final distribution = UrgencyDistribution(
        highCount: 10,
        mediumCount: 15,
        lowCount: 20,
        noneCount: 5,
      );

      expect(distribution.total, 50);
      expect(distribution.highPercentage, 0.2); // 10/50
      expect(distribution.mediumPercentage, 0.3); // 15/50
      expect(distribution.lowPercentage, 0.4); // 20/50
      expect(distribution.nonePercentage, 0.1); // 5/50
      expect(distribution.hasData, true);
    });

    test('UrgencyDistribution handles empty data', () {
      final distribution = UrgencyDistribution(
        highCount: 0,
        mediumCount: 0,
        lowCount: 0,
        noneCount: 0,
      );

      expect(distribution.total, 0);
      expect(distribution.highPercentage, 0.0);
      expect(distribution.mediumPercentage, 0.0);
      expect(distribution.lowPercentage, 0.0);
      expect(distribution.nonePercentage, 0.0);
      expect(distribution.hasData, false);
    });
  });
}