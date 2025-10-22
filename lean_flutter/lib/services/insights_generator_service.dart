import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/enrichment.dart';
import '../models/event.dart';
import '../models/pattern_models.dart';
import 'supabase_service.dart';
import 'user_fact_service.dart';

/// Service for generating personalized insights using LLM
class InsightsGeneratorService {
  final SupabaseClient _supabase;
  final String userId;

  InsightsGeneratorService(this._supabase, this.userId);

  /// Generate insights based on today's data, patterns, and streaks
  Future<String> generateInsights() async {
    print('[INSIGHTS] ====================================');
    print('[INSIGHTS] Starting insights generation');
    print('[INSIGHTS] User ID: $userId');
    print('[INSIGHTS] Timestamp: ${DateTime.now().toIso8601String()}');
    print('[INSIGHTS] ====================================');

    try {
      // 1. Gather today's data
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      print('[INSIGHTS] Step 1/6: Fetching today\'s data...');
      print('[INSIGHTS] Date range: ${startOfDay.toIso8601String()} to ${endOfDay.toIso8601String()}');

      final todayEnrichments = await _fetchEnrichments(startOfDay, endOfDay);
      final todayEvents = await _fetchEvents(startOfDay, endOfDay);

      print('[INSIGHTS] Today\'s data retrieved:');
      print('[INSIGHTS]   - ${todayEnrichments.length} enrichments');
      if (todayEnrichments.isNotEmpty) {
        final emotions = todayEnrichments.map((e) => e.emotion).where((e) => e != null).toSet();
        print('[INSIGHTS]     Emotions: ${emotions.join(', ')}');
      }
      print('[INSIGHTS]   - ${todayEvents.length} events');
      if (todayEvents.isNotEmpty) {
        final eventTypes = todayEvents.map((e) => e.type.value).toSet();
        print('[INSIGHTS]     Event types: ${eventTypes.join(', ')}');
      }

      // 2. Fetch recent data for context (last 7 days)
      final recentStart = startOfDay.subtract(const Duration(days: 7));
      print('[INSIGHTS] Step 2/6: Fetching recent data (7 days)...');
      print('[INSIGHTS] Date range: ${recentStart.toIso8601String()} to ${endOfDay.toIso8601String()}');

      final recentEnrichments = await _fetchEnrichments(recentStart, endOfDay);
      final recentEvents = await _fetchEvents(recentStart, endOfDay);

      print('[INSIGHTS] Recent data retrieved:');
      print('[INSIGHTS]   - ${recentEnrichments.length} enrichments');
      print('[INSIGHTS]   - ${recentEvents.length} events');

      // 3. Fetch active patterns
      print('[INSIGHTS] Step 3/6: Fetching recent patterns...');
      final patterns = await _fetchActivePatterns();

      print('[INSIGHTS] ${patterns.length} active patterns found:');
      for (final pattern in patterns) {
        print('[INSIGHTS]   - ${pattern.patternSignature} (${pattern.patternType.name}, confidence: ${(pattern.strengthMetrics.confidence * 100).toStringAsFixed(0)}%)');
        print('[INSIGHTS]     Trigger: ${pattern.triggerConditions}');
        print('[INSIGHTS]     Outcome: ${pattern.outcomeConditions}');

        // Validate pattern data for accuracy
        if (pattern.patternType == PatternType.correlation) {
          final trigger = pattern.triggerConditions as Map<String, dynamic>?;
          final outcome = pattern.outcomeConditions as Map<String, dynamic>?;
          if (trigger?['person'] == 'Sarah' && outcome?['emotion'] != null) {
            print('[INSIGHTS]     ⚠️ Sarah pattern detected: ${trigger?['person']} -> ${outcome?['emotion']}');
          }
        }
      }

      // 4. Fetch current streaks
      print('[INSIGHTS] Step 4/6: Fetching current streaks...');
      final streaks = await _fetchCurrentStreaks();

      print('[INSIGHTS] ${streaks.length} active streaks found:');
      for (final streak in streaks) {
        final streakName = streak.streakName ?? streak.streakType.name;
        print('[INSIGHTS]   - $streakName: ${streak.currentCount} days (best: ${streak.bestCount})');
      }

      // 5. Get user context facts
      print('[INSIGHTS] Step 5/6: Loading user context...');
      final userFactService = UserFactService();
      final contextFacts = await userFactService.getAllFacts();
      final contextString = userFactService.formatForLLM();

      print('[INSIGHTS] ${contextFacts.length} context facts loaded');
      if (contextFacts.isNotEmpty) {
        print('[INSIGHTS] Context preview: ${contextString.substring(0, contextString.length > 100 ? 100 : contextString.length)}...');
      }

      // 6. Call Edge Function for insights generation
      print('[INSIGHTS] Step 6/6: Calling Edge Function...');
      print('[INSIGHTS] Payload size estimate:');
      print('[INSIGHTS]   - Context: ${contextString.length} chars');
      print('[INSIGHTS]   - Today data: ${todayEnrichments.length + todayEvents.length} items');
      print('[INSIGHTS]   - Recent data: ${recentEnrichments.length + recentEvents.length} items');
      print('[INSIGHTS]   - Patterns: ${patterns.length} items');
      print('[INSIGHTS]   - Streaks: ${streaks.length} items');

      final insights = await _callInsightsEdgeFunction(
        todayEnrichments: todayEnrichments,
        todayEvents: todayEvents,
        recentEnrichments: recentEnrichments,
        recentEvents: recentEvents,
        patterns: patterns,
        streaks: streaks,
        userContext: contextString,
      );

      print('[INSIGHTS] ====================================');
      print('[INSIGHTS] ✅ Insights generated successfully');
      print('[INSIGHTS] Response length: ${insights.length} chars');
      print('[INSIGHTS] ====================================');

      return insights;

    } catch (e, stackTrace) {
      print('[INSIGHTS] ====================================');
      print('[INSIGHTS] ❌ ERROR generating insights');
      print('[INSIGHTS] Error: $e');
      print('[INSIGHTS] Stack trace: $stackTrace');
      print('[INSIGHTS] ====================================');

      // Return a fallback message
      return _generateFallbackInsights();
    }
  }

