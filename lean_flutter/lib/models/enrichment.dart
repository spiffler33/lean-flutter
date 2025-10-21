import 'dart:convert';

/// Enrichment model for AI-extracted metadata
class Enrichment {
  final int? id; // Local SQLite ID
  final String? cloudId; // Supabase UUID
  final int? entryId; // Reference to entry (local SQLite)
  final String? entryCloudId; // Reference to entry (Supabase)
  final String? userId; // Supabase user ID

  // Tier 1 Universal Enrichments (applied to 100% of entries)
  final String? emotion; // frustrated, anxious, excited, content, calm, etc.
  final List<String> themes; // max 3: work, personal, health, relationships, etc.
  final List<Map<String, dynamic>> people; // [{name, context, sentiment}]
  final String urgency; // none, low, medium, high

  // Extracted items
  final List<String> actions; // extracted todos/needs
  final List<Map<String, dynamic>> questions; // [{text, type, answered}]
  final List<Map<String, dynamic>> decisions; // [{text, options, context}]

  // Metadata
  final Map<String, double> confidenceScores; // per-field confidence
  final String enrichmentVersion;
  final String processingStatus; // pending, processing, complete, failed
  final int? processingTimeMs;
  final String? errorMessage;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Constrained vocabularies
  static const List<String> emotionVocabulary = [
    'frustrated', 'anxious', 'excited', 'content', 'calm', 'energized',
    'tired', 'sad', 'angry', 'overwhelmed', 'focused', 'grateful',
    'contemplative', 'curious', 'scattered', 'accomplished', 'lonely',
    'bored', 'neutral'
  ];

  static const List<String> themeVocabulary = [
    'work', 'personal', 'health', 'relationships', 'finance',
    'creative', 'tech', 'learning', 'leisure', 'reflection'
  ];

  static const List<String> urgencyLevels = ['none', 'low', 'medium', 'high'];

