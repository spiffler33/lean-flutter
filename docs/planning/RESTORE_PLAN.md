# URGENT: Restore Original UI/UX

## Problem
I changed too much. User had perfected:
1. Command handling (/export, /stats, /idea, /essay, /theme, etc)
2. CSS and visual design
3. Edit/delete button placement and style
4. Todo counter (top right)
5. Time dividers
6. Modal flows

## Solution
Take the EXACT original index.html JavaScript (1400+ lines) and:
- Keep 100% of the UI/UX code
- Keep 100% of the command handlers
- Keep 100% of the styling
- ONLY replace FastAPI fetch calls with IndexedDB calls

## Files to Restore
1. index.html - Use original HTML structure + inline CSS EXACTLY
2. main.ts - Port original JavaScript but swap storage layer only
3. Keep all modals, all commands, all features

## What NOT to change
- Any styling
- Any command logic
- Any animations
- Any user-facing behavior
- The 1400 lines of perfected JavaScript

##What TO change
- Replace `fetch('/entries')` with `db.entries.toArray()`
- Replace `fetch('/entries', {POST})` with `db.entries.add()`
- Replace HTMX with direct DOM manipulation
- That's it.
