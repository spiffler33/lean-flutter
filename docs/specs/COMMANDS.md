# Lean Commands Reference

All commands are entered in the input box and executed with Enter.

## Search & Filter Commands

- `/search [term]` - Search entries for text or #tags
- `/today` - Show today's entries only
- `/yesterday` - Show yesterday's entries only
- `/week` - Show entries from last 7 days
- `/clear` - Clear current view (empty state)

## Export & AI Commands

- `/export` - Opens modal with markdown export of all entries
- `/ai sum [N]` - Generate AI summary of last N entries (default: 20)
  - Requires `ANTHROPIC_API_KEY` in `.env` file
  - Shows "AI features not enabled" if key missing

## System Commands

- `/help` - Show available commands tooltip (auto-closes after 10s)

## Keyboard Shortcuts

- `Enter` - Save entry
- `Shift+Enter` - New line in entry
- `/` - Focus input box from anywhere
- `Esc` - Clear search/close modals/tooltips

## Tags

- Type `#tag` anywhere in entry
- Click any #tag to filter by that tag
- Tags work at end of lines too

## Permalinks

- Click any timestamp to copy permalink to clipboard
- Format: `http://localhost:8000#entry-123`

## Notes

- All commands are instant - no page reloads
- Smooth animations throughout
- Optimistic UI for instant feedback
- All entries saved to `/entries/YYYY-MM-DD.md`