  Enrichment({
    this.id,
    this.cloudId,
    this.entryId,
    this.entryCloudId,
    this.userId,
    this.emotion,
    List<String>? themes,
    List<Map<String, dynamic>>? people,
    this.urgency = 'none',
    List<String>? actions,
    List<Map<String, dynamic>>? questions,
    List<Map<String, dynamic>>? decisions,
    Map<String, double>? confidenceScores,
    this.enrichmentVersion = '1.0',
    this.processingStatus = 'pending',
    this.processingTimeMs,
    this.errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : themes = themes ?? [],
        people = people ?? [],
        actions = actions ?? [],
        questions = questions ?? [],
        decisions = decisions ?? [],
        confidenceScores = confidenceScores ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create Enrichment from database JSON
  factory Enrichment.fromJson(Map<String, dynamic> json) {
    // Handle id field - can be int (SQLite) or String UUID (Supabase)
    int? localId;
    String? cloudUuid;

    final idValue = json['id'];
    if (idValue is int) {
      localId = idValue;
    } else if (idValue is String) {
      cloudUuid = idValue;
    }

    if (json['cloud_id'] != null) {
      cloudUuid = json['cloud_id'] as String;
    }

    return Enrichment(
      id: localId,
      cloudId: cloudUuid,
      entryId: json['entry_id'] is int ? json['entry_id'] : null,
      entryCloudId: json['entry_cloud_id'] as String?,
      userId: json['user_id'] as String?,
      emotion: json['emotion'] as String?,
      themes: _parseJsonList(json['themes']),
      people: _parseJsonPeople(json['people']),
      urgency: json['urgency'] as String? ?? 'none',
      actions: _parseJsonList(json['actions']),
      questions: _parseJsonQuestions(json['questions']),
      decisions: _parseJsonDecisions(json['decisions']),
      confidenceScores: _parseConfidenceScores(json['confidence_scores']),
      enrichmentVersion: json['enrichment_version'] as String? ?? '1.0',
      processingStatus: json['processing_status'] as String? ?? 'pending',
      processingTimeMs: json['processing_time_ms'] as int?,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON for SQLite storage
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (cloudId != null) 'cloud_id': cloudId,
      if (entryId != null) 'entry_id': entryId,
      if (entryCloudId != null) 'entry_cloud_id': entryCloudId,
      if (userId != null) 'user_id': userId,
      'emotion': emotion,
      'themes': jsonEncode(themes),
      'people': jsonEncode(people),
      'urgency': urgency,
      'actions': jsonEncode(actions),
      'questions': jsonEncode(questions),
      'decisions': jsonEncode(decisions),
      'confidence_scores': jsonEncode(confidenceScores),
      'enrichment_version': enrichmentVersion,
      'processing_status': processingStatus,
      'processing_time_ms': processingTimeMs,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON for Supabase (JSONB fields)
  Map<String, dynamic> toSupabaseJson() {
    return {
      if (cloudId != null) 'id': cloudId,
      'entry_id': entryCloudId,
      'user_id': userId,
      'emotion': emotion,
      'themes': themes, // Direct array for PostgreSQL
      'people': people, // Direct JSONB for PostgreSQL
      'urgency': urgency,
      'actions': actions, // Direct array
      'questions': questions, // Direct JSONB
      'decisions': decisions, // Direct JSONB
      'confidence_scores': confidenceScores, // Direct JSONB
      'enrichment_version': enrichmentVersion,
      'processing_status': processingStatus,
      'processing_time_ms': processingTimeMs,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Enrichment copyWith({
    int? id,
    String? cloudId,
    int? entryId,
    String? entryCloudId,
    String? userId,
    String? emotion,
    List<String>? themes,
    List<Map<String, dynamic>>? people,
    String? urgency,
    List<String>? actions,
    List<Map<String, dynamic>>? questions,
    List<Map<String, dynamic>>? decisions,
    Map<String, double>? confidenceScores,
    String? enrichmentVersion,
    String? processingStatus,
    int? processingTimeMs,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Enrichment(
      id: id ?? this.id,
      cloudId: cloudId ?? this.cloudId,
      entryId: entryId ?? this.entryId,
      entryCloudId: entryCloudId ?? this.entryCloudId,
      userId: userId ?? this.userId,
      emotion: emotion ?? this.emotion,
      themes: themes ?? this.themes,
      people: people ?? this.people,
      urgency: urgency ?? this.urgency,
      actions: actions ?? this.actions,
      questions: questions ?? this.questions,
      decisions: decisions ?? this.decisions,
      confidenceScores: confidenceScores ?? this.confidenceScores,
      enrichmentVersion: enrichmentVersion ?? this.enrichmentVersion,
      processingStatus: processingStatus ?? this.processingStatus,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper parsing methods
  static List<String> _parseJsonList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.cast<String>();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static List<Map<String, dynamic>> _parseJsonPeople(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<Map<String, dynamic>>();
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static List<Map<String, dynamic>> _parseJsonQuestions(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<Map<String, dynamic>>();
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static List<Map<String, dynamic>> _parseJsonDecisions(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<Map<String, dynamic>>();
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e as Map<String, dynamic>).toList();
        }
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static Map<String, double> _parseConfidenceScores(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), (val as num).toDouble()));
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, val) => MapEntry(key.toString(), (val as num).toDouble()));
        }
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  /// Check if enrichment is complete
  bool get isComplete => processingStatus == 'complete';

  /// Check if enrichment failed
  bool get isFailed => processingStatus == 'failed';

  /// Check if enrichment is processing
  bool get isProcessing => processingStatus == 'processing';

  /// Check if enrichment is pending
  bool get isPending => processingStatus == 'pending';

  /// Get a summary of enrichments for display
  String get summary {
    final parts = <String>[];
    if (emotion != null && emotion!.isNotEmpty) {
      parts.add(emotion!);
    }
    if (themes.isNotEmpty) {
      parts.addAll(themes);
    }
    if (people.isNotEmpty) {
      parts.add('${people.length} people');
    }
    if (urgency != 'none') {
      parts.add('$urgency urgency');
    }
    return parts.join(', ');
  }
}