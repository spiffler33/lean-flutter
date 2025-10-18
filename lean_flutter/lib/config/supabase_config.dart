/// Supabase configuration
/// For production, use environment variables or --dart-define
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://elamvfzkztkquqdkovcs.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVsYW12ZnprenRrcXVxZGtvdmNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0NDMwODUsImV4cCI6MjA3NjAxOTA4NX0.DEc9k2msWuX5qL0uhdJvmNpu1tS97PGSPmrHk5n9B-Q',
  );

  /// Check if Supabase is configured
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
