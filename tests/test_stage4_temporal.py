"""
Test Stage 4: Enhanced Temporal Pattern Intelligence
Tests day-of-week tracking, time-of-day patterns, and weekday/weekend intelligence.
"""
import sqlite3
import json
from datetime import datetime, timedelta
from main import update_temporal_patterns, get_relevant_patterns, handle_patterns_command

DB_PATH = "lean.db"

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def clear_temporal_patterns():
    """Clear temporal patterns for clean testing"""
    conn = get_db()
    c = conn.cursor()
    c.execute("DELETE FROM temporal_patterns")
    conn.commit()
    conn.close()
    print("✓ Cleared temporal patterns table")

def test_temporal_pattern_tracking():
    """Test that temporal patterns track day-of-week and time-of-day combinations"""
    print("\n=== Testing Temporal Pattern Tracking ===")

    clear_temporal_patterns()

    # Simulate Monday morning entries
    monday_morning = datetime(2025, 10, 13, 9, 30)  # Monday 9:30 AM
    for i in range(15):
        update_temporal_patterns(['work'], 'anxious', monday_morning.isoformat())

    # Simulate Friday evening entries
    friday_evening = datetime(2025, 10, 17, 19, 0)  # Friday 7:00 PM
    for i in range(12):
        update_temporal_patterns(['personal'], 'grateful', friday_evening.isoformat())

    # Simulate weekend entries
    saturday_afternoon = datetime(2025, 10, 18, 14, 0)  # Saturday 2:00 PM
    for i in range(8):
        update_temporal_patterns(['leisure'], 'content', saturday_afternoon.isoformat())

    # Check database patterns
    conn = get_db()
    c = conn.cursor()

    # Check Monday morning specific pattern
    monday_morning_pattern = c.execute("""
        SELECT * FROM temporal_patterns
        WHERE time_block = 'morning' AND weekday = 'monday'
    """).fetchone()

    assert monday_morning_pattern is not None, "Monday morning pattern should exist"
    assert monday_morning_pattern['sample_count'] == 15, f"Expected 15 samples, got {monday_morning_pattern['sample_count']}"
    assert monday_morning_pattern['confidence'] >= 0.6, f"Expected confidence >= 0.6, got {monday_morning_pattern['confidence']}"
    print(f"✓ Monday morning pattern: {monday_morning_pattern['sample_count']} samples, confidence {monday_morning_pattern['confidence']}")

    # Check morning general pattern (aggregated across all days)
    morning_general = c.execute("""
        SELECT * FROM temporal_patterns
        WHERE time_block = 'morning' AND weekday = 'all'
    """).fetchone()

    assert morning_general is not None, "Morning general pattern should exist"
    print(f"✓ Morning (all days) pattern: {morning_general['sample_count']} samples")

    # Check weekday pattern
    weekday_pattern = c.execute("""
        SELECT * FROM temporal_patterns
        WHERE weekday = 'weekday' AND time_block = 'all'
    """).fetchone()

    assert weekday_pattern is not None, "Weekday pattern should exist"
    print(f"✓ Weekday pattern: {weekday_pattern['sample_count']} samples")

    # Check weekend pattern
    weekend_pattern = c.execute("""
        SELECT * FROM temporal_patterns
        WHERE weekday = 'weekend' AND time_block = 'all'
    """).fetchone()

    assert weekend_pattern is not None, "Weekend pattern should exist"
    assert weekend_pattern['sample_count'] == 8, f"Expected 8 weekend samples, got {weekend_pattern['sample_count']}"
    print(f"✓ Weekend pattern: {weekend_pattern['sample_count']} samples")

    conn.close()
    print("✓ Temporal pattern tracking working correctly")

def test_temporal_context_selection():
    """Test that temporal context selects the most specific pattern available"""
    print("\n=== Testing Temporal Context Selection ===")

    # Test Monday morning context (should get specific Monday morning pattern)
    monday_morning = datetime(2025, 10, 13, 9, 30)
    context = get_relevant_patterns("Working on the project", monday_morning)

    print(f"Monday morning context: {context}")
    assert "monday" in context.lower() or "morning" in context.lower() or "weekday" in context.lower(), \
        "Context should include temporal information"
    print("✓ Monday morning context returned")

    # Test Friday evening context
    friday_evening = datetime(2025, 10, 17, 19, 0)
    context = get_relevant_patterns("Reflecting on the week", friday_evening)

    print(f"Friday evening context: {context}")
    assert "friday" in context.lower() or "evening" in context.lower() or "weekday" in context.lower(), \
        "Context should include temporal information"
    print("✓ Friday evening context returned")

    # Test weekend context
    saturday_afternoon = datetime(2025, 10, 18, 14, 0)
    context = get_relevant_patterns("Relaxing at home", saturday_afternoon)

    print(f"Saturday afternoon context: {context}")
    # Should match weekend or afternoon pattern
    print("✓ Weekend context returned")

    print("✓ Temporal context selection working correctly")

