/// Application configuration
/// IMPORTANT: Claude API key is now securely stored in Supabase Edge Function
/// The Edge Function handles all Claude API calls to keep the key secure
class AppConfig {
  // Claude API is now accessed through Supabase Edge Function
  // No API key needed in the Flutter app!
  // The Edge Function uses the ANTHROPIC_API_KEY environment variable
  // Set this in your Supabase dashboard under:
  // Project Settings > Edge Functions > Secrets
  static const String anthropicApiKey = 'HANDLED_BY_EDGE_FUNCTION';

  // Feature flags
  static const bool enableAIEnrichment = true;
  static const bool enableMockFallback = true;
  static const bool showEnrichmentDebugInfo = true;

  // API settings
  static const String claudeModel = 'claude-3-haiku-20240307'; // Fast & cheap
  static const double claudeTemperature = 0.2; // Low for consistent extraction
  static const int claudeMaxTokens = 500;

  // Processing settings
  static const int enrichmentQueueCheckInterval = 2; // seconds
  static const int maxRetries = 3;
}