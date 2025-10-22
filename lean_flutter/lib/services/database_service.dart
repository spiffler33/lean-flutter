import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/entry.dart';

/// Local SQLite database service for offline-first storage
/// Note: On web, uses in-memory storage (entries cleared on refresh)
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;
  static List<Entry> _webMemoryStorage = []; // For web platform

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  DatabaseService._();

  Future<Database> get database async {
    if (kIsWeb) {
      // On web, return null database (will use memory storage)
      throw UnsupportedError('SQLite not supported on web');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lean.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        tags TEXT,
        actions TEXT DEFAULT '[]',
        mood TEXT,
        themes TEXT DEFAULT '[]',
        people TEXT DEFAULT '[]',
        urgency TEXT DEFAULT 'none',
        synced INTEGER DEFAULT 0,
        remote_id INTEGER,
        cloud_id TEXT,
        user_id TEXT,
        device_id TEXT
      )
    ''');

    // Index for faster queries
    await db.execute('''
      CREATE INDEX idx_created_at ON entries(created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_synced ON entries(synced)
    ''');

    // Create enrichments table
    await _createEnrichmentsTable(db);

    // Create user facts table
    await _createUserFactsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add enrichments table in version 2
      await _createEnrichmentsTable(db);
    }
    if (oldVersion < 3) {
      // Add user facts table in version 3
      await _createUserFactsTable(db);
    }
  }

  Future<void> _createEnrichmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE enrichments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
        emotion TEXT,
        themes TEXT DEFAULT '[]',
        people TEXT DEFAULT '[]',
        urgency TEXT DEFAULT 'none',
        actions TEXT DEFAULT '[]',
        questions TEXT DEFAULT '[]',
        decisions TEXT DEFAULT '[]',
        confidence_scores TEXT DEFAULT '{}',
        enrichment_version TEXT DEFAULT '1.0',
        processing_status TEXT DEFAULT 'pending',
        processing_time_ms INTEGER,
        error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_enrichments_entry_id ON enrichments(entry_id)');
    await db.execute('CREATE INDEX idx_enrichments_status ON enrichments(processing_status)');
  }

  Future<void> _createUserFactsTable(Database db) async {
    await db.execute('''
      CREATE TABLE user_facts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category TEXT NOT NULL,
        fact TEXT NOT NULL,
        entity_refs TEXT DEFAULT '',
        added_at INTEGER NOT NULL,
        active INTEGER DEFAULT 1
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_user_facts_user_id ON user_facts(user_id)');
    await db.execute('CREATE INDEX idx_user_facts_category ON user_facts(category)');
    await db.execute('CREATE INDEX idx_user_facts_active ON user_facts(active)');
  }

  /// Insert entry (returns local ID)
  Future<int> insertEntry(Entry entry) async {
    if (kIsWeb) {
      // Web: use in-memory storage
      final id = _webMemoryStorage.isEmpty ? 1 : (_webMemoryStorage.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);

      // CRITICAL: Preserve the original timestamp from the entry
      final newEntry = entry.copyWith(id: id);

      // Insert in the correct position based on created_at timestamp
      // This ensures proper chronological ordering (newest first)
      int insertIndex = 0;
      for (int i = 0; i < _webMemoryStorage.length; i++) {
        if (_webMemoryStorage[i].createdAt.isBefore(newEntry.createdAt)) {
          break;
        }
        insertIndex = i + 1;
      }

      _webMemoryStorage.insert(insertIndex, newEntry);

      return id;
    }

    final db = await database;
    final data = entry.toJson();
    data['synced'] = 0; // Mark as not synced
    data.remove('id'); // Let SQLite generate ID

    return await db.insert('entries', data);
  }

  /// Update entry
  Future<int> updateEntry(Entry entry) async {
    if (entry.id == null) {
      throw Exception('Cannot update entry without ID');
    }

    if (kIsWeb) {
      print('🔄 DEBUG updateEntry: id=${entry.id}, content="${entry.content.substring(0, entry.content.length > 30 ? 30 : entry.content.length)}..."');

      // Web: update in memory storage
      final index = _webMemoryStorage.indexWhere((e) => e.id == entry.id);
      print('   📍 Found entry at index: $index');

      if (index != -1) {
        print('   📝 Updating entry at index $index');
        _webMemoryStorage[index] = entry;

        // Debug: Check for duplicates after update
        final duplicates = _webMemoryStorage.where((e) => e.content == entry.content).toList();
        if (duplicates.length > 1) {
          print('   ⚠️ WARNING: Found ${duplicates.length} entries with same content!');
          for (var dup in duplicates) {
            print('      - ID: ${dup.id}, createdAt: ${dup.createdAt.toIso8601String()}');
          }
        }

        return 1; // Success
      }
      print('   ❌ Entry not found in storage!');
      return 0; // Not found
    }

    final db = await database;
    final data = entry.toJson();
    data['synced'] = 0; // Mark as modified, needs sync

    return await db.update(
      'entries',
      data,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Delete entry
  Future<int> deleteEntry(int id) async {
    if (kIsWeb) {
      // Web: delete from memory storage
      final initialLength = _webMemoryStorage.length;
      _webMemoryStorage.removeWhere((e) => e.id == id);
      return initialLength - _webMemoryStorage.length; // Return number deleted
    }

    final db = await database;
    return await db.delete(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get entry by ID
  Future<Entry?> getEntryById(int id) async {
    if (kIsWeb) {
      // Web: search in memory storage
      try {
        return _webMemoryStorage.firstWhere((e) => e.id == id);
      } catch (e) {
        return null;
      }
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Entry.fromJson(maps.first);
  }

  /// Get all entries
  Future<List<Entry>> getEntries({int limit = 50}) async {
    if (kIsWeb) {
      // Web: return from memory storage
      print('💾 getEntries called: ${_webMemoryStorage.length} total in storage, returning up to $limit');

      // Debug: Check for duplicates in storage
      final contentMap = <String, List<Entry>>{};
      for (var entry in _webMemoryStorage) {
        final key = entry.content.substring(0, entry.content.length > 50 ? 50 : entry.content.length);
        contentMap[key] = (contentMap[key] ?? [])..add(entry);
      }

      for (var key in contentMap.keys) {
        if (contentMap[key]!.length > 1) {
          print('   ⚠️ DUPLICATE FOUND: "${key}..." appears ${contentMap[key]!.length} times');
          for (var dup in contentMap[key]!) {
            print('      - ID: ${dup.id}, createdAt: ${dup.createdAt.toIso8601String()}');
          }
        }
      }

      final result = _webMemoryStorage.take(limit).toList();
      print('📋 Returning ${result.length} entries');

      // Debug: Print first few entries being returned
      print('   📊 First 5 entries being returned:');
      for (int i = 0; i < result.length && i < 5; i++) {
        print('      [$i] ID: ${result[i].id}, "${result[i].content.substring(0, result[i].content.length > 30 ? 30 : result[i].content.length)}..." createdAt: ${result[i].createdAt.toIso8601String()}');
      }

      return result;
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) => Entry.fromJson(maps[i]));
  }

  /// Get entry by ID
  Future<Entry?> getEntry(int id) async {
    if (kIsWeb) {
      // Web: find in memory storage
      try {
        return _webMemoryStorage.firstWhere((e) => e.id == id);
      } catch (e) {
        return null;
      }
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Entry.fromJson(maps.first);
  }

  /// Search entries
  Future<List<Entry>> searchEntries(String query) async {
    if (kIsWeb) {
      // Web: search in memory storage
      return _webMemoryStorage
          .where((e) => e.content.toLowerCase().contains(query.toLowerCase()))
          .take(100)
          .toList();
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'content LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
      limit: 100,
    );

    return List.generate(maps.length, (i) => Entry.fromJson(maps[i]));
  }

  /// Get entries that need to be synced
  Future<List<Entry>> getUnsyncedEntries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) => Entry.fromJson(maps[i]));
  }

  /// Mark entry as synced with cloud ID
  Future<void> markAsSynced(int localId, String cloudId) async {
    if (kIsWeb) {
      // Web: update cloud_id in memory storage
      final index = _webMemoryStorage.indexWhere((e) => e.id == localId);
      if (index != -1) {
        final entry = _webMemoryStorage[index];
        _webMemoryStorage[index] = entry.copyWith(cloudId: cloudId);
      }
      return;
    }
    final db = await database;
    await db.update(
      'entries',
      {'cloud_id': cloudId},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Get entry count
  Future<int> getEntryCount() async {
    if (kIsWeb) {
      return _webMemoryStorage.length;
    }

    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM entries');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get entries for today
  Future<List<Entry>> getTodayEntries() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    if (kIsWeb) {
      // Web: filter memory storage
      return _webMemoryStorage
          .where((e) => e.createdAt.isAfter(todayStart))
          .toList();
    }

    final todayStartStr = todayStart.toIso8601String();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'created_at >= ?',
      whereArgs: [todayStartStr],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => Entry.fromJson(maps[i]));
  }

  /// Get todo entries (not done)
  Future<List<Entry>> getTodoEntries() async {
    if (kIsWeb) {
      // Web: filter memory storage
      return _webMemoryStorage
          .where((e) => e.content.contains('#todo') && !e.content.contains('#done'))
          .toList();
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'content LIKE ? AND content NOT LIKE ?',
      whereArgs: ['%#todo%', '%#done%'],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => Entry.fromJson(maps[i]));
  }

  /// Clear web memory storage (web only)
  Future<void> clearWebStorage() async {
    if (kIsWeb) {
      print('🗑️ Clearing web memory storage...');
      _webMemoryStorage.clear();
    }
  }

  /// Clear all entries (for testing)
  Future<void> clearAll() async {
    if (kIsWeb) {
      _webMemoryStorage.clear();
      return;
    }
    final db = await database;
    await db.delete('entries');
  }

  /// Close database
  Future<void> close() async {
    if (kIsWeb) return; // No database to close on web
    final db = await database;
    await db.close();
    _database = null;
  }
}
