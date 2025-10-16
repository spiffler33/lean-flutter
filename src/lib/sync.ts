/**
 * Lean v2 - Sync Engine
 * Bidirectional sync between IndexedDB and Supabase
 */

import { db } from './db';
import { supabase } from './supabase';
import type { Entry } from './types';
import { getCurrentUser } from './auth';

export interface SyncResult {
  pulled: number;
  pushed: number;
  conflicts: number;
  errors: string[];
}

/**
 * Sync state
 */
const syncState = {
  isSyncing: false,
  lastSyncAt: null as Date | null,
  autoSyncInterval: null as ReturnType<typeof setInterval> | null,
};

/**
 * Get last sync timestamp from localStorage
 */
function getLastSyncTimestamp(): Date | null {
  const timestamp = localStorage.getItem('lean-last-sync');
  return timestamp ? new Date(timestamp) : null;
}

/**
 * Save last sync timestamp to localStorage
 */
function setLastSyncTimestamp(date: Date) {
  localStorage.setItem('lean-last-sync', date.toISOString());
  syncState.lastSyncAt = date;
}

/**
 * Pull changes from Supabase
 */
async function pullFromCloud(): Promise<number> {
  const user = await getCurrentUser();
  if (!user) return 0;

  const lastSync = getLastSyncTimestamp();

  // Get entries modified since last sync
  let query = supabase
    .from('entries')
    .select('*')
    .eq('user_id', user.id)
    .is('deleted_at', null)
    .order('created_at', { ascending: false });

  if (lastSync) {
    query = query.or(`updated_at.gt.${lastSync.toISOString()},created_at.gt.${lastSync.toISOString()}`);
  }

  const { data: cloudEntries, error } = await query;

  if (error) {
    console.error('Pull error:', error);
    throw error;
  }

  if (!cloudEntries || cloudEntries.length === 0) {
    return 0;
  }

  // Upsert into local IndexedDB
  let pulledCount = 0;
  for (const cloudEntry of cloudEntries) {
    const localEntry = await db.entries.get(cloudEntry.id);

    // Convert cloud entry to local format
    const entry: Entry = {
      id: cloudEntry.id,
      content: cloudEntry.content,
      created_at: new Date(cloudEntry.created_at),
      updated_at: cloudEntry.updated_at ? new Date(cloudEntry.updated_at) : undefined,
      synced: true,
      device_id: cloudEntry.device_id,
      user_id: cloudEntry.user_id,
      tags: cloudEntry.tags || [],
      mood: cloudEntry.mood,
      actions: cloudEntry.actions || [],
      people: cloudEntry.people || [],
      themes: cloudEntry.themes || [],
      urgency: cloudEntry.urgency,
    };

    // Simple last-write-wins conflict resolution
    if (!localEntry || (cloudEntry.updated_at && localEntry.updated_at &&
        new Date(cloudEntry.updated_at) > localEntry.updated_at)) {
      await db.entries.put(entry);
      pulledCount++;
    }
  }

  return pulledCount;
}

/**
 * Push local changes to Supabase
 */
async function pushToCloud(): Promise<number> {
  const user = await getCurrentUser();
  if (!user) return 0;

  // Get all unsynced local entries
  const unsyncedEntries = await db.entries
    .filter(entry => !entry.synced)
    .toArray();

  if (unsyncedEntries.length === 0) {
    return 0;
  }

  let pushedCount = 0;

  // Push in batches of 50
  const batchSize = 50;
  for (let i = 0; i < unsyncedEntries.length; i += batchSize) {
    const batch = unsyncedEntries.slice(i, i + batchSize);

    // Convert to Supabase format
    const cloudEntries = batch.map(entry => ({
      id: entry.id,
      user_id: user.id,
      device_id: entry.device_id,
      content: entry.content,
      tags: entry.tags || [],
      mood: entry.mood,
      actions: entry.actions || [],
      people: entry.people || [],
      themes: entry.themes || [],
      urgency: entry.urgency,
      created_at: entry.created_at.toISOString(),
      updated_at: entry.updated_at ? entry.updated_at.toISOString() : entry.created_at.toISOString(),
    }));

    // Upsert to Supabase
    const { error } = await supabase
      .from('entries')
      .upsert(cloudEntries, {
        onConflict: 'id',
      });

    if (error) {
      console.error('Push error:', error);
      throw error;
    }

    // Mark as synced locally
    for (const entry of batch) {
      await db.entries.update(entry.id!, { synced: true });
    }

    pushedCount += batch.length;
  }

  return pushedCount;
}

/**
 * Full bidirectional sync
 */
export async function sync(): Promise<SyncResult> {
  if (syncState.isSyncing) {
    throw new Error('Sync already in progress');
  }

  const user = await getCurrentUser();
  if (!user) {
    throw new Error('Not authenticated');
  }

  syncState.isSyncing = true;

  const result: SyncResult = {
    pulled: 0,
    pushed: 0,
    conflicts: 0,
    errors: [],
  };

  try {
    // Pull first (get latest from cloud)
    result.pulled = await pullFromCloud();

    // Then push (send local changes)
    result.pushed = await pushToCloud();

    // Update last sync timestamp
    setLastSyncTimestamp(new Date());

    return result;
  } catch (error) {
    result.errors.push(error instanceof Error ? error.message : String(error));
    throw error;
  } finally {
    syncState.isSyncing = false;
  }
}

/**
 * Start automatic sync (every 10 seconds for near-instant sync)
 */
export function startAutoSync(intervalMs: number = 10 * 1000) {
  if (syncState.autoSyncInterval) {
    stopAutoSync();
  }

  console.log(`🔄 Starting auto-sync (every ${intervalMs / 1000}s)`);

  syncState.autoSyncInterval = setInterval(async () => {
    try {
      const user = await getCurrentUser();
      if (user) {
        const result = await sync();
        if (result.pulled > 0 || result.pushed > 0) {
          console.log(`🔄 Auto-sync: ${result.pushed} up ↑, ${result.pulled} down ↓`);
        }
      }
    } catch (error) {
      console.error('Auto-sync failed:', error);
    }
  }, intervalMs);

  // Do an initial sync immediately
  console.log('🔄 Initial sync starting...');
  sync()
    .then(result => {
      console.log(`✅ Initial sync complete: ${result.pushed} up ↑, ${result.pulled} down ↓`);
    })
    .catch(error => console.error('❌ Initial sync failed:', error));
}

/**
 * Stop automatic sync
 */
export function stopAutoSync() {
  if (syncState.autoSyncInterval) {
    clearInterval(syncState.autoSyncInterval);
    syncState.autoSyncInterval = null;
  }
}

/**
 * Check if sync is in progress
 */
export function isSyncing(): boolean {
  return syncState.isSyncing;
}

/**
 * Get last sync time
 */
export function getLastSyncTime(): Date | null {
  return syncState.lastSyncAt || getLastSyncTimestamp();
}

/**
 * Force a full sync (ignore timestamps, sync everything)
 */
export async function fullSync(): Promise<SyncResult> {
  // Clear last sync timestamp to force full sync
  localStorage.removeItem('lean-last-sync');
  return sync();
}
