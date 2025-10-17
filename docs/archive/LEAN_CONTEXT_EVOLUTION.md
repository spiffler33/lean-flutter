# LEAN_CONTEXT_EVOLUTION.md

## Overview
Transform Lean from a generic thought capture tool into a personalized intelligence system that learns your world through explicit facts and implicit patterns. A hybrid approach combining manual `/context` commands with automatic pattern learning.

## Core Philosophy
- **Frictionless first** - Learning happens automatically through usage
- **User control** - Explicit facts via `/context` when desired
- **Privacy absolute** - All learning stays local in SQLite
- **Specific over generic** - Your context, not everyone's

## Architecture Overview

### Two Knowledge Types
1. **FACTS** - Explicit, user-stated truths via `/context`
   - "I work at Deutsche Bank"
   - "My startup is Rubic"
   - Immutable, high confidence

2. **PATTERNS** - Implicit, statistically learned
   - "Rubic correlates with excited (78%)"
   - "Mornings are anxious + work (65%)"
   - Evolving, confidence-weighted

## Phase 1: Context Command System

### 1.1 Database Schema
Add tables for explicit facts:
```
user_facts table:
- fact_id INTEGER PRIMARY KEY
- fact_text TEXT
- fact_category TEXT (work/personal/people/location)
- created_at TIMESTAMP
- active BOOLEAN
```

### 1.2 /context Command Implementation
Command variants to implement:
- `/context` - Display all active facts
- `/context [text]` - Add new fact
- `/context clear` - Soft delete all facts
- `/context remove [id]` - Remove specific fact

Examples:
- `/context I work at Deutsche Bank and have a startup called Rubic`
- `/context Sarah is my manager at Deutsche`
- `/context I have 2 kids aged 5 and 7`
- `/context I live in Singapore`

### 1.3 Context Integration
Modify LLM prompts to include facts:
- Prepend user facts to every extraction prompt
- Format: "User context: [facts]\n\nExtract from: [entry]"
- Keep facts concise (<300 words total)

