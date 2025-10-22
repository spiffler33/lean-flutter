import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pattern_models.dart';
import '../models/enrichment.dart';
import '../models/event.dart';

/// Service for detecting patterns in user data
class PatternDetectionService {
  final SupabaseClient _supabase;
  final String userId;

  PatternDetectionService(this._supabase, this.userId);

  /// Main entry point - run all pattern detection
  Future<Map<String, dynamic>> detectAllPatterns({int days = 30}) async {
    print('[PATTERN-DETECT] ====================================');
    print('[PATTERN-DETECT] Starting pattern detection');
    print('[PATTERN-DETECT] User ID: $userId');
    print('[PATTERN-DETECT] Analyzing last $days days');
    print('[PATTERN-DETECT] ====================================');

    try {
      // Fetch enrichments and events from last N days
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      print('[PATTERN-DETECT] Date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');

      final enrichments = await _fetchEnrichments(startDate, endDate);
      final events = await _fetchEvents(startDate, endDate);

      print('[PATTERN-DETECT] Data fetched:');
      print('[PATTERN-DETECT]   - ${enrichments.length} enrichments');
      print('[PATTERN-DETECT]   - ${events.length} events');

      if (enrichments.isEmpty && events.isEmpty) {
        print('[PATTERN-DETECT] ⚠️ No data found for analysis');
        return {
          'temporal_patterns': 0,
          'correlations': 0,
          'streaks': 0,
          'new_patterns_saved': 0,
          'total_enrichments_analyzed': 0,
          'total_events_analyzed': 0,
          'message': 'No data found for analysis',
        };
      }

      // Run all detection methods
      print('[PATTERN-DETECT] Running detection algorithms...');

      print('[PATTERN-DETECT] 1/3 Detecting temporal patterns...');
      final temporalPatterns = await detectTemporalPatterns(enrichments);

      print('[PATTERN-DETECT] 2/3 Updating streaks...');
      final streaks = await updateStreaks(events, enrichments);

      print('[PATTERN-DETECT] 3/3 Detecting correlations...');
      final correlations = await detectSimpleCorrelations(enrichments);

      print('[PATTERN-DETECT] Detection complete:');
      print('[PATTERN-DETECT]   - ${temporalPatterns.length} temporal patterns found');
      print('[PATTERN-DETECT]   - ${streaks.length} streaks found');
      print('[PATTERN-DETECT]   - ${correlations.length} correlations found');

      // Save patterns to database
      print('[PATTERN-DETECT] Saving patterns to database...');
      int newPatterns = 0;
      int updatedPatterns = 0;

      for (final pattern in temporalPatterns) {
        final saved = await _savePattern(pattern);
        if (saved) {
          newPatterns++;
          print('[PATTERN-DETECT]   ✓ New pattern saved: ${pattern.patternSignature}');
        } else {
          updatedPatterns++;
          print('[PATTERN-DETECT]   ↻ Pattern updated: ${pattern.patternSignature}');
        }
      }

      for (final pattern in correlations) {
        final saved = await _savePattern(pattern);
        if (saved) {
          newPatterns++;
          print('[PATTERN-DETECT]   ✓ New pattern saved: ${pattern.patternSignature}');
        } else {
          updatedPatterns++;
          print('[PATTERN-DETECT]   ↻ Pattern updated: ${pattern.patternSignature}');
        }
      }

      // Save/update streaks
      print('[PATTERN-DETECT] Saving streaks...');
      for (final streak in streaks) {
        await _saveOrUpdateStreak(streak);
        print('[PATTERN-DETECT]   ✓ Streak saved: ${streak.streakType.name} (${streak.currentCount} days)');
      }

      print('[PATTERN-DETECT] ====================================');
      print('[PATTERN-DETECT] Pattern detection complete!');
      print('[PATTERN-DETECT]   - $newPatterns new patterns saved');
      print('[PATTERN-DETECT]   - $updatedPatterns patterns updated');
      print('[PATTERN-DETECT]   - ${streaks.length} streaks processed');
      print('[PATTERN-DETECT] ====================================');

      return {
        'temporal_patterns': temporalPatterns.length,
        'correlations': correlations.length,
        'streaks': streaks.length,
        'new_patterns_saved': newPatterns,
        'updated_patterns': updatedPatterns,
        'total_enrichments_analyzed': enrichments.length,
        'total_events_analyzed': events.length,
      };
    } catch (e, stackTrace) {
      print('[PATTERN-DETECT] ❌ ERROR in pattern detection:');
      print('[PATTERN-DETECT]   Error: $e');
      print('[PATTERN-DETECT]   Stack trace: $stackTrace');
      return {
        'error': e.toString(),
        'temporal_patterns': 0,
        'correlations': 0,
        'streaks': 0,
      };
    }
  }

