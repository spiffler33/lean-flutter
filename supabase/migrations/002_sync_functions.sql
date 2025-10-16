-- Lean v2 - Sync Helper Functions
-- Functions to make sync easier and more efficient

-- Function to get entries modified since a timestamp
CREATE OR REPLACE FUNCTION get_entries_since(since_timestamp TIMESTAMPTZ)
RETURNS SETOF entries AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM entries
    WHERE user_id = auth.uid()
    AND (updated_at > since_timestamp OR created_at > since_timestamp)
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to batch upsert entries (for sync from device)
CREATE OR REPLACE FUNCTION upsert_entries(entries_json JSONB)
RETURNS TABLE(id UUID, version INTEGER, updated_at TIMESTAMPTZ) AS $$
DECLARE
    entry_record JSONB;
    result_id UUID;
    result_version INTEGER;
    result_updated_at TIMESTAMPTZ;
BEGIN
    FOR entry_record IN SELECT * FROM jsonb_array_elements(entries_json)
    LOOP
        -- Insert or update based on id and version
        INSERT INTO entries (
            id, user_id, device_id, content, tags,
            mood, actions, people, themes, urgency,
            created_at, updated_at, version
        )
        VALUES (
            COALESCE((entry_record->>'id')::UUID, uuid_generate_v4()),
            auth.uid(),
            entry_record->>'device_id',
            entry_record->>'content',
            COALESCE((entry_record->>'tags')::TEXT[], ARRAY[]::TEXT[]),
            entry_record->>'mood',
            COALESCE((entry_record->>'actions')::TEXT[], ARRAY[]::TEXT[]),
            COALESCE((entry_record->>'people')::TEXT[], ARRAY[]::TEXT[]),
            COALESCE((entry_record->>'themes')::TEXT[], ARRAY[]::TEXT[]),
            entry_record->>'urgency',
            COALESCE((entry_record->>'created_at')::TIMESTAMPTZ, NOW()),
            COALESCE((entry_record->>'updated_at')::TIMESTAMPTZ, NOW()),
            COALESCE((entry_record->>'version')::INTEGER, 1)
        )
        ON CONFLICT (id) DO UPDATE
        SET
            content = EXCLUDED.content,
            tags = EXCLUDED.tags,
            mood = EXCLUDED.mood,
            actions = EXCLUDED.actions,
            people = EXCLUDED.people,
            themes = EXCLUDED.themes,
            urgency = EXCLUDED.urgency,
            updated_at = EXCLUDED.updated_at,
            version = EXCLUDED.version
        WHERE entries.version < EXCLUDED.version
        RETURNING entries.id, entries.version, entries.updated_at
        INTO result_id, result_version, result_updated_at;

        -- Return the result
        IF result_id IS NOT NULL THEN
            id := result_id;
            version := result_version;
            updated_at := result_updated_at;
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark entry as synced
CREATE OR REPLACE FUNCTION mark_synced(entry_ids UUID[])
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE entries
    SET synced_at = NOW()
    WHERE id = ANY(entry_ids)
    AND user_id = auth.uid();

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to soft delete entries
CREATE OR REPLACE FUNCTION soft_delete_entries(entry_ids UUID[])
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    UPDATE entries
    SET deleted_at = NOW()
    WHERE id = ANY(entry_ids)
    AND user_id = auth.uid()
    AND deleted_at IS NULL;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get sync stats
CREATE OR REPLACE FUNCTION get_sync_stats()
RETURNS TABLE(
    total_entries BIGINT,
    synced_entries BIGINT,
    unsynced_entries BIGINT,
    last_sync_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) as total_entries,
        COUNT(*) FILTER (WHERE synced_at IS NOT NULL) as synced_entries,
        COUNT(*) FILTER (WHERE synced_at IS NULL) as unsynced_entries,
        MAX(synced_at) as last_sync_at
    FROM entries
    WHERE user_id = auth.uid()
    AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_entries_since TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_entries TO authenticated;
GRANT EXECUTE ON FUNCTION mark_synced TO authenticated;
GRANT EXECUTE ON FUNCTION soft_delete_entries TO authenticated;
GRANT EXECUTE ON FUNCTION get_sync_stats TO authenticated;
