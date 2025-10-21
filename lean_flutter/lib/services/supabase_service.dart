import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/entry.dart';
import '../models/enrichment.dart';
import 'user_fact_service.dart';

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

    // Check if there's an existing session and load user facts
    if (_instance!.isAuthenticated) {
      try {
        final userFactService = UserFactService();
        await userFactService.loadFromCloud();
        print('✅ Restored user context facts from existing session');
      } catch (e) {
        print('⚠️ Failed to restore context facts: $e');
      }
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Check if connected (alias for isAuthenticated)
  bool get isConnected => isAuthenticated;

  /// Get current user ID
  String? get userId => _client.auth.currentUser?.id;

  /// Get current user ID (alias for userId)
  String? get currentUserId => userId;

  /// Get the Supabase client
  SupabaseClient get client => _client;

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

      // Load user context facts from cloud after successful signup
      try {
        final userFactService = UserFactService();
        await userFactService.loadFromCloud();
        print('✅ Loaded user context facts after signup');
      } catch (e) {
        print('⚠️ Failed to load context facts: $e');
        // Continue even if context loading fails
      }
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

      // Load user context facts from cloud after successful signin
      try {
        final userFactService = UserFactService();
        await userFactService.loadFromCloud();
        print('✅ Loaded user context facts after signin');
      } catch (e) {
        print('⚠️ Failed to load context facts: $e');
        // Continue even if context loading fails
      }
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

  // ============== ENRICHMENT METHODS ==============

  /// Create enrichment in Supabase
  Future<Enrichment> createEnrichment(Enrichment enrichment) async {
    final data = enrichment.toSupabaseJson();
    data['user_id'] = userId;
    data.remove('id'); // Let Supabase generate UUID

    final response = await _client
        .from('enrichments')
        .insert(data)
        .select()
        .single();

    return Enrichment.fromJson(response);
  }

  /// Update enrichment in Supabase
  Future<Enrichment> updateEnrichment(Enrichment enrichment) async {
    if (enrichment.cloudId == null) {
      throw Exception('Cannot update enrichment without cloud ID');
    }

    final data = enrichment.toSupabaseJson();
    data['user_id'] = userId;
    data['updated_at'] = DateTime.now().toIso8601String();

    final response = await _client
        .from('enrichments')
        .update(data)
        .eq('id', enrichment.cloudId!)
        .select()
        .single();

    return Enrichment.fromJson(response);
  }

  /// Get enrichment for a specific entry
  Future<Enrichment?> getEnrichmentForEntry(String entryCloudId) async {
    try {
      final response = await _client
          .from('enrichments')
          .select()
          .eq('entry_id', entryCloudId)
          .eq('user_id', userId ?? '')
          .single();

      return Enrichment.fromJson(response);
    } catch (e) {
      // No enrichment found
      return null;
    }
  }

  /// Get all enrichments for user
  Future<List<Enrichment>> fetchEnrichments({int limit = 50}) async {
    final response = await _client
        .from('enrichments')
        .select()
        .eq('user_id', userId ?? '')
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => Enrichment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get enrichments with specific status
  Future<List<Enrichment>> fetchEnrichmentsByStatus(String status) async {
    final response = await _client
        .from('enrichments')
        .select()
        .eq('user_id', userId ?? '')
        .eq('processing_status', status)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Enrichment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Delete enrichment
  Future<void> deleteEnrichment(String cloudId) async {
    await _client
        .from('enrichments')
        .delete()
        .eq('id', cloudId);
  }

  /// Watch enrichments for real-time updates
  Stream<List<Enrichment>> watchEnrichments() {
    return _client
        .from('enrichments')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId ?? '')
        .order('created_at')
        .map((data) =>
            data.map((json) => Enrichment.fromJson(json)).toList());
  }
}
