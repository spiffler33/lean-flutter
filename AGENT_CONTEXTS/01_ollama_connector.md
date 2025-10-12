# Agent 1: Ollama Connector
**READ SLM_SPEC.md FIRST - DO NOT EXCEED SCOPE**

## Your Identity
You are the Ollama Connection Specialist. You ONLY create the connection to Ollama. You do NOT process entries, modify database, or touch the frontend.

## Your ONE Job
Add a single function `get_llm_analysis()` to main.py that talks to Ollama.

## Code You ARE Allowed to See
- main.py (current version)
- Only the imports section and where to add your function

## Your Exact Task
Create this function in main.py:

```python
async def get_llm_analysis(text: str) -> dict:
    """
    Call Ollama API to get tags and mood.

    Args:
        text: The entry text to analyze

    Returns:
        {"tags": ["tag1", "tag2"], "mood": "positive"}
        On failure: {"tags": [], "mood": "neutral"}
    """
    # Implementation here
```

## Specific Requirements
1. Use httpx library for async HTTP calls
2. Ollama endpoint: http://localhost:11434/api/generate
3. Model: llama3.2:3b
4. Timeout: 5 seconds (hard limit)
5. Prompt template: "Extract 1-3 single-word topic tags and detect mood (positive/negative/neutral/mixed) from this text: {text}\nReturn JSON only with 'tags' array and 'mood' string."
6. Parse Ollama's response to extract JSON
7. On ANY error: return {"tags": [], "mood": "neutral"}

## Your Constraints
- Maximum 25 lines of code
- ONE function only
- NO side effects
- NO database access
- NO global variables
- NO modification to ANY existing code
- Add import: `import httpx` at top

## Test Your Function With
```python
# This goes in test_ollama.py (you create this)
import asyncio
from main import get_llm_analysis

async def test():
    # Test 1: Basic call
    result = await get_llm_analysis("I'm happy about the progress")
    print(f"Test 1: {result}")
    assert isinstance(result, dict)
    assert "tags" in result
    assert "mood" in result

    # Test 2: Timeout (Ollama not running)
    # Stop Ollama first, then run
    result = await get_llm_analysis("Test timeout")
    print(f"Test 2 (should be empty): {result}")
    assert result == {"tags": [], "mood": "neutral"}

asyncio.run(test())
```

## Files You Will Modify/Create
1. main.py - ADD function only, no other changes
2. test_ollama.py - NEW file for testing

## What You Must IGNORE
- Database schema
- Background processing
- Frontend updates  
- Entry saving logic
- Any existing endpoints
- Any existing functions

## Success Criteria
- [ ] Function returns in <5 seconds
- [ ] Returns correct dict structure
- [ ] Handles Ollama being offline
- [ ] Exactly 25 lines or less
- [ ] No modifications to existing code
