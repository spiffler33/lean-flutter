/**
 * Lean v2 - Supabase Client
 * Authentication and cloud sync
 */

import { createClient } from '@supabase/supabase-js';
import type { DBEntry } from './types';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string;
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

if (!supabaseUrl || !supabaseKey) {
  console.warn('Supabase credentials not found. Running in offline-only mode.');
}

// Create Supabase client
export const supabase = createClient(supabaseUrl, supabaseKey);

/**
 * Auth helpers
 */

export async function signInWithEmail(email: string): Promise<{ error: any }> {
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: import.meta.env.VITE_APP_URL || window.location.origin,
    },
  });

  return { error };
}

export async function signOut(): Promise<void> {
  await supabase.auth.signOut();
}

export async function getCurrentUser() {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}

export async function getSession() {
  const {
    data: { session },
  } = await supabase.auth.getSession();
  return session;
}

/**
 * Database helpers
 */

export async function syncEntryToCloud(entry: DBEntry): Promise<{ error: any }> {
  const { error } = await supabase.from('entries').upsert(entry);
  return { error };
}

export async function syncEntriesFromCloud(
  userId: string,
  limit: number = 100
): Promise<{ data: DBEntry[] | null; error: any }> {
  const { data, error } = await supabase
    .from('entries')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit);

  return { data, error };
}

export async function deleteEntryFromCloud(id: string): Promise<{ error: any }> {
  const { error } = await supabase.from('entries').delete().eq('id', id);
  return { error };
}

/**
 * Realtime subscriptions
 */

export function subscribeToEntries(
  userId: string,
  callback: (payload: any) => void
) {
  return supabase
    .channel('entries')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'entries',
        filter: `user_id=eq.${userId}`,
      },
      callback
    )
    .subscribe();
}

/**
 * Check if Supabase is configured
 */

export function isSupabaseConfigured(): boolean {
  return !!(supabaseUrl && supabaseKey);
}