  /// Call the Edge Function to generate insights
  Future<String> _callInsightsEdgeFunction({
    required List<Enrichment> todayEnrichments,
    required List<Event> todayEvents,
    required List<Enrichment> recentEnrichments,
    required List<Event> recentEvents,
    required List<IntelligencePattern> patterns,
    required List<UserStreak> streaks,
    required String userContext,
  }) async {
    print('[INSIGHTS-API] Preparing Edge Function request...');

    try {
      final requestBody = {
        'userId': userId,
        'userContext': userContext,
        'todayData': {
          'enrichments': todayEnrichments.map((e) => {
            'emotion': e.emotion,
            'themes': e.themes,
            'people': e.people,
            'urgency': e.urgency,
            'summary': e.summary,
            'createdAt': e.createdAt.toIso8601String(),
          }).toList(),
          'events': todayEvents.map((e) => {
            'type': e.type.value,
            'subtype': e.subtype,
            'metrics': e.metrics,
            'createdAt': e.createdAt.toIso8601String(),
          }).toList(),
        },
        'recentData': {
          'enrichments': recentEnrichments.map((e) => {
            'emotion': e.emotion,
            'themes': e.themes,
            'people': e.people,
            'urgency': e.urgency,
            'createdAt': e.createdAt.toIso8601String(),
          }).toList(),
          'events': recentEvents.map((e) => {
            'type': e.type.value,
            'subtype': e.subtype,
            'metrics': e.metrics,
            'createdAt': e.createdAt.toIso8601String(),
          }).toList(),
        },
        'patterns': patterns.map((p) {
          // Log each pattern being sent to Edge Function
          final patternData = {
            'type': p.patternType.name,
            'signature': p.patternSignature,
            'triggerConditions': p.triggerConditions,
            'outcomeConditions': p.outcomeConditions,
            'confidence': p.strengthMetrics.confidence,
            'occurrences': p.strengthMetrics.occurrences,
          };

          print('[INSIGHTS-API] Pattern to send: ${p.patternSignature}');
          print('[INSIGHTS-API]   Type: ${patternData['type']}');
          print('[INSIGHTS-API]   Trigger: ${patternData['triggerConditions']}');
          print('[INSIGHTS-API]   Outcome: ${patternData['outcomeConditions']}');
          print('[INSIGHTS-API]   Confidence: ${((patternData['confidence'] as double) * 100).toStringAsFixed(0)}%');

          // Validate Sarah patterns specifically
          if (p.patternType == PatternType.correlation) {
            final trigger = p.triggerConditions as Map<String, dynamic>?;
            final outcome = p.outcomeConditions as Map<String, dynamic>?;
            if (trigger?['person'] == 'Sarah') {
              print('[INSIGHTS-API]   ⚠️ SARAH PATTERN: ${trigger?['person']} -> ${outcome?['emotion']} (should be negative/stressed)');
            }
          }

          return patternData;
        }).toList(),
        'streaks': streaks.map((s) => {
          'type': s.streakType.name,
          'name': s.streakName,
          'currentCount': s.currentCount,
          'bestCount': s.bestCount,
          'isActive': s.isActive,
          'lastEntryDate': s.lastEntryDate?.toIso8601String(),
        }).toList(),
      };

      print('[INSIGHTS-API] Invoking Edge Function: generate-insights');
      print('[INSIGHTS-API] Request body size: ${requestBody.toString().length} chars');

      final response = await _supabase.functions.invoke(
        'generate-insights',
        body: requestBody,
      );

      print('[INSIGHTS-API] Edge Function response received');
      print('[INSIGHTS-API] Response status: ${response.status}');
      print('[INSIGHTS-API] Response has data: ${response.data != null}');

      if (response.data != null) {
        print('[INSIGHTS-API] Response data keys: ${response.data.keys.join(', ')}');

        if (response.data['success'] != null) {
          print('[INSIGHTS-API] Success flag: ${response.data['success']}');
        }

        if (response.data['error'] != null) {
          print('[INSIGHTS-API] Error in response: ${response.data['error']}');
        }

        if (response.data['insights'] != null) {
          final insights = response.data['insights'] as String;
          print('[INSIGHTS-API] ✅ Insights retrieved (${insights.length} chars)');
          return insights;
        }
      }

      print('[INSIGHTS-API] ❌ Invalid response structure');
      throw Exception('Invalid response from Edge Function: missing insights field');

    } catch (e) {
      print('[INSIGHTS-API] ❌ Edge Function error: $e');
      throw e;
    }
  }