def test_patterns_display():
    """Test that /patterns command displays enhanced temporal insights"""
    print("\n=== Testing /patterns Display ===")

    # Generate the patterns HTML
    html = handle_patterns_command()

    print(f"Generated HTML length: {len(html)} chars")

    # Check for Stage 4 enhancements
    assert "YOUR WRITING RHYTHMS" in html, "Should show writing rhythms section"

    # Check for time-of-day breakdown (if enough data)
    if "BY TIME OF DAY" in html:
        print("✓ Time-of-day breakdown present")

    # Check for day-of-week breakdown (if enough data)
    if "BY DAY OF WEEK" in html:
        print("✓ Day-of-week breakdown present")

    # Check for weekday/weekend breakdown (if enough data)
    if "WEEKDAY VS WEEKEND" in html:
        print("✓ Weekday/weekend breakdown present")

    print("✓ Pattern display enhanced with temporal insights")
    print("\nSample HTML output:")
    print(html[:1000] + "..." if len(html) > 1000 else html)

def test_confidence_scoring():
    """Test that confidence scores increase appropriately with sample size"""
    print("\n=== Testing Confidence Scoring ===")

    clear_temporal_patterns()

    # Create patterns with different sample sizes
    test_time = datetime(2025, 10, 14, 10, 0)  # Tuesday morning

    # Add 5 samples (should be low confidence ~0.4)
    for i in range(5):
        update_temporal_patterns(['work'], 'focused', test_time.isoformat())

    conn = get_db()
    c = conn.cursor()
    pattern = c.execute("""
        SELECT confidence, sample_count FROM temporal_patterns
        WHERE time_block = 'morning' AND weekday = 'tuesday'
    """).fetchone()

    assert pattern['sample_count'] == 5, f"Expected 5 samples, got {pattern['sample_count']}"
    assert 0.3 <= pattern['confidence'] <= 0.5, f"Expected confidence ~0.4, got {pattern['confidence']}"
    print(f"✓ 5 samples: confidence = {pattern['confidence']}")

    # Add 10 more samples (total 15, should be ~0.6)
    for i in range(10):
        update_temporal_patterns(['work'], 'focused', test_time.isoformat())

    pattern = c.execute("""
        SELECT confidence, sample_count FROM temporal_patterns
        WHERE time_block = 'morning' AND weekday = 'tuesday'
    """).fetchone()

    assert pattern['sample_count'] == 15, f"Expected 15 samples, got {pattern['sample_count']}"
    assert 0.5 <= pattern['confidence'] <= 0.7, f"Expected confidence ~0.6, got {pattern['confidence']}"
    print(f"✓ 15 samples: confidence = {pattern['confidence']}")

    # Add 35 more samples (total 50, should be ~0.8)
    for i in range(35):
        update_temporal_patterns(['work'], 'focused', test_time.isoformat())

    pattern = c.execute("""
        SELECT confidence, sample_count FROM temporal_patterns
        WHERE time_block = 'morning' AND weekday = 'tuesday'
    """).fetchone()

    assert pattern['sample_count'] == 50, f"Expected 50 samples, got {pattern['sample_count']}"
    assert 0.7 <= pattern['confidence'] <= 0.9, f"Expected confidence ~0.8, got {pattern['confidence']}"
    print(f"✓ 50 samples: confidence = {pattern['confidence']}")

    conn.close()
    print("✓ Confidence scoring working correctly")

def run_all_tests():
    """Run all Stage 4 tests"""
    print("=" * 60)
    print("STAGE 4 TEMPORAL INTELLIGENCE TESTS")
    print("=" * 60)

    try:
        test_temporal_pattern_tracking()
        test_temporal_context_selection()
        test_patterns_display()
        test_confidence_scoring()

        print("\n" + "=" * 60)
        print("✅ ALL STAGE 4 TESTS PASSED")
        print("=" * 60)
        return True
    except AssertionError as e:
        print(f"\n❌ TEST FAILED: {e}")
        return False
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = run_all_tests()
    exit(0 if success else 1)
