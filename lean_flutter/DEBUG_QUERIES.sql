-- RUN THESE QUERIES IN SUPABASE SQL EDITOR TO DEBUG

-- 1. CHECK: Are there entries WITHOUT user_id?
SELECT COUNT(*) as entries_without_user_id
FROM entries
WHERE user_id IS NULL;

-- 2. CHECK: Total entries in database (all users)
SELECT COUNT(*) as total_entries_all_users
FROM entries;

-- 3. CHECK: Your specific user ID and entry count
SELECT
  auth.uid() as your_user_id,
  (SELECT COUNT(*) FROM entries WHERE user_id = auth.uid()) as your_entries;

-- 4. CHECK: Is RLS (Row Level Security) enabled?
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'entries';

-- 5. CHECK: What user_ids exist in entries table?
SELECT DISTINCT user_id, COUNT(*) as entry_count
FROM entries
GROUP BY user_id
ORDER BY entry_count DESC;

-- 6. NUCLEAR OPTION: Delete ALL entries from ALL users (BE CAREFUL!)
-- DELETE FROM entries;

-- 7. CHECK RLS POLICIES on entries table
SELECT
  pol.polname as policy_name,
  pol.polcmd as command,
  pg_get_expr(pol.polqual, pol.polrelid) as using_expression,
  pg_get_expr(pol.polwithcheck, pol.polrelid) as with_check
FROM pg_policy pol
JOIN pg_class cls ON pol.polrelid = cls.oid
WHERE cls.relname = 'entries';