  /// Detect temporal patterns (time of day and day of week patterns)
  Future<List<IntelligencePattern>> detectTemporalPatterns(
    List<Enrichment> enrichments,
  ) async {
    print('[TEMPORAL] Starting temporal pattern detection...');
    final patterns = <IntelligencePattern>[];

    // Group enrichments by time periods
    final morningEmotions = <String, int>{};  // 6-12
    final eveningEmotions = <String, int>{};  // 18-24
    final mondayEmotions = <String, int>{};
    final fridayEmotions = <String, int>{};

    int enrichmentsWithEmotions = 0;
    for (final enrichment in enrichments) {
      if (enrichment.emotion == null) continue;
      enrichmentsWithEmotions++;

      final hour = enrichment.createdAt.hour;
      final dayOfWeek = enrichment.createdAt.weekday;
      final emotion = enrichment.emotion!;

      // Morning patterns (6-12)
      if (hour >= 6 && hour < 12) {
        morningEmotions[emotion] = (morningEmotions[emotion] ?? 0) + 1;
      }

      // Evening patterns (18-24)
      if (hour >= 18 && hour <= 23) {
        eveningEmotions[emotion] = (eveningEmotions[emotion] ?? 0) + 1;
      }

      // Monday patterns
      if (dayOfWeek == DateTime.monday) {
        mondayEmotions[emotion] = (mondayEmotions[emotion] ?? 0) + 1;
      }

      // Friday patterns
      if (dayOfWeek == DateTime.friday) {
        fridayEmotions[emotion] = (fridayEmotions[emotion] ?? 0) + 1;
      }
    }

    print('[TEMPORAL] Analyzed $enrichmentsWithEmotions enrichments with emotions');
    print('[TEMPORAL] Time period distributions:');
    print('[TEMPORAL]   Morning (6-12): ${_totalCount(morningEmotions)} entries');
    print('[TEMPORAL]   Evening (18-24): ${_totalCount(eveningEmotions)} entries');
    print('[TEMPORAL]   Mondays: ${_totalCount(mondayEmotions)} entries');
    print('[TEMPORAL]   Fridays: ${_totalCount(fridayEmotions)} entries');

    // Create patterns for morning if enough data (7+ occurrences)
    if (_totalCount(morningEmotions) >= 7) {
      final topEmotion = _getTopItem(morningEmotions);
      if (topEmotion != null) {
        final confidence = _calculateConfidence(
          morningEmotions[topEmotion]!,
          _totalCount(morningEmotions)
        );

        print('[TEMPORAL] ✓ Morning pattern detected: $topEmotion (${morningEmotions[topEmotion]} occurrences, ${(confidence * 100).toStringAsFixed(0)}% confidence)');

        patterns.add(IntelligencePattern(
          userId: userId,
          patternType: PatternType.temporal,
          patternSignature: 'temporal_morning_$topEmotion',
          triggerConditions: {'time_of_day': 'morning', 'hour_range': '6-12'},
          outcomeConditions: {'emotion': topEmotion},
          context: {
            'time_of_day': 'morning',
            'description': 'Morning emotional pattern',
          },
          strengthMetrics: ConfidenceMetrics(
            occurrences: morningEmotions[topEmotion]!,
            confidence: confidence,
            firstSeen: DateTime.now().subtract(Duration(days: 30)),
            lastSeen: DateTime.now(),
          ),
        ));
      }
    } else {
      print('[TEMPORAL] ✗ Morning: Not enough data (${_totalCount(morningEmotions)}/7 required)');
    }

    // Create patterns for evening if enough data
    if (_totalCount(eveningEmotions) >= 7) {
      final topEmotion = _getTopItem(eveningEmotions);
      if (topEmotion != null) {
        final confidence = _calculateConfidence(
          eveningEmotions[topEmotion]!,
          _totalCount(eveningEmotions)
        );

        print('[TEMPORAL] ✓ Evening pattern detected: $topEmotion (${eveningEmotions[topEmotion]} occurrences, ${(confidence * 100).toStringAsFixed(0)}% confidence)');

        patterns.add(IntelligencePattern(
          userId: userId,
          patternType: PatternType.temporal,
          patternSignature: 'temporal_evening_$topEmotion',
          triggerConditions: {'time_of_day': 'evening', 'hour_range': '18-24'},
          outcomeConditions: {'emotion': topEmotion},
          context: {
            'time_of_day': 'evening',
            'description': 'Evening emotional pattern',
          },
          strengthMetrics: ConfidenceMetrics(
            occurrences: eveningEmotions[topEmotion]!,
            confidence: confidence,
            firstSeen: DateTime.now().subtract(Duration(days: 30)),
            lastSeen: DateTime.now(),
          ),
        ));
      }
    } else {
      print('[TEMPORAL] ✗ Evening: Not enough data (${_totalCount(eveningEmotions)}/7 required)');
    }

    // Monday patterns
    if (_totalCount(mondayEmotions) >= 7) {
      final topEmotion = _getTopItem(mondayEmotions);
      if (topEmotion != null) {
        final confidence = _calculateConfidence(
          mondayEmotions[topEmotion]!,
          _totalCount(mondayEmotions)
        );

        patterns.add(IntelligencePattern(
          userId: userId,
          patternType: PatternType.temporal,
          patternSignature: 'temporal_monday_$topEmotion',
          triggerConditions: {'day_of_week': 'monday'},
          outcomeConditions: {'emotion': topEmotion},
          context: {
            'day_of_week': 'monday',
            'description': 'Monday emotional pattern',
          },
          strengthMetrics: ConfidenceMetrics(
            occurrences: mondayEmotions[topEmotion]!,
            confidence: confidence,
            firstSeen: DateTime.now().subtract(Duration(days: 30)),
            lastSeen: DateTime.now(),
          ),
        ));
      }
    }

    // Friday patterns
    if (_totalCount(fridayEmotions) >= 7) {
      final topEmotion = _getTopItem(fridayEmotions);
      if (topEmotion != null) {
        final confidence = _calculateConfidence(
          fridayEmotions[topEmotion]!,
          _totalCount(fridayEmotions)
        );

        patterns.add(IntelligencePattern(
          userId: userId,
          patternType: PatternType.temporal,
          patternSignature: 'temporal_friday_$topEmotion',
          triggerConditions: {'day_of_week': 'friday'},
          outcomeConditions: {'emotion': topEmotion},
          context: {
            'day_of_week': 'friday',
            'description': 'Friday emotional pattern',
          },
          strengthMetrics: ConfidenceMetrics(
            occurrences: fridayEmotions[topEmotion]!,
            confidence: confidence,
            firstSeen: DateTime.now().subtract(Duration(days: 30)),
            lastSeen: DateTime.now(),
          ),
        ));
      }
    }

    print('[TEMPORAL] Summary: ${patterns.length} temporal patterns detected');
    return patterns;
  }

