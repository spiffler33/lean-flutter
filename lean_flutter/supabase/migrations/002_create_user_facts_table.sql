-- Create user_facts table for storing user context
CREATE TABLE IF NOT EXISTS user_facts (
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
CREATE INDEX IF NOT EXISTS idx_user_facts_user_id ON user_facts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_facts_category ON user_facts(category);
CREATE INDEX IF NOT EXISTS idx_user_facts_active ON user_facts(active);

-- Enable Row Level Security (RLS)
ALTER TABLE user_facts ENABLE ROW LEVEL SECURITY;

-- Create policies for RLS
-- Users can only see their own facts
CREATE POLICY "Users can view own facts" ON user_facts
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own facts
CREATE POLICY "Users can insert own facts" ON user_facts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own facts
CREATE POLICY "Users can update own facts" ON user_facts
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own facts
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