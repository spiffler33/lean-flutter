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