  /// Fetch enrichments for a date range
  Future<List<Enrichment>> _fetchEnrichments(DateTime start, DateTime end) async {
    try {
      print('[INSIGHTS-DB] Fetching enrichments...');
      print('[INSIGHTS-DB]   Table: enrichments');
      print('[INSIGHTS-DB]   User ID: $userId');
      print('[INSIGHTS-DB]   Date range: ${start.toIso8601String()} to ${end.toIso8601String()}');

      final response = await _supabase
          .from('enrichments')
          .select()
          .eq('user_id', userId)
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      final enrichments = (response as List<dynamic>)
          .map((json) => Enrichment.fromJson(json as Map<String, dynamic>))
          .toList();

      print('[INSIGHTS-DB] ✅ Retrieved ${enrichments.length} enrichments');
      return enrichments;

    } catch (e) {
      print('[INSIGHTS-DB] ❌ Error fetching enrichments: $e');
      return [];
    }
  }

  /// Fetch events for a date range
  Future<List<Event>> _fetchEvents(DateTime start, DateTime end) async {
    try {
      print('[INSIGHTS-DB] Fetching events...');
      print('[INSIGHTS-DB]   Table: events');
      print('[INSIGHTS-DB]   User ID: $userId');
      print('[INSIGHTS-DB]   Date range: ${start.toIso8601String()} to ${end.toIso8601String()}');

      final response = await _supabase
          .from('events')
          .select()
          .eq('user_id', userId)
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      final events = (response as List<dynamic>)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();

      print('[INSIGHTS-DB] ✅ Retrieved ${events.length} events');
      return events;

    } catch (e) {
      print('[INSIGHTS-DB] ❌ Error fetching events: $e');
      return [];
    }
  }

  /// Fetch active patterns
  Future<List<IntelligencePattern>> _fetchActivePatterns() async {
    try {
      print('[INSIGHTS-DB] Fetching active patterns...');
      print('[INSIGHTS-DB]   Table: intelligence_patterns');
      print('[INSIGHTS-DB]   User ID: $userId');
      print('[INSIGHTS-DB]   Order by: updated_at DESC');

      final response = await _supabase
          .from('intelligence_patterns')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(10);

      final patterns = (response as List<dynamic>)
          .map((json) => IntelligencePattern.fromJson(json as Map<String, dynamic>))
          .toList();

      print('[INSIGHTS-DB] ✅ Retrieved ${patterns.length} patterns (limit: 10)');
      return patterns;

    } catch (e) {
      print('[INSIGHTS-DB] ❌ Error fetching patterns: $e');
      return [];
    }
  }

  /// Fetch current streaks
  Future<List<UserStreak>> _fetchCurrentStreaks() async {
    try {
      print('[INSIGHTS-DB] Fetching active streaks...');
      print('[INSIGHTS-DB]   Table: user_streaks');
      print('[INSIGHTS-DB]   User ID: $userId');
      print('[INSIGHTS-DB]   Filter: is_active = true');

      final response = await _supabase
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('current_count', ascending: false);

      final streaks = (response as List<dynamic>)
          .map((json) => UserStreak.fromJson(json as Map<String, dynamic>))
          .toList();

      print('[INSIGHTS-DB] ✅ Retrieved ${streaks.length} active streaks');
      return streaks;

    } catch (e) {
      print('[INSIGHTS-DB] ❌ Error fetching streaks: $e');
      return [];
    }
  }

  /// Generate fallback insights when Edge Function fails
  String _generateFallbackInsights() {
    return '''Unable to generate insights.

Run /analyze first to detect patterns.
Then run /insights again.

Alternative commands:
- /patterns: View detected patterns directly
- /streaks: Check active streaks
- /events: Review recent events''';
  }
}