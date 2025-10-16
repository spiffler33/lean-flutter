# Supabase Setup for Lean v2

## Quick Setup

1. **Go to your Supabase project**: https://app.supabase.com/project/elamvfzkztkquqdkovcs

2. **Run migrations**:
   - Click on "SQL Editor" in the left sidebar
   - Click "New Query"
   - Copy and paste the contents of `migrations/001_initial_schema.sql`
   - Click "Run" (or press Cmd/Ctrl + Enter)
   - Repeat for `migrations/002_sync_functions.sql`
   - Repeat for `migrations/003_ai_enrichment_tables.sql` (AI features)

3. **Verify**:
   - Go to "Table Editor" - you should see the `entries` table
   - Go to "Database" → "Functions" - you should see the sync functions

## What This Creates

### Tables
- `entries` - Main entries table with RLS enabled
- `user_stats` - View for quick stats queries
- `user_facts` - User context facts for /context command (AI enrichment)
- `entity_patterns` - Learned patterns about people/entities (AI tracking)
- `temporal_patterns` - Writing rhythm patterns by time/day (AI insights)

### Functions
- `get_entries_since(timestamp)` - Get all entries modified since a timestamp
- `upsert_entries(json)` - Batch insert/update entries from device
- `mark_synced(ids)` - Mark entries as synced
- `soft_delete_entries(ids)` - Soft delete for sync
- `get_sync_stats()` - Get sync statistics

### Security
- Row Level Security (RLS) enabled - users can only see their own entries
- All functions use SECURITY DEFINER with auth.uid() checks

## Testing

After running migrations, you can test with SQL:

```sql
-- Insert a test entry (after logging in)
INSERT INTO entries (user_id, device_id, content, tags)
VALUES (auth.uid(), 'test-device', 'Test entry', ARRAY['test']);

-- Query your entries
SELECT * FROM entries WHERE user_id = auth.uid();

-- Get sync stats
SELECT * FROM get_sync_stats();
```
