"""
AI features for Lean - isolated module for summarization
"""
import os
from typing import List, Optional
from pathlib import Path

# Try to import Anthropic SDK
try:
    from anthropic import Anthropic
    HAS_ANTHROPIC = True
except ImportError:
    HAS_ANTHROPIC = False

# Try to load .env file if it exists
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

def get_api_key() -> Optional[str]:
    """Get API key from environment"""
    return os.getenv('ANTHROPIC_API_KEY')

def is_ai_enabled() -> bool:
    """Check if AI features are available"""
    return HAS_ANTHROPIC and get_api_key() is not None

def summarize_entries(entries: List[dict], count: int = 20) -> str:
    """Summarize the last N entries using Claude"""

    if not is_ai_enabled():
        return "AI features not enabled. Add ANTHROPIC_API_KEY to .env file."

    if not entries:
        return "No entries to summarize."

    # Take the requested number of entries
    entries_to_summarize = entries[:count]

    # Format entries for Claude
    entries_text = "\n\n".join([
        f"[{entry.get('created_at', 'Unknown time')}]: {entry.get('content', '')}"
        for entry in entries_to_summarize
    ])

    try:
        client = Anthropic(api_key=get_api_key())

        prompt = f"""Please provide a concise summary of these {len(entries_to_summarize)} microblog entries.
Focus on key themes, topics, and insights. Keep it brief (2-3 paragraphs max).

Entries:
{entries_text}

Summary:"""

        response = client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=500,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        return response.content[0].text.strip()

    except Exception as e:
        return f"Error generating summary: {str(e)}"