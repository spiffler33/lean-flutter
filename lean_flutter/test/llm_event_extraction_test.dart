import 'package:test/test.dart';

/// Test cases for LLM-based event extraction via Edge Function
/// These are the examples that regex failed on, now handled by Claude
void main() {
  group('LLM Event Extraction Test Cases', () {
    // These test cases demonstrate what the LLM should extract
    // Actual testing would require mocking the Edge Function response

    test('Should extract coffee count from natural language', () {
      final testCases = [
        TestCase(
          input: 'Coffee #3 already and it\'s not even noon',
          expected: EventExpectation(
            type: 'consumption',
            subtype: 'coffee',
            metrics: {'count': 3},
            confidence: 0.95,
            reason: 'Clear count (#3) with present tense context',
          ),
        ),
        TestCase(
          input: 'Had my third coffee of the day',
          expected: EventExpectation(
            type: 'consumption',
            subtype: 'coffee',
            metrics: {'count': 3},
            confidence: 0.90,
            reason: 'Explicit count (third) in past tense',
          ),
        ),
        TestCase(
          input: 'Double espresso this morning, then another at lunch',
          expected: EventExpectation(
            type: 'consumption',
            subtype: 'coffee',
            metrics: {'count': 2},
            confidence: 0.85,
            reason: 'Multiple coffee instances mentioned',
          ),
        ),
      ];

      for (final testCase in testCases) {
        print('Input: "${testCase.input}"');
        print('Expected: ${testCase.expected}');
      }
    });

    test('Should extract swimming events with various phrasings', () {
      final testCases = [
        TestCase(
          input: 'Swam 40 laps in 35 minutes at the pool',
          expected: EventExpectation(
            type: 'exercise',
            subtype: 'swim',
            metrics: {'laps': 40, 'duration_min': 35},
            confidence: 1.0,
            reason: 'Explicit metrics with past tense verb',
          ),
        ),
        TestCase(
          input: 'Morning swim session, felt great',
          expected: EventExpectation(
            type: 'exercise',
            subtype: 'swim',
            metrics: {},
            confidence: 0.75,
            reason: 'Past activity implied but no metrics',
          ),
        ),
        TestCase(
          input: 'First swim in months',
          expected: EventExpectation(
            type: 'exercise',
            subtype: 'swim',
            metrics: {},
            confidence: 0.65,
            reason: 'Ambiguous - could be referencing past or recent activity',
          ),
        ),
        TestCase(
          input: 'Planning to swim tomorrow',
          expected: null, // Should NOT extract
            reason: 'Future intent, not completed activity',
          ),
      ];

      for (final testCase in testCases) {
        print('Input: "${testCase.input}"');
        print('Expected: ${testCase.expected}');
      }
    });

    test('Should handle complex exercise variations', () {
      final testCases = [
        TestCase(
          input: 'Did a quick 5k run in the park',
          expected: EventExpectation(
            type: 'exercise',
            subtype: 'run',
            metrics: {'distance_km': 5},
            confidence: 0.95,
            reason: 'Clear distance with past tense',
          ),
        ),
        TestCase(
          input: 'Yoga class this morning - 90 minute vinyasa',
          expected: EventExpectation(
            type: 'exercise',
            subtype: 'yoga',
            metrics: {'duration_min': 90},
            confidence: 0.90,
            reason: 'Specific duration with time context',
          ),
        ),
        TestCase(
          input: 'Hit the gym hard today - legs and core',
          expected: EventExpectation(
            type: 'exercise',
            subtype: 'gym',
            metrics: {},
            confidence: 0.80,
            reason: 'Clear past activity but no metrics',
          ),
        ),
      ];

      for (final testCase in testCases) {
        print('Input: "${testCase.input}"');
        print('Expected: ${testCase.expected}');
      }
    });

    test('Should extract spending with context', () {
      final testCases = [
        TestCase(
          input: 'Groceries ran me \$127 at Whole Foods',
          expected: EventExpectation(
            type: 'spend',
            subtype: 'groceries',
            metrics: {'amount': 127, 'currency': 'USD'},
            confidence: 0.95,
            reason: 'Clear amount with category context',
          ),
        ),
        TestCase(
          input: 'Dropped 50 bucks on dinner',
          expected: EventExpectation(
            type: 'spend',
            subtype: 'dinner',
            metrics: {'amount': 50, 'currency': 'USD'},
            confidence: 0.90,
            reason: 'Colloquial but clear spending',
          ),
        ),
        TestCase(
          input: 'That coffee was expensive',
          expected: null, // No specific amount
            reason: 'No quantifiable metrics',
          ),
      ];

      for (final testCase in testCases) {
        print('Input: "${testCase.input}"');
        print('Expected: ${testCase.expected}');
      }
    });

    test('Should handle meeting extraction with participants', () {
      final testCases = [
        TestCase(
          input: '2 hour strategy meeting with Sarah and Mike',
          expected: EventExpectation(
            type: 'meeting',
            subtype: 'strategy',
            metrics: {'duration_min': 120, 'attendees': ['Sarah', 'Mike']},
            confidence: 0.95,
            reason: 'Clear duration and attendees',
          ),
        ),
        TestCase(
          input: 'Quick sync with the team',
          expected: EventExpectation(
            type: 'meeting',
            subtype: 'sync',
            metrics: {},
            confidence: 0.70,
            reason: 'Meeting implied but no specifics',
          ),
        ),
        TestCase(
          input: 'Scheduled a meeting for next week',
          expected: null, // Future event
            reason: 'Future scheduling, not completed',
          ),
      ];

      for (final testCase in testCases) {
        print('Input: "${testCase.input}"');
        print('Expected: ${testCase.expected}');
      }
    });

    test('Should distinguish between completed and intended activities', () {
      final completedVsIntended = [
        // Completed activities (should extract)
        'Ran 5 miles this morning',
        'Just finished my workout',
        'Had three coffees already',
        'Spent \$200 on groceries',
        'Slept for 8 hours last night',

        // Intended activities (should NOT extract)
        'Going to run 5 miles tomorrow',
        'Planning to hit the gym',
        'Need to cut back on coffee',
        'Budget \$200 for groceries',
        'Hope to get 8 hours of sleep',
      ];

      print('Completed activities (SHOULD extract):');
      for (final text in completedVsIntended.take(5)) {
        print('  ✓ "$text"');
      }

      print('\nIntended activities (should NOT extract):');
      for (final text in completedVsIntended.skip(5)) {
        print('  ✗ "$text"');
      }
    });

    test('Should handle edge cases that confused regex', () {
      final edgeCases = [
        TestCase(
          input: 'Coffee break with the team, probably my 4th today',
          expected: EventExpectation(
            type: 'consumption',
            subtype: 'coffee',
            metrics: {'count': 4},
            confidence: 0.75,
            reason: 'Uncertain count ("probably") but likely completed',
          ),
        ),
        TestCase(
          input: 'Marathon training: 18 miles in 2:45',
          expected: EventExpectation(
            type: 'exercise',
            subtype: 'run',
            metrics: {'distance_mi': 18, 'duration_min': 165},
            confidence: 0.95,
            reason: 'Clear metrics with training context',
          ),
        ),
        TestCase(
          input: 'Swim → Bike → Run. First triathlon!',
          expected: EventExpectation(
            type: 'exercise',
            subtype: 'triathlon',
            metrics: {},
            confidence: 0.85,
            reason: 'Multiple activities as single event',
          ),
        ),
      ];

      for (final testCase in edgeCases) {
        print('Input: "${testCase.input}"');
        print('Expected: ${testCase.expected}');
      }
    });
  });
}

class TestCase {
  final String input;
  final EventExpectation? expected;
  final String reason;

  TestCase({
    required this.input,
    this.expected,
    required this.reason,
  });
}

class EventExpectation {
  final String type;
  final String subtype;
  final Map<String, dynamic> metrics;
  final double confidence;
  final String reason;

  EventExpectation({
    required this.type,
    required this.subtype,
    required this.metrics,
    required this.confidence,
    required this.reason,
  });

  @override
  String toString() {
    return 'Event(type: $type.$subtype, confidence: ${confidence.toStringAsFixed(2)}, metrics: $metrics) - $reason';
  }
}