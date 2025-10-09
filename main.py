"""
Lean - Local Microblog MVP
FastAPI backend with SQLite storage and HTMX frontend
"""
import os
import sqlite3
from datetime import datetime, timedelta
from collections import Counter, defaultdict
from pathlib import Path
from typing import List, Optional
import json
import re

from fastapi import FastAPI, Request, Form, Query
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

# Import AI features
from ai import summarize_entries

# Setup
app = FastAPI()
BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "lean.db"
ENTRIES_DIR = BASE_DIR / "entries"
ENTRIES_DIR.mkdir(exist_ok=True)

templates = Jinja2Templates(directory=str(BASE_DIR))

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
        # Handle inline commands
        if search.startswith("/search "):
            search = search[8:]  # Remove "/search " prefix
        elif search == "/today":
            today = datetime.now().strftime("%Y-%m-%d")
            query = "SELECT * FROM entries WHERE date(created_at) = date(?) ORDER BY created_at DESC"
            entries = c.execute(query, (today,)).fetchall()
        elif search == "/yesterday":
            yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
            query = "SELECT * FROM entries WHERE date(created_at) = date(?) ORDER BY created_at DESC"
            entries = c.execute(query, (yesterday,)).fetchall()
        elif search == "/week":
            week_ago = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
            query = "SELECT * FROM entries WHERE date(created_at) >= date(?) ORDER BY created_at DESC"
            entries = c.execute(query, (week_ago,)).fetchall()
        else:
            # Regular search in content and tags
            query = "SELECT * FROM entries WHERE content LIKE ? OR tags LIKE ? ORDER BY created_at DESC"
            search_term = f"%{search}%"
            entries = c.execute(query, (search_term, search_term)).fetchall()
    else:
        entries = c.execute("SELECT * FROM entries ORDER BY created_at DESC LIMIT 50").fetchall()

    # Get total count
    total_count = c.execute("SELECT COUNT(*) FROM entries").fetchone()[0]
    conn.close()

    # Format entries HTML
    html = ""
    for entry in entries:
        content_html = format_content_with_tags(entry['content'])
        # Replace newlines with <br> for display
        content_html = content_html.replace('\n', '<br>')
        relative_time = get_relative_time(entry['created_at'])

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
                <div class="entry-meta">{relative_time}</div>
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
                <div class="entry-meta">{relative_time}</div>
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

    # Check for commands
    if (content.startswith("/search ") or
        content == "/today" or
        content == "/yesterday" or
        content == "/week"):
        # Return search results instead of creating entry
        return await get_entries(search=content)

    # Save to database
    conn = get_db()
    c = conn.cursor()
    tags = json.dumps(extract_tags(content))
    c.execute("INSERT INTO entries (content, tags) VALUES (?, ?)", (content, tags))
    entry_id = c.lastrowid
    conn.commit()

    # Get the created entry
    entry = c.execute("SELECT * FROM entries WHERE id = ?", (entry_id,)).fetchone()
    conn.close()

    # Save to markdown
    save_entry_to_markdown(entry_id, content, entry['created_at'])

    # Return formatted entry HTML
    content_html = format_content_with_tags(content)
    content_html = content_html.replace('\n', '<br>')
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

    # Update the entry
    tags = json.dumps(extract_tags(content))
    c.execute(
        "UPDATE entries SET content = ?, tags = ? WHERE id = ?",
        (content, tags, entry_id)
    )
    conn.commit()

    # Get the updated entry
    entry = c.execute("SELECT * FROM entries WHERE id = ?", (entry_id,)).fetchone()
    conn.close()

    if not entry:
        return ""

    # Format and return the updated entry
    content_html = format_content_with_tags(content)
    content_html = content_html.replace('\n', '<br>')
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

