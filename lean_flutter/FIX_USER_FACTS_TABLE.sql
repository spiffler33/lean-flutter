-- First, check if user_facts table exists and what columns it has
-- Run this query first to see the current structure:
/*
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_facts'
ORDER BY ordinal_position;
*/

-- OPTION 1: DROP AND RECREATE (Recommended if no important data exists)
-- =====================================================================
-- This will delete the existing table and create it fresh with the correct schema

-- Drop existing policies first (if they exist)
DROP POLICY IF EXISTS "Users can view own facts" ON user_facts;
DROP POLICY IF EXISTS "Users can insert own facts" ON user_facts;
DROP POLICY IF EXISTS "Users can update own facts" ON user_facts;
DROP POLICY IF EXISTS "Users can delete own facts" ON user_facts;

-- Drop the trigger and function if they exist
DROP TRIGGER IF EXISTS update_user_facts_updated_at ON user_facts;
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Drop the existing table
DROP TABLE IF EXISTS user_facts CASCADE;

-- Create the table with the correct schema
CREATE TABLE user_facts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('work', 'personal', 'people', 'location')),
    fact TEXT NOT NULL,
    entity_refs TEXT[] DEFAULT '{}',
    added_at TIMESTAMPTZ DEFAULT NOW(),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX idx_user_facts_user_id ON user_facts(user_id);
CREATE INDEX idx_user_facts_category ON user_facts(category);
CREATE INDEX idx_user_facts_active ON user_facts(active);

-- Enable Row Level Security (RLS)
ALTER TABLE user_facts ENABLE ROW LEVEL SECURITY;

-- Create policies for RLS
CREATE POLICY "Users can view own facts" ON user_facts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own facts" ON user_facts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own facts" ON user_facts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own facts" ON user_facts
    FOR DELETE USING (auth.uid() = user_id);

-- Add a trigger to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_facts_updated_at BEFORE UPDATE
    ON user_facts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Verify the table was created correctly
SELECT 'Table user_facts created successfully with columns:' as message;
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_facts'
ORDER BY ordinal_position;


-- OPTION 2: ALTER EXISTING TABLE (Use this if you want to preserve data)
-- ========================================================================
-- Uncomment and run these commands if you want to modify the existing table
-- instead of dropping it:

/*
-- Add missing columns if they don't exist
ALTER TABLE user_facts
ADD COLUMN IF NOT EXISTS category TEXT;

-- Add constraint for category
ALTER TABLE user_facts
DROP CONSTRAINT IF EXISTS user_facts_category_check;

ALTER TABLE user_facts
ADD CONSTRAINT user_facts_category_check
CHECK (category IN ('work', 'personal', 'people', 'location'));

-- Add other missing columns
ALTER TABLE user_facts
ADD COLUMN IF NOT EXISTS fact TEXT,
ADD COLUMN IF NOT EXISTS entity_refs TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS added_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Update any NULL values in required columns
UPDATE user_facts SET category = 'personal' WHERE category IS NULL;
UPDATE user_facts SET fact = '' WHERE fact IS NULL;

-- Now make columns NOT NULL
ALTER TABLE user_facts
ALTER COLUMN category SET NOT NULL,
ALTER COLUMN fact SET NOT NULL;
*/