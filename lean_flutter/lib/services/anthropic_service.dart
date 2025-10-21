import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/enrichment.dart';
import '../models/user_fact.dart';
import '../config/app_config.dart';
import '../config/supabase_config.dart';
import 'user_fact_service.dart';
import 'supabase_service.dart';

/// Service for calling Anthropic Claude API for entry enrichment via Supabase Edge Function
class AnthropicService {
  // Use Supabase Edge Function URL instead of direct API
  static String get _baseUrl => '${SupabaseConfig.url}/functions/v1/enrich-entry';

  final Dio _dio;
  final UserFactService _userFactService = UserFactService();

  AnthropicService() : _dio = Dio() {
    // For Edge Function, we use the Supabase anon key for authentication
    _dio.options.headers = {
      'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      'Content-Type': 'application/json',
    };
  }

  /// Generate enrichment for an entry using Claude via Supabase Edge Function
  Future<Enrichment> generateEnrichment(String entryText, String entryId) async {
    // Check if Supabase is properly configured
    if (!SupabaseConfig.isConfigured) {
      print('⚠️ Supabase not configured, using mock enrichment');
      return _generateMockEnrichment(entryText, entryId);
    }

    try {
      // Get user context facts
      final userFacts = await _userFactService.getAllFacts();
      final contextString = _buildUserContext(userFacts);

      // Call Supabase Edge Function (which will call Claude API server-side)
      final response = await _dio.post(
        _baseUrl,
        data: {
          'entryText': entryText,
          'entryId': entryId,
          'userContext': contextString,
        },
      );

      // Check if the Edge Function was successful
      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Edge Function error');
      }

      // Extract the enrichment data from the Edge Function response
      final enrichmentData = response.data['enrichment'] as Map<String, dynamic>;

      // The Edge Function already formats the data correctly, so we can directly use it
      // Parse people list (already formatted as list from Edge Function)
      final peopleList = List<Map<String, dynamic>>.from(enrichmentData['people'] ?? []);

      // Parse questions list (already formatted as list from Edge Function)
      final questionsList = List<Map<String, dynamic>>.from(enrichmentData['questions'] ?? []);

      // Parse decisions list (already formatted as list from Edge Function)
      final decisionsList = List<Map<String, dynamic>>.from(enrichmentData['decisions'] ?? []);

      // Create Enrichment object
      return Enrichment(
        entryId: enrichmentData['entryId'] is int
            ? enrichmentData['entryId']
            : int.tryParse(enrichmentData['entryId'].toString()),
        emotion: enrichmentData['emotion'] ?? 'neutral',
        themes: List<String>.from(enrichmentData['themes'] ?? []),
        people: peopleList,
        urgency: enrichmentData['urgency'] ?? 'none',
        actions: List<String>.from(enrichmentData['actions'] ?? []),
        questions: questionsList,
        decisions: decisionsList,
        confidenceScores: Map<String, double>.from(
          enrichmentData['confidenceScores']?.map((k, v) =>
            MapEntry(k.toString(), (v as num).toDouble())) ?? {}
        ),
        processingStatus: enrichmentData['processingStatus'] ?? 'completed',
        createdAt: enrichmentData['createdAt'] != null
            ? DateTime.parse(enrichmentData['createdAt'])
            : DateTime.now(),
        updatedAt: enrichmentData['updatedAt'] != null
            ? DateTime.parse(enrichmentData['updatedAt'])
            : DateTime.now(),
      );

    } catch (e) {
      print('❌ Edge Function error: $e');
      print('⚠️ Falling back to mock enrichment');
      return _generateMockEnrichment(entryText, entryId);
    }
  }

  /// Build user context string from facts
  String _buildUserContext(List<UserFact> facts) {
    if (facts.isEmpty) return '';

    final buffer = StringBuffer('User Context:\n');
    for (final fact in facts) {
      buffer.writeln('- ${fact.fact}');
    }
    return buffer.toString();
  }

  /// Build the enrichment prompt for Claude
  String _buildEnrichmentPrompt(String entryText, String contextString) {
    return '''
$contextString

You are analyzing a personal journal entry to extract metadata. Be accurate and thoughtful.

Entry: "$entryText"

Extract structured information and respond ONLY with valid JSON:
{
  "emotion": "string",  // Dominant emotional state from: frustrated, anxious, excited, content, calm, energized, tired, sad, angry, overwhelmed, focused, grateful, contemplative, curious, scattered, accomplished, lonely, bored, neutral
  "themes": ["string"],  // 1-3 main topics from: work, personal, health, relationships, finance, creative, tech, learning, leisure, reflection
  "people": {"name": "context"},  // ONLY proper human names (like Sarah, Mike, Kerem). NOT words like "She", "Down", "Celebrated", "Time", "It", "Quarterly", "Credit", "Between"
  "urgency": "string",  // Actual urgency level: low, medium, high, none
  "actions": ["string"],  // Actionable items they need to do (not past actions)
  "questions": {"question": "type"},  // Questions posed
  "decisions": {"decision": "status"},  // Decision points
  "confidence_scores": {
    "emotion": 0.0-1.0,
    "themes": 0.0-1.0,
    "people": 0.0-1.0,
    "urgency": 0.0-1.0
  }
}

Critical Instructions:
- For emotion: Choose based on the overall tone and feeling expressed
  * "Finally hit my goal weight" + "proud" → excited or accomplished
  * "Quiet Sunday" + "no urgency" → calm or content
  * "Production is down" + "ASAP" → anxious or frustrated
- For themes: Choose the main subject area, not random keywords
- For people: ONLY extract actual proper names of humans. Never include:
  * Common English words (Time, Down, Need, Between, Credit)
  * Tech terms (Python, Kubernetes, Rust, Coursera)
  * Verbs/adjectives (Celebrated, Started, Built, Quiet)
  * Pronouns (She, It, We)
- For urgency: Base on actual time pressure, not just presence of time words

Return ONLY the JSON, no other text.
''';
  }

  /// Generate mock enrichment (fallback when API unavailable)
  /// Basic pattern matching as fallback - not as good as real AI
  Enrichment _generateMockEnrichment(String entryText, String entryId) {
    final text = entryText.toLowerCase();

    // Basic emotion detection
    String emotion = 'neutral';
    if (text.contains('excited') || text.contains('proud') || text.contains('finally hit') ||
        text.contains('goal') || text.contains('amazing')) {
      emotion = 'excited';
    } else if (text.contains('frustrated') || text.contains('failed') ||
               text.contains('furious') || text.contains('angry')) {
      emotion = 'frustrated';
    } else if (text.contains('anxious') || text.contains('worried') ||
               text.contains('stress') || text.contains('breathing down')) {
      emotion = 'anxious';
    } else if (text.contains('quiet') || text.contains('calm') ||
               text.contains('peaceful') || text.contains('no urgency')) {
      emotion = 'calm';
    } else if (text.contains('sad') || text.contains('worse') ||
               text.contains('wish')) {
      emotion = 'contemplative';
    }

    // Basic theme detection
    List<String> themes = [];
    if (text.contains('work') || text.contains('deadline') || text.contains('client') ||
        text.contains('deployment') || text.contains('meeting')) {
      themes.add('work');
    }
    if (text.contains('mom') || text.contains('dad') || text.contains('family')) {
      themes.add('relationships');
    }
    if (text.contains('weight') || text.contains('run') || text.contains('health') ||
        text.contains('pounds')) {
      themes.add('health');
    }
    if (text.contains('kubernetes') || text.contains('deployment') || text.contains('database') ||
        text.contains('script') || text.contains('ci/cd')) {
      themes.add('tech');
    }
    if (text.contains('budget') || text.contains('credit card') || text.contains('rent') ||
        text.contains('\$')) {
      themes.add('finance');
    }
    if (themes.isEmpty) {
      themes.add('personal');
    }

    // Basic urgency detection
    String urgency = 'none';
    if (text.contains('asap') || text.contains('immediately') || text.contains('urgent') ||
        text.contains('production is down')) {
      urgency = 'high';
    } else if (text.contains('deadline') || text.contains('by friday') ||
               text.contains('next month')) {
      urgency = 'medium';
    } else if (text.contains('maybe') || text.contains('no urgency')) {
      urgency = 'low';
    }

    // Basic people extraction - only obvious names
    List<Map<String, dynamic>> people = [];
    final knownNames = ['Sarah', 'Mike', 'Mom', 'Dad', 'Alex', 'Kerem', 'CEO'];
    for (final name in knownNames) {
      if (entryText.contains(name)) {
        people.add({'name': name, 'context': 'mentioned'});
      }
    }

    return Enrichment(
      entryId: int.tryParse(entryId),
      emotion: emotion,
      themes: themes.take(3).toList(), // Limit to 3
      people: people,
      urgency: urgency,
      actions: [],
      questions: [],
      decisions: [],
      confidenceScores: {
        'emotion': 0.5,
        'themes': 0.5,
        'people': 0.5,
        'urgency': 0.5,
      },
      processingStatus: 'completed',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}