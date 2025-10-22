/// Pattern Detection Models for Lean Intelligence System
/// These models correspond to the database tables created in migration 006

import 'package:uuid/uuid.dart';

/// Pattern types that can be detected
enum PatternType {
  temporal,    // Time-based patterns (morning anxiety, evening calm)
  causal,      // Event A leads to Event B
  streak,      // Consecutive day patterns
  correlation, // Co-occurrence patterns (person + emotion)
  anomaly,     // Unusual patterns or breaks
}

/// User feedback on detected patterns
enum PatternFeedback {
  validated,  // User confirmed pattern is accurate
  rejected,   // User said pattern is not accurate
  pending,    // Not yet reviewed by user
}

/// Intelligence Pattern matching the database schema
class IntelligencePattern {
  final String id;
  final String userId;
  final PatternType patternType;
  final String patternSignature; // Unique identifier for deduplication
  final Map<String, dynamic> triggerConditions;
  final Map<String, dynamic> outcomeConditions;
  final Map<String, dynamic> context; // time_of_day, day_of_week, people_involved
  final ConfidenceMetrics strengthMetrics;
  final PatternFeedback? userFeedback;
  final DateTime createdAt;
  final DateTime updatedAt;

  IntelligencePattern({
    String? id,
    required this.userId,
    required this.patternType,
    required this.patternSignature,
    required this.triggerConditions,
    required this.outcomeConditions,
    Map<String, dynamic>? context,
    required this.strengthMetrics,
    this.userFeedback,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        context = context ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create from database JSON
  factory IntelligencePattern.fromJson(Map<String, dynamic> json) {
    return IntelligencePattern(
      id: json['id'],
      userId: json['user_id'],
      patternType: PatternType.values.firstWhere(
        (e) => e.name == json['pattern_type'],
      ),
      patternSignature: json['pattern_signature'],
      triggerConditions: json['trigger_conditions'] ?? {},
      outcomeConditions: json['outcome_conditions'] ?? {},
      context: json['context'] ?? {},
      strengthMetrics: ConfidenceMetrics.fromJson(
        json['strength_metrics'] ?? {},
      ),
      userFeedback: json['user_feedback'] != null
          ? PatternFeedback.values.firstWhere(
              (e) => e.name == json['user_feedback'],
            )
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pattern_type': patternType.name,
      'pattern_signature': patternSignature,
      'trigger_conditions': triggerConditions,
      'outcome_conditions': outcomeConditions,
      'context': context,
      'strength_metrics': strengthMetrics.toJson(),
      'user_feedback': userFeedback?.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Generate a human-readable description of the pattern
  String getDescription() {
    switch (patternType) {
      case PatternType.temporal:
        final timeOfDay = context['time_of_day'] ?? 'unknown time';
        final emotion = outcomeConditions['emotion'] ?? 'unknown';
        final confidence = (strengthMetrics.confidence * 100).toStringAsFixed(0);
        return 'During $timeOfDay, you often feel $emotion ($confidence% confidence)';

      case PatternType.causal:
        final trigger = triggerConditions['event'] ?? 'unknown trigger';
        final outcome = outcomeConditions['event'] ?? outcomeConditions['emotion'] ?? 'unknown outcome';
        return 'After $trigger, you typically experience $outcome';

      case PatternType.streak:
        final streakType = context['streak_type'] ?? 'activity';
        final currentDays = context['current_days'] ?? 0;
        return 'You\'ve maintained a $streakType streak for $currentDays days';

      case PatternType.correlation:
        final person = context['person'] ?? 'someone';
        final emotion = outcomeConditions['emotion'] ?? 'certain emotions';
        return 'When you interact with $person, you tend to feel $emotion';

      case PatternType.anomaly:
        final description = context['description'] ?? 'Unusual pattern detected';
        return description;
    }
  }

  /// Copy with updated fields
  IntelligencePattern copyWith({
    String? id,
    String? userId,
    PatternType? patternType,
    String? patternSignature,
    Map<String, dynamic>? triggerConditions,
    Map<String, dynamic>? outcomeConditions,
    Map<String, dynamic>? context,
    ConfidenceMetrics? strengthMetrics,
    PatternFeedback? userFeedback,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IntelligencePattern(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      patternType: patternType ?? this.patternType,
      patternSignature: patternSignature ?? this.patternSignature,
      triggerConditions: triggerConditions ?? this.triggerConditions,
      outcomeConditions: outcomeConditions ?? this.outcomeConditions,
      context: context ?? this.context,
      strengthMetrics: strengthMetrics ?? this.strengthMetrics,
      userFeedback: userFeedback ?? this.userFeedback,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Confidence metrics for pattern strength
class ConfidenceMetrics {
  final int occurrences;     // Number of times pattern observed
  final double confidence;    // Confidence score (0.0 - 1.0)
  final DateTime? firstSeen;  // When pattern was first detected
  final DateTime? lastSeen;   // Most recent occurrence

  ConfidenceMetrics({
    required this.occurrences,
    required this.confidence,
    this.firstSeen,
    this.lastSeen,
  });

  /// Create from JSON
  factory ConfidenceMetrics.fromJson(Map<String, dynamic> json) {
    return ConfidenceMetrics(
      occurrences: json['occurrences'] ?? 0,
      confidence: (json['confidence'] ?? 0).toDouble(),
      firstSeen: json['first_seen'] != null
          ? DateTime.parse(json['first_seen'])
          : null,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'occurrences': occurrences,
      'confidence': confidence,
      if (firstSeen != null) 'first_seen': firstSeen!.toIso8601String(),
      if (lastSeen != null) 'last_seen': lastSeen!.toIso8601String(),
    };
  }

  /// Update metrics with new observation
  ConfidenceMetrics withNewObservation({DateTime? observedAt}) {
    final now = observedAt ?? DateTime.now();
    return ConfidenceMetrics(
      occurrences: occurrences + 1,
      confidence: _calculateNewConfidence(occurrences + 1),
      firstSeen: firstSeen ?? now,
      lastSeen: now,
    );
  }

  /// Calculate confidence based on occurrences
  double _calculateNewConfidence(int count) {
    // Simple confidence calculation: increases with more observations
    // Reaches 0.5 at 3 observations, 0.75 at 7, 0.9 at 15
    if (count <= 0) return 0.0;
    if (count >= 15) return 0.9;
    if (count >= 7) return 0.75;
    if (count >= 3) return 0.5;
    return count * 0.15;
  }
}

/// Streak types that can be tracked
enum StreakType {
  exercise,
  sleep,
  mood,
  productivity,
  custom,
}

/// User Streak for tracking consecutive events
class UserStreak {
  final String id;
  final String userId;
  final StreakType streakType;
  final String? streakName;      // For custom streaks
  final int currentCount;
  final int bestCount;
  final DateTime? lastEntryDate;
  final DateTime? startedAt;
  final DateTime? brokenAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserStreak({
    String? id,
    required this.userId,
    required this.streakType,
    this.streakName,
    this.currentCount = 0,
    this.bestCount = 0,
    this.lastEntryDate,
    this.startedAt,
    this.brokenAt,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create from database JSON
  factory UserStreak.fromJson(Map<String, dynamic> json) {
    return UserStreak(
      id: json['id'],
      userId: json['user_id'],
      streakType: StreakType.values.firstWhere(
        (e) => e.name == json['streak_type'],
      ),
      streakName: json['streak_name'],
      currentCount: json['current_count'] ?? 0,
      bestCount: json['best_count'] ?? 0,
      lastEntryDate: json['last_entry_date'] != null
          ? DateTime.parse(json['last_entry_date'])
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      brokenAt: json['broken_at'] != null
          ? DateTime.parse(json['broken_at'])
          : null,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'streak_type': streakType.name,
      if (streakName != null) 'streak_name': streakName,
      'current_count': currentCount,
      'best_count': bestCount,
      if (lastEntryDate != null) 'last_entry_date': lastEntryDate!.toIso8601String().split('T')[0],
      if (startedAt != null) 'started_at': startedAt!.toIso8601String().split('T')[0],
      if (brokenAt != null) 'broken_at': brokenAt!.toIso8601String().split('T')[0],
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get human-readable streak name
  String get displayName {
    if (streakName != null) return streakName!;
    switch (streakType) {
      case StreakType.exercise:
        return 'Exercise';
      case StreakType.sleep:
        return 'Good Sleep';
      case StreakType.mood:
        return 'Positive Mood';
      case StreakType.productivity:
        return 'High Productivity';
      case StreakType.custom:
        return 'Custom Streak';
    }
  }

  /// Get streak status message
  String get statusMessage {
    if (!isActive) {
      return 'Streak ended after $bestCount days';
    }
    if (currentCount == 0) {
      return 'Start your streak today!';
    }
    if (currentCount == bestCount) {
      return '🔥 $currentCount day streak (personal best!)';
    }
    return '🔥 $currentCount day streak';
  }

  /// Update streak with new entry
  UserStreak withNewEntry(DateTime entryDate) {
    final today = DateTime(entryDate.year, entryDate.month, entryDate.day);
    final lastEntry = lastEntryDate != null
        ? DateTime(lastEntryDate!.year, lastEntryDate!.month, lastEntryDate!.day)
        : null;

    // If this is the first entry or continuing from yesterday
    if (lastEntry == null || today.difference(lastEntry).inDays == 1) {
      final newCount = (lastEntry == null) ? 1 : currentCount + 1;
      return UserStreak(
        id: id,
        userId: userId,
        streakType: streakType,
        streakName: streakName,
        currentCount: newCount,
        bestCount: newCount > bestCount ? newCount : bestCount,
        lastEntryDate: today,
        startedAt: startedAt ?? today,
        brokenAt: null,
        isActive: true,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
    }

    // If it's the same day, no change
    if (lastEntry != null && today.difference(lastEntry).inDays == 0) {
      return this;
    }

    // Streak is broken
    return UserStreak(
      id: id,
      userId: userId,
      streakType: streakType,
      streakName: streakName,
      currentCount: 1, // Restart at 1
      bestCount: bestCount,
      lastEntryDate: today,
      startedAt: today,
      brokenAt: lastEntry,
      isActive: true,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if streak should be marked as broken (missed a day)
  UserStreak checkForBreak(DateTime currentDate) {
    if (!isActive || lastEntryDate == null) return this;

    final today = DateTime(currentDate.year, currentDate.month, currentDate.day);
    final lastEntry = DateTime(lastEntryDate!.year, lastEntryDate!.month, lastEntryDate!.day);

    // If more than 1 day has passed, streak is broken
    if (today.difference(lastEntry).inDays > 1) {
      return UserStreak(
        id: id,
        userId: userId,
        streakType: streakType,
        streakName: streakName,
        currentCount: 0,
        bestCount: bestCount,
        lastEntryDate: lastEntryDate,
        startedAt: startedAt,
        brokenAt: lastEntry,
        isActive: false,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
    }

    return this;
  }
}