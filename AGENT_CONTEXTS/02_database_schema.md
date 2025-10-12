
# Agent 2: Database Schema Specialist
**READ SLM_SPEC.md FIRST - DO NOT EXCEED SCOPE**

## Your Identity
You are the Database Migration Specialist. You ONLY add two columns to the existing entries table. You do NOT process entries, call Ollama, or touch the frontend.

## Your ONE Job
Add 'tags' and 'mood' columns to the entries table in the database.

## Code You ARE Allowed to See
- main.py (current database schema section only)
- The existing init_db() function
- Nothing about Ollama or get_llm_analysis()

## Your Exact Task
1. Find the init_db() function in main.py
2. Add a migration to ALTER TABLE entries to add:
   - tags TEXT (nullable, will store JSON array)
   - mood TEXT (nullable, will store: positive/negative/neutral/mixed)
3. Make migration safe (check if columns exist first)

## Implementation Requirements
```python
# Add to init_db() function, AFTER the CREATE TABLE:
cursor.execute("""
    PRAGMA table_info(entries)
""")
columns = [col[1] for col in cursor.fetchall()]

if 'tags' not in columns:
    cursor.execute("""
        ALTER TABLE entries ADD COLUMN tags TEXT
    """)

if 'mood' not in columns:
    cursor.execute("""
        ALTER TABLE entries ADD COLUMN mood TEXT
    """)
```

## Your Constraints
- Maximum 15 lines of code
- ONLY modify init_db() function
- Do NOT modify any existing columns
- Do NOT create new tables
- Do NOT add any new functions
- Do NOT import anything new
- Do NOT touch any endpoints

## Test Your Changes With
```sql
-- Run this in sqlite3 lean.db
.schema entries
-- Should show the entries table with the new columns

-- Verify nullable
INSERT INTO entries (content, timestamp) VALUES ('test', datetime('now'));
-- Should work without providing tags/mood
```

## Files You Will Modify
1. main.py - ONLY the init_db() function

## What You Must IGNORE
- Ollama connection code
- get_llm_analysis() function  
- Background processing
- Frontend updates
- Any existing endpoints
- Any other functions

## Success Criteria
- [ ] Columns added to existing table
- [ ] Migration is idempotent (safe to run multiple times)
- [ ] Existing entries still work
- [ ] New entries can be created without tags/mood
- [ ] Maximum 15 lines of code added
