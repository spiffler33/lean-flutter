import 'package:uuid/uuid.dart';

/// Types of trackable events
enum EventType {
  exercise('exercise'),
  consumption('consumption'),
  spend('spend'),
  sleep('sleep'),
  meeting('meeting'),
  health('health');

  final String value;
  const EventType(this.value);

  static EventType? fromString(String value) {
    return EventType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => EventType.health,
    );
  }
}

/// Extraction methods for events
enum ExtractionMethod {
  metrics('metrics'),     // Extracted via numbers + units
  vlp('vlp'),            // Matched a Very Likely Pattern
  perfective('perfective'), // Perfective past tense
  mixed('mixed'),        // Multiple signals
  llm('llm');           // Extracted via LLM (Claude)

  final String value;
  const ExtractionMethod(this.value);

  static ExtractionMethod fromString(String value) {
    return ExtractionMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => ExtractionMethod.metrics,
    );
  }
}

/// Type-safe metrics for different event types
class EventMetrics {
  // Exercise metrics
  final double? distanceKm;
  final int? durationMin;
  final double? speedKmh;
  final int? reps;
  final int? sets;
  final double? weightKg;
  final int? calories;

  // Spend metrics
  final double? amount;
  final String? currency;

  // Sleep metrics
  final double? hoursSlept;
  final int? minutesSlept;

  // Consumption metrics
  final double? quantity;
  final String? unit;

  // Meeting metrics
  final int? attendees;
  final int? meetingDurationMin;

  EventMetrics({
    this.distanceKm,
    this.durationMin,
    this.speedKmh,
    this.reps,
    this.sets,
    this.weightKg,
    this.calories,
    this.amount,
    this.currency,
    this.hoursSlept,
    this.minutesSlept,
    this.quantity,
    this.unit,
    this.attendees,
    this.meetingDurationMin,
  });