  /// Update streaks based on events and enrichments
  Future<List<UserStreak>> updateStreaks(
    List<Event> events,
    List<Enrichment> enrichments,
  ) async {
    print('[STREAKS] Starting streak detection...');
    final streaks = <UserStreak>[];

    // Exercise streak - check for exercise events
    final exerciseEvents = events.where((e) => e.type == EventType.exercise).toList();
    print('[STREAKS] Found ${exerciseEvents.length} exercise events');

    final exerciseStreak = await _calculateStreak(
      StreakType.exercise,
      exerciseEvents,
      enrichments,
    );
    if (exerciseStreak != null) {
      streaks.add(exerciseStreak);
      print('[STREAKS] ✓ Exercise streak: ${exerciseStreak.currentCount} days (best: ${exerciseStreak.bestCount})');
    } else {
      print('[STREAKS] ✗ No exercise streak detected');
    }

    // Mood streak - consecutive days with same dominant emotion
    final moodStreak = await _calculateMoodStreak(enrichments);
    if (moodStreak != null) {
      streaks.add(moodStreak);
      print('[STREAKS] ✓ Mood streak (${moodStreak.streakName}): ${moodStreak.currentCount} days (best: ${moodStreak.bestCount})');
    } else {
      print('[STREAKS] ✗ No mood streak detected');
    }

    // Productivity streak - days with high urgency entries
    final productivityStreak = await _calculateProductivityStreak(enrichments);
    if (productivityStreak != null) {
      streaks.add(productivityStreak);
      print('[STREAKS] ✓ Productivity streak: ${productivityStreak.currentCount} days (best: ${productivityStreak.bestCount})');
    } else {
      print('[STREAKS] ✗ No productivity streak detected');
    }

    print('[STREAKS] Summary: ${streaks.length} streaks detected');
    return streaks;
  }

