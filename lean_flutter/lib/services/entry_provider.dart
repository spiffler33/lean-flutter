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
  bool _isLoading = false;
  String? _error;
  Timer? _syncTimer;

  List<Entry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _supabase?.isAuthenticated ?? false;

  /// Initialize with optional Supabase
  Future<void> initialize({SupabaseService? supabase}) async {
    _supabase = supabase;

    // Load entries from local database
    await loadEntries();

    // Start background sync if online
    if (_supabase != null && _supabase!.isAuthenticated) {
      startBackgroundSync();
    }
  }

  /// Load entries from local database
  Future<void> loadEntries() async {
    try {
      _isLoading = true;
      notifyListeners();

      _entries = await _db.getEntries();

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
      // Create temporary entry
      final tempEntry = Entry(
        content: content,
        createdAt: DateTime.now(),
      );

      // Add to UI immediately (optimistic)
      _entries.insert(0, tempEntry);
      notifyListeners();

      // Save to local database
      final localId = await _db.insertEntry(tempEntry);
      final savedEntry = await _db.getEntry(localId);

      if (savedEntry != null) {
        // Update UI with entry that has ID
        final index = _entries.indexWhere((e) => e.id == null);
        if (index != -1) {
          _entries[index] = savedEntry;
          notifyListeners();
        }

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

      // Update in local list
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _entries[index] = entry;
        notifyListeners();
      }

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
      await _db.deleteEntry(id);

      // Remove from local list
      _entries.removeWhere((e) => e.id == id);
      notifyListeners();

      // Delete from cloud
      if (_supabase != null && _supabase!.isAuthenticated) {
        await _supabase!.deleteEntry(id);
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

    try {
      if (entry.id == null) return;

      final remoteEntry = await _supabase!.createEntry(entry);

      // Mark as synced in local database
      if (remoteEntry.id != null) {
        await _db.markAsSynced(entry.id!, remoteEntry.id!);
      }
    } catch (e) {
      debugPrint('Sync failed for entry ${entry.id}: $e');
      // Don't notify user, will retry in background sync
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
      // Get unsynced entries
      final unsyncedEntries = await _db.getUnsyncedEntries();

      // Sync each entry
      for (final entry in unsyncedEntries) {
        await _syncEntryToCloud(entry);
      }

      // Pull remote changes (last 24 hours)
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final remoteEntries = await _supabase!.fetchEntriesAfter(yesterday);

      // Merge remote entries into local database
      // (In Phase 2, we'll add conflict resolution)
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
    } catch (e) {
      debugPrint('Background sync failed: $e');
      // Silent failure - will retry next cycle
    }
  }

  /// Manual sync trigger
  Future<void> manualSync() async {
    await _performBackgroundSync();
  }

  @override
  void dispose() {
    stopBackgroundSync();
    super.dispose();
  }
}