@app.get("/stats")
async def get_stats():
    """Get statistics about entries"""
    conn = get_db()
    c = conn.cursor()

    # Get all entries for analysis
    entries = c.execute("""
        SELECT id, content, tags, created_at,
               date(created_at) as date,
               length(content) as char_count
        FROM entries
        ORDER BY created_at DESC
    """).fetchall()

    # Basic counts
    total_entries = len(entries)
    total_chars = sum(e['char_count'] for e in entries)
    total_words = sum(len(e['content'].split()) for e in entries)

    # Today's stats
    today = datetime.utcnow().strftime("%Y-%m-%d")
    today_entries = [e for e in entries if e['date'] == today]
    today_count = len(today_entries)

    # This week's stats
    week_ago = (datetime.utcnow() - timedelta(days=7)).strftime("%Y-%m-%d")
    week_entries = [e for e in entries if e['date'] >= week_ago]
    week_count = len(week_entries)

    # Daily activity for last 7 days
    daily_counts = defaultdict(int)
    for e in week_entries:
        daily_counts[e['date']] += 1

    # Build day-by-day activity
    activity_7days = []
    for i in range(6, -1, -1):
        date = (datetime.utcnow() - timedelta(days=i))
        date_str = date.strftime("%Y-%m-%d")
        day_name = date.strftime("%a")
        count = daily_counts.get(date_str, 0)
        activity_7days.append({
            'day': day_name,
            'date': date_str,
            'count': count
        })

    # Calculate max for scaling
    max_day_count = max((d['count'] for d in activity_7days), default=1)

    # Add sparkline bars
    for day in activity_7days:
        if day['count'] == 0:
            day['bar'] = '▁'
        else:
            # Scale to 5 levels
            level = int((day['count'] / max_day_count) * 4) + 1
            bars = ['▁', '▃', '▅', '▇', '█']
            day['bar'] = bars[min(level - 1, 4)] * min(5, max(1, int(day['count'] * 5 / max_day_count)))

    # Top tags
    all_tags = []
    for e in entries:
        if e['tags']:
            try:
                tags = json.loads(e['tags'])
                all_tags.extend(tags)
            except:
                pass

    tag_counts = Counter(all_tags)
    top_tags = tag_counts.most_common(5)
    max_tag_count = max((count for _, count in top_tags), default=1)

    # Format top tags with bars
    formatted_tags = []
    for i, (tag, count) in enumerate(top_tags):
        bar_length = int((count / max_tag_count) * 12)
        formatted_tags.append({
            'tag': f'#{tag}',
            'bar': '█' * bar_length,
            'count': count
        })

    # Calculate streak
    dates_with_entries = sorted(list(set(e['date'] for e in entries)), reverse=True)
    current_streak = 0
    longest_streak = 0

    if dates_with_entries:
        # Current streak
        today_date = datetime.utcnow().date()
        for i, date_str in enumerate(dates_with_entries):
            date = datetime.fromisoformat(date_str).date()
            expected_date = today_date - timedelta(days=i)
            if date == expected_date:
                current_streak += 1
            else:
                break

        # Longest streak
        temp_streak = 1
        for i in range(1, len(dates_with_entries)):
            curr_date = datetime.fromisoformat(dates_with_entries[i]).date()
            prev_date = datetime.fromisoformat(dates_with_entries[i-1]).date()
            if (prev_date - curr_date).days == 1:
                temp_streak += 1
                longest_streak = max(longest_streak, temp_streak)
            else:
                temp_streak = 1
        longest_streak = max(longest_streak, temp_streak)

    # 30-day heatmap
    heatmap = []
    for i in range(29, -1, -1):
        date = (datetime.utcnow() - timedelta(days=i))
        date_str = date.strftime("%Y-%m-%d")
        count = sum(1 for e in entries if e['date'] == date_str)

        if count == 0:
            heatmap.append('□')
        elif count <= 2:
            heatmap.append('▤')
        elif count <= 5:
            heatmap.append('▥')
        elif count <= 10:
            heatmap.append('▦')
        elif count <= 15:
            heatmap.append('▧')
        elif count <= 20:
            heatmap.append('▨')
        else:
            heatmap.append('█')

    # Calculate trend (compare this week to last week)
    last_week_start = (datetime.utcnow() - timedelta(days=14)).strftime("%Y-%m-%d")
    last_week_end = (datetime.utcnow() - timedelta(days=7)).strftime("%Y-%m-%d")
    last_week_count = len([e for e in entries if last_week_start <= e['date'] < last_week_end])

    if last_week_count > 0:
        trend_percent = int(((week_count - last_week_count) / last_week_count) * 100)
        if trend_percent > 0:
            trend = f"▲ Up {trend_percent}%"
        elif trend_percent < 0:
            trend = f"▼ Down {abs(trend_percent)}%"
        else:
            trend = "→ Stable"
    else:
        trend = "★ New this week!"

    # Best day
    if entries:
        date_counts = Counter(e['date'] for e in entries)
        best_date, best_count = date_counts.most_common(1)[0]
        best_day = f"{best_count} ({datetime.fromisoformat(best_date).strftime('%b %d')})"
    else:
        best_day = "—"

    # Average per day
    if dates_with_entries:
        days_active = len(dates_with_entries)
        avg_per_day = round(total_entries / days_active, 1)
    else:
        avg_per_day = 0

    conn.close()

    return JSONResponse({
        'total_entries': total_entries,
        'total_words': total_words,
        'today_count': today_count,
        'week_count': week_count,
        'avg_per_day': avg_per_day,
        'best_day': best_day,
        'current_streak': current_streak,
        'longest_streak': longest_streak,
        'activity_7days': activity_7days,
        'top_tags': formatted_tags,
        'heatmap': ''.join(heatmap),
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