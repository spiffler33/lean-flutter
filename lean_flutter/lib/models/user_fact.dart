import 'package:uuid/uuid.dart';

/// User context/facts for enrichment intelligence
class UserFact {
  final String id;
  final String userId;
  final String category; // work/personal/people/location
  final String fact;
  final List<String> entityRefs; // linked entities
  final DateTime addedAt;
  final bool active;

  UserFact({
    required this.id,
    required this.userId,
    required this.category,
    required this.fact,
    this.entityRefs = const [],
    required this.addedAt,
    this.active = true,
  });

  factory UserFact.create({
    required String userId,
    required String category,
    required String fact,
    List<String> entityRefs = const [],
  }) {
    return UserFact(
      id: const Uuid().v4(),
      userId: userId,
      category: category,
      fact: fact,
      entityRefs: entityRefs,
      addedAt: DateTime.now(),
      active: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'fact': fact,
      'entity_refs': entityRefs,
      'added_at': addedAt.toIso8601String(),
      'active': active,
    };
  }

  factory UserFact.fromJson(Map<String, dynamic> json) {
    return UserFact(
      id: json['id'] ?? const Uuid().v4(),
      userId: json['user_id'] ?? '',
      category: json['category'] ?? 'personal',
      fact: json['fact'] ?? '',
      entityRefs: (json['entity_refs'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      addedAt: json['added_at'] != null
          ? DateTime.parse(json['added_at'])
          : DateTime.now(),
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'fact': fact,
      'entity_refs': entityRefs.join(','), // Store as comma-separated string
      'added_at': addedAt.millisecondsSinceEpoch,
      'active': active ? 1 : 0,
    };
  }

  factory UserFact.fromDatabase(Map<String, dynamic> row) {
    return UserFact(
      id: row['id'],
      userId: row['user_id'],
      category: row['category'],
      fact: row['fact'],
      entityRefs: row['entity_refs'] != null && row['entity_refs'].toString().isNotEmpty
          ? row['entity_refs'].toString().split(',')
          : [],
      addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at']),
      active: row['active'] == 1,
    );
  }

  UserFact copyWith({
    String? id,
    String? userId,
    String? category,
    String? fact,
    List<String>? entityRefs,
    DateTime? addedAt,
    bool? active,
  }) {
    return UserFact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      fact: fact ?? this.fact,
      entityRefs: entityRefs ?? this.entityRefs,
      addedAt: addedAt ?? this.addedAt,
      active: active ?? this.active,
    );
  }

  @override
  String toString() {
    return 'UserFact{id: $id, category: $category, fact: $fact, active: $active}';
  }
}

/// Valid categories for user facts
class UserFactCategory {
  static const String work = 'work';
  static const String personal = 'personal';
  static const String people = 'people';
  static const String location = 'location';

  static const List<String> all = [work, personal, people, location];

  static bool isValid(String category) {
    return all.contains(category.toLowerCase());
  }
}