  /// Detect simple correlations between people and emotions
  Future<List<IntelligencePattern>> detectSimpleCorrelations(
    List<Enrichment> enrichments,
  ) async {
    print('[CORRELATIONS] Starting correlation detection...');
    final patterns = <IntelligencePattern>[];

    // Track person-emotion correlations
    final personEmotions = <String, Map<String, int>>{};

    int enrichmentsWithPeople = 0;
    for (final enrichment in enrichments) {
      if (enrichment.emotion == null) continue;

      for (final person in enrichment.people) {
        final name = person['name'] as String?;
        if (name == null) continue;

        enrichmentsWithPeople++;
        personEmotions.putIfAbsent(name, () => {});
        personEmotions[name]![enrichment.emotion!] =
            (personEmotions[name]![enrichment.emotion!] ?? 0) + 1;
      }
    }

    print('[CORRELATIONS] Analyzed $enrichmentsWithPeople enrichments with people');
    print('[CORRELATIONS] Found ${personEmotions.length} unique people');

    // Create patterns for people mentioned 5+ times
    for (final entry in personEmotions.entries) {
      final personName = entry.key;
      final emotions = entry.value;
      final totalMentions = _totalCount(emotions);

      if (totalMentions >= 5) {
        final dominantEmotion = _getTopItem(emotions);
        if (dominantEmotion != null) {
          final confidence = _calculateConfidence(
            emotions[dominantEmotion]!,
            totalMentions,
          );

          print('[CORRELATIONS] ✓ Pattern found: $personName → $dominantEmotion ($totalMentions mentions, ${(confidence * 100).toStringAsFixed(0)}% confidence)');

          patterns.add(IntelligencePattern(
            userId: userId,
            patternType: PatternType.correlation,
            patternSignature: 'correlation_${personName.toLowerCase().replaceAll(' ', '_')}_$dominantEmotion',
            triggerConditions: {'person': personName},
            outcomeConditions: {'emotion': dominantEmotion},
            context: {
              'person': personName,
              'total_mentions': totalMentions,
              'emotion_distribution': emotions,
            },
            strengthMetrics: ConfidenceMetrics(
              occurrences: totalMentions,
              confidence: confidence,
              firstSeen: DateTime.now().subtract(Duration(days: 30)),
              lastSeen: DateTime.now(),
            ),
          ));
        }
      } else if (totalMentions > 0) {
        print('[CORRELATIONS] ✗ $personName: Not enough mentions ($totalMentions/5 required)');
      }
    }

    print('[CORRELATIONS] Summary: ${patterns.length} correlation patterns detected');
    return patterns;
  }

  // Helper methods

