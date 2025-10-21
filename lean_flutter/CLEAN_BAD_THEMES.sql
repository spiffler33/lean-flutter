-- SQL script to clean up bad theme data in Supabase entries table
-- Run this in your Supabase SQL editor

-- First, let's see what themes we currently have (for analysis)
SELECT DISTINCT
    unnest(themes) as theme,
    COUNT(*) as count
FROM entries
WHERE themes IS NOT NULL AND array_length(themes, 1) > 0
GROUP BY theme
ORDER BY count DESC;

-- Define list of bad themes to remove
-- These are common words that were incorrectly extracted as themes
WITH bad_themes AS (
    SELECT unnest(ARRAY[
        'Should', 'It', 'The', 'This', 'That', 'These', 'Those',
        'Finally', 'My', 'Your', 'His', 'Her', 'Their', 'Our',
        'Had', 'Have', 'Has', 'Having', 'Been', 'Being', 'Was', 'Were',
        'Am', 'Is', 'Are', 'Be', 'Do', 'Does', 'Did', 'Done',
        'Will', 'Would', 'Could', 'Can', 'May', 'Might', 'Must',
        'Shall', 'Should', 'Ought', 'Need', 'Dare',
        'Today', 'Tomorrow', 'Yesterday', 'Now', 'Then', 'Time',
        'Here', 'There', 'Where', 'When', 'Why', 'How', 'What',
        'And', 'Or', 'But', 'If', 'Because', 'Since', 'For',
        'With', 'Without', 'About', 'After', 'Before', 'During',
        'I', 'You', 'He', 'She', 'We', 'They', 'Me', 'Him', 'Her',
        'A', 'An', 'Some', 'Any', 'All', 'Many', 'Few', 'Much',
        'So', 'Very', 'Too', 'Just', 'Only', 'Also', 'Still', 'Yet',
        'Up', 'Down', 'In', 'Out', 'On', 'Off', 'Over', 'Under'
    ]) AS bad_theme
)

-- Update entries to remove bad themes
UPDATE entries
SET themes = (
    SELECT array_agg(theme)
    FROM unnest(themes) AS theme
    WHERE theme NOT IN (SELECT bad_theme FROM bad_themes)
    AND theme != ''
)
WHERE themes IS NOT NULL;

-- Clean up entries where all themes were bad (set to empty array or NULL)
UPDATE entries
SET themes = ARRAY[]::text[]
WHERE themes IS NULL OR array_length(themes, 1) = 0 OR array_length(themes, 1) IS NULL;

-- Add proper themes based on content analysis
-- This adds meaningful themes based on keywords in content
UPDATE entries
SET themes =
    CASE
        WHEN themes IS NULL THEN ARRAY[]::text[]
        ELSE themes
    END ||
    CASE
        WHEN content ~* '\y(work|meeting|project|deadline|sprint|office|team|boss|manager)\y'
            AND NOT ('work' = ANY(themes))
            THEN ARRAY['work']
        ELSE ARRAY[]::text[]
    END ||
    CASE
        WHEN content ~* '\y(run|running|gym|exercise|workout|fitness|health|10k|5k|marathon)\y'
            AND NOT ('health' = ANY(themes))
            THEN ARRAY['health']
        ELSE ARRAY[]::text[]
    END ||
    CASE
        WHEN content ~* '\y(friend|family|date|relationship|wife|husband|partner)\y'
            AND NOT ('relationships' = ANY(themes))
            THEN ARRAY['relationships']
        ELSE ARRAY[]::text[]
    END ||
    CASE
        WHEN content ~* '\y(learn|study|course|book|reading|research|tutorial)\y'
            AND NOT ('learning' = ANY(themes))
            THEN ARRAY['learning']
        ELSE ARRAY[]::text[]
    END ||
    CASE
        WHEN content ~* '\y(code|programming|debug|refactor|framework|database|api|frontend|backend|auth)\y'
            AND NOT ('tech' = ANY(themes))
            THEN ARRAY['tech']
        ELSE ARRAY[]::text[]
    END ||
    CASE
        WHEN content ~* '\y(money|budget|expense|pay|salary|cost|price)\y'
            AND NOT ('finance' = ANY(themes))
            THEN ARRAY['finance']
        ELSE ARRAY[]::text[]
    END
WHERE content IS NOT NULL;

-- Remove duplicates from themes array
UPDATE entries
SET themes = array(SELECT DISTINCT unnest(themes))
WHERE themes IS NOT NULL AND array_length(themes, 1) > 0;

-- Ensure themes don't exceed 3 items (keep most relevant ones)
UPDATE entries
SET themes = themes[1:3]
WHERE array_length(themes, 1) > 3;

-- Also clean up the 'people' field - remove common non-names
WITH bad_people AS (
    SELECT unnest(ARRAY[
        'The', 'This', 'That', 'Today', 'Tomorrow', 'Yesterday',
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    ]) AS bad_name
)
UPDATE entries
SET people = (
    SELECT array_agg(person)
    FROM unnest(people) AS person
    WHERE person NOT IN (SELECT bad_name FROM bad_people)
    AND person != ''
    AND length(person) > 1  -- Remove single letters
)
WHERE people IS NOT NULL;

-- Clean up people array (set to empty if all were bad)
UPDATE entries
SET people = ARRAY[]::text[]
WHERE people IS NULL OR array_length(people, 1) = 0 OR array_length(people, 1) IS NULL;

-- Final check: show the cleaned themes distribution
SELECT DISTINCT
    unnest(themes) as theme,
    COUNT(*) as count
FROM entries
WHERE themes IS NOT NULL AND array_length(themes, 1) > 0
GROUP BY theme
ORDER BY count DESC;