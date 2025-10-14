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
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
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

    conn.commit()
    conn.close()

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

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
    # SQLite stores as UTC, but without timezone info
    # We need to treat the stored time as UTC and compare with current UTC
    dt = datetime.fromisoformat(created_at)
    # Get current time in UTC (matching what SQLite stores)
    now = datetime.utcnow()
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

async def extract_themes(text: str) -> List[str]:
    """Extract 1-3 themes from taxonomy using LLM with fallback."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            prompt = f"""Identify 1-3 themes from this list: work, personal, health, finance, relationships, learning, daily, creative, tech, leisure.

Text: "{text}"

Return ONLY a JSON array like: ["work", "health"]"""

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

def extract_people_fallback(text: str) -> List[str]:
    """Fallback people extraction using regex."""
    # Find capitalized words not at sentence start
    words = text.split()
    people = []

    # Common words to filter out
    exclude = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
               'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
               'September', 'October', 'November', 'December', 'I', 'The', 'A', 'An'}

    for i, word in enumerate(words):
        # Clean punctuation
        clean_word = word.strip('.,!?;:').strip()
        # Check if capitalized and not sentence start (unless first word)
        if clean_word and clean_word[0].isupper() and len(clean_word) > 1:
            if i == 0 or (i > 0 and words[i-1][-1] not in '.!?'):
                if clean_word not in exclude and clean_word.lower() not in text.lower()[:i]:
                    if clean_word not in people:
                        people.append(clean_word)

    return people[:5]

async def extract_people(text: str) -> List[str]:
    """Extract mentioned people's names using LLM with fallback."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            prompt = f"""Extract people's names mentioned in this text.

Text: "{text}"

Return ONLY a JSON array of names like: ["Sarah", "John"]"""

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

    return extract_people_fallback(text)

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

async def extract_urgency(text: str) -> str:
    """Extract urgency level using LLM with fallback."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            prompt = f"""Rate urgency as one word: none, low, medium, or high.

Text: "{text}"

Return ONLY one word."""

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

async def get_llm_analysis(text: str) -> dict:
    """
    Call Ollama API to get tags, mood (as specific emotion), and action items.

    Args:
        text: The entry text to analyze

    Returns:
        {"actions": ["action1"], "tags": ["tag1", "tag2"], "mood": "anxious"}
        On failure: {"actions": [], "tags": [], "mood": "neutral"}
    """
    # Fallback: extract hashtags directly from text
    hashtags = [word[1:] for word in text.split() if word.startswith('#') and len(word) > 1]

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            prompt = f"""Extract actions, tags, and emotion from this text. Return ONE emotion word only.

IMPORTANT: Only extract #hashtags for tags (words starting with #). Do NOT extract regular words as tags.

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

async def process_entry_with_llm(entry_id: int, content: str):
    """Background task to add tags, emotion, actions, themes, people, urgency to entry."""
    try:
        # Stage 3: Run all extractors in parallel using asyncio.gather
        results = await asyncio.gather(
            get_llm_analysis(content),
            extract_themes(content),
            extract_people(content),
            extract_urgency(content),
            return_exceptions=True  # Don't fail if one extractor fails
        )

        # Unpack results with error handling
        base_result = results[0] if not isinstance(results[0], Exception) else {"tags": [], "mood": "neutral", "actions": []}
        themes = results[1] if not isinstance(results[1], Exception) else []
        people = results[2] if not isinstance(results[2], Exception) else []
        urgency = results[3] if not isinstance(results[3], Exception) else 'none'

        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        # Update with all Stage 3 extracted data
        c.execute(
            """UPDATE entries SET tags = ?, mood = ?, emotion = ?, actions = ?,
               themes = ?, people = ?, urgency = ? WHERE id = ?""",
            (json.dumps(base_result["tags"]), base_result["mood"], base_result["mood"],
             json.dumps(base_result["actions"]), json.dumps(themes), json.dumps(people), urgency, entry_id)
        )
        conn.commit()
        conn.close()
        print(f"LLM processed entry {entry_id}: emotion={base_result['mood']}, themes={themes}, people={people}, urgency={urgency}")
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
    age_seconds = (datetime.utcnow() - created_dt).total_seconds()
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
    now = datetime.utcnow()

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
    today = datetime.utcnow().strftime("%Y-%m-%d")
    week_ago = (datetime.utcnow() - timedelta(days=7)).strftime("%Y-%m-%d")
    month_ago = (datetime.utcnow() - timedelta(days=30)).strftime("%Y-%m-%d")

    today_count = len([e for e in entries if e['date'] == today])
    week_count = len([e for e in entries if e['date'] >= week_ago])
    month_count = len([e for e in entries if e['date'] >= month_ago])

    # Calculate streaks
    dates = sorted(list(set(e['date'] for e in entries)), reverse=True)
    current_streak = 0
    longest_streak = 0

    # Current streak
    if dates:
        today_date = datetime.utcnow().date()
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
        date = datetime.utcnow() - timedelta(days=i)
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
        date_str = (datetime.utcnow() - timedelta(days=i)).strftime("%Y-%m-%d")
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
    last_week = (datetime.utcnow() - timedelta(days=14)).strftime("%Y-%m-%d")
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