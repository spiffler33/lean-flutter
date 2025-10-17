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
        emotion TEXT,
        themes TEXT DEFAULT '[]',
        people TEXT DEFAULT '[]',
        urgency TEXT DEFAULT 'none',
        synced INTEGER DEFAULT 0,
        remote_id INTEGER
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
      return _webMemoryStorage.take(limit).toList();
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

  /// Mark entry as synced
  Future<void> markAsSynced(int localId, int remoteId) async {
    final db = await database;
    await db.update(
      'entries',
      {'synced': 1, 'remote_id': remoteId},
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
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'created_at >= ?',
      whereArgs: [todayStart],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => Entry.fromJson(maps[i]));
  }

  /// Get todo entries (not done)
  Future<List<Entry>> getTodoEntries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'entries',
      where: 'content LIKE ? AND content NOT LIKE ?',
      whereArgs: ['%#todo%', '%#done%'],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => Entry.fromJson(maps[i]));
  }

  /// Clear all entries (for testing)
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('entries');
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
