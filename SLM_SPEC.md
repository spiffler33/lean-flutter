# SLM Integration Specification
**THIS DOCUMENT IS IMMUTABLE ONCE CODING STARTS**

## Scope (LOCKED - DO NOT EXPAND)
- **Auto-tagging**: 1-3 topic tags per entry (single words only)
- **Mood detection**: One of: neutral/positive/negative/mixed
- **Processing**: Background only, AFTER entry is saved
- **Code budget**: Max 30 lines per component, 100 lines total

## Non-Goals (FORBIDDEN FEATURES)
- ❌ Semantic search
- ❌ Pattern detection across entries
- ❌ Entry suggestions or autocomplete
- ❌ Real-time processing (must be async)
- ❌ Summarization
- ❌ Any UI changes except showing tags/mood
- ❌ Blocking the entry save

## Technical Requirements
### Performance
- Entry save: Still <100ms (SLM runs AFTER save completes)
- SLM processing: <2 seconds per entry
- Ollama timeout: 5 seconds max then give up
- If Ollama is down: App continues working perfectly

### Data Flow (EXACT)
1. User types entry and hits Enter
2. Entry saves to DB instantly (existing behavior)
3. AFTER save: Background task calls Ollama
4. Ollama returns tags/mood (or timeout)
5. UPDATE existing entry with tags/mood
6. Frontend shows tags/mood on next refresh

### Ollama Configuration
- Model: llama3.2:3b
- Max prompt length: 50 tokens
- Temperature: 0.3 (consistent results)
- System prompt: "You are a tagger. Return JSON only."

### Database Changes
- ADD: tags column (TEXT, nullable, JSON array)
- ADD: mood column (TEXT, nullable)
- NO changes to existing columns
- NO new tables

## Success Criteria
- [ ] Entry save time unchanged (<100ms)
- [ ] Works with Ollama offline (graceful degradation)
- [ ] Tags appear within 2 seconds when Ollama is running
- [ ] Existing features untouched
- [ ] Total addition: <100 lines of code

## Rollback Plan
If this feature needs removal:
1. Remove the two columns from DB
2. Remove get_llm_analysis() function
3. Remove background task call
4. Total removal: <5 minutes
