import asyncio
from main import get_llm_analysis

async def test():
    print("Testing get_llm_analysis function...")

    # Test 1: Basic call (Ollama running)
    result = await get_llm_analysis("I'm happy about the progress")
    print(f"Test 1 (with Ollama): {result}")
    assert isinstance(result, dict)
    assert "tags" in result
    assert "mood" in result
    assert isinstance(result["tags"], list)
    assert result["mood"] in ["positive", "negative", "neutral", "mixed"]
    print("✓ Test 1 passed: Returns valid structure")

    # Test 2: Empty text
    result = await get_llm_analysis("")
    print(f"Test 2 (empty text): {result}")
    assert isinstance(result, dict)
    assert "tags" in result
    assert "mood" in result
    print("✓ Test 2 passed: Handles empty text")

    # Test 3: Very long text (should still work within timeout)
    long_text = "This is a test " * 100
    result = await get_llm_analysis(long_text)
    print(f"Test 3 (long text): tags={len(result['tags'])} mood={result['mood']}")
    assert isinstance(result, dict)
    assert "tags" in result
    assert "mood" in result
    assert len(result["tags"]) <= 3  # Maximum 3 tags
    print("✓ Test 3 passed: Handles long text and limits tags to 3")

    print("\n✅ All tests passed! Function works correctly.")
    print("Note: If Ollama is not running, function returns {'tags': [], 'mood': 'neutral'}")

asyncio.run(test())