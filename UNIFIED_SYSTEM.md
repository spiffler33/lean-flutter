# LEAN INTELLIGENCE SYSTEM - UNIFIED APPROACH

## Current State (October 2025)

### Completed
- **Enrichment Pipeline**: Real-time emotion, themes, people, urgency extraction via Claude
- **Event Extraction**: LLM-based event detection with confidence scoring
- **Database Schema**: entries, enrichments, events, shadow_events, vlps tables
- **User Context**: /context command for personal facts

### What's Working
- Entries save instantly, enrich async in ~3 seconds
- Claude extracts both enrichments AND events in single API call
- High-confidence events (≥0.85) saved to database
- Shadow events (0.65-0.85) tracked for learning

## Maximizing Intelligence with /context

### Why Context Matters
The AI enrichment becomes significantly more accurate when it understands your personal context. Adding 5-10 key facts can improve extraction accuracy from ~70% to ~90%.

### Best Practices for Context Facts
Add facts that help the AI understand:
- **People**: "/context add Sarah is my manager at Google"
- **Work**: "/context add I work as a software engineer at Google"
- **Projects**: "/context add Lean is my side project about personal intelligence"
- **Routine**: "/context add I usually run in the mornings before work"
- **Preferences**: "/context add I don't drink alcohol"
- **Health**: "/context add I'm training for a marathon"

### What Makes a Good Context Fact
- **Specific**: "I work at Google" vs "I work in tech"
- **Relevant**: Focus on things you write about often
- **Current**: Update when situations change
- **Concise**: One fact per statement

### Impact on Intelligence
With good context, the AI will:
- Correctly identify "Sarah" as work-related stress (not personal)
- Understand "PR review" means pull request (not public relations)
- Know "lean" refers to your project (not diet or manufacturing)
- Recognize your baseline patterns (morning runner vs night owl)

Start with 3-5 core facts about work, key people, and main activities. The system learns from these to better understand all your entries.

## New Architecture: Unified Intelligence

### Core Philosophy
Users don't want separate views of events, patterns, and insights. They want ONE place to understand their life. Everything connects: emotions → events → patterns → actionable insights.

### System Design
```
Raw Entries → Enrichment + Events (DONE)
                    ↓
            Pattern Detection Engine (NEXT)
                    ↓
            Single /insights Command
```

## Phase 3: Pattern Detection Engine

### Database Schema

