-- Event Extraction Tables for Lean Intelligence System
-- Captures trackable events from user entries (exercise, spending, sleep, etc.)

-- Events table: stores extracted events with high confidence (≥0.85)
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  entry_id UUID REFERENCES entries(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('exercise', 'consumption', 'spend', 'sleep', 'meeting', 'health')),
  subtype TEXT, -- run, coffee, groceries, etc
  metrics JSONB DEFAULT '{}', -- {distance_km: 5, duration_min: 28, amount: 200, etc}
  context JSONB DEFAULT '{}', -- {people: ['Sarah'], location: 'gym', work_related: true}
  confidence FLOAT NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
  extraction_method TEXT CHECK (extraction_method IN ('metrics', 'vlp', 'perfective', 'mixed')),
  user_validated BOOLEAN DEFAULT NULL, -- null = not yet validated, true/false = user decision
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX idx_events_user_id ON events(user_id);
CREATE INDEX idx_events_entry_id ON events(entry_id);
CREATE INDEX idx_events_type ON events(type);
CREATE INDEX idx_events_created_at ON events(created_at DESC);
CREATE INDEX idx_events_confidence ON events(confidence DESC);
CREATE INDEX idx_events_user_validated ON events(user_validated) WHERE user_validated IS NULL;

-- VLPs (Very Likely Patterns) table: tracks repeated phrases for future extraction
CREATE TABLE IF NOT EXISTS vlps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  phrase TEXT NOT NULL,
  phrase_normalized TEXT NOT NULL, -- lowercase, trimmed version for matching
  event_type TEXT CHECK (event_type IN ('exercise', 'consumption', 'spend', 'sleep', 'meeting', 'health', NULL)),
  usage_count INTEGER DEFAULT 1,
  first_seen TIMESTAMPTZ DEFAULT NOW(),
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  user_action TEXT CHECK (user_action IN ('validated', 'rejected', NULL)),
  metrics_template JSONB DEFAULT '{}', -- learned metrics structure from validations
  confidence_boost FLOAT DEFAULT 0.30, -- how much this VLP adds to confidence
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, phrase_normalized)
);

-- Create indexes for VLP lookups
CREATE INDEX idx_vlps_user_id ON vlps(user_id);
CREATE INDEX idx_vlps_phrase_normalized ON vlps(phrase_normalized);
CREATE INDEX idx_vlps_usage_count ON vlps(usage_count DESC);
CREATE INDEX idx_vlps_user_action ON vlps(user_action);

-- Shadow events table: stores lower confidence extractions (0.65-0.85) for learning
CREATE TABLE IF NOT EXISTS shadow_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  entry_id UUID REFERENCES entries(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  subtype TEXT,
  metrics JSONB DEFAULT '{}',
  context JSONB DEFAULT '{}',
  confidence FLOAT NOT NULL CHECK (confidence >= 0.65 AND confidence < 0.85),
  extraction_method TEXT,
  phrase TEXT, -- the actual phrase that triggered this shadow event
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for shadow events
CREATE INDEX idx_shadow_events_user_id ON shadow_events(user_id);
CREATE INDEX idx_shadow_events_phrase ON shadow_events(phrase);
CREATE INDEX idx_shadow_events_created_at ON shadow_events(created_at DESC);

-- Function to promote shadow events to VLPs when threshold is met
CREATE OR REPLACE FUNCTION promote_shadow_to_vlp()
RETURNS void AS $$
DECLARE
  shadow_record RECORD;
BEGIN
  -- Find phrases that appear 3+ times in last 28 days
  FOR shadow_record IN
    SELECT
      user_id,
      phrase,
      LOWER(TRIM(phrase)) as phrase_normalized,
      type as event_type,
      COUNT(*) as occurrence_count,
      MIN(created_at) as first_seen,
      MAX(created_at) as last_seen,
      JSONB_AGG(DISTINCT metrics) FILTER (WHERE metrics != '{}') as metrics_samples
    FROM shadow_events
    WHERE
      created_at > NOW() - INTERVAL '28 days'
      AND phrase IS NOT NULL
      AND phrase != ''
    GROUP BY user_id, phrase, type
    HAVING COUNT(*) >= 3
  LOOP
    -- Insert or update VLP
    INSERT INTO vlps (
      user_id,
      phrase,
      phrase_normalized,
      event_type,
      usage_count,
      first_seen,
      last_seen,
      metrics_template
    ) VALUES (
      shadow_record.user_id,
      shadow_record.phrase,
      shadow_record.phrase_normalized,
      shadow_record.event_type,
      shadow_record.occurrence_count,
      shadow_record.first_seen,
      shadow_record.last_seen,
      COALESCE(shadow_record.metrics_samples->0, '{}')
    )
    ON CONFLICT (user_id, phrase_normalized)
    DO UPDATE SET
      usage_count = vlps.usage_count + EXCLUDED.usage_count,
      last_seen = EXCLUDED.last_seen,
      event_type = COALESCE(vlps.event_type, EXCLUDED.event_type),
      metrics_template = CASE
        WHEN vlps.metrics_template = '{}' THEN EXCLUDED.metrics_template
        ELSE vlps.metrics_template
      END,
      updated_at = NOW();
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vlps_updated_at BEFORE UPDATE ON vlps
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to get event statistics for a user
CREATE OR REPLACE FUNCTION get_event_stats(p_user_id UUID, p_days INTEGER DEFAULT 30)
RETURNS TABLE (
  event_type TEXT,
  total_count BIGINT,
  avg_metrics JSONB,
  last_occurrence TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.type as event_type,
    COUNT(*) as total_count,
    JSONB_BUILD_OBJECT(
      'avg_distance_km', AVG((metrics->>'distance_km')::FLOAT),
      'avg_duration_min', AVG((metrics->>'duration_min')::FLOAT),
      'avg_amount', AVG((metrics->>'amount')::FLOAT),
      'total_distance_km', SUM((metrics->>'distance_km')::FLOAT),
      'total_duration_min', SUM((metrics->>'duration_min')::FLOAT),
      'total_amount', SUM((metrics->>'amount')::FLOAT)
    ) as avg_metrics,
    MAX(e.created_at) as last_occurrence
  FROM events e
  WHERE
    e.user_id = p_user_id
    AND e.created_at > NOW() - (p_days || ' days')::INTERVAL
    AND (e.user_validated IS NULL OR e.user_validated = true)
  GROUP BY e.type
  ORDER BY total_count DESC;
END;
$$ LANGUAGE plpgsql;

-- RLS Policies
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE vlps ENABLE ROW LEVEL SECURITY;
ALTER TABLE shadow_events ENABLE ROW LEVEL SECURITY;

-- Users can only see and modify their own events
CREATE POLICY "Users can view own events" ON events
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own vlps" ON vlps
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own shadow events" ON shadow_events
  FOR ALL USING (auth.uid() = user_id);