# Run This SQL in Supabase SQL Editor

Go to your Supabase dashboard → SQL Editor → New Query → Paste this:

```sql
-- Create enrichments table for storing AI-extracted metadata
CREATE TABLE IF NOT EXISTS enrichments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id UUID NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),

    -- Tier 1 Universal Enrichments
    emotion TEXT,
    themes TEXT[],
    people JSONB,
    urgency TEXT DEFAULT 'none',

    -- Extracted items
    actions TEXT[],
    questions JSONB,
    decisions JSONB,

    -- Metadata
    confidence_scores JSONB,
    enrichment_version TEXT DEFAULT '1.0',
    processing_status TEXT DEFAULT 'pending',
    processing_time_ms INTEGER,
    error_message TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_enrichments_entry_id ON enrichments(entry_id);
CREATE INDEX idx_enrichments_user_id ON enrichments(user_id);
CREATE INDEX idx_enrichments_status ON enrichments(processing_status);

-- RLS Policies
ALTER TABLE enrichments ENABLE ROW LEVEL SECURITY;

CREATE POLICY enrichments_select_own ON enrichments
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY enrichments_insert_own ON enrichments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY enrichments_update_own ON enrichments
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY enrichments_delete_own ON enrichments
    FOR DELETE USING (auth.uid() = user_id);
```

## To Clean Up Test Entries:

```sql
-- DELETE ALL ENTRIES (be careful!)
DELETE FROM entries WHERE user_id = auth.uid();

-- Or delete entries with specific patterns:
-- DELETE FROM entries WHERE content LIKE 'test%' AND user_id = auth.uid();
```