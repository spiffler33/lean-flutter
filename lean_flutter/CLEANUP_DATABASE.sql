-- Run this in Supabase SQL Editor to clean up test entries

-- Option 1: DELETE ALL ENTRIES (nuclear option)
DELETE FROM entries WHERE user_id = auth.uid();

-- Option 2: Keep only entries from today
DELETE FROM entries
WHERE user_id = auth.uid()
AND created_at < CURRENT_DATE;

-- Option 3: Delete specific test entries (adjust pattern as needed)
DELETE FROM entries
WHERE user_id = auth.uid()
AND (
  content LIKE 'test%'
  OR content LIKE 'Test%'
  OR content = 'test'
  OR content = 'hello'
  OR LENGTH(content) < 10  -- Delete very short entries
);

-- Option 4: Keep only the last 10 entries
DELETE FROM entries
WHERE user_id = auth.uid()
AND id NOT IN (
  SELECT id FROM entries
  WHERE user_id = auth.uid()
  ORDER BY created_at DESC
  LIMIT 10
);

-- After deleting, check how many entries remain:
SELECT COUNT(*) as total_entries FROM entries WHERE user_id = auth.uid();