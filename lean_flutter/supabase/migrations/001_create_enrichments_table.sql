-- Create enrichments table for storing AI-extracted metadata
CREATE TABLE IF NOT EXISTS enrichments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),

    -- Tier 1 Universal Enrichments (applied to 100% of entries)
    emotion TEXT, -- constrained vocabulary: frustrated, anxious, excited, content, calm, etc.
    themes TEXT[], -- max 3, constrained vocabulary: work, personal, health, relationships, etc.
    people JSONB, -- {name: string, context: string, sentiment: string}[]
    urgency TEXT DEFAULT 'none', -- low, medium, high, none

    -- Extracted items
    actions TEXT[], -- extracted todos/needs
    questions JSONB, -- {text: string, type: string, answered: boolean}[]
    decisions JSONB, -- {text: string, options: string[], context: string}[]

    -- Metadata
    confidence_scores JSONB, -- per-field confidence scores
    enrichment_version TEXT DEFAULT '1.0',
    processing_status TEXT DEFAULT 'pending', -- pending, processing, complete, failed
    processing_time_ms INTEGER,
    error_message TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_enrichments_entry_id ON enrichments(entry_id);
CREATE INDEX idx_enrichments_user_id ON enrichments(user_id);
CREATE INDEX idx_enrichments_status ON enrichments(processing_status);
CREATE INDEX idx_enrichments_emotion ON enrichments(emotion);
CREATE INDEX idx_enrichments_urgency ON enrichments(urgency);

-- Add GIN index for JSONB and array searches
CREATE INDEX idx_enrichments_themes ON enrichments USING GIN(themes);
CREATE INDEX idx_enrichments_people ON enrichments USING GIN(people);

-- RLS Policies
ALTER TABLE enrichments ENABLE ROW LEVEL SECURITY;

-- Users can only see their own enrichments
CREATE POLICY enrichments_select_own ON enrichments
    FOR SELECT USING (auth.uid() = user_id);

-- Users can only insert their own enrichments
CREATE POLICY enrichments_insert_own ON enrichments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only update their own enrichments
CREATE POLICY enrichments_update_own ON enrichments
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can only delete their own enrichments
CREATE POLICY enrichments_delete_own ON enrichments
    FOR DELETE USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_enrichments_updated_at
    BEFORE UPDATE ON enrichments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();