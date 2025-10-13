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

    # Add mood column if it doesn't exist
    if 'mood' not in columns:
        c.execute("ALTER TABLE entries ADD COLUMN mood TEXT")

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

async def get_llm_analysis(text: str) -> dict:
    """
    Call Ollama API to get tags and mood.

    Args:
        text: The entry text to analyze

    Returns:
        {"tags": ["tag1", "tag2"], "mood": "positive"}
        On failure: {"tags": [], "mood": "neutral"}
    """
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            prompt = f"Extract 1-3 single-word tags and mood (positive/negative/neutral/mixed) from: {text}\nRespond with valid JSON only with 'tags' array and 'mood' string."
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={"model": "llama3.2:3b", "prompt": prompt, "stream": False}
            )
            if response.status_code == 200:
                result = response.json()
                raw_response = result.get("response", "{}")
                print(f"DEBUG - Ollama raw response: {raw_response}")
                try:
                    analysis = json.loads(raw_response)
                except json.JSONDecodeError as e:
                    print(f"DEBUG - JSON parse failed: {e}")
                    print(f"DEBUG - Raw text was: {raw_response[:200]}")
                    analysis = {}
                return {"tags": analysis.get("tags", [])[:3], "mood": analysis.get("mood", "neutral")}
    except Exception as e:
        print(f"LLM analysis failed: {e}")
    return {"tags": [], "mood": "neutral"}

async def process_entry_with_llm(entry_id: int, content: str):
    """Background task to add tags and mood to entry."""
    try:
        result = await get_llm_analysis(content)
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute(
            "UPDATE entries SET tags = ?, mood = ? WHERE id = ?",
            (json.dumps(result["tags"]), result["mood"], entry_id)
        )
        conn.commit()
        conn.close()
        print(f"LLM processed entry {entry_id}: tags={result['tags']}, mood={result['mood']}")
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

        # Build SLM indicators
        slm_indicators = ""
        if entry['tags']:
            try:
                tag_list = json.loads(entry['tags']) if isinstance(entry['tags'], str) else entry['tags']
                if tag_list and len(tag_list) > 0:
                    slm_indicators += f'<span class="slm-indicator">[#{len(tag_list)}]</span>'
            except: pass
        if 'mood' in entry.keys() and entry['mood'] and entry['mood'] != 'neutral':
            mood_text = {'positive': '+', 'negative': '-', 'mixed': '~'}.get(entry['mood'], '')
            if mood_text:
                slm_indicators += f'<span class="slm-indicator">[{mood_text}]</span>'

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
        <div class="entry new-entry {todo_class}" data-id="{entry_id}" data-created="{entry['created_at']}">
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
        <div class="entry new-entry" data-id="{entry_id}" data-created="{entry['created_at']}">
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
            <div class="entry-meta">{relative_time}<span class="success-indicator">✓</span></div>
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
            <div class="entry-meta">{relative_time}<span class="success-indicator">✓</span></div>
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