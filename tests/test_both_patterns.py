"""
Test that /patterns shows BOTH entity patterns AND temporal patterns when data exists
"""
import sqlite3
import json
from main import handle_patterns_command

DB_PATH = "lean.db"

def add_test_entity_pattern():
    """Add a high-confidence entity pattern for testing"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    # Add a test entity with 15 mentions and 0.8 confidence
    entity = "TestPerson"
    c.execute("""
        INSERT OR REPLACE INTO entity_patterns
        (entity, mention_count, theme_correlations, emotion_correlations,
         urgency_correlations, time_patterns, confidence_score)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        entity,
        15,  # Above 10 threshold
        json.dumps({"work": 12, "personal": 3}),
        json.dumps({"focused": 10, "anxious": 5}),
        json.dumps({"none": 10, "medium": 5}),
        json.dumps({"9": 8, "monday": 7}),
        0.8  # Above 0.7 threshold
    ))

    conn.commit()
    conn.close()
    print("✓ Added test entity pattern: TestPerson (15 mentions, 0.8 confidence)")

def test_both_patterns():
    """Test that /patterns shows both entity and temporal patterns"""
    print("\n=== Testing /patterns Display ===\n")

    # Add test entity
    add_test_entity_pattern()

    # Get patterns HTML
    html = handle_patterns_command()

    # Check for both sections
    has_entity_section = "PEOPLE YOU MENTION OFTEN" in html
    has_temporal_section = "YOUR WRITING RHYTHMS" in html
    has_test_entity = "TestPerson" in html

    print("Checking for pattern sections:")
    print(f"  Entity patterns section: {'✓ PRESENT' if has_entity_section else '✗ MISSING'}")
    print(f"  Temporal patterns section: {'✓ PRESENT' if has_temporal_section else '✗ MISSING'}")
    print(f"  Test entity displayed: {'✓ YES' if has_test_entity else '✗ NO'}")

    if has_entity_section and has_temporal_section:
        print("\n✅ SUCCESS: Both entity AND temporal patterns are displayed!")
        print("\nSample output:")
        print("-" * 60)
        # Clean HTML for display
        sample = html.replace("<br>", "\n").replace("<strong>", "").replace("</strong>", "")
        sample = sample.replace("</div>", "").replace('<div class="entry">', "")
        sample = sample.replace('<div class="entry-content">', "")
        print(sample[:800])
        return True
    else:
        print("\n✗ FAILED: One or both pattern sections missing")
        return False

def cleanup():
    """Remove test entity"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("DELETE FROM entity_patterns WHERE entity = 'TestPerson'")
    conn.commit()
    conn.close()
    print("\n✓ Cleaned up test data")

if __name__ == "__main__":
    try:
        success = test_both_patterns()
        cleanup()
        exit(0 if success else 1)
    except Exception as e:
        print(f"\n✗ Error: {e}")
        cleanup()
        exit(1)