  Future<List<Enrichment>> _fetchEnrichments(DateTime start, DateTime end) async {
    try {
      print('[DB-FETCH] Fetching enrichments from Supabase...');
      final response = await _supabase
          .from('enrichments')
          .select()
          .eq('user_id', userId)
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      final enrichments = (response as List<dynamic>)
          .map((json) => Enrichment.fromJson(json as Map<String, dynamic>))
          .toList();

      print('[DB-FETCH] Successfully fetched ${enrichments.length} enrichments');
      return enrichments;
    } catch (e, stackTrace) {
      print('[DB-FETCH] ❌ Error fetching enrichments: $e');
      print('[DB-FETCH] Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Event>> _fetchEvents(DateTime start, DateTime end) async {
    try {
      print('[DB-FETCH] Fetching events from Supabase...');
      final response = await _supabase
          .from('events')
          .select()
          .eq('user_id', userId)
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      final events = (response as List<dynamic>)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();

      print('[DB-FETCH] Successfully fetched ${events.length} events');

      // Group events by type for debugging
      final eventsByType = <EventType, int>{};
      for (final event in events) {
        eventsByType[event.type] = (eventsByType[event.type] ?? 0) + 1;
      }
      if (eventsByType.isNotEmpty) {
        print('[DB-FETCH] Event types: ${eventsByType.entries.map((e) => "${e.key.value}: ${e.value}").join(", ")}');
      }

      return events;
    } catch (e, stackTrace) {
      print('[DB-FETCH] ❌ Error fetching events: $e');
      print('[DB-FETCH] Stack trace: $stackTrace');
      return [];
    }
  }

  Future<bool> _savePattern(IntelligencePattern pattern) async {
    try {
      // Check if pattern already exists (by signature)
      final existing = await _supabase
          .from('intelligence_patterns')
          .select()
          .eq('user_id', userId)
          .eq('pattern_signature', pattern.patternSignature)
          .maybeSingle();

      if (existing != null) {
        // Update existing pattern's metrics
        await _supabase
            .from('intelligence_patterns')
            .update({
              'strength_metrics': pattern.strengthMetrics.toJson(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
        return false; // Not a new pattern
      }

      // Save new pattern
      await _supabase
          .from('intelligence_patterns')
          .insert(pattern.toJson());

      return true; // New pattern saved
    } catch (e) {
      print('Error saving pattern: $e');
      return false;
    }
  }

  Future<void> _saveOrUpdateStreak(UserStreak streak) async {
    try {
      print('[DB-SAVE] Saving streak: ${streak.streakType.name}${streak.streakName != null ? " (${streak.streakName})" : ""}');

      // Check if streak exists
      final existing = await _supabase
          .from('user_streaks')
          .select()
          .eq('user_id', userId)
          .eq('streak_type', streak.streakType.name)
          .eq('streak_name', streak.streakName ?? '')
          .maybeSingle();

      if (existing != null) {
        print('[DB-SAVE] Updating existing streak (ID: ${existing['id']})');
        // Update existing streak
        await _supabase
            .from('user_streaks')
            .update({
              'current_count': streak.currentCount,
              'best_count': streak.bestCount,
              'last_entry_date': streak.lastEntryDate?.toIso8601String().split('T')[0],
              'started_at': streak.startedAt?.toIso8601String().split('T')[0],
              'broken_at': streak.brokenAt?.toIso8601String().split('T')[0],
              'is_active': streak.isActive,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
        print('[DB-SAVE] ✓ Streak updated successfully');
      } else {
        print('[DB-SAVE] Creating new streak');
        // Save new streak
        await _supabase
            .from('user_streaks')
            .insert(streak.toJson());
        print('[DB-SAVE] ✓ Streak created successfully');
      }
    } catch (e, stackTrace) {
      print('[DB-SAVE] ❌ Error saving streak: $e');
      print('[DB-SAVE] Stack trace: $stackTrace');
    }
  }

  UserStreak? _calculateStreak(
    StreakType type,
    List<Event> events,
    List<Enrichment> enrichments,
  ) {
    if (events.isEmpty) return null;

    // Sort events by date
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Calculate consecutive days
    int currentStreak = 0;
    int bestStreak = 0;
    DateTime? lastDate;
    DateTime? startDate;

    for (final event in events) {
      final eventDate = DateTime(
        event.createdAt.year,
        event.createdAt.month,
        event.createdAt.day,
      );

      if (lastDate == null) {
        currentStreak = 1;
        lastDate = eventDate;
        startDate = eventDate;
      } else {
        final dayDiff = lastDate.difference(eventDate).inDays;

        if (dayDiff == 1) {
          currentStreak++;
          lastDate = eventDate;
        } else if (dayDiff > 1) {
          bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;
          currentStreak = 1;
          lastDate = eventDate;
          startDate = eventDate;
        }
      }
    }

    bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;

    return UserStreak(
      userId: userId,
      streakType: type,
      currentCount: currentStreak,
      bestCount: bestStreak,
      lastEntryDate: lastDate,
      startedAt: startDate,
      isActive: lastDate != null &&
          DateTime.now().difference(lastDate).inDays <= 1,
    );
  }

  UserStreak? _calculateMoodStreak(List<Enrichment> enrichments) {
    if (enrichments.isEmpty) return null;

    // Group by date and find dominant emotion per day
    final dailyEmotions = <DateTime, String>{};
    final emotionCounts = <DateTime, Map<String, int>>{};

    for (final enrichment in enrichments) {
      if (enrichment.emotion == null) continue;

      final date = DateTime(
        enrichment.createdAt.year,
        enrichment.createdAt.month,
        enrichment.createdAt.day,
      );

      emotionCounts.putIfAbsent(date, () => {});
      emotionCounts[date]![enrichment.emotion!] =
          (emotionCounts[date]![enrichment.emotion!] ?? 0) + 1;
    }

    // Find dominant emotion per day
    for (final entry in emotionCounts.entries) {
      final topEmotion = _getTopItem(entry.value);
      if (topEmotion != null) {
        dailyEmotions[entry.key] = topEmotion;
      }
    }

    // Calculate streak of same emotion
    final sortedDates = dailyEmotions.keys.toList()..sort((a, b) => b.compareTo(a));
    if (sortedDates.isEmpty) return null;

    int currentStreak = 1;
    int bestStreak = 1;
    String? currentEmotion = dailyEmotions[sortedDates.first];
    DateTime? lastDate = sortedDates.first;
    DateTime? startDate = sortedDates.first;

    for (int i = 1; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final emotion = dailyEmotions[date];

      if (emotion == currentEmotion &&
          lastDate!.difference(date).inDays == 1) {
        currentStreak++;
      } else {
        bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;
        currentStreak = 1;
        currentEmotion = emotion;
        startDate = date;
      }
      lastDate = date;
    }

    bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;

    return UserStreak(
      userId: userId,
      streakType: StreakType.mood,
      streakName: currentEmotion,
      currentCount: currentStreak,
      bestCount: bestStreak,
      lastEntryDate: lastDate,
      startedAt: startDate,
      isActive: lastDate != null &&
          DateTime.now().difference(lastDate).inDays <= 1,
    );
  }

  UserStreak? _calculateProductivityStreak(List<Enrichment> enrichments) {
    // Track days with high urgency entries
    final highUrgencyDays = <DateTime>{};

    for (final enrichment in enrichments) {
      if (enrichment.urgency == 'high') {
        final date = DateTime(
          enrichment.createdAt.year,
          enrichment.createdAt.month,
          enrichment.createdAt.day,
        );
        highUrgencyDays.add(date);
      }
    }

    if (highUrgencyDays.isEmpty) return null;

    // Sort dates and calculate streak
    final sortedDates = highUrgencyDays.toList()..sort((a, b) => b.compareTo(a));

    int currentStreak = 1;
    int bestStreak = 1;
    DateTime? lastDate = sortedDates.first;
    DateTime? startDate = sortedDates.first;

    for (int i = 1; i < sortedDates.length; i++) {
      final date = sortedDates[i];

      if (lastDate!.difference(date).inDays == 1) {
        currentStreak++;
      } else {
        bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;
        currentStreak = 1;
        startDate = date;
      }
      lastDate = date;
    }

    bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;

    return UserStreak(
      userId: userId,
      streakType: StreakType.productivity,
      currentCount: currentStreak,
      bestCount: bestStreak,
      lastEntryDate: lastDate,
      startedAt: startDate,
      isActive: lastDate != null &&
          DateTime.now().difference(lastDate).inDays <= 1,
    );
  }

  String? _getTopItem(Map<String, int> counts) {
    if (counts.isEmpty) return null;

    String? topItem;
    int maxCount = 0;

    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        topItem = entry.key;
      }
    }

    return topItem;
  }

  int _totalCount(Map<String, int> counts) {
    return counts.values.fold(0, (sum, count) => sum + count);
  }

  double _calculateConfidence(int occurrences, int total) {
    // Base confidence on frequency and total occurrences
    final frequency = occurrences / total;

    // Scale confidence based on total observations
    if (total >= 20) return frequency * 0.9;
    if (total >= 10) return frequency * 0.75;
    if (total >= 7) return frequency * 0.6;
    return frequency * 0.5;
  }
}