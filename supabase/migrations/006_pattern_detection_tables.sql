-- Pattern Detection Tables for Lean Intelligence System
-- Migration 006: Create intelligence_patterns and user_streaks tables

-- Create intelligence_patterns table for storing detected patterns
CREATE TABLE IF NOT EXISTS intelligence_patterns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    pattern_type TEXT NOT NULL CHECK (pattern_type IN ('temporal', 'causal', 'streak', 'correlation', 'anomaly')),
    pattern_signature TEXT NOT NULL, -- Unique identifier for deduplication
    trigger_conditions JSONB NOT NULL DEFAULT '{}',
    outcome_conditions JSONB NOT NULL DEFAULT '{}',
    context JSONB NOT NULL DEFAULT '{}', -- time_of_day, day_of_week, people_involved
    strength_metrics JSONB NOT NULL DEFAULT '{}', -- occurrences, confidence, last_seen, first_seen
    user_feedback TEXT CHECK (user_feedback IN ('validated', 'rejected', 'pending')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, pattern_signature) -- Prevent duplicate patterns per user
);

-- Create user_streaks table for tracking consecutive events
CREATE TABLE IF NOT EXISTS user_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    streak_type TEXT NOT NULL CHECK (streak_type IN ('exercise', 'sleep', 'mood', 'productivity', 'custom')),
    streak_name TEXT, -- Optional custom name for custom streaks
    current_count INTEGER NOT NULL DEFAULT 0,
    best_count INTEGER NOT NULL DEFAULT 0,
    last_entry_date DATE,
    started_at DATE,
    broken_at DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, streak_type, streak_name) -- One streak per type per user
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_intelligence_patterns_user_id ON intelligence_patterns(user_id);
CREATE INDEX IF NOT EXISTS idx_intelligence_patterns_pattern_type ON intelligence_patterns(pattern_type);
CREATE INDEX IF NOT EXISTS idx_intelligence_patterns_user_feedback ON intelligence_patterns(user_feedback);
CREATE INDEX IF NOT EXISTS idx_intelligence_patterns_updated_at ON intelligence_patterns(updated_at);
CREATE INDEX IF NOT EXISTS idx_intelligence_patterns_strength_metrics ON intelligence_patterns USING GIN(strength_metrics);

CREATE INDEX IF NOT EXISTS idx_user_streaks_user_id ON user_streaks(user_id);
CREATE INDEX IF NOT EXISTS idx_user_streaks_streak_type ON user_streaks(streak_type);
CREATE INDEX IF NOT EXISTS idx_user_streaks_is_active ON user_streaks(is_active);
CREATE INDEX IF NOT EXISTS idx_user_streaks_last_entry_date ON user_streaks(last_entry_date);

-- Create updated_at trigger for intelligence_patterns
CREATE OR REPLACE FUNCTION update_intelligence_patterns_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_intelligence_patterns_updated_at
    BEFORE UPDATE ON intelligence_patterns
    FOR EACH ROW
    EXECUTE FUNCTION update_intelligence_patterns_updated_at();

-- Create updated_at trigger for user_streaks
CREATE OR REPLACE FUNCTION update_user_streaks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_streaks_updated_at
    BEFORE UPDATE ON user_streaks
    FOR EACH ROW
    EXECUTE FUNCTION update_user_streaks_updated_at();

-- Enable RLS (Row Level Security)
ALTER TABLE intelligence_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_streaks ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for intelligence_patterns
CREATE POLICY "Users can view their own patterns" ON intelligence_patterns
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own patterns" ON intelligence_patterns
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own patterns" ON intelligence_patterns
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own patterns" ON intelligence_patterns
    FOR DELETE USING (auth.uid() = user_id);

-- Create RLS policies for user_streaks
CREATE POLICY "Users can view their own streaks" ON user_streaks
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own streaks" ON user_streaks
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own streaks" ON user_streaks
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own streaks" ON user_streaks
    FOR DELETE USING (auth.uid() = user_id);

-- Add helpful comments
COMMENT ON TABLE intelligence_patterns IS 'Stores detected patterns from user entries including temporal, causal, and correlation patterns';
COMMENT ON TABLE user_streaks IS 'Tracks consecutive daily events like exercise, mood, and productivity streaks';

COMMENT ON COLUMN intelligence_patterns.pattern_signature IS 'Unique identifier for pattern deduplication, e.g., "temporal_morning_anxious" or "causal_exercise_to_happiness"';
COMMENT ON COLUMN intelligence_patterns.trigger_conditions IS 'JSON conditions that trigger the pattern, e.g., {"time_of_day": "morning", "day_of_week": "monday"}';
COMMENT ON COLUMN intelligence_patterns.outcome_conditions IS 'JSON conditions that represent the outcome, e.g., {"emotion": "anxious", "confidence": 0.85}';
COMMENT ON COLUMN intelligence_patterns.context IS 'Additional context like people involved, location, or other metadata';
COMMENT ON COLUMN intelligence_patterns.strength_metrics IS 'Pattern strength indicators: occurrences, confidence score, first_seen, last_seen timestamps';

COMMENT ON COLUMN user_streaks.streak_type IS 'Type of streak being tracked: exercise, sleep, mood, productivity, or custom';
COMMENT ON COLUMN user_streaks.current_count IS 'Current consecutive days for this streak';
COMMENT ON COLUMN user_streaks.best_count IS 'Best ever consecutive days achieved for this streak';
COMMENT ON COLUMN user_streaks.last_entry_date IS 'Date of the last entry contributing to this streak';
COMMENT ON COLUMN user_streaks.started_at IS 'Date when the current streak started';
COMMENT ON COLUMN user_streaks.broken_at IS 'Date when the streak was broken (null if active)';