-- Add 'llm' as an allowed extraction method for events
-- This supports LLM-based event extraction via Claude

-- Drop the existing constraint
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_extraction_method_check;

-- Add the new constraint with 'llm' included
ALTER TABLE events ADD CONSTRAINT events_extraction_method_check
  CHECK (extraction_method IN ('metrics', 'vlp', 'perfective', 'mixed', 'llm'));

-- Also update shadow_events table if it has any extraction_method constraint
-- (it doesn't have a constraint in the original migration, but let's be safe)
ALTER TABLE shadow_events DROP CONSTRAINT IF EXISTS shadow_events_extraction_method_check;

-- Add a constraint to shadow_events to match
ALTER TABLE shadow_events ADD CONSTRAINT shadow_events_extraction_method_check
  CHECK (extraction_method IS NULL OR extraction_method IN ('metrics', 'vlp', 'perfective', 'mixed', 'llm'));