import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/entry.dart';
import 'database_service.dart';
import 'enrichment_service.dart';
import 'supabase_service.dart';

/// State management for entries with offline-first + Supabase sync
class EntryProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final EnrichmentService _enrichmentService = EnrichmentService.instance;
  SupabaseService? _supabase;

  List<Entry> _entries = [];
  List<Entry> _allEntries = []; // Store all entries for filtering
  bool _isLoading = false;
  String? _error;
  Timer? _syncTimer;
  String? _filterLabel; // Label for active filter (e.g., "today's entries")
  bool _showTimeDivider = true; // Show time divider on app load (PWA behavior)
  final Set<int> _failedSyncEntries = {}; // Track entries that permanently failed to sync

  List<Entry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _supabase?.isAuthenticated ?? false;
  String? get filterLabel => _filterLabel;
  bool get showTimeDivider => _showTimeDivider;

  /// Get count of open todos from ALL entries (not filtered list)
  int get openTodoCount => _allEntries
      .where((e) => e.isTodo && !e.isDone)
      .length;

  /// Set Supabase service reference (synchronous)
  void setSupabase(SupabaseService supabase) {
    print('📡 Setting Supabase reference in EntryProvider');
    _supabase = supabase;
    notifyListeners();
  }

  /// Initialize with optional Supabase
  Future<void> initialize({SupabaseService? supabase}) async {
    if (supabase != null) {
      _supabase = supabase;
    }

    // Initialize enrichment service
    await _enrichmentService.initialize();

    // On web: Fetch from Supabase first (web uses in-memory storage)
    if (kIsWeb && _supabase != null && _supabase!.isAuthenticated) {
      await _fetchFromSupabaseWeb();
    }

    // Load entries from local database
    await loadEntries();

    // Start background sync if online
    if (_supabase != null && _supabase!.isAuthenticated) {
      startBackgroundSync();
    }
  }

  /// Fetch entries from Supabase and populate web memory storage
  Future<void> _fetchFromSupabaseWeb() async {
    if (_supabase == null || !_supabase!.isAuthenticated) return;

    try {
      print('📥 Pulling all entries from Supabase...');
      final remoteEntries = await _supabase!.fetchEntries(limit: 1000);

      print('📦 Pulled ${remoteEntries.length} entries from Supabase');

      // Clear existing web memory storage before repopulating
      await _db.clearWebStorage();

      // Populate web memory storage with fresh data from Supabase
      // Insert in reverse order to maintain chronological order (newest first)
      for (var i = remoteEntries.length - 1; i >= 0; i--) {
        await _db.insertEntry(remoteEntries[i]);
      }

      print('✅ Successfully inserted ${remoteEntries.length} entries into storage');
    } catch (e, stackTrace) {
      print('⚠️ Failed to fetch from Supabase: $e');
      print('Stack: $stackTrace');
    }
  }

  /// Load entries from local database
  Future<void> loadEntries() async {
    try {
      print('📖 Loading entries from database...');
      _isLoading = true;
      notifyListeners();

      _allEntries = await _db.getEntries();
      _entries = List.from(_allEntries); // Create a copy to avoid duplicates
      _filterLabel = null; // Clear any filter
      _showTimeDivider = true; // Show divider after loading (PWA: indicates refresh)

      print('✅ Loaded ${_entries.length} entries successfully');

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Error loading entries: $e');
      print('Stack: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create entry (optimistic UI)
  Future<Entry> createEntry(String content) async {
    try {
      // Hide time divider (PWA: user is writing, session continues)
      _showTimeDivider = false;

      // Create temporary entry
      final tempEntry = Entry(
        content: content,
        createdAt: DateTime.now(),
      );

      // Add to allEntries (source of truth)
      _allEntries.insert(0, tempEntry);

      // Update displayed entries only if no filter is active
      if (_filterLabel == null) {
        _entries.insert(0, tempEntry);
      }

      notifyListeners();

      // Save to local database
      final localId = await _db.insertEntry(tempEntry);
      final savedEntry = await _db.getEntry(localId);

      if (savedEntry != null) {
        // Update in allEntries
        final allIndex = _allEntries.indexWhere((e) => e.id == null);
        if (allIndex != -1) {
          _allEntries[allIndex] = savedEntry;
        }

        // Update in displayed entries if no filter
        if (_filterLabel == null) {
          final index = _entries.indexWhere((e) => e.id == null);
          if (index != -1) {
            _entries[index] = savedEntry;
          }
        }

        notifyListeners();

        // Queue for AI enrichment
        await _enrichmentService.queueForEnrichment(savedEntry);
        print('⚡ Queued entry ${savedEntry.id} for AI enrichment');

        // Sync to Supabase (await on web to ensure persistence before signout)
        print('🔍 Checking sync conditions: supabase=${_supabase != null}, auth=${_supabase?.isAuthenticated}, web=$kIsWeb');
        if (_supabase != null && _supabase!.isAuthenticated) {
          print('✅ Sync conditions met, syncing entry ${savedEntry.id}...');
          if (kIsWeb) {
            await _syncEntryToCloud(savedEntry);
          } else {
            _syncEntryToCloud(savedEntry); // Background on mobile
          }
        } else {
          print('❌ Sync conditions NOT met - entry will not sync to cloud!');
        }

        return savedEntry;
      }

      return tempEntry;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update entry
  Future<void> updateEntry(Entry entry) async {
    try {
      await _db.updateEntry(entry);

      // Update in allEntries
      final allIndex = _allEntries.indexWhere((e) => e.id == entry.id);
      if (allIndex != -1) {
        _allEntries[allIndex] = entry;
      }

      // Update in displayed entries
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _entries[index] = entry;
      }

      notifyListeners();

      // Sync to cloud (await on web to ensure persistence)
      if (_supabase != null && _supabase!.isAuthenticated) {
        if (kIsWeb) {
          await _syncEntryToCloud(entry);
        } else {
          _syncEntryToCloud(entry); // Background on mobile
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete entry
  Future<void> deleteEntry(int id) async {
    try {
      // Find entry to get cloud ID before deleting
      final entryToDelete = _allEntries.firstWhere((e) => e.id == id, orElse: () => throw Exception('Entry not found'));

      await _db.deleteEntry(id);

      // Remove from BOTH local lists
      _entries.removeWhere((e) => e.id == id);
      _allEntries.removeWhere((e) => e.id == id);
      notifyListeners();

      // Delete from cloud if it has been synced
      if (_supabase != null && _supabase!.isAuthenticated && entryToDelete.cloudId != null) {
        await _supabase!.deleteEntry(entryToDelete.cloudId!);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Search entries
  Future<List<Entry>> searchEntries(String query) async {
    try {
      return await _db.searchEntries(query);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Get today's entries
  Future<List<Entry>> getTodayEntries() async {
    try {
      return await _db.getTodayEntries();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Get todo entries
  Future<List<Entry>> getTodoEntries() async {
    try {
      return await _db.getTodoEntries();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Get entry count
  Future<int> getEntryCount() async {
    return await _db.getEntryCount();
  }

  /// Sync single entry to cloud (background)
  Future<void> _syncEntryToCloud(Entry entry) async {
    // Use print() for release builds (debugPrint is stripped)
    if (_supabase == null || !_supabase!.isAuthenticated) {
      print('⚠️ Sync skipped: Not authenticated (supabase: $_supabase, auth: ${_supabase?.isAuthenticated})');
      return;
    }
    if (entry.id == null) {
      print('⚠️ Sync skipped: Entry has no local ID');
      return;
    }

    // Skip entries that have permanently failed (malformed data from before fix)
    if (_failedSyncEntries.contains(entry.id)) return;

    try {
      Entry remoteEntry;

      // Check if entry already exists in cloud (has cloudId)
      if (entry.cloudId != null) {
        print('☁️ Updating existing entry ${entry.id} (cloudId: ${entry.cloudId}) in Supabase...');
        remoteEntry = await _supabase!.updateEntry(entry);
        print('✅ Updated entry ${entry.id} in Supabase');
      } else {
        print('☁️ Creating new entry ${entry.id} in Supabase...');
        remoteEntry = await _supabase!.createEntry(entry);
        print('✅ Created entry ${entry.id}, got cloudId: ${remoteEntry.cloudId}');

        // Mark as synced in local database (only for new entries)
        if (remoteEntry.cloudId != null && entry.id != null) {
          await _db.markAsSynced(entry.id!, remoteEntry.cloudId!);
          print('✅ Marked entry ${entry.id} as synced with cloudId ${remoteEntry.cloudId}');
        }
      }
    } catch (e, stackTrace) {
      final errorStr = e.toString();

      // If it's a permanent error (malformed/incompatible data), stop retrying this entry
      if (errorStr.contains('22P02') ||
          errorStr.contains('malformed array literal') ||
          errorStr.contains('type \'String\' is not a subtype of type \'int')) {
        _failedSyncEntries.add(entry.id!);
        // Silently skip - these are old entries with incompatible data
        return;
      }

      // Log other errors (network issues, etc.)
      print('❌ Sync failed for entry ${entry.id}: $e');
      print('Stack trace: $stackTrace');

      // On web, rethrow to notify user of sync failure
      if (kIsWeb) {
        rethrow;
      }
    }
  }

  /// Start background sync (every 10 seconds)
  void startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _performBackgroundSync();
    });
  }

  /// Stop background sync
  void stopBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Perform background sync
  Future<void> _performBackgroundSync() async {
    if (_supabase == null || !_supabase!.isAuthenticated) return;

    try {
      // Get unsynced entries (skip on web - uses in-memory storage)
      if (!kIsWeb) {
        final unsyncedEntries = await _db.getUnsyncedEntries();

        // Sync each entry
        for (final entry in unsyncedEntries) {
          await _syncEntryToCloud(entry);
        }
      }

      // Pull remote changes (last 24 hours)
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final remoteEntries = await _supabase!.fetchEntriesAfter(yesterday);

      // Merge remote entries into local database (skip on web)
      if (!kIsWeb) {
        for (final remoteEntry in remoteEntries) {
          // Simple merge: if remote ID not in local, insert it
          final exists = _entries.any((e) => e.id == remoteEntry.id);
          if (!exists) {
            await _db.insertEntry(remoteEntry);
          }
        }

        // Reload entries if any changes
        if (remoteEntries.isNotEmpty) {
          await loadEntries();
        }
      }
    } catch (e) {
      // Log unexpected errors only
      debugPrint('Background sync failed: $e');
    }
  }

  /// Manual sync trigger
  Future<void> manualSync() async {
    await _performBackgroundSync();
  }

  /// Set filtered entries (for commands like /today, /search)
  void setFilteredEntries(List<Entry> filteredEntries, String label) {
    _entries = filteredEntries;
    _filterLabel = label;
    notifyListeners();
  }

  /// Clear filter and show all entries
  void clearFilter() {
    _entries = _allEntries;
    _filterLabel = null;
    notifyListeners();
  }

  /// Toggle todo filter (show only open todos)
  void toggleTodoFilter() {
    if (_filterLabel == 'open todos') {
      // Already filtering todos, so clear filter
      clearFilter();
    } else {
      // Filter to show only open todos (not done)
      final todos = _allEntries
          .where((e) => e.isTodo && !e.isDone)
          .toList();
      setFilteredEntries(todos, 'open todos');
    }
  }

  /// Toggle todo status (between #todo and #done)
  Future<void> toggleTodo(Entry entry) async {
    if (entry.id == null) return;

    // Toggle between #todo and #done
    String newContent;
    if (entry.content.contains('#done')) {
      // Done -> Todo
      newContent = entry.content.replaceAll('#done', '#todo');
    } else if (entry.content.contains('#todo')) {
      // Todo -> Done
      newContent = entry.content.replaceAll('#todo', '#done');
    } else {
      return; // Not a todo
    }

    final updatedEntry = entry.copyWith(content: newContent);

    try {
      // Update in database
      await _db.updateEntry(updatedEntry);

      // Update in allEntries
      final allIndex = _allEntries.indexWhere((e) => e.id == entry.id);
      if (allIndex != -1) {
        _allEntries[allIndex] = updatedEntry;
      }

      // Update in displayed entries based on filter state
      if (_filterLabel == 'open todos') {
        // If marking as done, remove from filtered list
        if (newContent.contains('#done')) {
          _entries.removeWhere((e) => e.id == entry.id);
        } else {
          // If marking as todo again, update it
          final index = _entries.indexWhere((e) => e.id == entry.id);
          if (index != -1) {
            _entries[index] = updatedEntry;
          }
        }
      } else {
        // No filter active, just update the entry
        final index = _entries.indexWhere((e) => e.id == entry.id);
        if (index != -1) {
          _entries[index] = updatedEntry;
        }
      }

      // Single notification after all updates
      notifyListeners();

      // Clear filter if no more open todos (PWA behavior: updateTodoCounter line 1203)
      if (_filterLabel == 'open todos' && openTodoCount == 0) {
        clearFilter();
      }

      // Sync to cloud (await on web to ensure persistence)
      if (_supabase != null && _supabase!.isAuthenticated) {
        if (kIsWeb) {
          await _syncEntryToCloud(updatedEntry);
        } else {
          _syncEntryToCloud(updatedEntry); // Background on mobile
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Show time divider (for /clear command)
  void enableTimeDivider() {
    _showTimeDivider = true;
    notifyListeners();
  }

  /// Hide time divider
  void disableTimeDivider() {
    _showTimeDivider = false;
    notifyListeners();
  }

  /// Clear view (for /clear command) - clears displayed entries without deleting from database
  void clearView() {
    _entries = []; // Clear displayed entries
    _filterLabel = null; // Clear any filter
    _showTimeDivider = true; // Show time divider
    notifyListeners();
  }

  @override
  void dispose() {
    stopBackgroundSync();
    _enrichmentService.dispose();
    super.dispose();
  }
}