#### Intelligence Patterns Table
```
intelligence_patterns
- id: UUID
- user_id: UUID
- pattern_type: TEXT (temporal/causal/streak/correlation/anomaly)
- pattern_signature: TEXT (unique identifier for deduplication)
- trigger_conditions: JSONB
- outcome_conditions: JSONB
- context: JSONB (time_of_day, day_of_week, people_involved)
- strength_metrics: JSONB (occurrences, confidence, last_seen, first_seen)
- user_feedback: TEXT (validated/rejected/pending)
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

#### User Streaks Table
```
user_streaks
- id: UUID
- user_id: UUID
- streak_type: TEXT (exercise/sleep/mood/productivity)
- current_count: INTEGER
- best_count: INTEGER
- last_entry_date: DATE
- started_at: DATE
- broken_at: DATE
- is_active: BOOLEAN
```

### Pattern Types to Detect

#### Temporal Patterns
- Time-of-day correlations (morning anxiety, evening calm)
- Day-of-week patterns (Monday stress, Friday relief)
- Seasonal patterns (if enough data)

#### Causal Chains
- Event A → Event B within time window
- Emotion → Action patterns
- Person → Emotion correlations
- Trigger → Coping sequences

#### Streaks
- Consecutive days with specific events (exercise, good sleep)
- Mood streaks (positive/negative runs)
- Productivity streaks (high urgency entries)

#### Correlations
- People × Emotions (Sarah = stress)
- Themes × Time (work dominates mornings)
- Events × Outcomes (running → better mood)

#### Anomalies
- Unusual emotion for typical time
- Break in established pattern
- New people/contexts appearing
- Significant metric changes

### Pattern Detection Logic

#### Processing Schedule
- Real-time: Streak updates on each entry
- Hourly: Causal chain detection
- Daily: Temporal pattern analysis, correlation updates

#### Confidence Scoring
Patterns require minimum evidence:
- Temporal: 7+ occurrences
- Causal: 3+ occurrences with consistent timing
- Correlation: 5+ co-occurrences
- Anomaly: 2+ standard deviations from baseline

#### Pattern Lifecycle
1. Detection: Pattern identified in data
2. Validation: Meets minimum evidence threshold
3. Presentation: Shown in /insights
4. Feedback: User validates/rejects
5. Learning: Adjust confidence based on feedback

## Phase 4: Unified /insights Command

### Command Structure
Single command with smart defaults:
- `/insights` - Today's intelligence + active patterns
- `/insights week` - Weekly summary
- `/insights month` - Monthly analysis
- `/insights me` - Personal profile based on all data

### Display Sections

#### Today's Context
- Emotional arc throughout the day
- Events tracked with times
- People interactions and context
- Current streaks status

#### Active Patterns
- Strong patterns (>0.8 confidence)
- Emerging patterns (0.6-0.8 confidence)
- Recently broken patterns

#### Trends & Streaks
- Active streaks with current/best counts
- Weekly comparisons (this week vs last)
- Progress toward detected goals

#### Actionable Insights
- Specific, actionable recommendations
- Pattern-based predictions
- Optimization opportunities

### Intelligence Generation

#### Insight Types
1. **Observational**: "You mention Sarah in 80% of stressful entries"
2. **Predictive**: "Based on patterns, tomorrow morning may be challenging"
3. **Prescriptive**: "7+ hour sleep nights lead to 2x productivity next day"
4. **Celebratory**: "5-day exercise streak - your longest this month!"
5. **Warning**: "Unusual pattern detected: 3 days without positive emotions"

#### Natural Language Generation
- Use templates with variable substitution
- Vary phrasing to avoid repetition
- Prioritize insights by relevance and confidence
- Maximum 5 insights per view to avoid overwhelm

## Implementation Steps

### Step 1: Code Cleanup
Remove unnecessary code from failed approaches:
1. Delete `/patterns` command implementation (if exists)
2. Remove `/events` display command (keep extraction)
3. Clean up any regex-based extraction code remnants
4. Remove pattern-related code that doesn't fit unified model

### Step 2: Pattern Detection Engine
1. Create pattern detection service
2. Implement hourly batch job for pattern analysis
3. Build pattern deduplication logic
4. Create confidence scoring algorithm
5. Add pattern storage and retrieval

### Step 3: Streak Tracking
1. Create streak detection logic
2. Update on every entry save
3. Handle streak breaks gracefully
4. Calculate personal bests

### Step 4: /insights Command
1. Create insights generator service
2. Build natural language templates
3. Implement display formatting
4. Add time-based filtering (today/week/month)
5. Create insight prioritization logic

### Step 5: Feedback Loop
1. Add validation UI to insights
2. Store user feedback on patterns
3. Adjust confidence based on feedback
4. Learn from rejected patterns

## Success Metrics

### Pattern Quality
- False positive rate <10%
- Pattern acceptance rate >70%
- Average confidence score >0.75

### User Engagement
- /insights usage daily
- Pattern validation weekly
- Streak maintenance >50% users

### System Performance
- Pattern detection <60s
- Insight generation <2s
- Storage growth <1MB/user/month

## Data Privacy & Control

### User Controls
- Export all patterns and insights
- Delete all intelligence data
- Disable pattern detection
- Mark patterns as private

### Data Retention
- Patterns expire after 90 days without reinforcement
- Rejected patterns deleted immediately
- Anonymous patterns never cross users

## Next Commands for Claude Code

### Immediate Task: Code Cleanup
```
Clean up the codebase for the unified intelligence approach:

1. Remove or comment out these commands/features:
   - /patterns command handler (keep the PatternsCommand class but don't expose to users)
   - /events display command (keep event extraction, remove display)
   - Any UI for viewing raw events/patterns

2. Simplify command list to only show:
   - /help - Command list
   - /context - Manage personal facts
   - /clear - Clear entries
   - /export - Export data
   - /insights - View intelligence (mark as "coming soon")

3. Clean up any test code or experimental features related to patterns/events viewing

4. Verify event extraction still works in background (it should)

Keep all the extraction logic (enrichments and events) - we're just removing the fragmented viewing commands.
```

### Next Task: Pattern Detection Foundation
```
Build the pattern detection engine foundation:

1. Create database migration:
   - intelligence_patterns table
   - user_streaks table

2. Create PatternDetectionService with methods:
   - detectTemporalPatterns(): Hour/day patterns
   - detectCausalChains(): A→B sequences
   - updateStreaks(): Track consecutive events
   - detectCorrelations(): People/emotion/theme connections

3. Create batch job that runs hourly:
   - Fetch last 30 days of enrichments + events
   - Run all pattern detection methods
   - Store new patterns (check signature for duplicates)
   - Update pattern confidence scores

Start with simple temporal patterns (morning = anxious) and basic streaks (exercise days).
```

## Design Principles

### Intelligence Should Be:
1. **Unified**: One command to rule them all
2. **Connected**: Show relationships, not isolated data
3. **Actionable**: Every insight should suggest action
4. **Trustworthy**: High confidence, low false positives
5. **Personal**: Learn each user's unique patterns

### Intelligence Should Not:
1. Create anxiety about patterns
2. Over-interpret normal variation
3. Make users feel surveilled
4. Require configuration
5. Show raw data without context

## End Goal

User types `/insights` and sees:

"Good morning! You're on a 5-day exercise streak 🔥. Today matches your high-energy Tuesday pattern. Heads up: meetings with Sarah tend to run long (avg 2hrs) - you have one at 2pm. Your morning run yesterday led to great focus, matching your usual pattern. Sleep was light (5hrs) which typically means you'll want extra coffee, but try to stop before 2pm for better tomorrow."

This is intelligence that actually helps.
