import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_fact.dart';
import 'database_service.dart';
import 'supabase_service.dart';

/// Service for managing user facts/context
class UserFactService {
  final DatabaseService _db = DatabaseService.instance;
  final SupabaseService _supabaseService = SupabaseService.instance;

  // In-memory storage for web platform
  static final List<UserFact> _webMemoryStorage = [];

  /// Get the current user ID
  String get _userId => _supabaseService.currentUserId ?? 'local';

  /// Add a new user fact
  Future<UserFact> addFact({
    required String category,
    required String fact,
    List<String>? entityRefs,
  }) async {
    // Validate category
    if (!UserFactCategory.isValid(category)) {
      throw ArgumentError('Invalid category: $category');
    }

    final userFact = UserFact.create(
      userId: _userId,
      category: category,
      fact: fact,
      entityRefs: entityRefs ?? [],
    );

    if (kIsWeb) {
      // Web: add to memory storage
      _webMemoryStorage.add(userFact);
      print('✅ Added user fact to web storage: ${userFact.fact}');
    } else {
      // Mobile: save to SQLite
      try {
        final db = await _db.database;
        await db.insert('user_facts', userFact.toDatabase());
        print('✅ Saved user fact to SQLite: ${userFact.fact}');
      } catch (e) {
        print('❌ Failed to save user fact: $e');
        throw e;
      }
    }

    // Sync to Supabase if connected
    if (_supabaseService.isConnected) {
      try {
        await _supabaseService.client
            .from('user_facts')
            .insert(userFact.toJson());
        print('☁️ Synced user fact to Supabase');
      } catch (e) {
        print('⚠️ Failed to sync user fact to cloud: $e');
        // Continue even if cloud sync fails
      }
    }

    return userFact;
  }

