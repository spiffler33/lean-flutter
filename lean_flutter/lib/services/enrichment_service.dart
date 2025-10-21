import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/entry.dart';
import '../models/enrichment.dart';
import 'database_service.dart';
import 'supabase_service.dart';
import 'anthropic_service.dart';

/// Service to handle AI enrichment of entries
/// Uses Anthropic Claude API with fallback to mock data
class EnrichmentService {
  static EnrichmentService? _instance;
  final DatabaseService _db = DatabaseService.instance;
  final SupabaseService? _supabase;
  final AnthropicService _anthropic = AnthropicService();

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
  void initialize() {
    // Start processing timer (check queue every 2 seconds)
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _processQueue();
    });
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

  /// Enrich a single entry using Claude API
  Future<void> _enrichEntry(Entry entry) async {
    if (entry.id == null) return;

    final startTime = DateTime.now();

    try {
      // Use Claude API to generate enrichment (with fallback to mock)
      final enrichment = await _anthropic.generateEnrichment(
        entry.content,
        entry.id.toString(),
      );

      // Calculate processing time
      final processingTime = DateTime.now().difference(startTime).inMilliseconds;
      final finalEnrichment = enrichment.copyWith(
        processingTimeMs: processingTime,
        processingStatus: 'complete',
      );

      // Save enrichment
      await saveEnrichment(finalEnrichment);

      print('✅ Enriched entry ${entry.id} in ${processingTime}ms');
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
    if (kIsWeb) {
      // Web: save to memory storage
      if (enrichment.entryId != null) {
        _webEnrichmentStorage[enrichment.entryId!] = enrichment;
      }
    } else {
      // Mobile: save to SQLite (TODO: implement SQLite methods)
      // For now, just store in memory
      if (enrichment.entryId != null) {
        _webEnrichmentStorage[enrichment.entryId!] = enrichment;
      }
    }

    // If authenticated, also save to Supabase
    // Skip cloud sync for now - needs entry's cloudId which we don't have yet
    // TODO: Fix this by getting the entry's cloudId first
    /*
    if (_supabase?.isAuthenticated ?? false) {
      try {
        await _supabase!.createEnrichment(enrichment);
      } catch (e) {
        print('Failed to sync enrichment to cloud: $e');
      }
    }
    */
  }

  /// Get enrichment for an entry
  Future<Enrichment?> getEnrichmentForEntry(int entryId) async {
    if (kIsWeb || true) { // Using memory storage for now
      return _webEnrichmentStorage[entryId];
    }

    // TODO: Implement SQLite retrieval
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