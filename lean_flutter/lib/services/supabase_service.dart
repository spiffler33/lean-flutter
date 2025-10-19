import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/entry.dart';

// Re-export auth types for convenience
export 'package:supabase_flutter/supabase_flutter.dart' show User, AuthResponse;

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

  /// Get current user
  Future<User?> getCurrentUser() async {
    final response = await _client.auth.getUser();
    return response.user;
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      _userId = response.user!.id;
    }

    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      _userId = response.user!.id;
    }

    return response;
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
    _userId = null;
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Listen to auth state changes
  Stream<User?> onAuthStateChange() {
    return _client.auth.onAuthStateChange.map((data) => data.session?.user);
  }

  /// Create entry in Supabase
  Future<Entry> createEntry(Entry entry) async {
    final data = entry.toSupabaseJson(); // Use Supabase-specific serialization
    data['user_id'] = userId; // Add user_id for RLS
    data['device_id'] = entry.deviceId ?? 'flutter_app'; // Add device_id
    data.remove('id'); // Remove local SQLite ID
    data.remove('cloud_id'); // Let Supabase generate UUID

    final response = await _client
        .from('entries')
        .insert(data)
        .select()
        .single();

    return Entry.fromJson(response);
  }

  /// Update entry in Supabase
  Future<Entry> updateEntry(Entry entry) async {
    if (entry.cloudId == null) {
      throw Exception('Cannot update entry without cloud ID');
    }

    final data = entry.toSupabaseJson(); // Use Supabase-specific serialization
    data['user_id'] = userId;
    data['device_id'] = entry.deviceId ?? 'flutter_app';
    data.remove('id'); // Remove local SQLite ID
    data.remove('cloud_id'); // Remove cloud_id (Supabase uses 'id' for UUID)

    final response = await _client
        .from('entries')
        .update(data)
        .eq('id', entry.cloudId!)
        .select()
        .single();

    return Entry.fromJson(response);
  }

  /// Delete entry from Supabase (by cloud UUID)
  Future<void> deleteEntry(String cloudId) async {
    await _client
        .from('entries')
        .delete()
        .eq('id', cloudId);
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
