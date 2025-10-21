import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/entry.dart';
import '../models/enrichment.dart';
import '../models/event.dart';
import 'database_service.dart';
import 'supabase_service.dart';
import 'anthropic_service.dart';
import 'event_extraction_service.dart';

/// Service to handle AI enrichment of entries
/// Uses Anthropic Claude API with fallback to mock data
class EnrichmentService {
  static EnrichmentService? _instance;
  final DatabaseService _db = DatabaseService.instance;
  final SupabaseService? _supabase;
  final AnthropicService _anthropic = AnthropicService();
  EventExtractionService? _eventExtractor;

  // For web platform - in-memory storage
  static final Map<int, Enrichment> _webEnrichmentStorage = {};

  // Processing queue
  final _processingQueue = <Entry>[];
  Timer? _processingTimer;
  bool _isProcessing = false;

  static EnrichmentService get instance {
    _instance ??= EnrichmentService._();
    return _instance!;
  }

  EnrichmentService._() : _supabase = SupabaseService.instance;

  /// Initialize the enrichment service
  Future<void> initialize() async {
    // Initialize event extraction service if Supabase is available
    if (_supabase != null && _supabase!.client != null) {
      _eventExtractor = EventExtractionService(_supabase!.client);
      print('✅ EventExtractionService initialized');
    } else {
      print('⚠️ EventExtractionService not initialized - Supabase not available');
    }

    // Start processing timer (check queue every 2 seconds)
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _processQueue();
    });

    // Load existing enrichments from Supabase if authenticated
    if (_supabase?.isAuthenticated ?? false) {
      await loadEnrichmentsFromCloud();
    }
  }

  /// Load all enrichments from Supabase
  Future<void> loadEnrichmentsFromCloud() async {
    if (!(_supabase?.isAuthenticated ?? false)) return;

    try {
      print('📥 Loading enrichments from Supabase...');
      final enrichments = await _supabase!.fetchEnrichments();

      // Match enrichments to local entries and cache them
      for (final enrichment in enrichments) {
        if (enrichment.entryCloudId != null) {
          // Find the local entry with this cloud ID
          final entries = await _db.getEntries();
          for (final entry in entries) {
            if (entry.cloudId == enrichment.entryCloudId) {
              // Cache with local entry ID
              final localEnrichment = enrichment.copyWith(entryId: entry.id);
              _webEnrichmentStorage[entry.id!] = localEnrichment;
              break;
            }
          }
        }
      }

      print('✅ Loaded ${enrichments.length} enrichments from cloud');
    } catch (e) {
      print('⚠️ Failed to load enrichments from cloud: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _processingTimer?.cancel();
    _processingTimer = null;
  }

  /// Queue an entry for enrichment
  Future<void> queueForEnrichment(Entry entry) async {
    if (entry.id == null) return;

    // Check if already has enrichment
    final existingEnrichment = await getEnrichmentForEntry(entry.id!);
    if (existingEnrichment != null && existingEnrichment.isComplete) {
      print('⏭️ Entry ${entry.id} already has enrichment, skipping');
      return; // Already enriched
    }

    // Add to queue if not already there
    if (!_processingQueue.any((e) => e.id == entry.id)) {
      _processingQueue.add(entry);
      print('📝 Queued entry ${entry.id} for enrichment');
    }
  }

  /// Process the enrichment queue
  Future<void> _processQueue() async {
    if (_isProcessing || _processingQueue.isEmpty) return;

    _isProcessing = true;

    while (_processingQueue.isNotEmpty) {
      final entry = _processingQueue.removeAt(0);
      try {
        await _enrichEntry(entry);
      } catch (e) {
        print('❌ Error enriching entry ${entry.id}: $e');
      }
    }

    _isProcessing = false;
  }

  /// Enrich a single entry using Claude API with integrated event extraction
  Future<void> _enrichEntry(Entry entry) async {
    if (entry.id == null) return;

    // Refresh entry from database to get latest cloudId
    final refreshedEntry = await _db.getEntryById(entry.id!);
    if (refreshedEntry != null) {
      entry = refreshedEntry;
      print('🔄 Refreshed entry ${entry.id} - cloudId: ${entry.cloudId}');
    }

    final startTime = DateTime.now();

    try {
      // Use Claude API to generate enrichment AND extract events in one call
      final result = await _anthropic.generateEnrichmentWithEvents(
        entry.content,
        entry.id.toString(),
      );

      // Calculate processing time
      final processingTime = DateTime.now().difference(startTime).inMilliseconds;
      final finalEnrichment = result.enrichment.copyWith(
        processingTimeMs: processingTime,
        processingStatus: 'complete',
      );

      // Save enrichment
      await saveEnrichment(finalEnrichment);

      print('✅ Enriched entry ${entry.id} in ${processingTime}ms');

      // Process LLM-extracted events
      if (result.events.isNotEmpty && _supabase != null && entry.cloudId != null && _supabase!.userId != null) {
        try {
          print('🎯 Processing ${result.events.length} LLM-extracted events for entry ${entry.id}');

          // Save high-confidence events directly to database
          final highConfidenceEvents = <Map<String, dynamic>>[];
          final shadowEvents = <Map<String, dynamic>>[];

          for (final eventData in result.events) {
            final confidence = (eventData['confidence'] as num?)?.toDouble() ?? 0.5;

            // Create event record
            final event = {
              'user_id': _supabase!.userId!,
              'entry_id': entry.cloudId!,
              'type': eventData['type'],
              'subtype': eventData['subtype'],
              'metrics': eventData['metrics'] ?? {},
              'confidence': confidence,
              'extraction_method': 'llm',
            };

            if (confidence >= 0.85) {
              highConfidenceEvents.add(event);
              print('  ✓ High confidence (${confidence.toStringAsFixed(2)}): ${eventData['type']}.${eventData['subtype']}');
            } else if (confidence >= 0.65) {
              shadowEvents.add(event);
              print('  ~ Shadow event (${confidence.toStringAsFixed(2)}): ${eventData['type']}.${eventData['subtype']}');
            } else {
              print('  ✗ Low confidence (${confidence.toStringAsFixed(2)}): ${eventData['type']}.${eventData['subtype']} - skipping');
            }
          }

          // Save high-confidence events
          if (highConfidenceEvents.isNotEmpty) {
            await _supabase!.client.from('events').insert(highConfidenceEvents);
            print('📊 Saved ${highConfidenceEvents.length} high-confidence events');
          }

          // Save shadow events for learning
          if (shadowEvents.isNotEmpty) {
            final shadowRecords = shadowEvents.map((e) => {
              ...e,
              'phrase': entry.content.substring(0, 100.clamp(0, entry.content.length)),
            }).toList();

            await _supabase!.client.from('shadow_events').insert(shadowRecords);
            print('👻 Saved ${shadowEvents.length} shadow events for learning');
          }

        } catch (e) {
          print('⚠️ Error saving LLM events: $e');
        }
      } else if (result.events.isEmpty) {
        print('ℹ️ No events extracted by LLM for entry ${entry.id}');
      }

      // Legacy regex-based extraction fallback (can be removed after testing)
      // The regex-based extraction is now replaced by LLM extraction above
    } catch (e) {
      // Save failed enrichment
      final failedEnrichment = Enrichment(
        entryId: entry.id,
        processingStatus: 'failed',
        errorMessage: e.toString(),
        processingTimeMs: DateTime.now().difference(startTime).inMilliseconds,
      );
      await saveEnrichment(failedEnrichment);

      print('❌ Failed to enrich entry ${entry.id}: $e');
    }
  }

  /// Generate mock enrichment based on entry content
  Enrichment _generateMockEnrichment(Entry entry) {
    final content = entry.content.toLowerCase();
    final random = Random();

    // Mock emotion detection
    String? emotion;
    if (content.contains('happy') || content.contains('great') || content.contains('awesome')) {
      emotion = 'excited';
    } else if (content.contains('sad') || content.contains('down')) {
      emotion = 'sad';
    } else if (content.contains('stress') || content.contains('anxious')) {
      emotion = 'anxious';
    } else if (content.contains('tired') || content.contains('exhausted')) {
      emotion = 'tired';
    } else if (content.contains('angry') || content.contains('frustrated')) {
      emotion = 'frustrated';
    } else {
      emotion = Enrichment.emotionVocabulary[random.nextInt(Enrichment.emotionVocabulary.length)];
    }

    // Mock theme detection
    List<String> themes = [];
    if (content.contains('work') || content.contains('meeting') || content.contains('project')) {
      themes.add('work');
    }
    if (content.contains('exercise') || content.contains('gym') || content.contains('run')) {
      themes.add('health');
    }
    if (content.contains('friend') || content.contains('family') || content.contains('date')) {
      themes.add('relationships');
    }
    if (content.contains('money') || content.contains('budget') || content.contains('spent')) {
      themes.add('finance');
    }
    if (themes.isEmpty) {
      // Add random theme if none detected
      themes.add(Enrichment.themeVocabulary[random.nextInt(Enrichment.themeVocabulary.length)]);
    }
    // Limit to max 3 themes
    if (themes.length > 3) {
      themes = themes.sublist(0, 3);
    }

    // Mock urgency detection
    String urgency = 'none';
    if (content.contains('urgent') || content.contains('asap') || content.contains('immediately')) {
      urgency = 'high';
    } else if (content.contains('soon') || content.contains('today') || content.contains('deadline')) {
      urgency = 'medium';
    } else if (content.contains('eventually') || content.contains('someday')) {
      urgency = 'low';
    }

    // Mock people extraction (look for capitalized names)
    List<Map<String, dynamic>> people = [];
    final namePattern = RegExp(r'\b[A-Z][a-z]+\b');
    final matches = namePattern.allMatches(entry.content);
    for (final match in matches) {
      final name = match.group(0)!;
      // Filter out common words that start with capital
      if (!['The', 'This', 'That', 'These', 'Those', 'Today', 'Tomorrow'].contains(name)) {
        people.add({
          'name': name,
          'context': 'mentioned',
          'sentiment': 'neutral',
        });
      }
    }

    // Mock action extraction
    List<String> actions = [];
    if (content.contains('todo') || content.contains('need to') || content.contains('must')) {
      actions.add('Review and complete pending tasks');
    }
    if (content.contains('call') || content.contains('email') || content.contains('message')) {
      actions.add('Follow up on communication');
    }

    // Mock questions
    List<Map<String, dynamic>> questions = [];
    if (content.contains('?')) {
      questions.add({
        'text': 'Open question detected',
        'type': 'open-ended',
        'answered': false,
      });
    }

    // Mock confidence scores
    Map<String, double> confidenceScores = {
      'emotion': 0.85 + random.nextDouble() * 0.15,
      'themes': 0.80 + random.nextDouble() * 0.20,
      'urgency': 0.75 + random.nextDouble() * 0.25,
      'people': people.isNotEmpty ? 0.90 : 0.50,
      'actions': actions.isNotEmpty ? 0.85 : 0.60,
    };

    return Enrichment(
      entryId: entry.id,
      entryCloudId: entry.cloudId,
      userId: entry.userId,
      emotion: emotion,
      themes: themes,
      people: people,
      urgency: urgency,
      actions: actions,
      questions: questions,
      confidenceScores: confidenceScores,
      processingStatus: 'processing',
    );
  }

  /// Save enrichment to database
  Future<void> saveEnrichment(Enrichment enrichment) async {
    // Always save to memory first for fast access
    if (enrichment.entryId != null) {
      _webEnrichmentStorage[enrichment.entryId!] = enrichment;
    }

    // Save to Supabase if authenticated
    if (_supabase?.isAuthenticated ?? false) {
      try {
        // Get the entry to find its cloudId
        final entry = await _db.getEntryById(enrichment.entryId!);
        if (entry != null && entry.cloudId != null) {
          // Create enrichment with entry's cloud ID
          final cloudEnrichment = enrichment.copyWith(
            entryCloudId: entry.cloudId,
            userId: _supabase!.userId,
          );
          await _supabase!.createEnrichment(cloudEnrichment);
          print('☁️ Saved enrichment to Supabase for entry ${enrichment.entryId}');
        }
      } catch (e) {
        print('⚠️ Failed to sync enrichment to cloud: $e');
        // Continue - enrichment is still saved locally
      }
    }
  }

  /// Get enrichment for an entry
  Future<Enrichment?> getEnrichmentForEntry(int entryId) async {
    // Check memory storage first
    if (_webEnrichmentStorage.containsKey(entryId)) {
      return _webEnrichmentStorage[entryId];
    }

    // If not in memory and connected to Supabase, try to fetch from cloud
    if (_supabase?.isAuthenticated ?? false) {
      try {
        // Get the entry to find its cloudId
        final entry = await _db.getEntryById(entryId);
        if (entry != null && entry.cloudId != null) {
          final enrichment = await _supabase!.getEnrichmentForEntry(entry.cloudId!);
          if (enrichment != null) {
            // Update the local entryId to match our local database
            final localEnrichment = enrichment.copyWith(entryId: entryId);
            // Cache in memory for future access
            _webEnrichmentStorage[entryId] = localEnrichment;
            print('📥 Loaded enrichment from Supabase for entry $entryId');
            return localEnrichment;
          }
        }
      } catch (e) {
        print('⚠️ Failed to fetch enrichment from cloud: $e');
      }
    }

    return null;
  }

  /// Get all enrichments
  Future<List<Enrichment>> getAllEnrichments() async {
    if (kIsWeb || true) { // Using memory storage for now
      return _webEnrichmentStorage.values.toList();
    }

    // TODO: Implement SQLite retrieval
    return [];
  }

  /// Clear all enrichments (for testing)
  Future<void> clearAll() async {
    _webEnrichmentStorage.clear();
    _processingQueue.clear();
  }

  /// Manual trigger to enrich an entry immediately
  Future<void> enrichNow(Entry entry) async {
    await _enrichEntry(entry);
  }
}