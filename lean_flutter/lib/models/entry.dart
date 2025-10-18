import 'dart:convert';

/// Entry model matching existing Lean database schema
class Entry {
  final int? id; // Local SQLite ID (integer autoincrement)
  final String? cloudId; // Supabase UUID (for sync)
  final String? userId; // Supabase user ID (for sync)
  final String? deviceId; // Device identifier (for sync)
  final String content;
  final DateTime createdAt;
  final List<String> tags;
  final List<String> actions;
  final String? mood; // Changed from 'emotion' to match PWA/Supabase
  final List<String> themes;
  final List<String> people;
  final String urgency; // 'none', 'low', 'medium', 'high'

  Entry({
    this.id,
    this.cloudId,
    this.userId,
    this.deviceId,
    required this.content,
    DateTime? createdAt,
    List<String>? tags,
    List<String>? actions,
    this.mood, // Renamed from emotion
    List<String>? themes,
    List<String>? people,
    this.urgency = 'none',
  })  : createdAt = createdAt ?? DateTime.now(),
        tags = tags ?? [],
        actions = actions ?? [],
        themes = themes ?? [],
        people = people ?? [];

  /// Create Entry from SQLite or Supabase row
  factory Entry.fromJson(Map<String, dynamic> json) {
    // Handle id field - can be int (SQLite) or String UUID (Supabase)
    int? localId;
    String? cloudUuid;

    final idValue = json['id'];
    if (idValue is int) {
      localId = idValue; // SQLite local ID
    } else if (idValue is String) {
      cloudUuid = idValue; // Supabase UUID
    }

    // Also check explicit cloud_id field
    if (json['cloud_id'] != null) {
      cloudUuid = json['cloud_id'] as String;
    }

    return Entry(
      id: localId,
      cloudId: cloudUuid,
      userId: json['user_id'] as String?,
      deviceId: json['device_id'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      tags: _parseJsonList(json['tags']),
      actions: _parseJsonList(json['actions']),
      mood: json['mood'] as String?,
      themes: _parseJsonList(json['themes']),
      people: _parseJsonList(json['people']),
      urgency: json['urgency'] as String? ?? 'none',
    );
  }

  /// Convert Entry to JSON for SQLite (arrays as JSON strings)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (cloudId != null) 'cloud_id': cloudId,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'tags': jsonEncode(tags),
      'actions': jsonEncode(actions),
      'mood': mood, // Changed from emotion
      'themes': jsonEncode(themes),
      'people': jsonEncode(people),
      'urgency': urgency,
    };
  }

  /// Convert Entry to JSON for Supabase (arrays as actual arrays)
  Map<String, dynamic> toSupabaseJson() {
    return {
      if (id != null) 'id': id,
      if (cloudId != null) 'cloud_id': cloudId,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'tags': tags, // Direct array for PostgreSQL
      'actions': actions, // Direct array for PostgreSQL
      'mood': mood,
      'themes': themes, // Direct array for PostgreSQL
      'people': people, // Direct array for PostgreSQL
      'urgency': urgency,
    };
  }

  /// Create a copy with updated fields
  Entry copyWith({
    int? id,
    String? cloudId,
    String? userId,
    String? deviceId,
    String? content,
    DateTime? createdAt,
    List<String>? tags,
    List<String>? actions,
    String? mood,
    List<String>? themes,
    List<String>? people,
    String? urgency,
  }) {
    return Entry(
      id: id ?? this.id,
      cloudId: cloudId ?? this.cloudId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      actions: actions ?? this.actions,
      mood: mood ?? this.mood, // Changed from emotion
      themes: themes ?? this.themes,
      people: people ?? this.people,
      urgency: urgency ?? this.urgency,
    );
  }

  /// Helper to parse JSON arrays stored as strings
  static List<String> _parseJsonList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded.cast<String>();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  /// Check if entry is a todo
  bool get isTodo => content.toLowerCase().contains('#todo');

  /// Check if entry is completed todo
  bool get isDone => content.toLowerCase().contains('#done');

  /// Extract hashtags from content
  List<String> extractHashtags() {
    final regex = RegExp(r'#(\w+)');
    return regex
        .allMatches(content)
        .map((match) => match.group(1)!)
        .toList();
  }

  @override
  String toString() {
    return 'Entry{id: $id, content: ${content.substring(0, content.length > 30 ? 30 : content.length)}..., createdAt: $createdAt}';
  }
}
