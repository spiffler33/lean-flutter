import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../models/enrichment.dart';

/// Service for event statistics and validation
/// Event extraction now happens via LLM in the EnrichmentService
class EventExtractionService {
  final SupabaseClient _supabase;

  EventExtractionService(this._supabase);

  /// Get event statistics for a user
  Future<Map<String, dynamic>> getEventStats(String userId, {int days = 30}) async {
    try {
      final response = await _supabase
          .rpc('get_event_stats', params: {'p_user_id': userId, 'p_days': days});

      return {
        'stats': response as List<dynamic>,
        'period_days': days,
      };
    } catch (e) {
      print('Error getting event stats: $e');
      return {'stats': [], 'period_days': days};
    }
  }

  /// Get recent events for display
  Future<List<Event>> getRecentEvents(String userId, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting recent events: $e');
      return [];
    }
  }

  /// Get unvalidated events for user confirmation
  Future<List<Event>> getUnvalidatedEvents(String userId) async {
    try {
      // Query events where user_validated is null (not yet validated)
      final response = await _supabase
          .from('events')
          .select()
          .eq('user_id', userId)
          .filter('user_validated', 'is', null)
          .order('created_at', ascending: false)
          .limit(10);

      return (response as List<dynamic>)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting unvalidated events: $e');
      return [];
    }
  }

  /// Validate or reject an event
  Future<void> validateEvent(String eventId, bool isValid) async {
    try {
      await _supabase
          .from('events')
          .update({'user_validated': isValid})
          .eq('id', eventId);
    } catch (e) {
      print('Error validating event: $e');
    }
  }
}

/// VLP (Validated Language Pattern) model
/// Used for learning from validated events
class VLP {
  final String id;
  final String userId;
  final String phraseOriginal;
  final String phraseNormalized;
  final EventType eventType;
  final Map<String, dynamic> metricsTemplate;
  final int occurrenceCount;
  final double baseConfidence;
  final String userAction;
  final DateTime createdAt;
  final DateTime updatedAt;

  VLP({
    required this.id,
    required this.userId,
    required this.phraseOriginal,
    required this.phraseNormalized,
    required this.eventType,
    required this.metricsTemplate,
    required this.occurrenceCount,
    required this.baseConfidence,
    required this.userAction,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VLP.fromJson(Map<String, dynamic> json) {
    return VLP(
      id: json['id'],
      userId: json['user_id'],
      phraseOriginal: json['phrase_original'],
      phraseNormalized: json['phrase_normalized'],
      eventType: EventType.values.firstWhere((e) => e.value == json['event_type']),
      metricsTemplate: json['metrics_template'] ?? {},
      occurrenceCount: json['occurrence_count'] ?? 1,
      baseConfidence: (json['base_confidence'] as num).toDouble(),
      userAction: json['user_action'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}