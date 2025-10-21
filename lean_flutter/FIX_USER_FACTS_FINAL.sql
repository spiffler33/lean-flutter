-- Fix user_facts table to match Flutter app expectations
-- The existing table has wrong column names: fact_id, fact_text, fact_category
-- Flutter app expects: id, fact, category

-- Step 1: Drop existing policies (if they exist)
DROP POLICY IF EXISTS "Users can view own facts" ON user_facts;
DROP POLICY IF EXISTS "Users can insert own facts" ON user_facts;
DROP POLICY IF EXISTS "Users can update own facts" ON user_facts;
DROP POLICY IF EXISTS "Users can delete own facts" ON user_facts;

-- Step 2: Drop the trigger if it exists (but NOT the function since it's used elsewhere)
DROP TRIGGER IF EXISTS update_user_facts_updated_at ON user_facts;

-- Step 3: Drop the existing table
DROP TABLE IF EXISTS user_facts CASCADE;

-- Step 4: Create the table with the CORRECT column names that Flutter expects
CREATE TABLE user_facts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  -- Flutter expects 'id' not 'fact_id'
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('work', 'personal', 'people', 'location')),  -- Flutter expects 'category' not 'fact_category'
    fact TEXT NOT NULL,  -- Flutter expects 'fact' not 'fact_text'
    entity_refs TEXT[] DEFAULT '{}',
    added_at TIMESTAMPTZ DEFAULT NOW(),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 5: Add indexes for performance
CREATE INDEX idx_user_facts_user_id ON user_facts(user_id);
CREATE INDEX idx_user_facts_category ON user_facts(category);
CREATE INDEX idx_user_facts_active ON user_facts(active);

-- Step 6: Enable Row Level Security (RLS)
ALTER TABLE user_facts ENABLE ROW LEVEL SECURITY;

-- Step 7: Create policies for RLS
CREATE POLICY "Users can view own facts" ON user_facts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own facts" ON user_facts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own facts" ON user_facts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own facts" ON user_facts
    FOR DELETE USING (auth.uid() = user_id);

-- Step 8: Add trigger for updated_at (reuse existing function)
CREATE TRIGGER update_user_facts_updated_at BEFORE UPDATE
    ON user_facts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 9: Verify the table was created correctly
SELECT 'SUCCESS: Table user_facts recreated with correct column names!' as message;

-- Show the new structure
SELECT
    column_name,
    data_type,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_facts'
ORDER BY ordinal_position;