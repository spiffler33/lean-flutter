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
      version: 1,
      onCreate: _onCreate,
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
  }

  /// Insert entry (returns local ID)
  Future<int> insertEntry(Entry entry) async {
    if (kIsWeb) {
      // Web: use in-memory storage
      final id = _webMemoryStorage.isEmpty ? 1 : (_webMemoryStorage.map((e) => e.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
      final newEntry = entry.copyWith(id: id);
      _webMemoryStorage.insert(0, newEntry);
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
      // Web: update in memory storage
      final index = _webMemoryStorage.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _webMemoryStorage[index] = entry;
        return 1; // Success
      }
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

  /// Get all entries
  Future<List<Entry>> getEntries({int limit = 50}) async {
    if (kIsWeb) {
      // Web: return from memory storage
      print('💾 getEntries called: ${_webMemoryStorage.length} total in storage, returning up to $limit');
      final result = _webMemoryStorage.take(limit).toList();
      print('📋 Returning ${result.length} entries');
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
