# LEAN_SLM_REVOLUTION.md

## Overview
Enhance Lean's SLM integration for richer emotional/contextual extraction and implement auto-reveal display for extracted intelligence. Two interconnected improvements that transform Lean from basic capture to intelligent life logging.

## Phase 1: SLM Revolution - Emotional & Contextual Depth

### 1.1 Database Schema Evolution
**Objective**: Add granular extraction fields while preserving existing functionality

**New columns to add**:
- `emotion` TEXT - Specific emotion word (not just mood category)
- `themes` TEXT - JSON array of auto-extracted conceptual themes
- `people` TEXT - JSON array of mentioned people/entities
- `urgency` TEXT - Time sensitivity (low/medium/high/none)

**Keep existing**: `tags`, `mood`, `actions` for backwards compatibility

### 1.2 Multi-Prompt Extraction Strategy
**Objective**: Replace single mega-prompt with specialized extractors

**Implementation approach**:
1. Create 4 focused extraction functions, each with targeted prompt
2. Run in parallel using asyncio for speed
3. Each extractor has simple fallback for when LLM fails
4. Combine results into single database update

**Extractors needed**:

#### Emotion Extractor
- Input: Entry text
- Output: Specific emotion word
- Vocabulary: frustrated, anxious, excited, content, melancholic, hopeful, angry, contemplative, tired, energetic, confused, grateful, overwhelmed, calm, nostalgic, curious, determined
- Fallback: Scan for emotion keywords if LLM fails

#### Theme Extractor  
- Input: Entry text
- Output: Array of conceptual themes (max 5)
- Examples: "went to new sushi place" → ["food", "restaurant", "japanese"]
- Fallback: Extract nouns and map to common categories

#### People/Entity Extractor
- Input: Entry text
- Output: Array of people names and places mentioned
- Pattern: Capitalized words that aren't sentence starts
- Fallback: Regex for common name patterns

#### Urgency Detector
- Input: Entry text
- Output: urgency level
- Keywords: today, tomorrow, asap, urgent, must, deadline → high
- Fallback: Check for time markers and action words

### 1.3 Testing Protocol
**Each extractor must pass independently before integration**

Test entries with expected outputs:
1. "feeling anxious about Sarah's presentation tomorrow"
   - emotion: "anxious"
   - themes: ["work", "presentation"]
   - people: ["Sarah"]
   - urgency: "high"

2. "that new ramen place was incredible"
   - emotion: "excited"
   - themes: ["food", "restaurant", "ramen"]
   - urgency: "none"

3. "need to call john about project, feeling overwhelmed"
   - emotion: "overwhelmed"
   - themes: ["work", "project", "communication"]
   - people: ["john"]
   - actions: ["call john about project"]
   - urgency: "medium"

## Phase 2: Auto-Reveal Display

### 2.1 Display Architecture
**Objective**: Show extracted intelligence automatically after 3 seconds, no clicking required

**Approach**: Pure CSS with HTMX delivery
- Entry renders with `data-has-intelligence="true"` attribute
- CSS animation delays reveal by 3 seconds
- Intelligence div starts with opacity:0, transitions to opacity:1
- No JavaScript, pure CSS transitions

### 2.2 HTML Structure
**Entry container hierarchy**:
```
<div class="entry" data-has-intelligence="true">
  <div class="entry-content">original text</div>
  <div class="entry-indicators">[anxious] [#2] [@Sarah] [!high]</div>
  <div class="entry-intelligence">
    <span class="intelligence-emotion">anxious</span>
    <span class="intelligence-themes">work, presentation</span>
    <span class="intelligence-people">Sarah</span>
  </div>
</div>
```

### 2.3 Visual Design Rules
- Intelligence appears 3 seconds after entry loads
- Gentle fade-in animation (0.5s transition)
- Indented below main entry text
- Muted colors (50% opacity of main text)
- Single line format: emotion | themes | people
- Disappears on hover for clean reading
- Pure ASCII, no Unicode symbols

### 2.4 Indicator Format Updates
**Current**: `[#3] [+] [!2]`
**New**: `[anxious] [#work] [@sarah] [!urgent]`

- Emotion replaces mood symbol
- Primary theme shown as tag
- @ prefix for people
- ! prefix for high urgency only

## Implementation Phases

### Stage 1: Emotion Enhancement (Minimal Change)
1. Modify existing mood prompt to return specific emotion
2. Store emotion in mood field temporarily
3. Display emotion word instead of +/-/~
4. Verify with 10 test entries
5. Rollback point if needed

### Stage 2: Database Extension
1. Add new columns via migration
2. Update entry model
3. Verify existing functionality unaffected
4. Test rollback procedure

### Stage 3: Multi-Extractor Implementation
1. Implement emotion extractor alone first
2. Test thoroughly
3. Add theme extractor
4. Add people extractor
5. Add urgency detector
6. Each with isolated testing

### Stage 4: Auto-Reveal Display
1. Add CSS animations
2. Update entry HTML structure
3. Test reveal timing
4. Verify mobile compatibility
5. Test with all themes

### Stage 5: Integration & Polish
1. Connect all extractors
2. Update indicator display
3. Performance testing
4. Final refinements

## Success Metrics
- Emotion detection accuracy: 80%+ on test set
- Theme extraction: Identifies primary topic 90% of time
- Display reveal: Smooth animation, no layout shift
- Performance: Still <100ms save time
- Backwards compatibility: Old entries still display correctly

## Rollback Strategy
Each stage has isolated rollback:
- Stage 1: Revert prompt change
- Stage 2: Drop new columns
- Stage 3: Disable new extractors
- Stage 4: Remove CSS animations
- Stage 5: Feature flag to disable

## Technical Constraints
- No external dependencies
- Maximum 200 lines new code total
- LLM calls remain non-blocking
- Must work with llama3.2:3b
- Pure HTMX/CSS for display (no custom JS)
- ASCII only display, no emoji/unicode

## Testing Checklist
Before considering complete:
- [ ] 20 varied test entries processed correctly
- [ ] Auto-reveal works on all 5 themes
- [ ] Edit functionality preserves intelligence
- [ ] Performance under 100ms save time
- [ ] Mobile display works correctly
- [ ] Rollback tested at each stage
