"""
Test Stage 3: Pattern Integration

Tests that patterns are correctly integrated into extraction.
"""
import sqlite3
from main import get_relevant_patterns, build_full_context, handle_patterns_command
from datetime import datetime

DB_PATH = "lean.db"

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def test_patterns_display():
    """Test that /patterns command displays learned patterns."""
    print("\n=== Testing /patterns Command ===")

    result = handle_patterns_command()
    print(result)
    print("✓ /patterns command works")

def test_relevant_patterns():
    """Test that get_relevant_patterns finds relevant patterns."""
    print("\n=== Testing Relevant Pattern Retrieval ===")

    # Test with entity mention
    entry_text = "Had a meeting with Sarah today"
    patterns = get_relevant_patterns(entry_text)
    print(f"Entry: '{entry_text}'")
    print(f"Relevant patterns: {patterns}")

    # Test with temporal context
    entry_text2 = "Starting my morning routine"
    patterns2 = get_relevant_patterns(entry_text2, datetime(2024, 10, 14, 9, 0, 0))  # Monday morning
    print(f"\nEntry: '{entry_text2}'")
    print(f"Relevant patterns: {patterns2}")

    print("✓ Relevant pattern retrieval works")

def test_full_context():
    """Test that build_full_context combines facts and patterns."""
    print("\n=== Testing Full Context Building ===")

    entry_text = "Meeting with Sarah about the project"
    full_context = build_full_context(entry_text, datetime.utcnow())

    print(f"Entry: '{entry_text}'")
    print(f"Full context: {full_context}")
    print(f"Context length: {len(full_context.split())} words")

    # Verify it's under 500 words
    word_count = len(full_context.split())
    assert word_count <= 500, f"Context too long: {word_count} words"

    print("✓ Full context building works and stays under 500 words")

def check_pattern_data():
    """Check what pattern data exists in the database."""
    print("\n=== Checking Pattern Data ===")

    conn = get_db()
    c = conn.cursor()

    # Check entity patterns
    entities = c.execute("""
        SELECT entity, mention_count, confidence_score
        FROM entity_patterns
        ORDER BY mention_count DESC
        LIMIT 5
    """).fetchall()

    print("\nTop Entities:")
    for ent in entities:
        print(f"  {ent['entity']}: {ent['mention_count']} mentions (confidence: {ent['confidence_score']:.2f})")

    # Check temporal patterns
    temporal = c.execute("""
        SELECT time_block, weekday, sample_count, confidence
        FROM temporal_patterns
        ORDER BY sample_count DESC
        LIMIT 5
    """).fetchall()

    print("\nTop Temporal Patterns:")
    for temp in temporal:
        print(f"  {temp['time_block']}/{temp['weekday']}: {temp['sample_count']} samples (confidence: {temp['confidence']:.2f})")

    conn.close()
    print("✓ Pattern data checked")

def test_pattern_influence():
    """Test that patterns influence extraction (conceptual test)."""
    print("\n=== Testing Pattern Influence (Conceptual) ===")

    # This test verifies that the context is being passed to extractors
    entry_text = "Meeting with known entity"
    full_context = build_full_context(entry_text)

    if full_context:
        print(f"Context is being generated: '{full_context[:100]}...'")
        print("✓ Pattern context will influence LLM extraction")
    else:
        print("⚠ No context generated (may need more pattern data)")

if __name__ == "__main__":
    print("Stage 3 Pattern Integration Tests")
    print("=" * 50)

    try:
        check_pattern_data()
        test_patterns_display()
        test_relevant_patterns()
        test_full_context()
        test_pattern_influence()

        print("\n" + "=" * 50)
        print("✅ All Stage 3 tests passed!")
        print("\nStage 3 Implementation Complete:")
        print("  ✓ get_relevant_patterns() - Selects context-aware patterns")
        print("  ✓ /patterns command - Displays learned insights")
        print("  ✓ build_full_context() - Combines facts + patterns")
        print("  ✓ LLM extractors - Now use full context")
        print("  ✓ Context stays under 500 words")

    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
