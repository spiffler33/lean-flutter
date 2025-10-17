# Mission Control: Three-Column Intelligence Layer

## Design Vision
Transform entries from single blocks into intelligent three-column displays:
- CENTER: Original thought (sacred, untouched)
- LEFT: Metadata (tags, mood) - SLM extracted
- RIGHT: Actions (todos) - SLM extracted

Visual hierarchy: Center dominates, sides are subtle helpers.

## Pre-Flight Checklist
```bash
# Record current state
git status  # must be clean
git log --oneline -1  # record this SHA: 065ec9e
python -m pytest test_ollama.py  # must pass
```

## Critical Design Requirements
- NO emoji, NO unicode symbols, pure ASCII only
- Side panels: 15% width each, center: 70%
- Side panels: 0.7 opacity, fade in 0.3s after entry loads
- Hover zones: invisible until hover, then subtle reveal
- Mobile: panels hidden, swipe to reveal
- Performance: <10ms render impact

## STAGE 1: CSS FOUNDATION
*Goal: Add grid structure without changing ANY functionality*

### Checkpoint 1.1: Grid CSS Only
**Agent**: CSS_Grid_Specialist
**File**: static/lean.css
**Add**:
```css
/* Three-column container - hidden by default */
.entry-three-col {
    display: grid;
    grid-template-columns: 0 1fr 0;  /* Start collapsed */
    transition: grid-template-columns 0.3s ease;
}

.entry-three-col.active {
    grid-template-columns: 15% 70% 15%;
}

.entry-meta-left, .entry-actions-right {
    opacity: 0;
    transition: opacity 0.3s ease 0.2s;
    padding: 0 10px;
    font-size: 0.9em;
}

.entry-three-col.active .entry-meta-left,
.entry-three-col.active .entry-actions-right {
    opacity: 0.7;
}
```

**Test Commands**:
```bash
# Reload page - entries must look IDENTICAL to before
# Open dev tools - no console errors
# Create new entry - saves in <100ms
```

**Rollback**: `git checkout -- static/lean.css`
**Commit**: `git commit -m "Stage 1.1: Grid CSS foundation"`
**Success Criteria**:
- [ ] Zero visual change
- [ ] No console errors
- [ ] Performance unchanged

### GATE 1: CSS READY
- [X] All existing features work
- [X] No visual changes yet
**GO/NO-GO Decision**: GO ✅
**If NO-GO**: `git reset --hard [pre-flight-sha]`

---

## STAGE 2: STRUCTURE WITHOUT DATA
*Goal: Add HTML structure, still no functionality change*

### Checkpoint 2.1: HTML Containers
**Agent**: HTML_Structure_Specialist
**File**: index.html
**Modify**: Entry render function
**Add**:
```html
<!-- Wrap existing entry in three-col -->
<div class="entry-three-col" data-id="${entry.id}">
    <div class="entry-meta-left"></div>
    <div class="entry-content-center">
        <!-- EXISTING ENTRY HTML UNCHANGED -->
    </div>
    <div class="entry-actions-right"></div>
</div>
```

**Test Commands**:
```bash
# Entries still display normally
# Todo counter works
# Commands work
# No side panels visible yet
```

**Rollback**: `git checkout -- index.html`
**Commit**: `git commit -m "Stage 2.1: HTML structure ready"`

### GATE 2: STRUCTURE READY
- [X] Entries wrapped but look identical
- [X] All interactions work
**GO/NO-GO Decision**: GO ✅

---

## STAGE 3: DISPLAY EXISTING DATA
*Goal: Show SLM data that's already in database*

### Checkpoint 3.1: Reveal on Hover
**Agent**: Display_Specialist  
**Files**: index.html, static/lean.css
**Add**: Hover detection and data display

JavaScript addition:
```javascript
// On entry hover, add 'active' class
// On entry leave, remove 'active' class
// Pull tags/mood from data attributes
```

**Critical**: READ-ONLY display, no edit yet

**Test**:
```bash
# Hover over entry with SLM data
# See side panels fade in
# Mouse away - panels fade out
# No edit buttons yet
```

**Rollback**: `git checkout -- index.html static/lean.css`
**Commit**: `git commit -m "Stage 3.1: Display SLM data on hover"`

### GATE 3: DATA VISIBLE
- [ ] Tags/mood appear on left
- [ ] Actions appear on right  
- [ ] Smooth fade in/out
- [ ] No edit capability
**GO/NO-GO Decision**: ________

---

## STAGE 4: EDIT CAPABILITY
*Goal: Add inline editing with database updates*

### Checkpoint 4.1: Edit UI
**Agent**: Edit_UI_Specialist
**Add**: Click-to-edit on side panels
- Click tag → inline input appears
- Enter → saves to database
- Escape → cancels edit
- Small [x] to delete individual items

### Checkpoint 4.2: Database Updates
**Agent**: Edit_Backend_Specialist  
**Add**: API endpoints for updating tags/mood/actions

### GATE 4: FULL FEATURE
- [ ] Can edit all extractions
- [ ] Changes persist in database
- [ ] Original entry never modified
**GO/NO-GO Decision**: ________

---

## STAGE 5: POLISH
*Goal: Smooth UX touches*

### Checkpoint 5.1: Keyboard Shortcuts
- Tab: Cycle through panels
- E: Edit focused panel
- X: Delete focused item

### Checkpoint 5.2: Mobile Swipe
- Swipe left: Show metadata
- Swipe right: Show actions

---

## EMERGENCY PROCEDURES

### If anything breaks:
```bash
# Stop everything
pkill python
brew services restart ollama

# Reset to last good state
git status  # See what changed
git diff    # Review changes
git reset --hard [last-good-sha]

# Restart clean
./run.sh
```

### If SLM stops working:
```bash
ollama list  # Check model exists
curl http://localhost:11434/api/tags  # Check API
python test_ollama.py  # Test connection
```

---

## Success Metrics
- [ ] Total lines added: < 150
- [ ] Performance impact: < 10ms  
- [ ] All original features intact
- [ ] Can use app ignoring new features
- [ ] Zero emoji/unicode symbols

---

## Notes Section
*Update this during implementation*

### What's Working:
-

### Issues Encountered:
-

### Decisions Made:
-