  factory EventMetrics.fromJson(Map<String, dynamic> json) {
    // Helper function for safe number conversion
    double? toDoubleOrNull(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? toIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return EventMetrics(
      distanceKm: toDoubleOrNull(json['distance_km']),
      durationMin: toIntOrNull(json['duration_min']),
      speedKmh: toDoubleOrNull(json['speed_kmh']),
      reps: toIntOrNull(json['reps']),
      sets: toIntOrNull(json['sets']),
      weightKg: toDoubleOrNull(json['weight_kg']),
      calories: toIntOrNull(json['calories']),
      amount: toDoubleOrNull(json['amount']),
      currency: json['currency'] as String?,
      hoursSlept: toDoubleOrNull(json['hours_slept']),
      minutesSlept: toIntOrNull(json['minutes_slept']),
      quantity: toDoubleOrNull(json['quantity']),
      unit: json['unit'] as String?,
      attendees: toIntOrNull(json['attendees']),
      meetingDurationMin: toIntOrNull(json['meeting_duration_min']),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (distanceKm != null) json['distance_km'] = distanceKm;
    if (durationMin != null) json['duration_min'] = durationMin;
    if (speedKmh != null) json['speed_kmh'] = speedKmh;
    if (reps != null) json['reps'] = reps;
    if (sets != null) json['sets'] = sets;
    if (weightKg != null) json['weight_kg'] = weightKg;
    if (calories != null) json['calories'] = calories;
    if (amount != null) json['amount'] = amount;
    if (currency != null) json['currency'] = currency;
    if (hoursSlept != null) json['hours_slept'] = hoursSlept;
    if (minutesSlept != null) json['minutes_slept'] = minutesSlept;
    if (quantity != null) json['quantity'] = quantity;
    if (unit != null) json['unit'] = unit;
    if (attendees != null) json['attendees'] = attendees;
    if (meetingDurationMin != null) json['meeting_duration_min'] = meetingDurationMin;

    return json;
  }

  bool get isEmpty => toJson().isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// Context for events
class EventContext {
  final List<String>? people;
  final String? location;
  final bool? workRelated;
  final String? mood;
  final String? weather;
  final String? timeOfDay;

  EventContext({
    this.people,
    this.location,
    this.workRelated,
    this.mood,
    this.weather,
    this.timeOfDay,
  });

  factory EventContext.fromJson(Map<String, dynamic> json) {
    return EventContext(
      people: (json['people'] as List<dynamic>?)?.cast<String>(),
      location: json['location'] as String?,
      workRelated: json['work_related'] as bool?,
      mood: json['mood'] as String?,
      weather: json['weather'] as String?,
      timeOfDay: json['time_of_day'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (people != null && people!.isNotEmpty) json['people'] = people;
    if (location != null) json['location'] = location;
    if (workRelated != null) json['work_related'] = workRelated;
    if (mood != null) json['mood'] = mood;
    if (weather != null) json['weather'] = weather;
    if (timeOfDay != null) json['time_of_day'] = timeOfDay;

    return json;
  }
}

/// Main Event model
class Event {
  final String id;
  final String userId;
  final String entryId;
  final EventType type;
  final String? subtype;
  final EventMetrics metrics;
  final EventContext context;
  final double confidence;
  final ExtractionMethod extractionMethod;
  final bool? userValidated;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    String? id,
    required this.userId,
    required this.entryId,
    required this.type,
    this.subtype,
    EventMetrics? metrics,
    EventContext? context,
    required this.confidence,
    required this.extractionMethod,
    this.userValidated,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        metrics = metrics ?? EventMetrics(),
        context = context ?? EventContext(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      entryId: json['entry_id'] as String,
      type: EventType.fromString(json['type'] as String)!,
      subtype: json['subtype'] as String?,
      metrics: EventMetrics.fromJson(json['metrics'] ?? {}),
      context: EventContext.fromJson(json['context'] ?? {}),
      confidence: (json['confidence'] as num).toDouble(),
      extractionMethod: ExtractionMethod.fromString(json['extraction_method'] as String? ?? 'metrics'),
      userValidated: json['user_validated'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'entry_id': entryId,
      'type': type.value,
      'subtype': subtype,
      'metrics': metrics.toJson(),
      'context': context.toJson(),
      'confidence': confidence,
      'extraction_method': extractionMethod.value,
      'user_validated': userValidated,
      // Store local time (not UTC) - remove 'Z' suffix to avoid UTC conversion
      'created_at': createdAt.toLocal().toIso8601String().replaceFirst(RegExp(r'Z$'), ''),
      'updated_at': updatedAt.toLocal().toIso8601String().replaceFirst(RegExp(r'Z$'), ''),
    };
  }

  Event copyWith({
    String? id,
    String? userId,
    String? entryId,
    EventType? type,
    String? subtype,
    EventMetrics? metrics,
    EventContext? context,
    double? confidence,
    ExtractionMethod? extractionMethod,
    bool? userValidated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entryId: entryId ?? this.entryId,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      metrics: metrics ?? this.metrics,
      context: context ?? this.context,
      confidence: confidence ?? this.confidence,
      extractionMethod: extractionMethod ?? this.extractionMethod,
      userValidated: userValidated ?? this.userValidated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this is a high-confidence event (≥0.85)
  bool get isHighConfidence => confidence >= 0.85;

  /// Check if this is a shadow event (0.65-0.85)
  bool get isShadowEvent => confidence >= 0.65 && confidence < 0.85;

  /// Check if this event needs validation
  bool get needsValidation => userValidated == null && isHighConfidence;

  /// Get a human-readable description of the event
  String get description {
    final buffer = StringBuffer();

    buffer.write('${type.value}');
    if (subtype != null) {
      buffer.write(' (${subtype})');
    }

    // Add key metrics
    if (metrics.distanceKm != null) {
      buffer.write(' - ${metrics.distanceKm}km');
    }
    if (metrics.durationMin != null) {
      buffer.write(' - ${metrics.durationMin}min');
    }
    if (metrics.amount != null) {
      buffer.write(' - \$${metrics.amount}');
    }
    if (metrics.hoursSlept != null) {
      buffer.write(' - ${metrics.hoursSlept}hrs');
    }

    // Add context
    if (context.people != null && context.people!.isNotEmpty) {
      buffer.write(' with ${context.people!.join(", ")}');
    }
    if (context.location != null) {
      buffer.write(' at ${context.location}');
    }

    return buffer.toString();
  }

  @override
  String toString() => 'Event($type: $description, confidence: $confidence)';
}

/// VLP (Very Likely Pattern) model
class VLP {
  final String id;
  final String userId;
  final String phrase;
  final String phraseNormalized;
  final EventType? eventType;
  final int usageCount;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String? userAction; // validated, rejected, null
  final Map<String, dynamic> metricsTemplate;
  final double confidenceBoost;
  final DateTime createdAt;
  final DateTime updatedAt;

  VLP({
    String? id,
    required this.userId,
    required this.phrase,
    required this.phraseNormalized,
    this.eventType,
    this.usageCount = 1,
    DateTime? firstSeen,
    DateTime? lastSeen,
    this.userAction,
    Map<String, dynamic>? metricsTemplate,
    this.confidenceBoost = 0.30,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        metricsTemplate = metricsTemplate ?? {},
        firstSeen = firstSeen ?? DateTime.now(),
        lastSeen = lastSeen ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory VLP.fromJson(Map<String, dynamic> json) {
    return VLP(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      phrase: json['phrase'] as String,
      phraseNormalized: json['phrase_normalized'] as String,
      eventType: json['event_type'] != null
        ? EventType.fromString(json['event_type'] as String)
        : null,
      usageCount: json['usage_count'] as int,
      firstSeen: DateTime.parse(json['first_seen'] as String),
      lastSeen: DateTime.parse(json['last_seen'] as String),
      userAction: json['user_action'] as String?,
      metricsTemplate: json['metrics_template'] ?? {},
      confidenceBoost: (json['confidence_boost'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'phrase': phrase,
      'phrase_normalized': phraseNormalized,
      'event_type': eventType?.value,
      'usage_count': usageCount,
      // Store local time (not UTC) - remove 'Z' suffix to avoid UTC conversion
      'first_seen': firstSeen.toLocal().toIso8601String().replaceFirst(RegExp(r'Z$'), ''),
      'last_seen': lastSeen.toLocal().toIso8601String().replaceFirst(RegExp(r'Z$'), ''),
      'user_action': userAction,
      'metrics_template': metricsTemplate,
      'confidence_boost': confidenceBoost,
      'created_at': createdAt.toLocal().toIso8601String().replaceFirst(RegExp(r'Z$'), ''),
      'updated_at': updatedAt.toLocal().toIso8601String().replaceFirst(RegExp(r'Z$'), ''),
    };
  }

  bool get isValidated => userAction == 'validated';
  bool get isRejected => userAction == 'rejected';
  bool get isPending => userAction == null;
}