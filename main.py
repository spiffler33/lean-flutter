"""
Lean - Local Microblog MVP
FastAPI backend with SQLite storage and HTMX frontend
"""
import os
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional
import json
import re
from collections import Counter
import httpx
import asyncio

from fastapi import FastAPI, Request, Form, Query
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

# Import AI features
from ai import summarize_entries

# Global set to keep background tasks alive
background_tasks = set()

# Setup
app = FastAPI()
BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "lean.db"
ENTRIES_DIR = BASE_DIR / "entries"
ENTRIES_DIR.mkdir(exist_ok=True)

templates = Jinja2Templates(directory=str(BASE_DIR))

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Database setup
def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT (datetime('now','localtime')),
            tags TEXT
        )
    """)

    # Check existing columns
    c.execute("PRAGMA table_info(entries)")
    columns = [col[1] for col in c.fetchall()]

    # Add mood column if it doesn't exist (legacy - kept for backwards compatibility)
    if 'mood' not in columns:
        c.execute("ALTER TABLE entries ADD COLUMN mood TEXT")

    # Add actions column if it doesn't exist
    if 'actions' not in columns:
        c.execute("ALTER TABLE entries ADD COLUMN actions TEXT DEFAULT '[]'")

    # Stage 2: Add new rich extraction columns
    if 'emotion' not in columns:
        c.execute("ALTER TABLE entries ADD COLUMN emotion TEXT")
        # Migrate existing mood data to emotion column
        c.execute("UPDATE entries SET emotion = mood WHERE mood IS NOT NULL")
        print("Migrated existing mood data to emotion column")

    if 'themes' not in columns:
        c.execute("ALTER TABLE entries ADD COLUMN themes TEXT DEFAULT '[]'")

    if 'people' not in columns:
        c.execute("ALTER TABLE entries ADD COLUMN people TEXT DEFAULT '[]'")

    if 'urgency' not in columns:
        c.execute("ALTER TABLE entries ADD COLUMN urgency TEXT DEFAULT 'none'")

    # Stage 1: Context system - user_facts table
    c.execute("""
        CREATE TABLE IF NOT EXISTS user_facts (
            fact_id INTEGER PRIMARY KEY AUTOINCREMENT,
            fact_text TEXT NOT NULL,
            fact_category TEXT,
            created_at TIMESTAMP DEFAULT (datetime('now','localtime')),
            active BOOLEAN DEFAULT 1
        )
    """)

    # Stage 2: Pattern learning - entity_patterns table
    c.execute("""
        CREATE TABLE IF NOT EXISTS entity_patterns (
            entity TEXT PRIMARY KEY,
            entity_type TEXT DEFAULT 'unknown',
            mention_count INTEGER DEFAULT 1,
            theme_correlations TEXT DEFAULT '{}',
            emotion_correlations TEXT DEFAULT '{}',
            urgency_correlations TEXT DEFAULT '{}',
            time_patterns TEXT DEFAULT '{}',
            confidence_score FLOAT DEFAULT 0.0,
            first_seen TIMESTAMP DEFAULT (datetime('now','localtime')),
            last_seen TIMESTAMP DEFAULT (datetime('now','localtime'))
        )
    """)

    # Stage 2: Pattern learning - temporal_patterns table
    c.execute("""
        CREATE TABLE IF NOT EXISTS temporal_patterns (
            pattern_id INTEGER PRIMARY KEY AUTOINCREMENT,
            time_block TEXT NOT NULL,
            weekday TEXT NOT NULL,
            common_themes TEXT DEFAULT '[]',
            common_emotions TEXT DEFAULT '[]',
            sample_count INTEGER DEFAULT 0,
            confidence FLOAT DEFAULT 0.0,
            UNIQUE(time_block, weekday)
        )
    """)

    conn.commit()
    conn.close()

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def categorize_fact(fact_text: str) -> str:
    """
    Auto-categorize a fact based on keywords.

    Stage 5: Voice-ready design - accepts natural language statements:
    - "I work at Deutsche Bank" ✅
    - "Work at Deutsche Bank" ✅ (normalize to full sentence)
    - "Deutsche Bank is my employer" ✅ (extract relationship)

    Future voice integration points:
    - Intent classification: thought vs context update vs command vs query
    - Natural language normalization
    - Relationship extraction
    """
    text_lower = fact_text.lower()

    # Work keywords
    if any(kw in text_lower for kw in ['work at', 'job', 'office', 'company', 'employed', 'career']):
        return 'work'
    # Location keywords
    if any(kw in text_lower for kw in ['live in', 'from', 'based in', 'located in', 'city', 'country']):
        return 'location'
    # Personal keywords
    if any(kw in text_lower for kw in ['married', 'kids', 'family', 'spouse', 'children', 'partner']):
        return 'personal'
    # People keywords (names + relationship words)
    if any(kw in text_lower for kw in ['manager', 'colleague', 'friend', 'boss', 'coworker', 'is my', 'is a']):
        return 'people'

    return 'other'

def get_user_context(conn=None) -> str:
    """Get all active user facts formatted as context string. Cached per request."""
    close_conn = False
    if conn is None:
        conn = get_db()
        close_conn = True

    try:
        c = conn.cursor()
        facts = c.execute(
            "SELECT fact_text, fact_category FROM user_facts WHERE active = 1 ORDER BY created_at"
        ).fetchall()

        if not facts:
            return ""

        # Group by category
        categorized = {'work': [], 'personal': [], 'people': [], 'location': [], 'other': []}
        for fact in facts:
            text = fact['fact_text'][:200]  # Truncate long facts
            category = fact['fact_category'] or 'other'
            categorized[category].append(text)

        # Build context string
        context_parts = []
        for category, items in categorized.items():
            if items:
                context_parts.extend(items)

        # Limit to 500 words total
        context = " | ".join(context_parts)
        words = context.split()
        if len(words) > 500:
            context = " ".join(words[:500]) + "..."

        return context
    finally:
        if close_conn:
            conn.close()

def calculate_time_decay(last_seen: str, current_time: datetime = None) -> float:
    """
    Stage 5: Calculate time-based decay weight for patterns.
    Recent patterns have higher confidence than old ones.
    """
    if current_time is None:
        current_time = datetime.now()

    try:
        last_seen_dt = datetime.fromisoformat(last_seen)
        days_ago = (current_time - last_seen_dt).total_seconds() / (24 * 3600)

        if days_ago <= 7:
            return 1.0   # 100% weight (last 7 days)
        elif days_ago <= 30:
            return 0.8   # 80% weight (8-30 days)
        elif days_ago <= 90:
            return 0.6   # 60% weight (31-90 days)
        else:
            return 0.4   # 40% weight (90+ days)
    except:
        return 0.5  # Default weight if parsing fails

def get_relevant_patterns(entry_text: str = "", current_time: datetime = None) -> str:
    """
    Stage 3/5: Get patterns relevant to current entry text and time.
    Stage 5: Apply time-based decay weighting to pattern confidence.
    Returns formatted string of relevant patterns, max 200 words.
    """
    if current_time is None:
        current_time = datetime.now()

    try:
        conn = get_db()
        c = conn.cursor()

        pattern_parts = []

        # 1. Find mentioned entities in text
        words = entry_text.split()
        capitalized = [w.strip('.,!?;:') for w in words if w and w[0].isupper() and len(w) > 1]

        if capitalized:
            # Get entity patterns for mentioned entities with confidence > 0.5 (before decay)
            placeholders = ','.join(['?'] * len(capitalized))
            entities = c.execute(f"""
                SELECT entity, mention_count, theme_correlations, emotion_correlations, confidence_score, last_seen
                FROM entity_patterns
                WHERE entity IN ({placeholders}) AND mention_count >= 5
                ORDER BY mention_count DESC
                LIMIT 5
            """, capitalized).fetchall()

            # Stage 5: Apply time decay and filter by final confidence
            filtered_entities = []
            for ent in entities:
                decay_weight = calculate_time_decay(ent['last_seen'], current_time)
                final_confidence = ent['confidence_score'] * decay_weight
                if final_confidence > 0.5:  # Only include if final confidence > 50%
                    filtered_entities.append(ent)

            entities = filtered_entities[:3]  # Top 3 after filtering

            for ent in entities:
                themes = json.loads(ent['theme_correlations'])
                emotions = json.loads(ent['emotion_correlations'])

                # Calculate percentages
                total = ent['mention_count']
                top_theme = max(themes.items(), key=lambda x: x[1]) if themes else None
                top_emotion = max(emotions.items(), key=lambda x: x[1]) if emotions else None

                entity_info = f"{ent['entity']}: {ent['mention_count']} mentions"
                if top_theme:
                    pct = int((top_theme[1] / total) * 100)
                    entity_info += f" [{top_theme[0]} {pct}%]"
                if top_emotion:
                    pct = int((top_emotion[1] / total) * 100)
                    entity_info += f" [{top_emotion[0]} {pct}%]"

                pattern_parts.append(entity_info)

        # 2. Stage 4: Enhanced temporal context selection with fallbacks
        hour = current_time.hour
        weekday = current_time.strftime('%A').lower()
        day_type = 'weekend' if weekday in ['saturday', 'sunday'] else 'weekday'

        if 5 <= hour < 12:
            time_block = 'morning'
        elif 12 <= hour < 17:
            time_block = 'afternoon'
        elif 17 <= hour < 22:
            time_block = 'evening'
        else:
            time_block = 'night'

        # Try specific match first (day + time), then time-only, then day-type
        temporal = c.execute("""
            SELECT time_block, weekday, common_themes, common_emotions, sample_count, confidence
            FROM temporal_patterns
            WHERE time_block = ? AND weekday = ? AND sample_count >= 5 AND confidence > 0.4
            ORDER BY sample_count DESC LIMIT 1
        """, (time_block, weekday)).fetchone()

        if not temporal:
            # Fallback to time-only pattern
            temporal = c.execute("""
                SELECT time_block, weekday, common_themes, common_emotions, sample_count, confidence
                FROM temporal_patterns
                WHERE time_block = ? AND weekday = 'all' AND sample_count >= 10 AND confidence > 0.5
            """, (time_block,)).fetchone()

        if not temporal:
            # Fallback to day-type pattern
            temporal = c.execute("""
                SELECT time_block, weekday, common_themes, common_emotions, sample_count, confidence
                FROM temporal_patterns
                WHERE time_block = 'all' AND weekday = ? AND sample_count >= 10 AND confidence > 0.5
            """, (day_type,)).fetchone()

        if temporal:
            themes = json.loads(temporal['common_themes'])
            emotions = json.loads(temporal['common_emotions'])

            # Stage 4: More descriptive temporal context
            if temporal['weekday'] not in ['all', 'weekday', 'weekend']:
                time_info = f"{weekday.title()} {time_block}s: usually "
            elif temporal['weekday'] in ['weekday', 'weekend']:
                time_info = f"{temporal['weekday'].title()}s: typically "
            else:
                time_info = f"{time_block.title()}s: often "

            theme_str = ', '.join(themes[:2]) if themes else ''
            emotion_str = ', '.join(emotions[:2]) if emotions else ''

            if theme_str and emotion_str:
                time_info += f"{theme_str} ({emotion_str})"
            elif theme_str:
                time_info += theme_str
            elif emotion_str:
                time_info += emotion_str

            time_info += f" [{temporal['sample_count']} times]"
            pattern_parts.append(time_info)

        conn.close()

        # Format and limit to 200 words
        if pattern_parts:
            result = " | ".join(pattern_parts)
            words = result.split()
            if len(words) > 200:
                result = " ".join(words[:200]) + "..."
            return result

        return ""
    except Exception as e:
        print(f"Pattern retrieval failed: {e}")
        return ""

def build_full_context(entry_text: str = "", current_time: datetime = None) -> str:
    """
    Stage 3: Build full context combining user facts (Stage 1) and relevant patterns (Stage 3).
    Total kept under 500 words.
    """
    parts = []

    # Get user facts
    facts = get_user_context()
    if facts:
        parts.append(f"User facts: {facts}")

    # Get relevant patterns
    patterns = get_relevant_patterns(entry_text, current_time)
    if patterns:
        parts.append(f"Relevant patterns: {patterns}")

    if not parts:
        return ""

    # Combine and limit to 500 words
    full_context = " | ".join(parts)
    words = full_context.split()
    if len(words) > 500:
        full_context = " ".join(words[:500]) + "..."

    return full_context

def calculate_confidence(mention_count: int) -> float:
    """Calculate confidence score based on mention count."""
    if mention_count < 5:
        return 0.3  # Low confidence
    elif mention_count < 10:
        return 0.6  # Medium confidence
    elif mention_count < 20:
        return 0.8  # High confidence
    else:
        return 0.9  # Very high confidence

def update_entity_patterns(people: List[str], themes: List[str], emotion: str, urgency: str, created_at: str):
    """Update entity patterns table with new observation. Runs asynchronously."""
    if not people:
        return

    try:
        conn = get_db()
        c = conn.cursor()

        # Parse time for temporal patterns
        dt = datetime.fromisoformat(created_at)
        hour = dt.hour
        weekday = dt.strftime('%A').lower()

        for person in people:
            # Check if entity exists
            existing = c.execute(
                "SELECT * FROM entity_patterns WHERE entity = ?", (person,)
            ).fetchone()

            if existing:
                # Update existing entity
                mention_count = existing['mention_count'] + 1

                # Update correlations
                theme_corr = json.loads(existing['theme_correlations'])
                for theme in themes:
                    theme_corr[theme] = theme_corr.get(theme, 0) + 1

                emotion_corr = json.loads(existing['emotion_correlations'])
                emotion_corr[emotion] = emotion_corr.get(emotion, 0) + 1

                urgency_corr = json.loads(existing['urgency_correlations'])
                urgency_corr[urgency] = urgency_corr.get(urgency, 0) + 1

                time_pat = json.loads(existing['time_patterns'])
                time_pat[str(hour)] = time_pat.get(str(hour), 0) + 1
                time_pat[weekday] = time_pat.get(weekday, 0) + 1

                # Calculate new confidence
                confidence = calculate_confidence(mention_count)

                c.execute("""
                    UPDATE entity_patterns
                    SET mention_count = ?, theme_correlations = ?, emotion_correlations = ?,
                        urgency_correlations = ?, time_patterns = ?, confidence_score = ?,
                        last_seen = (datetime('now','localtime'))
                    WHERE entity = ?
                """, (mention_count, json.dumps(theme_corr), json.dumps(emotion_corr),
                      json.dumps(urgency_corr), json.dumps(time_pat), confidence, person))
            else:
                # Create new entity
                theme_corr = {theme: 1 for theme in themes}
                emotion_corr = {emotion: 1}
                urgency_corr = {urgency: 1}
                time_pat = {str(hour): 1, weekday: 1}
                confidence = calculate_confidence(1)

                c.execute("""
                    INSERT INTO entity_patterns
                    (entity, mention_count, theme_correlations, emotion_correlations,
                     urgency_correlations, time_patterns, confidence_score)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (person, 1, json.dumps(theme_corr), json.dumps(emotion_corr),
                      json.dumps(urgency_corr), json.dumps(time_pat), confidence))

        conn.commit()
        conn.close()
        print(f"Pattern update: tracked {len(people)} entities")
    except Exception as e:
        print(f"Pattern update failed: {e}")

