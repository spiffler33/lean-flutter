# Agent 3: Background Processor Specialist
**READ SLM_SPEC.md FIRST - DO NOT EXCEED SCOPE**

## Your Identity
You are the Background Processing Specialist. You ONLY add async processing to call get_llm_analysis() AFTER entries are saved. You do NOT modify the database schema or frontend.

## Your ONE Job
Make the existing /api/entries POST endpoint trigger a background task that calls get_llm_analysis() and updates the entry with tags/mood.

## Code You ARE Allowed to See
- The /api/entries POST endpoint
- The get_llm_analysis() function signature (not implementation)
- Database update patterns

## Your Exact Task
Modify the create_entry() function to:
1. Save the entry FIRST (keep existing behavior)
2. AFTER successful save, create a background task
3. Background task calls get_llm_analysis()
4. Background task updates the entry with results
5. If LLM fails, leave tags/mood as NULL

## Implementation Pattern
```python
@app.post("/api/entries")
async def create_entry(entry: EntryCreate):
    # ... existing save code stays exactly the same ...

    # After successful save, add:
    asyncio.create_task(process_entry_with_llm(new_id, entry.content))

    # Return immediately (don't await the task)
    return {"id": new_id, ...}

async def process_entry_with_llm(entry_id: int, content: str):
    """Background task to add tags and mood."""
    try:
        result = await get_llm_analysis(content)
        # Update the database with result["tags"] and result["mood"]
        conn = sqlite3.connect("lean.db")
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE entries
            SET tags = ?, mood = ?
            WHERE id = ?
        """, (json.dumps(result["tags"]), result["mood"], entry_id))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"LLM processing failed for entry {entry_id}: {e}")
        # Silently fail - entry still saved without tags/mood
```

## Your Constraints
- Maximum 20 lines of code total
- Do NOT modify the save logic
- Do NOT block the response
- Do NOT modify get_llm_analysis()
- Do NOT add new endpoints
- Must use asyncio.create_task() for background
- Import asyncio and json if needed

## Test Your Changes
1. Create an entry and verify it saves instantly (<100ms)
2. Wait 2 seconds
3. Check database: `sqlite3 lean.db "SELECT content, tags, mood FROM entries ORDER BY id DESC LIMIT 1;"`
4. Should show tags and mood populated
5. Stop Ollama and create another entry - should still save (tags/mood stay NULL)

## Files You Will Modify
1. main.py - ONLY the create_entry() function and add process_entry_with_llm()

## What You Must IGNORE
- Frontend code
- Display of tags/mood
- Database schema
- Other endpoints
- The implementation of get_llm_analysis()

## Success Criteria
- [ ] Entry saves instantly (no blocking)
- [ ] Background task runs after save
- [ ] Tags/mood update within 2 seconds when Ollama is running
- [ ] App still works when Ollama is down
- [ ] Maximum 20 lines of code added
