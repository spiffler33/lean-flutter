import 'package:flutter_test/flutter_test.dart';
import 'lib/services/anthropic_service.dart';

void main() {
  test('Improved enrichment generates meaningful themes', () async {
    final service = AnthropicService();

    // Test entry 1: Framework decision
    final entry1 = """Should I switch to the new framework? It's faster but means rewriting everything. The team prefers stability but performance matters.""";

    final enrichment1 = await service.generateEnrichment(entry1, '1');
    print('\n=== Entry 1 ===');
    print('Content: $entry1');
    print('Emotion: ${enrichment1.emotion}');
    print('Themes: ${enrichment1.themes}');
    print('People: ${enrichment1.people}');
    print('Urgency: ${enrichment1.urgency}');
    print('Questions: ${enrichment1.questions}');

    // Expected: themes should include 'work', 'tech'
    // Should NOT include: 'Should', 'It'
    assert(!enrichment1.themes.contains('Should'));
    assert(!enrichment1.themes.contains('It'));

    // Test entry 2: Running achievement
    final entry2 = """Finally ran my first 10K today! My legs are sore but I'm so proud. Time was 52 minutes.""";

    final enrichment2 = await service.generateEnrichment(entry2, '2');
    print('\n=== Entry 2 ===');
    print('Content: $entry2');
    print('Emotion: ${enrichment2.emotion}');
    print('Themes: ${enrichment2.themes}');
    print('People: ${enrichment2.people}');
    print('Urgency: ${enrichment2.urgency}');

    // Expected: themes should include 'health', 'personal'
    // Should NOT include: 'Finally', 'My', 'Time'
    assert(!enrichment2.themes.contains('Finally'));
    assert(!enrichment2.themes.contains('My'));
    assert(!enrichment2.themes.contains('Time'));

    // Test entry 3: Work meeting with Kerem
    final entry3 = """Had a frustrating meeting with Kerem about the sprint deadline. The requirements keep changing and I need to refactor the entire auth system by Friday.""";

    final enrichment3 = await service.generateEnrichment(entry3, '3');
    print('\n=== Entry 3 ===');
    print('Content: $entry3');
    print('Emotion: ${enrichment3.emotion}');
    print('Themes: ${enrichment3.themes}');
    print('People: ${enrichment3.people}');
    print('Urgency: ${enrichment3.urgency}');
    print('Actions: ${enrichment3.actions}');

    // Expected: themes should include 'work', 'tech'
    // People should include 'Kerem'
    // Should NOT include: 'Had', 'Friday' as themes
    assert(!enrichment3.themes.contains('Had'));
    assert(!enrichment3.themes.contains('Friday'));

    // Check if Kerem is properly recognized as a person
    final hasKerem = enrichment3.people.any((p) => p['name'] == 'Kerem');
    assert(hasKerem, 'Kerem should be recognized as a person');

    print('\n✅ All tests passed! Enrichment quality improved.');
  });

  test('Name recognition filters out common words', () async {
    final service = AnthropicService();

    // Test with common words that should NOT be recognized as names
    final testEntry = """Finally, Should and Could went to meet Had and Was. Then My friend Bob came over. Tomorrow I'll see Sarah.""";

    final enrichment = await service.generateEnrichment(testEntry, 'test');
    print('\n=== Name Recognition Test ===');
    print('Content: $testEntry');
    print('People found: ${enrichment.people}');

    // Should only find real names: Bob and Sarah
    final names = enrichment.people.map((p) => p['name']).toList();

    // These should be found
    assert(names.contains('Bob'), 'Bob should be recognized');
    assert(names.contains('Sarah'), 'Sarah should be recognized');

    // These should NOT be found
    assert(!names.contains('Finally'), 'Finally should not be a name');
    assert(!names.contains('Should'), 'Should should not be a name');
    assert(!names.contains('Could'), 'Could should not be a name');
    assert(!names.contains('Had'), 'Had should not be a name');
    assert(!names.contains('Was'), 'Was should not be a name');
    assert(!names.contains('My'), 'My should not be a name');
    assert(!names.contains('Tomorrow'), 'Tomorrow should not be a name');

    print('✅ Name recognition working correctly!');
  });

  test('Theme detection is meaningful', () async {
    final service = AnthropicService();

    // Test various content types
    final tests = [
      {
        'content': 'Had a great workout at the gym, ran 5k in 25 minutes',
        'expected_themes': ['health'],
        'not_expected': ['Had'],
      },
      {
        'content': 'Working on refactoring the authentication system for our app',
        'expected_themes': ['work', 'tech'],
        'not_expected': ['Working'],
      },
      {
        'content': 'Reading a book about machine learning algorithms',
        'expected_themes': ['learning'],
        'not_expected': ['Reading'],
      },
      {
        'content': 'Meeting with my financial advisor about investment options',
        'expected_themes': ['finance'],
        'not_expected': ['Meeting'],
      },
    ];

    for (final test in tests) {
      final enrichment = await service.generateEnrichment(test['content'] as String, 'test');
      print('\n=== Theme Test ===');
      print('Content: ${test['content']}');
      print('Themes found: ${enrichment.themes}');

      // Check expected themes are found
      for (final expected in test['expected_themes'] as List<String>) {
        assert(enrichment.themes.contains(expected),
            'Expected theme "$expected" not found');
      }

      // Check bad themes are NOT found
      for (final notExpected in test['not_expected'] as List<String>) {
        assert(!enrichment.themes.contains(notExpected),
            'Bad theme "$notExpected" should not be present');
      }
    }

    print('\n✅ Theme detection working correctly!');
  });
}