import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/entry.dart';

/// Supabase service for cloud sync and authentication
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance!;

  final SupabaseClient _client;
  String? _userId;

  SupabaseService._(this._client);

  /// Initialize Supabase with credentials
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    _instance = SupabaseService._(Supabase.instance.client);
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Get current user ID
  String? get userId => _client.auth.currentUser?.id;

  /// Sign in anonymously
  Future<void> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously();
    _userId = response.user?.id;
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
    _userId = null;
  }

  /// Create entry in Supabase
  Future<Entry> createEntry(Entry entry) async {
    final data = entry.toJson();
    data['user_id'] = userId; // Add user_id for RLS

    final response = await _client
        .from('entries')
        .insert(data)
        .select()
        .single();

    return Entry.fromJson(response);
  }

  /// Update entry in Supabase
  Future<Entry> updateEntry(Entry entry) async {
    if (entry.id == null) {
      throw Exception('Cannot update entry without ID');
    }

    final data = entry.toJson();
    data['user_id'] = userId;

    final response = await _client
        .from('entries')
        .update(data)
        .eq('id', entry.id!)
        .select()
        .single();

    return Entry.fromJson(response);
  }

  /// Delete entry from Supabase
  Future<void> deleteEntry(int entryId) async {
    await _client
        .from('entries')
        .delete()
        .eq('id', entryId);
  }

  /// Fetch all entries for current user
  Future<List<Entry>> fetchEntries({int limit = 50}) async {
    final response = await _client
        .from('entries')
        .select()
        .eq('user_id', userId ?? '')
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => Entry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch entries created after a specific timestamp (for sync)
  Future<List<Entry>> fetchEntriesAfter(DateTime timestamp) async {
    final response = await _client
        .from('entries')
        .select()
        .eq('user_id', userId ?? '')
        .gte('created_at', timestamp.toIso8601String())
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Entry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Search entries by content
  Future<List<Entry>> searchEntries(String query) async {
    final response = await _client
        .from('entries')
        .select()
        .eq('user_id', userId ?? '')
        .ilike('content', '%$query%')
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List)
        .map((json) => Entry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Listen to realtime changes
  Stream<List<Entry>> watchEntries() {
    return _client
        .from('entries')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId ?? '')
        .order('created_at')
        .map((data) =>
            data.map((json) => Entry.fromJson(json)).toList());
  }
}
