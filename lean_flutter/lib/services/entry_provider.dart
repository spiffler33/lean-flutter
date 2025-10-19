import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/entry.dart';
import 'database_service.dart';
import 'supabase_service.dart';

/// State management for entries with offline-first + Supabase sync
class EntryProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
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

  /// Initialize with optional Supabase
  Future<void> initialize({SupabaseService? supabase}) async {
    _supabase = supabase;

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
      debugPrint('📥 Pulling all entries from Supabase...');
      final remoteEntries = await _supabase!.fetchEntries(limit: 1000);

      debugPrint('📦 Pulled ${remoteEntries.length} entries from Supabase');

      // Populate web memory storage directly
      for (final remoteEntry in remoteEntries) {
        await _db.insertEntry(remoteEntry);
      }

      debugPrint('✅ Successfully synced entries from cloud');
    } catch (e) {
      debugPrint('⚠️ Failed to fetch from Supabase: $e');
    }
  }

  /// Load entries from local database
  Future<void> loadEntries() async {
    try {
      _isLoading = true;
      notifyListeners();

      _allEntries = await _db.getEntries();
      _entries = List.from(_allEntries); // Create a copy to avoid duplicates
      _filterLabel = null; // Clear any filter
      _showTimeDivider = true; // Show divider after loading (PWA: indicates refresh)

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
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

        // Sync to Supabase in background
        if (_supabase != null && _supabase!.isAuthenticated) {
          _syncEntryToCloud(savedEntry);
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

      // Sync to cloud
      if (_supabase != null && _supabase!.isAuthenticated) {
        _syncEntryToCloud(entry);
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
    if (_supabase == null || !_supabase!.isAuthenticated) return;
    if (entry.id == null) return;

    // Skip entries that have permanently failed (malformed data from before fix)
    if (_failedSyncEntries.contains(entry.id)) return;

    try {
      final remoteEntry = await _supabase!.createEntry(entry);

      // Mark as synced in local database (use cloudId instead of id)
      if (remoteEntry.cloudId != null && entry.id != null) {
        await _db.markAsSynced(entry.id!, remoteEntry.cloudId!);
      }
    } catch (e) {
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
      debugPrint('Sync failed for entry ${entry.id}: $e');
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
    await updateEntry(updatedEntry);

    // Reload to refresh the list
    await loadEntries();
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
    super.dispose();
  }
}
