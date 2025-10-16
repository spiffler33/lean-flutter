-- Migration 003: AI Enrichment and Pattern Learning Tables
-- Adds support for /context command and pattern tracking

-- User Facts Table (for /context command)
CREATE TABLE IF NOT EXISTS user_facts (
    fact_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fact_text TEXT NOT NULL CHECK (length(fact_text) <= 200),
    fact_category TEXT CHECK (fact_category IN ('work', 'personal', 'people', 'location', 'other')),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for user_facts
CREATE INDEX idx_user_facts_user_id ON user_facts(user_id);
CREATE INDEX idx_user_facts_active ON user_facts(user_id, active);

-- RLS for user_facts
ALTER TABLE user_facts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own facts"
    ON user_facts FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own facts"
    ON user_facts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own facts"
    ON user_facts FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own facts"
    ON user_facts FOR DELETE
    USING (auth.uid() = user_id);

-- Entity Patterns Table (track people, correlations)
CREATE TABLE IF NOT EXISTS entity_patterns (
    entity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    entity TEXT NOT NULL,
    entity_type TEXT DEFAULT 'person',
    mention_count INTEGER DEFAULT 1,
    theme_correlations JSONB DEFAULT '{}',
    emotion_correlations JSONB DEFAULT '{}',
    urgency_correlations JSONB DEFAULT '{}',
    time_patterns JSONB DEFAULT '{}',
    confidence_score FLOAT DEFAULT 0.0,
    first_seen TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, entity)
);

-- Indexes for entity_patterns
CREATE INDEX idx_entity_patterns_user_id ON entity_patterns(user_id);
CREATE INDEX idx_entity_patterns_confidence ON entity_patterns(user_id, confidence_score);
CREATE INDEX idx_entity_patterns_mentions ON entity_patterns(user_id, mention_count);

-- RLS for entity_patterns
ALTER TABLE entity_patterns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own patterns"
    ON entity_patterns FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own patterns"
    ON entity_patterns FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own patterns"
    ON entity_patterns FOR UPDATE
    USING (auth.uid() = user_id);

-- Temporal Patterns Table (track time-based writing patterns)
CREATE TABLE IF NOT EXISTS temporal_patterns (
    pattern_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    time_block TEXT NOT NULL CHECK (time_block IN ('morning', 'afternoon', 'evening', 'night', 'all')),
    weekday TEXT NOT NULL CHECK (weekday IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday', 'weekday', 'weekend', 'all')),
    common_themes TEXT[] DEFAULT ARRAY[]::TEXT[],
    common_emotions TEXT[] DEFAULT ARRAY[]::TEXT[],
    sample_count INTEGER DEFAULT 0,
    confidence FLOAT DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, time_block, weekday)
);

-- Indexes for temporal_patterns
CREATE INDEX idx_temporal_patterns_user_id ON temporal_patterns(user_id);
CREATE INDEX idx_temporal_patterns_confidence ON temporal_patterns(user_id, confidence);
CREATE INDEX idx_temporal_patterns_samples ON temporal_patterns(user_id, sample_count);

-- RLS for temporal_patterns
ALTER TABLE temporal_patterns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own temporal patterns"
    ON temporal_patterns FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own temporal patterns"
    ON temporal_patterns FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own temporal patterns"
    ON temporal_patterns FOR UPDATE
    USING (auth.uid() = user_id);

-- Update trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_facts_updated_at BEFORE UPDATE ON user_facts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_temporal_patterns_updated_at BEFORE UPDATE ON temporal_patterns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