def update_temporal_patterns(themes: List[str], emotion: str, created_at: str):
    """Stage 4: Enhanced temporal pattern tracking with day-type and confidence scoring."""
    try:
        conn = get_db()
        c = conn.cursor()

        # Classify time block
        dt = datetime.fromisoformat(created_at)
        hour = dt.hour
        weekday = dt.strftime('%A').lower()
        day_type = 'weekend' if weekday in ['saturday', 'sunday'] else 'weekday'

        if 5 <= hour < 12:
            time_block = 'morning'
        elif 12 <= hour < 17:
            time_block = 'afternoon'
        elif 17 <= hour < 22:
            time_block = 'evening'
        else:
            time_block = 'night'

        # Track 3 pattern types: specific (day+time), time-only, day-type
        patterns_to_update = [
            (time_block, weekday),  # Specific: "monday morning"
            (time_block, 'all'),    # Time-only: "morning"
            ('all', day_type)       # Day-type: "weekday" or "weekend"
        ]

        for block, day in patterns_to_update:
            existing = c.execute(
                "SELECT * FROM temporal_patterns WHERE time_block = ? AND weekday = ?",
                (block, day)
            ).fetchone()

            if existing:
                sample_count = existing['sample_count'] + 1
                common_themes = json.loads(existing['common_themes'])
                common_emotions = json.loads(existing['common_emotions'])

                # Add new observations (keep unique)
                for theme in themes:
                    if theme not in common_themes:
                        common_themes.append(theme)
                if emotion not in common_emotions:
                    common_emotions.append(emotion)

                # Stage 4: Enhanced confidence scoring
                if sample_count < 10:
                    confidence = 0.4
                elif sample_count < 20:
                    confidence = 0.6
                elif sample_count < 50:
                    confidence = 0.8
                else:
                    confidence = 0.9

                c.execute("""
                    UPDATE temporal_patterns
                    SET common_themes = ?, common_emotions = ?, sample_count = ?, confidence = ?
                    WHERE time_block = ? AND weekday = ?
                """, (json.dumps(common_themes), json.dumps(common_emotions),
                      sample_count, confidence, block, day))
            else:
                c.execute("""
                    INSERT INTO temporal_patterns
                    (time_block, weekday, common_themes, common_emotions, sample_count, confidence)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (block, day, json.dumps(themes), json.dumps([emotion]), 1, 0.05))

        conn.commit()
        conn.close()
        print(f"Temporal patterns updated: {time_block}/{weekday}, {time_block}, {day_type}")
    except Exception as e:
        print(f"Temporal pattern update failed: {e}")

# Initialize database on startup
init_db()

# Helper functions
def extract_tags(content: str) -> List[str]:
    """Extract #tags from content"""
    return re.findall(r'#(\w+)', content)

def format_content_with_tags(content: str) -> str:
    """Convert #tags to clickable links"""
    return re.sub(r'#(\w+)', r'<a href="#" class="tag" onclick="searchTag(\'#\1\')">#\1</a>', content)

def get_relative_time(created_at: str) -> str:
    """Convert timestamp to relative time with clock emoji"""
    # SQLite stores local time (device time)
    dt = datetime.fromisoformat(created_at)
    # Get current local time
    now = datetime.now()
    delta = now - dt

    seconds = int(delta.total_seconds())
    minutes = seconds // 60
    hours = minutes // 60
    days = hours // 24

    if seconds < 60:
        return "◷ just now"
    elif minutes == 1:
        return "◷ 1m ago"
    elif minutes < 60:
        return f"◷ {minutes}m ago"
    elif hours == 1:
        return "◷ 1h ago"
    elif hours < 24:
        return f"◷ {hours}h ago"
    elif days == 1:
        return "◷ yesterday"
    elif days < 30:
        return f"◷ {days} days ago"
    else:
        return f"◷ {dt.strftime('%b %d')}"

def save_entry_to_markdown(entry_id: int, content: str, created_at: str):
    """Append entry to daily markdown file"""
    dt = datetime.fromisoformat(created_at)
    date_str = dt.strftime("%Y-%m-%d")
    filename = ENTRIES_DIR / f"{date_str}.md"

    # Create header if file doesn't exist
    if not filename.exists():
        filename.write_text(f"# Entries for {date_str}\n\n")

    # Append the entry with timestamp
    time_str = dt.strftime("%H:%M:%S")
    with open(filename, 'a') as f:
        f.write(f"## {time_str}\n\n{content}\n\n---\n\n")

def detect_emotion_fallback(text: str) -> str:
    """
    Fallback emotion detection using keyword mapping.
    Returns one emotion word from the emotion vocabulary.
    """
    text_lower = text.lower()

    # Emotion keyword mapping
    emotion_map = {
        'frustrated': ['frustrated', 'frustrating', 'annoyed', 'annoying'],
        'anxious': ['anxious', 'worried', 'nervous', 'stress', 'stressed'],
        'excited': ['excited', 'exciting', 'thrilled', 'pumped'],
        'content': ['content', 'satisfied', 'happy', 'good'],
        'melancholic': ['melancholic', 'sad', 'down', 'blue'],
        'hopeful': ['hopeful', 'optimistic', 'positive'],
        'angry': ['angry', 'mad', 'furious', 'pissed', 'hate', 'hating', 'hatred', 'horrible'],
        'contemplative': ['contemplative', 'thinking', 'wondering', 'pondering'],
        'tired': ['tired', 'exhausted', 'drained', 'worn out'],
        'energetic': ['energetic', 'energized', 'pumped up', 'motivated'],
        'confused': ['confused', 'puzzled', 'unclear', 'lost'],
        'grateful': ['grateful', 'thankful', 'blessed', 'appreciative'],
        'overwhelmed': ['overwhelmed', 'swamped', 'drowning', 'too much'],
        'calm': ['calm', 'peaceful', 'relaxed', 'serene'],
        'nostalgic': ['nostalgic', 'remember', 'miss', 'old days'],
        'curious': ['curious', 'interested', 'intrigued'],
        'determined': ['determined', 'focused', 'driven', 'committed'],
        'scattered': ['scattered', 'unfocused', 'distracted', 'all over']
    }

    # Check for emotion keywords
    for emotion, keywords in emotion_map.items():
        for keyword in keywords:
            if keyword in text_lower:
                return emotion

    return 'neutral'

def extract_themes_fallback(text: str) -> List[str]:
    """Fallback theme detection using keyword mapping."""
    text_lower = text.lower()
    themes = []

    theme_keywords = {
        'work': ['meeting', 'project', 'deadline', 'boss', 'colleague', 'office', 'work', 'client'],
        'health': ['exercise', 'sick', 'doctor', 'workout', 'gym', 'tired', 'pain', 'medical'],
        'relationships': ['friend', 'family', 'wife', 'husband', 'partner', 'mom', 'dad', 'dinner'],
        'tech': ['coding', 'bug', 'server', 'deploy', 'git', 'database', 'api', 'code'],
        'finance': ['money', 'budget', 'expense', 'bill', 'payment', 'salary', 'invoice'],
        'learning': ['study', 'learn', 'course', 'tutorial', 'book', 'reading', 'research'],
        'creative': ['write', 'design', 'art', 'music', 'paint', 'create', 'idea'],
        'leisure': ['movie', 'game', 'relax', 'fun', 'vacation', 'hobby', 'weekend']
    }

    for theme, keywords in theme_keywords.items():
        for keyword in keywords:
            if keyword in text_lower:
                if theme not in themes:
                    themes.append(theme)
                break
        if len(themes) >= 3:
            break

    return themes[:3]

async def extract_themes(text: str, user_context: str = "") -> List[str]:
    """Extract 1-3 themes from taxonomy using LLM with fallback."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            context_prefix = f"User context: {user_context}\n\n" if user_context else ""

            prompt = f"""{context_prefix}Identify 1-3 themes EXPLICITLY MENTIONED OR STRONGLY IMPLIED in the text from this list: work, personal, health, finance, relationships, learning, daily, creative, tech, leisure.

IMPORTANT: Only extract themes that are clearly present in the text itself. Do not infer themes from user context unless the text explicitly mentions them.

Text: "{text}"

Return ONLY a JSON array like: ["work", "health"]. If no clear themes in the text, return []"""

            response = await client.post(
                "http://localhost:11434/api/generate",
                json={"model": "llama3.2:3b", "prompt": prompt, "stream": False}
            )
            if response.status_code == 200:
                result = response.json()
                raw_response = result.get("response", "[]")

                # Extract JSON array
                import re
                json_match = re.search(r'\[.*?\]', raw_response)
                if json_match:
                    themes = json.loads(json_match.group())
                    return themes[:3] if isinstance(themes, list) else []
    except Exception as e:
        print(f"Theme extraction failed: {e}")

    return extract_themes_fallback(text)

def extract_people_fallback(text: str, user_context: str = "") -> List[str]:
    """
    Fallback people extraction using regex + context matching + fuzzy matching.

    Features:
    - Case-insensitive exact matching against context
    - Fuzzy matching for typos (80%+ similarity)
    - Efficient caching for growing context
    """
    from difflib import SequenceMatcher

    words = text.split()
    people = []

    # Common words to filter out
    exclude = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
               'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
               'September', 'October', 'November', 'December', 'I', 'The', 'A', 'An'}

    # Extract known people from context (look for common patterns)
    context_people = []
    if user_context:
        # Look for patterns like "my daughter's name is Nandini", "my son's name is Ved", etc.
        name_patterns = [
            r"(?:daughter|son|wife|husband|partner|boss|manager|colleague|friend|coworker|colleague|teammate)(?:'s)?\s+(?:name\s+)?is\s+(\w+)",
            r"(\w+)\s+is\s+my\s+(?:daughter|son|wife|husband|partner|boss|manager|colleague|friend|coworker|teammate)",
        ]
        for pattern in name_patterns:
            matches = re.findall(pattern, user_context.lower())
            context_people.extend([m.capitalize() for m in matches if len(m) > 1])

        # Remove duplicates while preserving order
        seen = set()
        unique_context_people = []
        for name in context_people:
            if name.lower() not in seen:
                seen.add(name.lower())
                unique_context_people.append(name)
        context_people = unique_context_people

    # Helper function for fuzzy matching
    def fuzzy_match_person(typo: str, context_people: List[str], threshold: float = 0.8) -> Optional[str]:
        """
        Find best fuzzy match for a potential typo against known people.
        Returns correct name if similarity >= threshold, else None.

        Optimized for context growth:
        - Early exit on exact match
        - Only checks names of similar length (±3 chars)
        - Caches similarity calculations implicitly via SequenceMatcher
        """
        typo_lower = typo.lower()
        typo_len = len(typo)

        # Exact match check (fast path)
        for person in context_people:
            if person.lower() == typo_lower:
                return person

        # Fuzzy match (only for similar-length names)
        best_match = None
        best_ratio = threshold

        for person in context_people:
            # Skip if length difference > 3 (unlikely typo)
            if abs(len(person) - typo_len) > 3:
                continue

            # Calculate similarity using quick_ratio first (faster approximation)
            matcher = SequenceMatcher(None, typo_lower, person.lower())
            quick_ratio = matcher.quick_ratio()

            # Only do full calculation if quick check passes
            if quick_ratio >= threshold:
                ratio = matcher.ratio()
                if ratio >= best_ratio:
                    best_ratio = ratio
                    best_match = person

        return best_match

    # Check each word in text against context people (case-insensitive + fuzzy)
    text_lower = text.lower()
    for context_person in context_people:
        if context_person.lower() in text_lower:
            if context_person not in people:
                people.append(context_person)

    # Also check ALL words (not just capitalized) for fuzzy matches against context
    # This catches lowercase typos like "kerer" → "Kerem"
    for i, word in enumerate(words):
        # Clean punctuation
        clean_word = word.strip('.,!?;:').strip()

        if not clean_word or len(clean_word) <= 1:
            continue

        # Skip if already found
        if clean_word in people or clean_word.lower() in [p.lower() for p in people]:
            continue

        # Try fuzzy match against context people (works for any case)
        fuzzy_match = fuzzy_match_person(clean_word, context_people)
        if fuzzy_match:
            # Found a typo! Use correct spelling from context
            if fuzzy_match not in people:
                people.append(fuzzy_match)
                print(f"Fuzzy match: '{clean_word}' → '{fuzzy_match}'")
        # Only add as new person if capitalized and not already matched
        elif clean_word[0].isupper():
            if i == 0 or (i > 0 and words[i-1][-1] not in '.!?'):
                if clean_word not in exclude:
                    # No match in context, treat as new person
                    if clean_word not in people:
                        people.append(clean_word)

    return people[:5]

async def extract_people(text: str, user_context: str = "") -> List[str]:
    """Extract mentioned people's names using LLM with fallback."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            context_prefix = f"User context: {user_context}\n\n" if user_context else ""

            prompt = f"""{context_prefix}Extract people's names MENTIONED in this text. Consider known names from context even if lowercase.

IMPORTANT:
- Extract names that appear in the text, even if they're lowercase
- Use the user context to recognize known people (e.g., if context says "my daughter is Nandini", then "nandini" in text refers to that person)
- Return the properly capitalized version from context when available

Text: "{text}"

Return ONLY a JSON array of names like: ["Sarah", "John", "Nandini"]. If no names in text, return []"""

            response = await client.post(
                "http://localhost:11434/api/generate",
                json={"model": "llama3.2:3b", "prompt": prompt, "stream": False}
            )
            if response.status_code == 200:
                result = response.json()
                raw_response = result.get("response", "[]")

                # Extract JSON array
                import re
                json_match = re.search(r'\[.*?\]', raw_response)
                if json_match:
                    people = json.loads(json_match.group())
                    return people[:5] if isinstance(people, list) else []
    except Exception as e:
        print(f"People extraction failed: {e}")

    # Pass user_context to fallback for context-aware extraction
    return extract_people_fallback(text, user_context)

def extract_urgency_fallback(text: str) -> str:
    """Fallback urgency detection using keyword mapping."""
    text_lower = text.lower()

    high_keywords = ['asap', 'urgent', 'immediately', 'now', 'critical', 'emergency']
    medium_keywords = ['today', 'tomorrow', 'soon', 'deadline', 'this week']
    low_keywords = ['someday', 'eventually', 'maybe', 'later', 'sometime']

    for keyword in high_keywords:
        if keyword in text_lower:
            return 'high'

    for keyword in medium_keywords:
        if keyword in text_lower:
            return 'medium'

    for keyword in low_keywords:
        if keyword in text_lower:
            return 'low'

    return 'none'

async def extract_urgency(text: str, user_context: str = "") -> str:
    """Extract urgency level using LLM with fallback."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            context_prefix = f"User context: {user_context}\n\n" if user_context else ""

            prompt = f"""{context_prefix}Rate urgency BASED ONLY ON THE TEXT ITSELF as one word: none, low, medium, or high.

IMPORTANT: Only rate urgency based on explicit signals in the text (words like "urgent", "asap", "today", "deadline"). Do not infer urgency from user context.

Text: "{text}"

Return ONLY one word from: none, low, medium, high"""

            response = await client.post(
                "http://localhost:11434/api/generate",
                json={"model": "llama3.2:3b", "prompt": prompt, "stream": False}
            )
            if response.status_code == 200:
                result = response.json()
                raw_response = result.get("response", "none").strip().lower()

                # Extract urgency level
                if 'high' in raw_response:
                    return 'high'
                elif 'medium' in raw_response:
                    return 'medium'
                elif 'low' in raw_response:
                    return 'low'
                elif 'none' in raw_response:
                    return 'none'
    except Exception as e:
        print(f"Urgency extraction failed: {e}")

    return extract_urgency_fallback(text)

async def get_llm_analysis(text: str, user_context: str = "") -> dict:
    """
    Call Ollama API to get tags, mood (as specific emotion), and action items.

    Args:
        text: The entry text to analyze
        user_context: User facts for personalization

    Returns:
        {"actions": ["action1"], "tags": ["tag1", "tag2"], "mood": "anxious"}
        On failure: {"actions": [], "tags": [], "mood": "neutral"}
    """
    # Fallback: extract hashtags directly from text
    hashtags = [word[1:] for word in text.split() if word.startswith('#') and len(word) > 1]

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            # Build prompt with context
            context_prefix = f"User context: {user_context}\n\n" if user_context else ""

            prompt = f"""{context_prefix}Extract actions, tags, and emotion BASED ONLY ON THE TEXT ITSELF. Return ONE emotion word only.

IMPORTANT:
- Only extract #hashtags for tags (words starting with #). Do NOT extract regular words as tags.
- Only detect emotion from explicit words/phrases in the text. Do not infer emotion from user context.
- If text has no clear emotional indicators, return "neutral"

Emotion vocabulary: frustrated, anxious, excited, content, melancholic, hopeful, angry, contemplative, tired, energetic, confused, grateful, overwhelmed, calm, nostalgic, curious, determined, focused, scattered, neutral

Examples:
Text: "feeling anxious about tomorrow's presentation"
Output: {{"actions": [], "tags": [], "mood": "anxious"}}

Text: "I love this!"
Output: {{"actions": [], "tags": [], "mood": "excited"}}

Text: "I hate this!"
Output: {{"actions": [], "tags": [], "mood": "angry"}}

Text: "totally scattered today #work"
Output: {{"actions": [], "tags": ["work"], "mood": "scattered"}}

Text: "friday morning"
Output: {{"actions": [], "tags": [], "mood": "neutral"}}

Now extract from:
Text: "{text}"
Output:"""
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={"model": "llama3.2:3b", "prompt": prompt, "stream": False}
            )
            if response.status_code == 200:
                result = response.json()
                raw_response = result.get("response", "{}")
                print(f"DEBUG - Ollama raw response: {raw_response[:500]}")

                analysis = {}
                try:
                    # Try multiple extraction patterns
                    # 1. Try to extract from markdown code blocks
                    import re
                    json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', raw_response, re.DOTALL)
                    if json_match:
                        analysis = json.loads(json_match.group(1))
                    else:
                        # 2. Try to extract raw JSON object
                        json_match = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', raw_response)
                        if json_match:
                            analysis = json.loads(json_match.group())
                        else:
                            # 3. Try direct parse as last resort
                            analysis = json.loads(raw_response)

                    print(f"DEBUG - Extracted JSON: {analysis}")
                except (json.JSONDecodeError, AttributeError) as e:
                    print(f"DEBUG - JSON parse failed: {e}")
                    analysis = {}

                # Merge LLM tags with hashtag extraction, validate tags are real hashtags
                llm_tags = analysis.get("tags", [])
                # Filter LLM tags to only include words that exist as hashtags in original text
                valid_llm_tags = [tag for tag in llm_tags if tag in hashtags or f"#{tag}" in text]
                if valid_llm_tags:
                    final_tags = valid_llm_tags[:3]
                else:
                    final_tags = hashtags[:3]

                # Get actions from LLM
                actions = analysis.get("actions", [])

                # Manual action extraction fallback if LLM didn't find any
                if not actions or len(actions) == 0:
                    import re
                    # Split text into sentences/phrases for better processing
                    text_lower = text.lower()

                    # Pattern 1: "need to" variations
                    if 'need to ' in text_lower or 'needs to ' in text_lower:
                        match = re.search(r'(?:need|needs)\s+to\s+(.+?)(?:\.|$)', text, re.IGNORECASE)
                        if match:
                            action = match.group(1).strip().rstrip('#').strip()
                            if action and len(action) > 3:
                                actions.append(action)

                    # Pattern 2: "must" variations
                    if 'must ' in text_lower:
                        match = re.search(r'must\s+(.+?)(?:\.|$)', text, re.IGNORECASE)
                        if match:
                            action = match.group(1).strip().rstrip('#').strip()
                            if action and len(action) > 3 and action not in actions:
                                actions.append(action)

                    # Pattern 3: "have to" / "has to"
                    if 'have to ' in text_lower or 'has to ' in text_lower:
                        match = re.search(r'(?:have|has)\s+to\s+(.+?)(?:\.|$)', text, re.IGNORECASE)
                        if match:
                            action = match.group(1).strip().rstrip('#').strip()
                            if action and len(action) > 3 and action not in actions:
                                actions.append(action)

                    # Pattern 4: "todo:" variations
                    if 'todo:' in text_lower or 'todo ' in text_lower:
                        # First try with colon
                        match = re.search(r'todo:\s*(.+?)(?:\.|$)', text, re.IGNORECASE)
                        if match:
                            # Handle multiple actions separated by "and" or commas
                            action_text = match.group(1).strip().rstrip('#').strip()
                            if ' and ' in action_text:
                                for part in action_text.split(' and '):
                                    part = part.strip()
                                    if part and len(part) > 3 and part not in actions:
                                        actions.append(part)
                            else:
                                if action_text and len(action_text) > 3 and action_text not in actions:
                                    actions.append(action_text)

                    # Pattern 5: "should" variations
                    if 'should ' in text_lower or 'ought to ' in text_lower:
                        match = re.search(r'(?:should|ought\s+to)\s+(.+?)(?:\.|$)', text, re.IGNORECASE)
                        if match:
                            action = match.group(1).strip().rstrip('#').strip()
                            if action and len(action) > 3 and action not in actions:
                                actions.append(action)

                    # Remove duplicates while preserving order
                    actions = list(dict.fromkeys(actions[:5]))  # Max 5 actions

                    if actions:
                        print(f"Fallback extracted actions: {actions}")

                # Get emotion, use fallback if invalid
                llm_mood = analysis.get("mood", "")
                valid_emotions = [
                    'frustrated', 'anxious', 'excited', 'content', 'melancholic',
                    'hopeful', 'angry', 'contemplative', 'tired', 'energetic',
                    'confused', 'grateful', 'overwhelmed', 'calm', 'nostalgic',
                    'curious', 'determined', 'focused', 'scattered', 'neutral'
                ]
                if llm_mood not in valid_emotions:
                    llm_mood = detect_emotion_fallback(text)

                return {
                    "actions": actions,
                    "tags": final_tags,
                    "mood": llm_mood
                }
    except Exception as e:
        print(f"LLM analysis failed: {e}")

    # Return fallback with emotion detection and hashtags extracted
    return {"actions": [], "tags": hashtags[:3], "mood": detect_emotion_fallback(text)}

def handle_context_command(command: str) -> str:
    """Handle /context commands and return HTML response."""
    conn = get_db()
    c = conn.cursor()

    try:
        if command == "/context":
            # Display all active facts
            facts = c.execute(
                "SELECT fact_id, fact_text, fact_category FROM user_facts WHERE active = 1 ORDER BY fact_category, created_at"
            ).fetchall()

            if not facts:
                return '<div class="entry"><div class="entry-content">No context facts yet. Use <code>/context [text]</code> to add facts.</div></div>'

            # Group by category
            categorized = {'work': [], 'personal': [], 'people': [], 'location': [], 'other': []}
            for fact in facts:
                category = fact['fact_category'] or 'other'
                categorized[category].append(fact)

            # Build HTML
            html = '<div class="entry"><div class="entry-content"><strong>Your Context Facts:</strong><br><br>'
            for category, items in categorized.items():
                if items:
                    html += f'<strong>{category.title()}:</strong><br>'
                    for fact in items:
                        html += f'[{fact["fact_id"]}] {fact["fact_text"]}<br>'
                    html += '<br>'
            html += '<em>Use /context remove [id] to delete a fact</em></div></div>'
            return html

        elif command == "/context clear":
            # Soft delete all facts
            c.execute("UPDATE user_facts SET active = 0 WHERE active = 1")
            conn.commit()
            return '<div class="entry new-entry"><div class="entry-content">All context facts cleared.</div></div>'

        elif command.startswith("/context remove "):
            # Remove specific fact
            try:
                fact_id = int(command.split()[-1])
                c.execute("UPDATE user_facts SET active = 0 WHERE fact_id = ?", (fact_id,))
                conn.commit()
                if c.rowcount > 0:
                    return f'<div class="entry new-entry"><div class="entry-content">Removed fact #{fact_id}.</div></div>'
                else:
                    return f'<div class="entry"><div class="entry-content">Fact #{fact_id} not found.</div></div>'
            except ValueError:
                return '<div class="entry"><div class="entry-content">Invalid fact ID. Use /context remove [id]</div></div>'

        elif command.startswith("/context "):
            # Add new fact
            fact_text = command[9:].strip()  # Remove "/context "
            if not fact_text or len(fact_text) > 200:
                return '<div class="entry"><div class="entry-content">Fact must be 1-200 characters.</div></div>'

            category = categorize_fact(fact_text)
            c.execute(
                "INSERT INTO user_facts (fact_text, fact_category) VALUES (?, ?)",
                (fact_text, category)
            )
            conn.commit()
            return f'<div class="entry new-entry"><div class="entry-content">Added to context ({category}): {fact_text}</div></div>'

    finally:
        conn.close()

    return ""

def generate_insights(conn) -> list:
    """
    Stage 5: Generate intelligent insights from patterns.
    Returns list of insight strings with 70%+ confidence.
    """
    c = conn.cursor()
    insights = []

    try:
        # Get all entries from last 30 days
        entries = c.execute("""
            SELECT content, created_at, themes, emotion, people
            FROM entries
            WHERE created_at >= datetime('now', '-30 days')
        """).fetchall()

        if len(entries) < 20:
            return []  # Need 20+ entries for insights

        # Parse timestamps for temporal analysis
        weekday_counts = {'weekday': 0, 'weekend': 0}
        day_emotion_map = {}
        person_emotion_map = {}

        for entry in entries:
            dt = datetime.fromisoformat(entry['created_at'])
            weekday = dt.strftime('%A').lower()
            is_weekend = weekday in ['saturday', 'sunday']

            # Count weekday vs weekend
            if is_weekend:
                weekday_counts['weekend'] += 1
            else:
                weekday_counts['weekday'] += 1

            # Track emotions by day
            if entry['emotion']:
                if weekday not in day_emotion_map:
                    day_emotion_map[weekday] = []
                day_emotion_map[weekday].append(entry['emotion'])

            # Track person-emotion correlations
            if entry['people'] and entry['emotion']:
                try:
                    people_list = json.loads(entry['people']) if isinstance(entry['people'], str) else entry['people']
                    for person in people_list:
                        if person not in person_emotion_map:
                            person_emotion_map[person] = []
                        person_emotion_map[person].append(entry['emotion'])
                except: pass

        # Insight 1: Weekday vs Weekend writing frequency
        if weekday_counts['weekday'] > 0 and weekday_counts['weekend'] > 0:
            ratio = weekday_counts['weekday'] / weekday_counts['weekend']
            if ratio >= 2.0:
                insights.append(f"You write {ratio:.1f}x more on weekdays ({weekday_counts['weekday']} entries vs {weekday_counts['weekend']} weekend)")

        # Insight 2: Day-specific emotional patterns
        for day, emotions in day_emotion_map.items():
            if len(emotions) >= 10:  # Need 10+ samples
                emotion_counts = Counter(emotions)
                top_emotion, top_count = emotion_counts.most_common(1)[0]
                pct = (top_count / len(emotions)) * 100
                if pct >= 70:  # 70%+ confidence
                    insights.append(f"{day.title()}s are usually {top_emotion} ({top_count}/{len(emotions)} entries)")

        # Insight 3: Person-emotion correlations
        for person, emotions in person_emotion_map.items():
            if len(emotions) >= 10:  # Need 10+ samples
                emotion_counts = Counter(emotions)
                top_emotion, top_count = emotion_counts.most_common(1)[0]
                pct = (top_count / len(emotions)) * 100
                if pct >= 70:  # 70%+ confidence
                    insights.append(f"When you mention {person}, you're usually {top_emotion} ({int(pct)}%)")

        # Return top 5 most meaningful insights
        return insights[:5]
    except Exception as e:
        print(f"Insight generation failed: {e}")
        return []

def handle_patterns_command() -> str:
    """
    Handle /patterns command - Display learned insights in human-readable format.
    Stage 5: Now includes intelligent insights section.
    Filters test data, uses quality thresholds, and shows meaningful insights.
    """
    conn = get_db()
    c = conn.cursor()

    try:
        # Get entity patterns with quality thresholds
        # 10+ mentions, NOT test data, only high confidence (>0.7)
        entities = c.execute("""
            SELECT entity, mention_count, theme_correlations, emotion_correlations
            FROM entity_patterns
            WHERE mention_count >= 10
              AND confidence_score > 0.7
              AND entity NOT LIKE '%test%'
              AND entity NOT LIKE '%Test%'
            ORDER BY mention_count DESC
            LIMIT 5
        """).fetchall()

        # Get temporal patterns with quality thresholds
        # 20+ samples, only high confidence (>0.7)
        temporal = c.execute("""
            SELECT time_block, weekday, common_themes, common_emotions, sample_count, confidence
            FROM temporal_patterns
            WHERE sample_count >= 20
              AND confidence > 0.7
            ORDER BY sample_count DESC
            LIMIT 5
        """).fetchall()

        # Empty state - no strong patterns yet
        if not entities and not temporal:
            return '''<div class="entry"><div class="entry-content">
<strong>=== What Lean Has Learned About You ===</strong><br><br>
<strong>Lean is still learning your patterns...</strong><br><br>
Write 20+ entries to see insights about:<br>
• People you mention frequently<br>
• Your daily writing rhythms<br>
• Common themes and moods<br><br>
The more you write, the smarter Lean gets!<br><br>
<em>Tip: Use /context to teach Lean about your world</em>
</div></div>'''

        # Build human-readable HTML display
        html = '<div class="entry"><div class="entry-content"><strong>=== What Lean Has Learned About You ===</strong><br><br>'

        # Display people/entities
        if entities:
            html += '<strong>PEOPLE YOU MENTION OFTEN</strong><br>'
            for ent in entities:
                themes = json.loads(ent['theme_correlations'])
                emotions = json.loads(ent['emotion_correlations'])
                total = ent['mention_count']

                # Build human-readable description
                entity_line = f"• <strong>{ent['entity']}</strong> ({total} times)"

                # Describe primary theme context
                if themes:
                    top_theme = max(themes.items(), key=lambda x: x[1])
                    theme_count = top_theme[1]
                    theme_ratio = f"{theme_count}/{total}"

                    if theme_count / total >= 0.8:
                        entity_line += f"<br>  Usually {top_theme[0]}-related ({theme_ratio} entries)"
                    else:
                        # Show mix of top 2 themes
                        sorted_themes = sorted(themes.items(), key=lambda x: x[1], reverse=True)[:2]
                        theme_names = " and ".join([t[0] for t in sorted_themes])
                        entity_line += f"<br>  Mix of {theme_names} entries"

                # Describe primary emotion
                if emotions:
                    top_emotion = max(emotions.items(), key=lambda x: x[1])
                    emotion_pct = int((top_emotion[1] / total) * 100)
                    if emotion_pct >= 50:
                        entity_line += f"<br>  Often when you're feeling {top_emotion[0]}"

                html += entity_line + '<br><br>'

        # Stage 4: Enhanced temporal pattern display with time-of-day and day-of-week breakdown
        if temporal:
            html += '<strong>YOUR WRITING RHYTHMS</strong><br><br>'

            # Group by pattern type
            time_patterns = [t for t in temporal if t['weekday'] == 'all']
            day_patterns = [t for t in temporal if t['time_block'] != 'all' and t['weekday'] not in ['all', 'weekday', 'weekend']]
            daytype_patterns = [t for t in temporal if t['weekday'] in ['weekday', 'weekend']]

            # Display time-of-day patterns
            if time_patterns:
                html += '<strong>BY TIME OF DAY</strong><br>'
                for temp in time_patterns[:4]:
                    themes = json.loads(temp['common_themes'])
                    emotions = json.loads(temp['common_emotions'])

                    time_name = {'morning': 'Mornings', 'afternoon': 'Afternoons', 'evening': 'Evenings', 'night': 'Late nights'}.get(temp['time_block'], temp['time_block'])

                    html += f"• <strong>{time_name}</strong> ({temp['sample_count']} entries)<br>"
                    if themes:
                        html += f"  {', '.join(themes[:3])}"
                    if emotions:
                        html += f" — {', '.join(emotions[:2])}"
                    html += '<br>'
                html += '<br>'

            # Display day-of-week specific patterns
            if day_patterns:
                html += '<strong>BY DAY OF WEEK</strong><br>'
                # Sort by day order
                day_order = {'monday': 0, 'tuesday': 1, 'wednesday': 2, 'thursday': 3, 'friday': 4, 'saturday': 5, 'sunday': 6}
                day_patterns_sorted = sorted(day_patterns, key=lambda x: day_order.get(x['weekday'], 7))

                for temp in day_patterns_sorted[:7]:
                    themes = json.loads(temp['common_themes'])
                    emotions = json.loads(temp['common_emotions'])

                    time_name = {'morning': 'mornings', 'afternoon': 'afternoons', 'evening': 'evenings', 'night': 'nights'}.get(temp['time_block'], temp['time_block'])
                    html += f"• <strong>{temp['weekday'].title()} {time_name}</strong> ({temp['sample_count']} entries)<br>"

                    if themes:
                        html += f"  {', '.join(themes[:2])}"
                    if emotions:
                        html += f" — {', '.join(emotions[:2])}"
                    html += '<br>'
                html += '<br>'

            # Display weekday vs weekend patterns
            if daytype_patterns:
                html += '<strong>WEEKDAY VS WEEKEND</strong><br>'
                for temp in daytype_patterns:
                    themes = json.loads(temp['common_themes'])
                    emotions = json.loads(temp['common_emotions'])

                    html += f"• <strong>{temp['weekday'].title()}s</strong> ({temp['sample_count']} entries)<br>"
                    if themes:
                        html += f"  {', '.join(themes[:3])}"
                    if emotions:
                        html += f" — {', '.join(emotions[:2])}"
                    html += '<br>'
                html += '<br>'

        # Stage 5: Add insights section
        insights = generate_insights(conn)
        if insights:
            html += '<strong>💡 INSIGHTS (last 30 days)</strong><br><br>'
            for insight in insights:
                html += f'• {insight}<br>'
            html += '<br>'

        html += '<strong>Keep writing!</strong> Only showing strong patterns (10+ mentions, 70%+ confidence)<br><br>'
        html += '<em>Patterns weighted by recency - recent behavior matters more</em><br>'
        html += '<em>Tip: Type /clear-test-data to remove test entries</em>'
        html += '</div></div>'

        return html

    finally:
        conn.close()

def handle_clear_test_data_command() -> str:
    """
    Handle /clear-test-data command - Remove test entries and recalculate patterns.
    Deletes entries containing test-related content and updates pattern statistics.
    """
    conn = get_db()
    c = conn.cursor()

    try:
        # Count entries before deletion
        total_before = c.execute("SELECT COUNT(*) FROM entries").fetchone()[0]

        # Delete test entries based on multiple criteria
        c.execute("""
            DELETE FROM entries
            WHERE content LIKE '%ConfidenceTest%'
               OR content LIKE '%TestPerson%'
               OR content LIKE '%test pattern%'
               OR content LIKE '%TestEntity%'
               OR (themes LIKE '%test%' AND emotion = 'neutral')
        """)

        deleted_entries = c.rowcount

        # Delete test entity patterns
        c.execute("""
            DELETE FROM entity_patterns
            WHERE entity LIKE '%test%'
               OR entity LIKE '%Test%'
        """)

        deleted_entities = c.rowcount

        conn.commit()

        # Build response message
        if deleted_entries == 0 and deleted_entities == 0:
            return '<div class="entry new-entry"><div class="entry-content">✓ No test data found. Your patterns are clean!</div></div>'

        total_after = c.execute("SELECT COUNT(*) FROM entries").fetchone()[0]

        html = '<div class="entry new-entry"><div class="entry-content">'
        html += '<strong>🧹 Test Data Cleanup Complete</strong><br><br>'
        html += f'• Deleted {deleted_entries} test entries<br>'
        html += f'• Removed {deleted_entities} test entity patterns<br>'
        html += f'• Total entries: {total_before} → {total_after}<br><br>'
        html += '<em>Tip: Type /patterns to see your refreshed pattern insights</em>'
        html += '</div></div>'

        return html

    except Exception as e:
        print(f"Clear test data failed: {e}")
        return f'<div class="entry"><div class="entry-content">Error clearing test data: {str(e)}</div></div>'
    finally:
        conn.close()

async def process_entry_with_llm(entry_id: int, content: str):
    """Background task to add tags, emotion, actions, themes, people, urgency to entry."""
    try:
        # Stage 3: Build full context (facts + patterns) once per entry
        # Get entry timestamp for temporal patterns
        conn = get_db()
        c = conn.cursor()
        entry = c.execute("SELECT created_at FROM entries WHERE id = ?", (entry_id,)).fetchone()
        created_at = datetime.fromisoformat(entry['created_at']) if entry else datetime.now()
        conn.close()

        # Build full context combining facts and relevant patterns
        full_context = build_full_context(content, created_at)

        # Stage 3: Run all extractors in parallel using asyncio.gather
        results = await asyncio.gather(
            get_llm_analysis(content, full_context),
            extract_themes(content, full_context),
            extract_people(content, full_context),
            extract_urgency(content, full_context),
            return_exceptions=True  # Don't fail if one extractor fails
        )

        # Unpack results with error handling
        base_result = results[0] if not isinstance(results[0], Exception) else {"tags": [], "mood": "neutral", "actions": []}
        themes = results[1] if not isinstance(results[1], Exception) else []
        people = results[2] if not isinstance(results[2], Exception) else []
        urgency = results[3] if not isinstance(results[3], Exception) else 'none'

        conn = get_db()
        c = conn.cursor()
        # Update with all Stage 3 extracted data
        c.execute(
            """UPDATE entries SET tags = ?, mood = ?, emotion = ?, actions = ?,
               themes = ?, people = ?, urgency = ? WHERE id = ?""",
            (json.dumps(base_result["tags"]), base_result["mood"], base_result["mood"],
             json.dumps(base_result["actions"]), json.dumps(themes), json.dumps(people), urgency, entry_id)
        )
        conn.commit()

        # Get entry timestamp for pattern tracking
        entry = c.execute("SELECT created_at FROM entries WHERE id = ?", (entry_id,)).fetchone()
        created_at = entry['created_at'] if entry else datetime.now().isoformat()

        conn.close()
        print(f"LLM processed entry {entry_id}: emotion={base_result['mood']}, themes={themes}, people={people}, urgency={urgency}")

        # Stage 2: Update patterns asynchronously (non-blocking)
        try:
            update_entity_patterns(people, themes, base_result['mood'], urgency, created_at)
            update_temporal_patterns(themes, base_result['mood'], created_at)
        except Exception as pattern_err:
            print(f"Pattern tracking failed (non-critical): {pattern_err}")
    except Exception as e:
        print(f"LLM processing failed for entry {entry_id}: {e}")

# Routes
@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Main page"""
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/entries", response_class=HTMLResponse)
async def get_entries(search: Optional[str] = None):
    """Get all entries or search results"""
    conn = get_db()
    c = conn.cursor()

    if search:
        if search.startswith("/search "):
            search = search[8:]
        if search == "/today":
            entries = c.execute("SELECT * FROM entries WHERE date(created_at) = date('now') ORDER BY created_at DESC").fetchall()
        elif search == "/yesterday":
            entries = c.execute("SELECT * FROM entries WHERE date(created_at) = date('now', '-1 day') ORDER BY created_at DESC").fetchall()
        elif search == "/week":
            entries = c.execute("SELECT * FROM entries WHERE date(created_at) >= date('now', '-7 days') ORDER BY created_at DESC").fetchall()
        else:
            entries = c.execute("SELECT * FROM entries WHERE content LIKE ? OR tags LIKE ? ORDER BY created_at DESC",
                              (f"%{search}%", f"%{search}%")).fetchall()
    else:
        entries = c.execute("SELECT * FROM entries ORDER BY created_at DESC LIMIT 50").fetchall()

    # Get total count
    total_count = c.execute("SELECT COUNT(*) FROM entries").fetchone()[0]
    conn.close()

    # Format entries HTML
    html = ""
    for entry in entries:
        content_html = format_content_with_tags(entry['content']).replace('\n', '<br>')
        relative_time = get_relative_time(entry['created_at'])

        # Build SLM indicators - Stage 3: show emotion, themes, people, urgency
        slm_indicators = ""
        # Emotion
        if 'mood' in entry.keys() and entry['mood']:
            slm_indicators += f'<span class="slm-indicator">[{entry["mood"]}]</span>'
        # Themes
        if 'themes' in entry.keys() and entry['themes']:
            try:
                theme_list = json.loads(entry['themes']) if isinstance(entry['themes'], str) else entry['themes']
                for theme in theme_list[:2]:  # Show max 2 themes
                    slm_indicators += f'<span class="slm-indicator">[#{theme}]</span>'
            except: pass
        # People
        if 'people' in entry.keys() and entry['people']:
            try:
                people_list = json.loads(entry['people']) if isinstance(entry['people'], str) else entry['people']
                for person in people_list[:2]:  # Show max 2 people
                    slm_indicators += f'<span class="slm-indicator">[@{person}]</span>'
            except: pass
        # Urgency (only show medium/high)
        if 'urgency' in entry.keys() and entry['urgency'] in ['medium', 'high']:
            slm_indicators += f'<span class="slm-indicator">[!{entry["urgency"]}]</span>'
        # Actions count (legacy)
        if 'actions' in entry.keys() and entry['actions']:
            try:
                action_list = json.loads(entry['actions']) if isinstance(entry['actions'], str) else entry['actions']
                if action_list and len(action_list) > 0:
                    slm_indicators += f'<span class="slm-indicator">[!{len(action_list)}]</span>'
            except: pass

        # Check if it's a todo
        is_todo = '#todo' in entry['content'].lower()
        is_done = '#done' in entry['content'].lower()

        if is_todo or is_done:
            checkbox = '☑' if is_done else '□'
            todo_class = 'todo-done' if is_done else ''
            # Format content with checkbox inline
            todo_content = f'<span class="todo-checkbox" onclick="toggleTodo({entry["id"]})">{checkbox}</span><span class="todo-text">{content_html}</span>'
            html += f"""
            <div class="entry {todo_class}" data-id="{entry['id']}" data-created="{entry['created_at']}">
                <div class="entry-actions">
                    <button class="entry-action edit" onclick="editEntry({entry['id']})" title="Edit">✎</button>
                    <button class="entry-action delete" onclick="deleteEntry({entry['id']})" title="Delete">×</button>
                </div>
                <div class="entry-content">{todo_content}</div>
                <div class="entry-meta">{relative_time}{slm_indicators}</div>
            </div>
            """
        else:
            html += f"""
            <div class="entry" data-id="{entry['id']}" data-created="{entry['created_at']}">
                <div class="entry-actions">
                    <button class="entry-action edit" onclick="editEntry({entry['id']})" title="Edit">✎</button>
                    <button class="entry-action delete" onclick="deleteEntry({entry['id']})" title="Delete">×</button>
                </div>
                <div class="entry-content">{content_html}</div>
                <div class="entry-meta">{relative_time}{slm_indicators}</div>
            </div>
            """

    if html:
        # Add counter at the end
        thought_word = "thought" if total_count == 1 else "thoughts"
        html += f'<div class="entry-counter">{total_count} {thought_word} captured</div>'
        return html
    else:
        # Still show counter even when no entries
        return '<div class="no-entries">No entries yet. Start typing above!</div><div class="entry-counter">0 thoughts captured</div>'

@app.post("/entries", response_class=HTMLResponse)
async def create_entry(content: str = Form(...)):
    """Create new entry"""
    if not content.strip():
        return ""

    # Commands
    if content.startswith("/context"):
        return handle_context_command(content)

    if content == "/patterns":
        return handle_patterns_command()

    if content == "/clear-test-data":
        return handle_clear_test_data_command()

    if content.startswith("/search ") or content in ["/today", "/yesterday", "/week"]:
        return await get_entries(search=content)

    # Save entry
    conn = get_db()
    c = conn.cursor()
    tags = json.dumps(extract_tags(content))
    c.execute("INSERT INTO entries (content, tags) VALUES (?, ?)", (content, tags))
    entry_id = c.lastrowid
    conn.commit()
    entry = c.execute("SELECT * FROM entries WHERE id = ?", (entry_id,)).fetchone()
    conn.close()

    save_entry_to_markdown(entry_id, content, entry['created_at'])

    # Trigger background LLM processing (non-blocking)
    # Store task reference to prevent garbage collection
    task = asyncio.create_task(process_entry_with_llm(entry_id, content))
    background_tasks.add(task)
    task.add_done_callback(background_tasks.discard)

    # Return HTML
    content_html = format_content_with_tags(content).replace('\n', '<br>')
    relative_time = get_relative_time(entry['created_at'])

    # Check if it's a todo
    is_todo = '#todo' in content.lower()
    is_done = '#done' in content.lower()

    if is_todo or is_done:
        checkbox = '☑' if is_done else '□'
        todo_class = 'todo-done' if is_done else ''
        # Format content with checkbox inline
        todo_content = f'<span class="todo-checkbox" onclick="toggleTodo({entry_id})">{checkbox}</span><span class="todo-text">{content_html}</span>'
        return f"""
        <div class="entry new-entry {todo_class}" data-id="{entry_id}" data-created="{entry['created_at']}"
             hx-get="/entries/{entry_id}/refresh" hx-trigger="every 3s" hx-swap="outerHTML">
            <div class="entry-actions">
                <button class="entry-action edit" onclick="editEntry({entry_id})" title="Edit">✎</button>
                <button class="entry-action delete" onclick="deleteEntry({entry_id})" title="Delete">×</button>
            </div>
            <div class="entry-content">{todo_content}</div>
            <div class="entry-meta">{relative_time}<span class="success-indicator">✓</span></div>
        </div>
        """
    else:
        return f"""
        <div class="entry new-entry" data-id="{entry_id}" data-created="{entry['created_at']}"
             hx-get="/entries/{entry_id}/refresh" hx-trigger="every 3s" hx-swap="outerHTML">
            <div class="entry-actions">
                <button class="entry-action edit" onclick="editEntry({entry_id})" title="Edit">✎</button>
                <button class="entry-action delete" onclick="deleteEntry({entry_id})" title="Delete">×</button>
            </div>
            <div class="entry-content">{content_html}</div>
            <div class="entry-meta">{relative_time}<span class="success-indicator">✓</span></div>
        </div>
        """

@app.put("/entries/{entry_id}", response_class=HTMLResponse)
async def update_entry(entry_id: int, content: str = Form(...)):
    """Update existing entry"""
    if not content.strip():
        return ""

    conn = get_db()
    c = conn.cursor()
    tags = json.dumps(extract_tags(content))
    c.execute("UPDATE entries SET content = ?, tags = ? WHERE id = ?", (content, tags, entry_id))
    conn.commit()
    entry = c.execute("SELECT * FROM entries WHERE id = ?", (entry_id,)).fetchone()
    conn.close()

    if not entry:
        return ""

    content_html = format_content_with_tags(content).replace('\n', '<br>')
    relative_time = get_relative_time(entry['created_at'])

    # Build SLM indicators - Stage 3 (same as in get_entries)
    slm_indicators = ""
    if 'mood' in entry.keys() and entry['mood']:
        slm_indicators += f'<span class="slm-indicator">[{entry["mood"]}]</span>'
    if 'themes' in entry.keys() and entry['themes']:
        try:
            theme_list = json.loads(entry['themes']) if isinstance(entry['themes'], str) else entry['themes']
            for theme in theme_list[:2]:
                slm_indicators += f'<span class="slm-indicator">[#{theme}]</span>'
        except: pass
    if 'people' in entry.keys() and entry['people']:
        try:
            people_list = json.loads(entry['people']) if isinstance(entry['people'], str) else entry['people']
            for person in people_list[:2]:
                slm_indicators += f'<span class="slm-indicator">[@{person}]</span>'
        except: pass
    if 'urgency' in entry.keys() and entry['urgency'] in ['medium', 'high']:
        slm_indicators += f'<span class="slm-indicator">[!{entry["urgency"]}]</span>'
    if 'actions' in entry.keys() and entry['actions']:
        try:
            action_list = json.loads(entry['actions']) if isinstance(entry['actions'], str) else entry['actions']
            if action_list and len(action_list) > 0:
                slm_indicators += f'<span class="slm-indicator">[!{len(action_list)}]</span>'
        except: pass

    # Check if it's a todo
    is_todo = '#todo' in content.lower()
    is_done = '#done' in content.lower()

    if is_todo or is_done:
        checkbox = '☑' if is_done else '□'
        todo_class = 'todo-done' if is_done else ''
        # Format content with checkbox inline
        todo_content = f'<span class="todo-checkbox" onclick="toggleTodo({entry_id})">{checkbox}</span><span class="todo-text">{content_html}</span>'
        return f"""
        <div class="entry {todo_class}" data-id="{entry_id}" data-created="{entry['created_at']}">
            <div class="entry-actions">
                <button class="entry-action edit" onclick="editEntry({entry_id})" title="Edit">✎</button>
                <button class="entry-action delete" onclick="deleteEntry({entry_id})" title="Delete">×</button>
            </div>
            <div class="entry-content">{todo_content}</div>
            <div class="entry-meta">{relative_time}{slm_indicators}<span class="success-indicator">✓</span></div>
        </div>
        """
    else:
        return f"""
        <div class="entry" data-id="{entry_id}" data-created="{entry['created_at']}">
            <div class="entry-actions">
                <button class="entry-action edit" onclick="editEntry({entry_id})" title="Edit">✎</button>
                <button class="entry-action delete" onclick="deleteEntry({entry_id})" title="Delete">×</button>
            </div>
            <div class="entry-content">{content_html}</div>
            <div class="entry-meta">{relative_time}{slm_indicators}<span class="success-indicator">✓</span></div>
        </div>
        """

@app.get("/entries/{entry_id}/refresh", response_class=HTMLResponse)
async def refresh_entry(entry_id: int):
    """Refresh entry with updated LLM indicators - used for polling"""
    conn = get_db()
    c = conn.cursor()
    entry = c.execute("SELECT * FROM entries WHERE id = ?", (entry_id,)).fetchone()
    conn.close()

    if not entry:
        return ""

    # Check if entry is older than 2 minutes
    created_dt = datetime.fromisoformat(entry['created_at'])
    age_seconds = (datetime.now() - created_dt).total_seconds()
    is_old = age_seconds > 120  # 2 minutes

    # Check if entry has indicators (LLM processing complete)
    has_indicators = False
    if ('mood' in entry.keys() and entry['mood']) or \
       ('actions' in entry.keys() and entry['actions'] and json.loads(entry['actions'] or '[]')) or \
       ('tags' in entry.keys() and entry['tags'] and json.loads(entry['tags'] or '[]')):
        has_indicators = True

    # Stop polling if entry is old OR has indicators
    should_stop_polling = is_old or has_indicators

    content_html = format_content_with_tags(entry['content']).replace('\n', '<br>')
    relative_time = get_relative_time(entry['created_at'])

    # Build SLM indicators - Stage 3
    slm_indicators = ""
    if 'mood' in entry.keys() and entry['mood']:
        slm_indicators += f'<span class="slm-indicator">[{entry["mood"]}]</span>'
    if 'themes' in entry.keys() and entry['themes']:
        try:
            theme_list = json.loads(entry['themes']) if isinstance(entry['themes'], str) else entry['themes']
            for theme in theme_list[:2]:
                slm_indicators += f'<span class="slm-indicator">[#{theme}]</span>'
        except: pass
    if 'people' in entry.keys() and entry['people']:
        try:
            people_list = json.loads(entry['people']) if isinstance(entry['people'], str) else entry['people']
            for person in people_list[:2]:
                slm_indicators += f'<span class="slm-indicator">[@{person}]</span>'
        except: pass
    if 'urgency' in entry.keys() and entry['urgency'] in ['medium', 'high']:
        slm_indicators += f'<span class="slm-indicator">[!{entry["urgency"]}]</span>'
    if 'actions' in entry.keys() and entry['actions']:
        try:
            action_list = json.loads(entry['actions']) if isinstance(entry['actions'], str) else entry['actions']
            if action_list and len(action_list) > 0:
                slm_indicators += f'<span class="slm-indicator">[!{len(action_list)}]</span>'
        except: pass

    # Check if it's a todo
    is_todo = '#todo' in entry['content'].lower()
    is_done = '#done' in entry['content'].lower()

    # Add polling attributes only if we should keep polling
    polling_attrs = '' if should_stop_polling else f'hx-get="/entries/{entry_id}/refresh" hx-trigger="every 3s" hx-swap="outerHTML"'

    if is_todo or is_done:
        checkbox = '☑' if is_done else '□'
        todo_class = 'todo-done' if is_done else ''
        todo_content = f'<span class="todo-checkbox" onclick="toggleTodo({entry_id})">{checkbox}</span><span class="todo-text">{content_html}</span>'
        return f"""
        <div class="entry {todo_class}" data-id="{entry_id}" data-created="{entry['created_at']}" {polling_attrs}>
            <div class="entry-actions">
                <button class="entry-action edit" onclick="editEntry({entry_id})" title="Edit">✎</button>
                <button class="entry-action delete" onclick="deleteEntry({entry_id})" title="Delete">×</button>
            </div>
            <div class="entry-content">{todo_content}</div>
            <div class="entry-meta">{relative_time}{slm_indicators}</div>
        </div>
        """
    else:
        return f"""
        <div class="entry" data-id="{entry_id}" data-created="{entry['created_at']}" {polling_attrs}>
            <div class="entry-actions">
                <button class="entry-action edit" onclick="editEntry({entry_id})" title="Edit">✎</button>
                <button class="entry-action delete" onclick="deleteEntry({entry_id})" title="Delete">×</button>
            </div>
            <div class="entry-content">{content_html}</div>
            <div class="entry-meta">{relative_time}{slm_indicators}</div>
        </div>
        """

@app.delete("/entries/{entry_id}")
async def delete_entry(entry_id: int):
    """Delete an entry"""
    conn = get_db()
    c = conn.cursor()
    c.execute("DELETE FROM entries WHERE id = ?", (entry_id,))
    conn.commit()
    conn.close()
    return JSONResponse({"success": True})

@app.post("/ai/summarize")
async def ai_summarize(count: int = Form(20)):
    """Generate AI summary of recent entries"""
    conn = get_db()
    c = conn.cursor()
    entries = c.execute(
        "SELECT * FROM entries ORDER BY created_at DESC LIMIT ?",
        (count,)
    ).fetchall()
    conn.close()

    # Convert rows to dicts for ai.py
    entries_list = [dict(entry) for entry in entries]
    summary = summarize_entries(entries_list, count)

    return JSONResponse({"summary": summary, "count": len(entries_list)})

@app.get("/todo-count")
async def get_todo_count():
    """Get count of uncompleted todos from database"""
    conn = get_db()
    c = conn.cursor()

    # Get all entries with #todo but not #done
    entries = c.execute("""
        SELECT id, content, created_at
        FROM entries
        WHERE content LIKE '%#todo%'
        AND content NOT LIKE '%#done%'
        ORDER BY created_at DESC
    """).fetchall()

    conn.close()

    # Check for old todos (> 24 hours)
    has_old_todos = False
    now = datetime.now()

    for entry in entries:
        created = datetime.fromisoformat(entry['created_at'])
        if (now - created).total_seconds() > 24 * 60 * 60:
            has_old_todos = True
            break

    return JSONResponse({
        "count": len(entries),
        "has_old": has_old_todos
    })

@app.get("/stats")
async def get_stats():
    """Get beautiful statistics for modal display"""
    conn = get_db()
    c = conn.cursor()

    # Single efficient query for all entries with dates
    entries = c.execute("""
        SELECT content, date(created_at) as date, created_at
        FROM entries
        ORDER BY created_at DESC
    """).fetchall()

    if not entries:
        conn.close()
        return JSONResponse({"empty": True})

    # Basic counts
    total_entries = len(entries)
    total_words = sum(len(e['content'].split()) for e in entries)

    # Date calculations
    today = datetime.now().strftime("%Y-%m-%d")
    week_ago = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
    month_ago = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")

    today_count = len([e for e in entries if e['date'] == today])
    week_count = len([e for e in entries if e['date'] >= week_ago])
    month_count = len([e for e in entries if e['date'] >= month_ago])

    # Calculate streaks
    dates = sorted(list(set(e['date'] for e in entries)), reverse=True)
    current_streak = 0
    longest_streak = 0

    # Current streak
    if dates:
        today_date = datetime.now().date()
        for i, date_str in enumerate(dates):
            date = datetime.fromisoformat(date_str).date()
            expected = today_date - timedelta(days=i)
            if date == expected:
                current_streak += 1
            else:
                break

        # Longest streak
        streak = 1
        for i in range(1, len(dates)):
            curr = datetime.fromisoformat(dates[i]).date()
            prev = datetime.fromisoformat(dates[i-1]).date()
            if (prev - curr).days == 1:
                streak += 1
                longest_streak = max(longest_streak, streak)
            else:
                streak = 1
        longest_streak = max(longest_streak, streak)

    # Daily average
    days_active = len(dates) if dates else 1
    daily_avg = round(total_entries / days_active, 1)

    # Best day
    date_counts = Counter(e['date'] for e in entries)
    best_date, best_count = date_counts.most_common(1)[0] if date_counts else (today, 0)
    best_day_str = f"{best_count} ({datetime.fromisoformat(best_date).strftime('%b %d')})"

    # Last 7 days activity
    activity_7days = []
    for i in range(6, -1, -1):
        date = datetime.now() - timedelta(days=i)
        date_str = date.strftime("%Y-%m-%d")
        day_name = date.strftime("%a")
        count = len([e for e in entries if e['date'] == date_str])
        activity_7days.append({
            'day': day_name,
            'count': count
        })

    # Last 30 days for heatmap
    heatmap_data = []
    for i in range(29, -1, -1):
        date_str = (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
        count = len([e for e in entries if e['date'] == date_str])
        heatmap_data.append(count)

    # Top 5 tags
    all_tags = []
    for e in entries:
        tags = re.findall(r'#(\w+)', e['content'])
        all_tags.extend(tags)

    tag_counts = Counter(all_tags)
    top_tags = [{'tag': tag, 'count': count} for tag, count in tag_counts.most_common(5)]

    # Week trend
    last_week = (datetime.now() - timedelta(days=14)).strftime("%Y-%m-%d")
    last_week_end = week_ago
    last_week_count = len([e for e in entries if last_week <= e['date'] < last_week_end])

    if last_week_count > 0:
        trend_pct = int(((week_count - last_week_count) / last_week_count) * 100)
        if trend_pct > 0:
            trend = f"▲ Up {trend_pct}%"
        elif trend_pct < 0:
            trend = f"▼ Down {abs(trend_pct)}%"
        else:
            trend = "→ Stable"
    else:
        trend = "▲ New week!"

    conn.close()

    return JSONResponse({
        'total_entries': total_entries,
        'total_words': total_words,
        'today_count': today_count,
        'week_count': week_count,
        'month_count': month_count,
        'daily_avg': daily_avg,
        'best_day': best_day_str,
        'current_streak': current_streak,
        'longest_streak': longest_streak,
        'activity_7days': activity_7days,
        'heatmap': heatmap_data,
        'top_tags': top_tags,
        'trend': trend
    })

@app.get("/export")
async def export_entries(
    date_range: str = Query("all"),
    tag: Optional[str] = Query(None),
    include_timestamps: bool = Query(True),
    format: str = Query("markdown")
):
    """Export entries with filters"""
    conn = get_db()
    c = conn.cursor()

    # Build query based on date range
    query = "SELECT * FROM entries WHERE 1=1"
    params = []

    if date_range == "day":
        query += " AND created_at >= datetime('now', '-1 day')"
    elif date_range == "week":
        query += " AND created_at >= datetime('now', '-7 days')"
    elif date_range == "month":
        query += " AND created_at >= datetime('now', '-30 days')"

    # Filter by tag if provided
    if tag:
        tag_clean = tag.strip().replace('#', '')
        if tag_clean:
            query += " AND tags LIKE ?"
            params.append(f'%"{tag_clean}"%')

    query += " ORDER BY created_at DESC"
    entries = c.execute(query, params).fetchall()
    conn.close()

    if format == "writeas":
        # write.as format - clean, minimal
        markdown = f"# Thoughts\n\n*Exported from Lean on {datetime.now().strftime('%B %d, %Y')}*\n\n---\n\n"

        for entry in entries:
            # Clean content without timestamps in the body
            content = entry['content']
            markdown += f"{content}\n\n"

            if include_timestamps:
                # Add subtle timestamp as italic text
                date_str = datetime.fromisoformat(entry['created_at']).strftime("%b %d, %I:%M %p")
                markdown += f"*{date_str}*\n\n"

            markdown += "---\n\n"
    else:
        # Standard markdown format
        markdown = "# Lean Export\n\n"
        for entry in entries:
            if include_timestamps:
                date_str = datetime.fromisoformat(entry['created_at']).strftime("%Y-%m-%d %H:%M")
                markdown += f"## {date_str}\n\n"

            markdown += f"{entry['content']}\n\n---\n\n"

    return JSONResponse({
        "markdown": markdown,
        "count": len(entries),
        "format": format
    })