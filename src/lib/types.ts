/**
 * Lean v2 - Type Definitions
 * Core TypeScript interfaces for the application
 */

export interface Entry {
  id?: string;
  content: string;
  created_at: Date;
  updated_at?: Date;

  // AI-extracted metadata
  tags?: string[];
  mood?: string;
  actions?: string[];
  people?: string[];
  themes?: string[];
  urgency?: 'none' | 'low' | 'medium' | 'high';

  // Sync metadata
  synced: boolean;
  device_id: string;
  user_id?: string; // For Supabase
}

export interface SyncStatus {
  lastSync: Date | null;
  pending: number;
  failed: number;
  isOnline: boolean;
  isSyncing: boolean;
}

export interface Stats {
  total_entries: number;
  total_words: number;
  today_count: number;
  week_count: number;
  month_count: number;
  daily_avg: number;
  best_day: string;
  current_streak: number;
  longest_streak: number;
  activity_7days: Array<{ day: string; count: number }>;
  heatmap: number[];
  top_tags: Array<{ tag: string; count: number }>;
  trend: string;
}

export interface Command {
  name: string;
  description: string;
  handler: (args?: string) => Promise<void> | void;
  needsParam?: boolean;
}

export interface Theme {
  name: string;
  displayName: string;
  colors: {
    background: string;
    text: string;
    accent: string;
    border: string;
  };
}

export interface AppState {
  editingEntryId: string | null;
  currentTheme: string;
  todoFilterActive: boolean;
  isLoggedIn: boolean;
  syncStatus: SyncStatus;
}

// Supabase database row (matches our SQL schema)
export interface DBEntry {
  id: string;
  user_id: string;
  content: string;
  created_at: string; // PostgreSQL timestamp
  updated_at: string;
  tags: string[] | null;
  mood: string | null;
  actions: string[] | null;
  people: string[] | null;
  themes: string[] | null;
  urgency: string | null;
  synced: boolean;
  device_id: string | null;
}

// Claude API enrichment response
export interface EnrichmentResult {
  tags: string[];
  mood: string;
  actions: string[];
  people: string[];
  themes: string[];
  urgency: 'none' | 'low' | 'medium' | 'high';
}

// User Facts (for /context command)
export interface UserFact {
  fact_id: string;
  user_id: string;
  fact_text: string;
  fact_category: 'work' | 'personal' | 'people' | 'location' | 'other';
  active: boolean;
  created_at: Date;
  updated_at: Date;
}

// Entity Patterns (people tracking)
export interface EntityPattern {
  entity_id: string;
  user_id: string;
  entity: string;
  entity_type: string;
  mention_count: number;
  theme_correlations: Record<string, number>;
  emotion_correlations: Record<string, number>;
  urgency_correlations: Record<string, number>;
  time_patterns: Record<string, number>;
  confidence_score: number;
  first_seen: Date;
  last_seen: Date;
}

// Temporal Patterns (writing rhythms)
export interface TemporalPattern {
  pattern_id: string;
  user_id: string;
  time_block: 'morning' | 'afternoon' | 'evening' | 'night' | 'all';
  weekday: 'monday' | 'tuesday' | 'wednesday' | 'thursday' | 'friday' | 'saturday' | 'sunday' | 'weekday' | 'weekend' | 'all';
  common_themes: string[];
  common_emotions: string[];
  sample_count: number;
  confidence: number;
  created_at: Date;
  updated_at: Date;
}
