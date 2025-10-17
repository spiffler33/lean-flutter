import 'dart:convert';

/// Entry model matching existing Lean database schema
class Entry {
  final int? id; // Null for new entries not yet saved
  final String content;
  final DateTime createdAt;
  final List<String> tags;
  final List<String> actions;
  final String? emotion;
  final List<String> themes;
  final List<String> people;
  final String urgency; // 'none', 'low', 'medium', 'high'

  Entry({
    this.id,
    required this.content,
    DateTime? createdAt,
    List<String>? tags,
    List<String>? actions,
    this.emotion,
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
    return Entry(
      id: json['id'] as int?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      tags: _parseJsonList(json['tags']),
      actions: _parseJsonList(json['actions']),
      emotion: json['emotion'] as String?,
      themes: _parseJsonList(json['themes']),
      people: _parseJsonList(json['people']),
      urgency: json['urgency'] as String? ?? 'none',
    );
  }

  /// Convert Entry to JSON for Supabase/SQLite
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'tags': jsonEncode(tags),
      'actions': jsonEncode(actions),
      'emotion': emotion,
      'themes': jsonEncode(themes),
      'people': jsonEncode(people),
      'urgency': urgency,
    };
  }

  /// Create a copy with updated fields
  Entry copyWith({
    int? id,
    String? content,
    DateTime? createdAt,
    List<String>? tags,
    List<String>? actions,
    String? emotion,
    List<String>? themes,
    List<String>? people,
    String? urgency,
  }) {
    return Entry(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      actions: actions ?? this.actions,
      emotion: emotion ?? this.emotion,
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
