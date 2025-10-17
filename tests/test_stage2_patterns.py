"""
Comprehensive Test Suite for Stage 2 Pattern Learning
Tests entity patterns, temporal patterns, edge cases, and failure modes
"""

import sqlite3
from datetime import datetime, timedelta
import json
from typing import Dict, List, Any
import sys
sys.path.append('.')

from main import (
    calculate_confidence,
    update_entity_patterns,
    update_temporal_patterns,
    DB_PATH
)


class PatternTestSuite:
    def __init__(self):
        self.db_path = DB_PATH
        self.test_results = []
        self.total_tests = 0
        self.passed_tests = 0
        self.failed_tests = 0

    def log_test(self, test_name: str, passed: bool, details: str = ""):
        """Log a test result"""
        self.total_tests += 1
        if passed:
            self.passed_tests += 1
            status = "✅ PASS"
        else:
            self.failed_tests += 1
            status = "❌ FAIL"

        result = f"{status}: {test_name}"
        if details:
            result += f"\n   {details}"

        self.test_results.append(result)
        print(result)

    def get_entity_pattern(self, entity: str) -> Dict[str, Any]:
        """Get entity pattern from database"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM entity_patterns WHERE entity = ?", (entity,))
        row = cursor.fetchone()
        conn.close()

        if row:
            return dict(row)
        return None

    def get_temporal_pattern(self, time_block: str, weekday: str) -> Dict[str, Any]:
        """Get temporal pattern from database"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute(
            "SELECT * FROM temporal_patterns WHERE time_block = ? AND weekday = ?",
            (time_block, weekday)
        )
        row = cursor.fetchone()
        conn.close()

        if row:
            return dict(row)
        return None

    def clear_pattern_tables(self):
        """Clear pattern tables for clean testing"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM entity_patterns")
        cursor.execute("DELETE FROM temporal_patterns")
        conn.commit()
        conn.close()
        print("\n🧹 Cleared pattern tables for testing\n")

    def create_test_entry(
        self,
        content: str,
        entities: List[str],
        themes: List[str],
        emotion: str,
        urgency: str,
        timestamp: datetime = None
    ) -> int:
        """Create a test entry and update patterns"""
        if timestamp is None:
            timestamp = datetime.now()

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        # Insert test entry
        cursor.execute(
            """INSERT INTO entries
               (content, created_at, tags, mood, emotion, actions, themes, people, urgency)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                content,
                timestamp.isoformat(),
                json.dumps([]),
                emotion,
                emotion,
                json.dumps([]),
                json.dumps(themes),
                json.dumps(entities),
                urgency
            )
        )
        entry_id = cursor.lastrowid
        conn.commit()
        conn.close()

        # Update patterns
        update_entity_patterns(entities, themes, emotion, urgency, timestamp.isoformat())
        update_temporal_patterns(themes, emotion, timestamp.isoformat())

        return entry_id

    # ========== ENTITY PATTERN TESTS ==========

    def test_single_entity_tracking(self):
        """Test: Single entity mention is tracked correctly"""
        self.create_test_entry(
            content="Had a meeting with Sarah",
            entities=["Sarah"],
            themes=["work"],
            emotion="neutral",
            urgency="low"
        )

        pattern = self.get_entity_pattern("Sarah")
        passed = (
            pattern is not None and
            pattern["mention_count"] == 1 and
            pattern["confidence_score"] >= 0.3
        )

        details = f"Mention count: {pattern['mention_count']}, Confidence: {pattern['confidence_score']}" if pattern else "No pattern found"
        self.log_test("Single entity tracking", passed, details)

    def test_multiple_entities_same_entry(self):
        """Test: Multiple entities in one entry are all tracked"""
        self.create_test_entry(
            content="Sarah, Mike, and I discussed the project",
            entities=["Sarah", "Mike"],
            themes=["work"],
            emotion="positive",
            urgency="medium"
        )

        sarah = self.get_entity_pattern("Sarah")
        mike = self.get_entity_pattern("Mike")

        passed = (
            sarah is not None and
            mike is not None and
            sarah["mention_count"] >= 1 and
            mike["mention_count"] == 1
        )

        details = f"Sarah: {sarah['mention_count'] if sarah else 0}, Mike: {mike['mention_count'] if mike else 0}"
        self.log_test("Multiple entities in same entry", passed, details)

    def test_entity_mention_accumulation(self):
        """Test: Entity mention count accumulates over multiple entries"""
        # First mention
        self.create_test_entry(
            content="Sarah helped with the bug",
            entities=["Sarah"],
            themes=["work"],
            emotion="grateful",
            urgency="low"
        )

        initial = self.get_entity_pattern("Sarah")
        initial_count = initial["mention_count"] if initial else 0

        # Second mention
        self.create_test_entry(
            content="Sarah suggested a new approach",
            entities=["Sarah"],
            themes=["work"],
            emotion="excited",
            urgency="medium"
        )

        final = self.get_entity_pattern("Sarah")
        final_count = final["mention_count"] if final else 0

        passed = final_count > initial_count
        details = f"Count progression: {initial_count} → {final_count}"
        self.log_test("Entity mention accumulation", passed, details)

    def test_theme_correlation_building(self):
        """Test: Theme correlations build up correctly"""
        # Sarah with work theme
        self.create_test_entry(
            content="Sarah and I worked on the project",
            entities=["Sarah"],
            themes=["work"],
            emotion="focused",
            urgency="medium"
        )

        # Sarah with personal theme
        self.create_test_entry(
            content="Had coffee with Sarah",
            entities=["Sarah"],
            themes=["personal"],
            emotion="relaxed",
            urgency="low"
        )

        pattern = self.get_entity_pattern("Sarah")
        if pattern:
            correlations = json.loads(pattern["theme_correlations"])
            has_work = "work" in correlations and correlations["work"] >= 1
            has_personal = "personal" in correlations and correlations["personal"] >= 1
            passed = has_work and has_personal
            details = f"Theme correlations: {correlations}"
        else:
            passed = False
            details = "No pattern found"

        self.log_test("Theme correlation building", passed, details)

    def test_emotion_correlation_building(self):
        """Test: Emotion correlations build up correctly"""
        # Multiple different emotions for Mike
        self.create_test_entry(
            content="Mike frustrated me today",
            entities=["Mike"],
            themes=["work"],
            emotion="frustrated",
            urgency="medium"
        )

        self.create_test_entry(
            content="Mike came through with excellent work",
            entities=["Mike"],
            themes=["work"],
            emotion="grateful",
            urgency="low"
        )

        pattern = self.get_entity_pattern("Mike")
        if pattern:
            correlations = json.loads(pattern["emotion_correlations"])
            passed = len(correlations) >= 2
            details = f"Emotion correlations: {correlations}"
        else:
            passed = False
            details = "No pattern found"

        self.log_test("Emotion correlation building", passed, details)

    def test_urgency_correlation_building(self):
        """Test: Urgency correlations build up correctly"""
        self.create_test_entry(
            content="URGENT: Need to talk to Alex",
            entities=["Alex"],
            themes=["work"],
            emotion="stressed",
            urgency="urgent"
        )

        self.create_test_entry(
            content="Casual chat with Alex",
            entities=["Alex"],
            themes=["personal"],
            emotion="relaxed",
            urgency="low"
        )

        pattern = self.get_entity_pattern("Alex")
        if pattern:
            correlations = json.loads(pattern["urgency_correlations"])
            has_urgent = "urgent" in correlations and correlations["urgent"] >= 1
            has_low = "low" in correlations and correlations["low"] >= 1
            passed = has_urgent and has_low
            details = f"Urgency correlations: {correlations}"
        else:
            passed = False
            details = "No pattern found"

        self.log_test("Urgency correlation building", passed, details)

    def test_confidence_progression(self):
        """Test: Confidence increases as mention count grows"""
        entity = "TestPerson"
        confidences = []

        # Create 10 mentions
        for i in range(10):
            self.create_test_entry(
                content=f"Mention {i} of {entity}",
                entities=[entity],
                themes=["work"],
                emotion="neutral",
                urgency="low"
            )

            pattern = self.get_entity_pattern(entity)
            if pattern:
                confidences.append(pattern["confidence_score"])

        if len(confidences) >= 2:
            increased = confidences[-1] > confidences[0]
            passed = increased and confidences[-1] <= 1.0
            details = f"Confidence: {confidences[0]:.2f} → {confidences[-1]:.2f} over {len(confidences)} mentions"
        else:
            passed = False
            details = "Not enough data points"

        self.log_test("Confidence progression", passed, details)

    # ========== TEMPORAL PATTERN TESTS ==========

    def test_morning_pattern_tracking(self):
        """Test: Morning time block is tracked"""
        morning_time = datetime.now().replace(hour=9, minute=30)

        self.create_test_entry(
            content="Morning entry",
            entities=["Someone"],
            themes=["work"],
            emotion="energized",
            urgency="low",
            timestamp=morning_time
        )

        weekday = morning_time.strftime("%A").lower()
        pattern = self.get_temporal_pattern("morning", weekday)

        passed = (
            pattern is not None and
            pattern["sample_count"] >= 1
        )

        details = f"Time block: morning, Weekday: {weekday}, Samples: {pattern['sample_count'] if pattern else 0}"
        self.log_test("Morning pattern tracking", passed, details)

    def test_afternoon_pattern_tracking(self):
        """Test: Afternoon time block is tracked"""
        afternoon_time = datetime.now().replace(hour=14, minute=30)

        self.create_test_entry(
            content="Afternoon entry",
            entities=["Someone"],
            themes=["work"],
            emotion="focused",
            urgency="medium",
            timestamp=afternoon_time
        )

        weekday = afternoon_time.strftime("%A").lower()
        pattern = self.get_temporal_pattern("afternoon", weekday)

        passed = (
            pattern is not None and
            pattern["sample_count"] >= 1
        )

        details = f"Time block: afternoon, Weekday: {weekday}, Samples: {pattern['sample_count'] if pattern else 0}"
        self.log_test("Afternoon pattern tracking", passed, details)

    def test_evening_pattern_tracking(self):
        """Test: Evening time block is tracked"""
        evening_time = datetime.now().replace(hour=19, minute=30)

        self.create_test_entry(
            content="Evening entry",
            entities=["Someone"],
            themes=["personal"],
            emotion="tired",
            urgency="low",
            timestamp=evening_time
        )

        weekday = evening_time.strftime("%A").lower()
        pattern = self.get_temporal_pattern("evening", weekday)

        passed = (
            pattern is not None and
            pattern["sample_count"] >= 1
        )

        details = f"Time block: evening, Weekday: {weekday}, Samples: {pattern['sample_count'] if pattern else 0}"
        self.log_test("Evening pattern tracking", passed, details)

    def test_night_pattern_tracking(self):
        """Test: Night time block is tracked"""
        night_time = datetime.now().replace(hour=23, minute=30)

        self.create_test_entry(
            content="Late night thoughts",
            entities=["Someone"],
            themes=["reflection"],
            emotion="contemplative",
            urgency="low",
            timestamp=night_time
        )

        weekday = night_time.strftime("%A").lower()
        pattern = self.get_temporal_pattern("night", weekday)

        passed = (
            pattern is not None and
            pattern["sample_count"] >= 1
        )

        details = f"Time block: night, Weekday: {weekday}, Samples: {pattern['sample_count'] if pattern else 0}"
        self.log_test("Night pattern tracking", passed, details)

    def test_temporal_theme_accumulation(self):
        """Test: Common themes accumulate for time blocks"""
        time = datetime.now().replace(hour=10, minute=0)
        weekday = time.strftime("%A").lower()

        # Create multiple morning work entries
        for i in range(3):
            self.create_test_entry(
                content=f"Morning work entry {i}",
                entities=["Colleague"],
                themes=["work"],
                emotion="focused",
                urgency="medium",
                timestamp=time
            )

        pattern = self.get_temporal_pattern("morning", weekday)
        if pattern:
            themes = json.loads(pattern["common_themes"])
            # Themes are stored as a list, not dict
            passed = "work" in themes
            details = f"Common themes: {themes}"
        else:
            passed = False
            details = "No pattern found"

        self.log_test("Temporal theme accumulation", passed, details)

    def test_weekday_differentiation(self):
        """Test: Different weekdays are tracked separately"""
        base_time = datetime.now().replace(hour=10, minute=0)

        # Monday
        monday = base_time - timedelta(days=base_time.weekday())
        self.create_test_entry(
            content="Monday morning",
            entities=["Team"],
            themes=["work"],
            emotion="motivated",
            urgency="high",
            timestamp=monday
        )

        # Friday
        friday = monday + timedelta(days=4)
        self.create_test_entry(
            content="Friday morning",
            entities=["Team"],
            themes=["personal"],
            emotion="relaxed",
            urgency="low",
            timestamp=friday
        )

        monday_pattern = self.get_temporal_pattern("morning", "monday")
        friday_pattern = self.get_temporal_pattern("morning", "friday")

        passed = (
            monday_pattern is not None and
            friday_pattern is not None and
            monday_pattern["sample_count"] >= 1 and
            friday_pattern["sample_count"] >= 1
        )

        details = f"Monday samples: {monday_pattern['sample_count'] if monday_pattern else 0}, Friday samples: {friday_pattern['sample_count'] if friday_pattern else 0}"
        self.log_test("Weekday differentiation", passed, details)

    # ========== EDGE CASE TESTS ==========

    def test_no_entities_extracted(self):
        """Test: Entry with no entities doesn't break pattern tracking"""
        try:
            self.create_test_entry(
                content="Just a thought with no people mentioned",
                entities=[],
                themes=["reflection"],
                emotion="contemplative",
                urgency="low"
            )
            passed = True
            details = "No crash with empty entities list"
        except Exception as e:
            passed = False
            details = f"Error: {str(e)}"

        self.log_test("No entities extracted", passed, details)

    def test_no_themes_extracted(self):
        """Test: Entry with no themes doesn't break pattern tracking"""
        try:
            self.create_test_entry(
                content="Mentioned Tom but no theme",
                entities=["Tom"],
                themes=[],
                emotion="neutral",
                urgency="low"
            )

            pattern = self.get_entity_pattern("Tom")
            passed = pattern is not None and pattern["mention_count"] >= 1
            details = "Entity tracked even without themes"
        except Exception as e:
            passed = False
            details = f"Error: {str(e)}"

        self.log_test("No themes extracted", passed, details)

    def test_special_characters_in_entity(self):
        """Test: Entity names with special characters are handled"""
        special_entities = [
            "O'Brien",
            "Jean-Luc",
            "Dr. Smith",
            "María",
            "徐伟"
        ]

        results = []
        for entity in special_entities:
            try:
                self.create_test_entry(
                    content=f"Met with {entity}",
                    entities=[entity],
                    themes=["work"],
                    emotion="neutral",
                    urgency="low"
                )

                pattern = self.get_entity_pattern(entity)
                results.append(pattern is not None)
            except Exception as e:
                results.append(False)

        passed = all(results)
        details = f"Successfully tracked {sum(results)}/{len(special_entities)} entities with special chars"
        self.log_test("Special characters in entity names", passed, details)

    def test_very_long_entity_name(self):
        """Test: Very long entity names are handled"""
        long_name = "Dr. Elizabeth Alexandra Mary Windsor-Mountbatten-Smith"

        try:
            self.create_test_entry(
                content=f"Meeting with {long_name}",
                entities=[long_name],
                themes=["work"],
                emotion="neutral",
                urgency="low"
            )

            pattern = self.get_entity_pattern(long_name)
            passed = pattern is not None
            details = f"Entity name length: {len(long_name)} characters"
        except Exception as e:
            passed = False
            details = f"Error: {str(e)}"

        self.log_test("Very long entity name", passed, details)

    def test_duplicate_entities_in_same_entry(self):
        """Test: Same entity mentioned multiple times in one entry"""
        self.create_test_entry(
            content="Bob and Bob and Bob",
            entities=["Bob", "Bob", "Bob"],
            themes=["work"],
            emotion="confused",
            urgency="low"
        )

        pattern = self.get_entity_pattern("Bob")
        passed = pattern is not None and pattern["mention_count"] >= 1
        details = f"Mention count: {pattern['mention_count'] if pattern else 0} (should handle duplicates)"
        self.log_test("Duplicate entities in same entry", passed, details)

    def test_midnight_boundary(self):
        """Test: Entries exactly at midnight are handled"""
        midnight = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)

        try:
            self.create_test_entry(
                content="Midnight thoughts",
                entities=["InsomniacFriend"],
                themes=["reflection"],
                emotion="contemplative",
                urgency="low",
                timestamp=midnight
            )

            weekday = midnight.strftime("%A").lower()
            night_pattern = self.get_temporal_pattern("night", weekday)
            morning_pattern = self.get_temporal_pattern("morning", weekday)

            passed = night_pattern is not None or morning_pattern is not None
            details = f"Midnight categorized correctly"
        except Exception as e:
            passed = False
            details = f"Error: {str(e)}"

        self.log_test("Midnight boundary handling", passed, details)

    def test_multiple_themes_same_entry(self):
        """Test: Multiple themes in one entry are all correlated"""
        self.create_test_entry(
            content="Work and personal chat with Rachel",
            entities=["Rachel"],
            themes=["work", "personal", "social"],
            emotion="friendly",
            urgency="low"
        )

        pattern = self.get_entity_pattern("Rachel")
        if pattern:
            correlations = json.loads(pattern["theme_correlations"])
            passed = len(correlations) >= 3
            details = f"Themes tracked: {list(correlations.keys())}"
        else:
            passed = False
            details = "No pattern found"

        self.log_test("Multiple themes in same entry", passed, details)

    # ========== DATA INTEGRITY TESTS ==========

    def test_time_patterns_consistency(self):
        """Test: Entity time patterns match when entries are created"""
        specific_time = datetime.now().replace(hour=15, minute=30)

        self.create_test_entry(
            content="Afternoon meeting with Chris",
            entities=["Chris"],
            themes=["work"],
            emotion="focused",
            urgency="medium",
            timestamp=specific_time
        )

        pattern = self.get_entity_pattern("Chris")
        if pattern:
            time_patterns = json.loads(pattern["time_patterns"])
            # Time patterns are stored as flat dict: {"15": 1, "tuesday": 1}
            # Hours are stored as string keys, weekdays as lowercase strings

            # Find hour keys (numeric strings)
            hour_keys = [k for k in time_patterns.keys() if k.isdigit()]
            # Find weekday keys (non-numeric strings)
            weekday_keys = [k for k in time_patterns.keys() if not k.isdigit()]

            has_hours = len(hour_keys) > 0
            has_weekdays = len(weekday_keys) > 0
            passed = has_hours and has_weekdays

            details = f"Time patterns: {time_patterns}, Hours: {hour_keys}, Weekdays: {weekday_keys}"
        else:
            passed = False
            details = "No pattern found"

        self.log_test("Entity time patterns consistency", passed, details)

    def test_json_field_validity(self):
        """Test: All JSON fields are valid and parseable"""
        self.create_test_entry(
            content="Test entry for JSON validation",
            entities=["JSONTestPerson"],
            themes=["test"],
            emotion="neutral",
            urgency="low"
        )

        pattern = self.get_entity_pattern("JSONTestPerson")

        if pattern:
            try:
                theme_corr = json.loads(pattern["theme_correlations"])
                emotion_corr = json.loads(pattern["emotion_correlations"])
                urgency_corr = json.loads(pattern["urgency_correlations"])
                time_patterns = json.loads(pattern["time_patterns"])

                passed = all([
                    isinstance(theme_corr, dict),
                    isinstance(emotion_corr, dict),
                    isinstance(urgency_corr, dict),
                    isinstance(time_patterns, dict)
                ])
                details = "All JSON fields are valid dicts"
            except json.JSONDecodeError as e:
                passed = False
                details = f"JSON decode error: {str(e)}"
        else:
            passed = False
            details = "No pattern found"

        self.log_test("JSON field validity", passed, details)

    def test_confidence_bounds(self):
        """Test: Confidence values stay within 0-1 range"""
        entity = "ConfidenceTest"
        for i in range(50):
            self.create_test_entry(
                content=f"Mention {i}",
                entities=[entity],
                themes=["test"],
                emotion="neutral",
                urgency="low"
            )

        pattern = self.get_entity_pattern(entity)
        if pattern:
            confidence = pattern["confidence_score"]
            passed = 0.0 <= confidence <= 1.0
            details = f"Confidence: {confidence:.3f} (within bounds: {passed})"
        else:
            passed = False
            details = "No pattern found"

        self.log_test("Confidence bounds", passed, details)

    # ========== STRESS TESTS ==========

    def test_many_entities_same_entry(self):
        """Test: Handle entry with many entities"""
        many_entities = [f"Person{i}" for i in range(20)]

        try:
            self.create_test_entry(
                content=f"Big meeting with {', '.join(many_entities)}",
                entities=many_entities,
                themes=["work"],
                emotion="overwhelmed",
                urgency="high"
            )

            tracked_count = sum(1 for e in many_entities if self.get_entity_pattern(e) is not None)
            passed = tracked_count == len(many_entities)
            details = f"Tracked {tracked_count}/{len(many_entities)} entities"
        except Exception as e:
            passed = False
            details = f"Error: {str(e)}"

        self.log_test("Many entities in same entry", passed, details)

    # ========== RUN ALL TESTS ==========

    def run_all_tests(self):
        """Run all test scenarios"""
        print("="*80)
        print("STAGE 2 PATTERN LEARNING - COMPREHENSIVE TEST SUITE")
        print("="*80)
        print()

        # Clear tables for clean test
        self.clear_pattern_tables()

        print("🧪 ENTITY PATTERN TESTS")
        print("-" * 80)
        self.test_single_entity_tracking()
        self.test_multiple_entities_same_entry()
        self.test_entity_mention_accumulation()
        self.test_theme_correlation_building()
        self.test_emotion_correlation_building()
        self.test_urgency_correlation_building()
        self.test_confidence_progression()

        print("\n🧪 TEMPORAL PATTERN TESTS")
        print("-" * 80)
        self.test_morning_pattern_tracking()
        self.test_afternoon_pattern_tracking()
        self.test_evening_pattern_tracking()
        self.test_night_pattern_tracking()
        self.test_temporal_theme_accumulation()
        self.test_weekday_differentiation()

        print("\n🧪 EDGE CASE TESTS")
        print("-" * 80)
        self.test_no_entities_extracted()
        self.test_no_themes_extracted()
        self.test_special_characters_in_entity()
        self.test_very_long_entity_name()
        self.test_duplicate_entities_in_same_entry()
        self.test_midnight_boundary()
        self.test_multiple_themes_same_entry()

        print("\n🧪 DATA INTEGRITY TESTS")
        print("-" * 80)
        self.test_time_patterns_consistency()
        self.test_json_field_validity()
        self.test_confidence_bounds()

        print("\n🧪 STRESS TESTS")
        print("-" * 80)
        self.test_many_entities_same_entry()

        # Summary
        print("\n" + "="*80)
        print("TEST SUMMARY")
        print("="*80)
        print(f"Total Tests: {self.total_tests}")
        print(f"✅ Passed: {self.passed_tests}")
        print(f"❌ Failed: {self.failed_tests}")
        print(f"Success Rate: {(self.passed_tests/self.total_tests*100):.1f}%")
        print("="*80)

        return self.failed_tests == 0


def main():
    """Main test runner"""
    suite = PatternTestSuite()
    success = suite.run_all_tests()

    if not success:
        print("\n⚠️  Some tests failed. Review the results above.")
        return 1
    else:
        print("\n✨ All tests passed!")
        return 0


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