  /// Get all active user facts
  Future<List<UserFact>> getAllFacts() async {
    // If connected to Supabase, try to load fresh data from cloud
    if (_supabaseService.isConnected) {
      try {
        final response = await _supabaseService.client
            .from('user_facts')
            .select()
            .eq('user_id', _userId)
            .eq('active', true)
            .order('added_at', ascending: false);

        final facts = (response as List)
            .map((json) => UserFact.fromJson(json))
            .toList();

        // Update memory storage with cloud data for web
        if (kIsWeb) {
          _webMemoryStorage.removeWhere((f) => f.userId == _userId);
          _webMemoryStorage.addAll(facts);
        }

        return facts;
      } catch (e) {
        print('⚠️ Failed to get facts from cloud, using local storage: $e');
        // Fall through to local storage
      }
    }

    // Fallback to local storage if not connected or error
    if (kIsWeb) {
      // Web: return from memory storage
      return _webMemoryStorage
          .where((f) => f.userId == _userId && f.active)
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }

    try {
      final db = await _db.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'user_facts',
        where: 'user_id = ? AND active = ?',
        whereArgs: [_userId, 1],
        orderBy: 'added_at DESC',
      );

      return maps.map((map) => UserFact.fromDatabase(map)).toList();
    } catch (e) {
      print('⚠️ Failed to get user facts from database: $e');
      return [];
    }
  }

  /// Get facts by category
  Future<List<UserFact>> getFactsByCategory(String category) async {
    // If connected to Supabase, try to load fresh data from cloud
    if (_supabaseService.isConnected) {
      try {
        final response = await _supabaseService.client
            .from('user_facts')
            .select()
            .eq('user_id', _userId)
            .eq('category', category)
            .eq('active', true)
            .order('added_at', ascending: false);

        return (response as List)
            .map((json) => UserFact.fromJson(json))
            .toList();
      } catch (e) {
        print('⚠️ Failed to get facts from cloud, using local storage: $e');
        // Fall through to local storage
      }
    }

    // Fallback to local storage if not connected or error
    if (kIsWeb) {
      // Web: filter memory storage
      return _webMemoryStorage
          .where((f) =>
              f.userId == _userId &&
              f.category == category &&
              f.active)
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }

    try {
      final db = await _db.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'user_facts',
        where: 'user_id = ? AND category = ? AND active = ?',
        whereArgs: [_userId, category, 1],
        orderBy: 'added_at DESC',
      );

      return maps.map((map) => UserFact.fromDatabase(map)).toList();
    } catch (e) {
      print('⚠️ Failed to get facts by category: $e');
      return [];
    }
  }

  /// Remove a user fact (soft delete)
  Future<void> removeFact(String factId) async {
    if (kIsWeb) {
      // Web: remove from memory storage
      _webMemoryStorage.removeWhere((f) => f.id == factId);
      print('✅ Removed user fact from web storage');
    } else {
      // Mobile: mark as inactive in SQLite
      try {
        final db = await _db.database;
        await db.update(
          'user_facts',
          {'active': 0},
          where: 'id = ?',
          whereArgs: [factId],
        );
        print('✅ Marked user fact as inactive in SQLite');
      } catch (e) {
        print('❌ Failed to remove user fact: $e');
        throw e;
      }
    }

    // Update in Supabase if connected
    if (_supabaseService.isConnected) {
      try {
        await _supabaseService.client
            .from('user_facts')
            .update({'active': false})
            .eq('id', factId);
        print('☁️ Updated user fact status in Supabase');
      } catch (e) {
        print('⚠️ Failed to update cloud: $e');
        // Continue even if cloud sync fails
      }
    }
  }

  /// Clear all user facts
  Future<void> clearAllFacts() async {
    if (kIsWeb) {
      // Web: clear memory storage for this user
      _webMemoryStorage.removeWhere((f) => f.userId == _userId);
      print('✅ Cleared all user facts from web storage');
    } else {
      // Mobile: mark all as inactive
      try {
        final db = await _db.database;
        await db.update(
          'user_facts',
          {'active': 0},
          where: 'user_id = ?',
          whereArgs: [_userId],
        );
        print('✅ Cleared all user facts in SQLite');
      } catch (e) {
        print('❌ Failed to clear user facts: $e');
        throw e;
      }
    }

    // Clear in Supabase if connected
    if (_supabaseService.isConnected) {
      try {
        await _supabaseService.client
            .from('user_facts')
            .update({'active': false})
            .eq('user_id', _userId);
        print('☁️ Cleared user facts in Supabase');
      } catch (e) {
        print('⚠️ Failed to clear cloud facts: $e');
      }
    }
  }

  /// Get facts formatted for context display
  Future<String> getFormattedFacts() async {
    final facts = await getAllFacts();

    if (facts.isEmpty) {
      return 'No context facts added yet.\n\nUse /context add [fact] to add context about yourself.';
    }

    final categories = {
      'work': <UserFact>[],
      'personal': <UserFact>[],
      'people': <UserFact>[],
      'location': <UserFact>[],
    };

    for (final fact in facts) {
      categories[fact.category]?.add(fact);
    }

    final buffer = StringBuffer();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('  Your Context');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();

    for (final entry in categories.entries) {
      if (entry.value.isNotEmpty) {
        buffer.writeln('${entry.key.toUpperCase()}');
        for (int i = 0; i < entry.value.length; i++) {
          final fact = entry.value[i];
          buffer.writeln('  ${i + 1}. ${fact.fact}');
          buffer.writeln('     ID: ${fact.id.substring(0, 8)}');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('To remove: /context remove [id]');
    buffer.writeln('To clear all: /context clear');

    return buffer.toString();
  }

  /// Sync local facts to cloud
  Future<void> syncToCloud() async {
    if (!_supabaseService.isConnected) return;

    if (kIsWeb) {
      // Web: sync memory storage
      final userFacts = _webMemoryStorage.where((f) => f.userId == _userId);

      for (final fact in userFacts) {
        try {
          await _supabaseService.client
              .from('user_facts')
              .upsert(fact.toJson());
        } catch (e) {
          print('⚠️ Failed to sync fact ${fact.id}: $e');
        }
      }
    } else {
      // Mobile: sync from SQLite
      final facts = await getAllFacts();

      for (final fact in facts) {
        try {
          await _supabaseService.client
              .from('user_facts')
              .upsert(fact.toJson());
        } catch (e) {
          print('⚠️ Failed to sync fact ${fact.id}: $e');
        }
      }
    }

    print('☁️ User facts sync complete');
  }

  /// Load facts from cloud
  Future<void> loadFromCloud() async {
    if (!_supabaseService.isConnected) return;

    try {
      final response = await _supabaseService.client
          .from('user_facts')
          .select()
          .eq('user_id', _userId)
          .eq('active', true);

      final facts = (response as List)
          .map((json) => UserFact.fromJson(json))
          .toList();

      if (kIsWeb) {
        // Web: update memory storage
        _webMemoryStorage.clear();
        _webMemoryStorage.addAll(facts);
      } else {
        // Mobile: update SQLite
        final db = await _db.database;

        // Clear existing and insert fresh from cloud
        await db.delete('user_facts', where: 'user_id = ?', whereArgs: [_userId]);

        for (final fact in facts) {
          await db.insert('user_facts', fact.toDatabase());
        }
      }

      print('☁️ Loaded ${facts.length} user facts from cloud');
    } catch (e) {
      print('❌ Failed to load facts from cloud: $e');
    }
  }

  /// Format user facts for LLM context
  String formatForLLM() {
    // Get facts synchronously from memory storage (for web) or return empty if not available
    List<UserFact> facts = [];

    if (kIsWeb) {
      facts = _webMemoryStorage
          .where((f) => f.userId == _userId && f.active)
          .toList();
    }

    if (facts.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('User context facts:');

    // Group by category for better organization
    final categories = {
      'work': <String>[],
      'personal': <String>[],
      'people': <String>[],
      'location': <String>[],
    };

    for (final fact in facts) {
      categories[fact.category]?.add(fact.fact);
    }

    for (final entry in categories.entries) {
      if (entry.value.isNotEmpty) {
        buffer.writeln('${entry.key}: ${entry.value.join(', ')}');
      }
    }

    return buffer.toString();
  }
}