/**
 * Lean v2 - IndexedDB Layer
 * Local-first storage using Dexie.js
 */

import Dexie, { Table } from 'dexie';
import type { Entry } from './types';

export class LeanDB extends Dexie {
  entries!: Table<Entry, string>;

  constructor() {
    super('LeanDB');

    this.version(1).stores({
      entries: 'id, created_at, synced, *tags, device_id, user_id',
    });
  }
}

// Export singleton instance
export const db = new LeanDB();

/**
 * Database utilities
 */

export async function addEntry(entry: Omit<Entry, 'id'>): Promise<Entry> {
  const id = crypto.randomUUID();
  const fullEntry: Entry = {
    ...entry,
    id,
  };

  await db.entries.add(fullEntry);
  return fullEntry;
}

export async function updateEntry(
  id: string,
  changes: Partial<Entry>
): Promise<void> {
  await db.entries.update(id, {
    ...changes,
    updated_at: new Date(),
  });
}

export async function deleteEntry(id: string): Promise<void> {
  await db.entries.delete(id);
}

export async function getEntry(id: string): Promise<Entry | undefined> {
  return await db.entries.get(id);
}

export async function getRecentEntries(limit: number = 50): Promise<Entry[]> {
  return await db.entries
    .orderBy('created_at')
    .reverse()
    .limit(limit)
    .toArray();
}

export async function searchEntries(query: string): Promise<Entry[]> {
  const lowerQuery = query.toLowerCase();

  return await db.entries
    .filter((entry) => {
      const contentMatch = entry.content.toLowerCase().includes(lowerQuery);
      const tagMatch =
        entry.tags?.some((tag) => tag.toLowerCase().includes(lowerQuery)) ??
        false;
      return contentMatch || tagMatch;
    })
    .reverse()
    .sortBy('created_at');
}

export async function getUnsyncedEntries(): Promise<Entry[]> {
  return await db.entries.filter(entry => entry.synced === false).toArray();
}

export async function markAsSynced(ids: string[]): Promise<void> {
  for (const id of ids) {
    await db.entries.update(id, { synced: true });
  }
}

export async function getTodayEntries(): Promise<Entry[]> {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return await db.entries
    .where('created_at')
    .above(today)
    .reverse()
    .sortBy('created_at');
}

export async function getEntriesByDateRange(
  start: Date,
  end: Date
): Promise<Entry[]> {
  return await db.entries
    .where('created_at')
    .between(start, end, true, true)
    .reverse()
    .sortBy('created_at');
}

export async function clearAllEntries(): Promise<void> {
  await db.entries.clear();
}

/**
 * Stats helpers
 */

export async function getEntryCount(): Promise<number> {
  return await db.entries.count();
}

export async function getTotalWordCount(): Promise<number> {
  const entries = await db.entries.toArray();
  return entries.reduce((total, entry) => {
    return total + entry.content.split(/\s+/).length;
  }, 0);
}

/**
 * Device ID management
 */

export function getDeviceId(): string {
  let deviceId = localStorage.getItem('lean-device-id');

  if (!deviceId) {
    deviceId = crypto.randomUUID();
    localStorage.setItem('lean-device-id', deviceId);
  }

  return deviceId;
}
