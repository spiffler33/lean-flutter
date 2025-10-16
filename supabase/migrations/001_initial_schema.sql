-- Lean v2 - Supabase Database Schema
-- This migration creates the core tables and security policies

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Entries table
CREATE TABLE entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,

    -- Content
    content TEXT NOT NULL,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],

    -- AI enrichment (optional, can be null)
    mood TEXT,
    actions TEXT[] DEFAULT ARRAY[]::TEXT[],
    people TEXT[] DEFAULT ARRAY[]::TEXT[],
    themes TEXT[] DEFAULT ARRAY[]::TEXT[],
    urgency TEXT CHECK (urgency IN ('none', 'low', 'medium', 'high')),

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Sync metadata
    synced_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,

    -- Version for conflict resolution
    version INTEGER NOT NULL DEFAULT 1
);

-- Indexes for performance
CREATE INDEX idx_entries_user_id ON entries(user_id);
CREATE INDEX idx_entries_created_at ON entries(created_at DESC);
CREATE INDEX idx_entries_tags ON entries USING GIN(tags);
CREATE INDEX idx_entries_device_id ON entries(device_id);
CREATE INDEX idx_entries_deleted_at ON entries(deleted_at) WHERE deleted_at IS NULL;

-- Full-text search index
CREATE INDEX idx_entries_content_search ON entries USING GIN(to_tsvector('english', content));

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_entries_updated_at BEFORE UPDATE ON entries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS)
ALTER TABLE entries ENABLE ROW LEVEL SECURITY;

-- Users can only see their own entries
CREATE POLICY "Users can view their own entries"
    ON entries FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own entries
CREATE POLICY "Users can insert their own entries"
    ON entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own entries
CREATE POLICY "Users can update their own entries"
    ON entries FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own entries (soft delete)
CREATE POLICY "Users can delete their own entries"
    ON entries FOR DELETE
    USING (auth.uid() = user_id);

-- User stats view (for performance)
CREATE OR REPLACE VIEW user_stats AS
SELECT
    user_id,
    COUNT(*) as total_entries,
    COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE) as today_count,
    COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '7 days') as week_count,
    COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '30 days') as month_count,
    MAX(created_at) as last_entry_at,
    MIN(created_at) as first_entry_at
FROM entries
WHERE deleted_at IS NULL
GROUP BY user_id;

-- Grant permissions
GRANT SELECT ON user_stats TO authenticated;

-- Comments for documentation
COMMENT ON TABLE entries IS 'User journal entries with optional AI enrichment';
COMMENT ON COLUMN entries.device_id IS 'Device identifier for conflict resolution';
COMMENT ON COLUMN entries.version IS 'Version number incremented on each update for conflict resolution';
COMMENT ON COLUMN entries.synced_at IS 'Last time this entry was synced to a device';
COMMENT ON COLUMN entries.deleted_at IS 'Soft delete timestamp for sync purposes';