### 1.4 Testing Protocol
Verify facts improve extraction:
1. Add: `/context My startup is Rubic`
2. Entry: "Rubic meeting went well"
3. Should extract: [#work] [#tech] with higher confidence

## Phase 2: Pattern Learning System

### 2.1 Database Schema
Add tables for learned patterns:
```
entity_patterns table:
- entity TEXT PRIMARY KEY
- entity_type TEXT (person/company/place)
- mention_count INTEGER
- theme_correlations TEXT (JSON)
- emotion_correlations TEXT (JSON)
- urgency_correlation TEXT (JSON)
- time_patterns TEXT (JSON)
- confidence_score FLOAT
- first_seen TIMESTAMP
- last_seen TIMESTAMP

temporal_patterns table:
- pattern_id INTEGER PRIMARY KEY
- time_block TEXT (morning/afternoon/evening/night)
- weekday TEXT
- common_themes TEXT (JSON)
- common_emotions TEXT (JSON)
- confidence FLOAT
```

### 2.2 Pattern Detection Logic
After each entry processing:
1. Update entity mention counts
2. Track entity-theme correlations
3. Track entity-emotion correlations
4. Track temporal patterns (time of day/week)
5. Calculate confidence scores

Thresholds:
- Entity becomes "known" after 5 mentions
- Pattern becomes "significant" at 60% correlation
- Temporal patterns need 10+ data points

### 2.3 Pattern Display Command
Implement `/patterns` command:
```
Entities:
- Rubic: 47 mentions (work 85%, tech 74%, excited 60%)
- Sarah: 23 mentions (urgent 70%, work 95%)
- Deutsche: 31 mentions (work 100%, overwhelmed 45%)

Time patterns:
- Monday mornings: work 90%, anxious 70%
- Friday evenings: personal 80%, grateful 65%
- Late night: contemplative 75%, tired 60%
```

### 2.4 Pattern Integration
Include learned patterns in LLM context:
- After facts, add "Observed patterns: [patterns]"
- Weight patterns by confidence score
- Limit to top 10 most relevant patterns

## Phase 3: Contextual Extraction Enhancement

### 3.1 Smart Context Selection
For each entry, select relevant context:
- Time-based: Include morning patterns for morning entries
- Entity-based: Include Rubic patterns when Rubic mentioned
- Emotion-based: Include emotional correlations
- Keep total context under 500 words

### 3.2 Confidence Scoring
Add extraction confidence based on context match:
- Fact match: High confidence (90%)
- Pattern match: Medium confidence (60-80%)
- No context match: Low confidence (30%)

Display confidence in indicators (optional):
- High: `[#work!]` (emphatic)
- Medium: `[#work]` (normal)
- Low: `[#work?]` (uncertain)

### 3.3 Feedback Loop
Track extraction accuracy:
- When user edits extracted data, note the correction
- Adjust pattern confidence accordingly
- Learn from mistakes without explicit training

## Phase 4: Voice-Ready Context

### 4.1 Natural Language Facts
Prepare for voice input by accepting natural statements:
- "I work at Deutsche Bank" → Same as typed
- "My manager is Sarah" → Extract relationship
- "Living in Singapore" → Normalize to "I live in Singapore"

### 4.2 Intent Detection
For future voice integration, classify input:
- Thought capture: "Feeling tired today"
- Context update: "By the way, I changed teams"
- Command: "Show me this week's entries"
- Query: "What did I write about Rubic?"

### 4.3 Context Extraction from Entries
Optionally extract facts from regular entries:
- "Just started at Deutsche Bank!" → Suggest: Add "works at Deutsche Bank" to context?
- "Sarah is now my manager" → Suggest: Update context?
- One-time suggestion per fact (don't nag)

## Phase 5: Advanced Intelligence

### 5.1 Relationship Mapping
Build entity relationship graph:
- "Sarah" + "manager" → Sarah is manager
- "Rubic" + "my startup" → Rubic is owned company
- "Tom" + "Sarah" frequently → Tom and Sarah are connected

### 5.2 Context Decay
Implement time-based relevance:
- Recent patterns weighted higher
- Old patterns fade unless reinforced
- Facts remain constant unless explicitly changed

### 5.3 Insight Generation
Generate insights from patterns:
- "You mention Rubic 3x more on Tuesdays"
- "Deutsche entries are 70% overwhelmed vs 30% for Rubic"
- "Your urgency peaks when Sarah is mentioned"

## Implementation Stages

### Stage 1: Basic /context Command (50 lines)
1. Add user_facts table
2. Implement /context command
3. Include facts in LLM prompts
4. Test with 5 facts

### Stage 2: Pattern Tracking (100 lines)
1. Add entity_patterns table
2. Track entity mentions and correlations
3. Calculate confidence scores
4. No display yet, just tracking

### Stage 3: Pattern Integration (75 lines)
1. Implement /patterns command
2. Include patterns in LLM context
3. Smart context selection (relevance-based)
4. Test extraction improvements

### Stage 4: Temporal Patterns (50 lines)
1. Add temporal_patterns table
2. Track time-of-day patterns
3. Track day-of-week patterns
4. Include in context when relevant

### Stage 5: Polish & Intelligence (75 lines)
1. Add confidence scoring
2. Implement context decay
3. Basic insight generation
4. Prepare for voice integration

## Success Metrics

### Accuracy Targets
- Fact-based extraction: 95% accurate
- Pattern-based extraction: 75% accurate
- Entity recognition: 85% accurate
- Theme detection: 80% accurate

### Performance Constraints
- Context building: <50ms
- Pattern updates: Async, non-blocking
- Total context size: <500 words
- Save time: Still <100ms

## Testing Protocol

### Stage Gate Tests
Each stage must pass before proceeding:

**Stage 1**: Facts improve extraction
- Add 5 facts via /context
- Test 10 entries
- Extraction improves for fact-related content

**Stage 2**: Patterns tracked correctly
- Create 20 entries with recurring entities
- Verify pattern detection after 5 mentions
- Check correlation calculations

**Stage 3**: Patterns improve extraction
- Patterns influence extraction
- /patterns command shows insights
- Context stays under 500 words

**Stage 4**: Time patterns work
- Morning vs evening patterns detected
- Weekday vs weekend patterns detected
- Temporal context influences extraction

**Stage 5**: Intelligence emerges
- Insights are meaningful
- Confidence scores are accurate
- System feels personalized

## Rollback Strategy

Each stage can be independently rolled back:
- Stage 1: Drop user_facts table, remove /context
- Stage 2: Drop entity_patterns table
- Stage 3: Disable pattern inclusion in prompts
- Stage 4: Drop temporal_patterns table
- Stage 5: Disable intelligence features

## Technical Constraints
- No external ML libraries
- Maximum 350 lines new code total
- All learning stays local (SQLite only)
- Must maintain <100ms save time
- Context must stay under 500 words
- Pure HTMX/Python (no complex JS)

## Privacy Guarantees
- All learning is local-only
- No data leaves the machine
- Facts are user-controlled
- Patterns are statistically anonymous
- Export includes option to exclude learned context
