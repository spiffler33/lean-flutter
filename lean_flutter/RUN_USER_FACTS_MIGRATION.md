# Fix /context Command - Run User Facts Migration

## Problem
The `/context` command is not working because the `user_facts` table doesn't exist in Supabase.

## Solution
Run the migration to create the `user_facts` table in your Supabase database.

## Steps to Run Migration

### Option 1: Via Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy the entire contents of `/supabase/migrations/002_create_user_facts_table.sql`
4. Paste it into the SQL editor
5. Click "Run" to execute the migration
6. You should see "Success. No rows returned" message

### Option 2: Via Supabase CLI
```bash
# From the lean_flutter directory
cd lean_flutter

# Apply the migration
supabase db push

# Or if you want to apply just this specific migration
supabase db push --file supabase/migrations/002_create_user_facts_table.sql
```

## Verify the Migration
After running the migration, verify it worked:

1. In Supabase Dashboard, go to Table Editor
2. You should now see a `user_facts` table
3. The table should have these columns:
   - id (UUID)
   - user_id (UUID)
   - category (TEXT)
   - fact (TEXT)
   - entity_refs (TEXT[])
   - added_at (TIMESTAMPTZ)
   - active (BOOLEAN)
   - created_at (TIMESTAMPTZ)
   - updated_at (TIMESTAMPTZ)

## Test the /context Command
1. Refresh your Flutter app
2. Try the following commands:
   - `/context add I work at Google as a software engineer`
   - `/context` (to list all facts)
   - `/context add My manager is Sarah`
   - `/context list`
   - `/context clear` (to remove all)

## What This Fixes
- ✅ Allows `/context` command to save user facts
- ✅ Persists context across login sessions
- ✅ Enables AI enrichment to use your personal context
- ✅ Provides Row Level Security (users can only see their own facts)

## Troubleshooting
If the migration fails:
1. Check if the table already exists (drop it first if needed)
2. Make sure you're connected to the right Supabase project
3. Verify you have permissions to create tables

If `/context` still doesn't work after migration:
1. Check browser console for errors
2. Make sure you're logged in
3. Try logging out and back in to reload context facts