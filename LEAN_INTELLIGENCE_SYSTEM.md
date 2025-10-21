# LEAN INTELLIGENCE SYSTEM - Implementation Specification

## Executive Summary

Build a privacy-first, local intelligence layer for Lean that extracts structured insights from unstructured thoughts. The system learns user patterns without requiring configuration, extracts trackable events conservatively, and surfaces meaningful connections between thoughts, people, and behaviors.

## System Architecture

### Core Components

**Entry Pipeline**
- User types entry → Save to DB instantly (<100ms)
- Trigger async enrichment pipeline
- Display enrichment status (⚡ processing → ✓ complete)
- Store raw entry + enrichments separately

**Intelligence Layers**
1. **Tier 1 (Universal)** - Applied to 100% of entries
2. **Tier 2 (Event)** - Applied when confidence ≥0.85
3. **Tier 3 (Patterns)** - Computed from accumulated data
4. **Tier 4 (Insights)** - Higher-order connections

**Storage Strategy**
- Raw entries: Immutable source of truth
- Enrichments: JSONB fields, versioned
- Patterns: Materialized views, refreshed hourly
- Events: Separate table with entry linkage

## Data Models

### Entry Enrichments Table
```
enrichments
- id: UUID (primary)
- entry_id: UUID (references entries)
- emotion: TEXT (constrained vocabulary)
- themes: TEXT[] (max 3, constrained vocabulary)
- people: JSONB (name + context per person)
- urgency: TEXT (low/medium/high)
- actions: TEXT[] (extracted todos/needs)
- questions: JSONB (open questions detected)
- decisions: JSONB (decision points detected)
- confidence_scores: JSONB (per-field confidence)
- enrichment_version: TEXT
- created_at: TIMESTAMP
```

### Events Table
```
events
- id: UUID (primary)
- user_id: UUID
- entry_id: UUID (source entry)
- type: TEXT (exercise/consumption/spend/sleep/meeting/etc)
- subtype: TEXT (squat/coffee/groceries/etc)
- metrics: JSONB (weight_kg, distance_km, amount, duration_min, etc)
- context: JSONB (people present, location, work-related, etc)
- confidence: FLOAT
- extraction_method: TEXT (metrics/vlp/perfective)
- user_validated: BOOLEAN
- created_at: TIMESTAMP
```

### Validated Logger Phrases (VLP)
```
vlps
- id: UUID
- user_id: UUID
- phrase: TEXT
- phrase_normalized: TEXT
- event_type: TEXT
- usage_count: INTEGER
- first_seen: TIMESTAMP
- last_promoted: TIMESTAMP
- user_action: TEXT (validated/rejected/null)
- variations: TEXT[]
```

### Person Entities
```
person_entities
- id: UUID
- user_id: UUID
- name: TEXT
- name_normalized: TEXT
- relationship: TEXT (manager/colleague/friend/family/client)
- sentiment_scores: JSONB (track per-mention sentiment)
- contexts: TEXT[] (work/personal/social)
- interaction_types: TEXT[] (meeting/feedback/conflict/collaboration)
- mention_count: INTEGER
- first_mention: TIMESTAMP
- last_mention: TIMESTAMP
```

### Patterns Tables

**Temporal Patterns**
```
temporal_patterns
- user_id: UUID
- time_block: TEXT (morning/afternoon/evening/night)
- day_type: TEXT (weekday/weekend)
- dominant_emotion: TEXT
- dominant_themes: TEXT[]
- entry_frequency: FLOAT
- pattern_confidence: FLOAT
```

**Causal Patterns**
```
causal_patterns
- user_id: UUID
- trigger_type: TEXT
- trigger_pattern: JSONB
- outcome_type: TEXT
- outcome_pattern: JSONB
- timeframe: TEXT (0-2h/2-6h/6-24h/1-3d)
- occurrence_count: INTEGER
- confidence: FLOAT
- last_observed: TIMESTAMP
```

**User Context**
```
user_facts
- user_id: UUID
- category: TEXT (work/personal/people/location)
- fact: TEXT
- entity_refs: TEXT[] (linked entities)
- added_at: TIMESTAMP
- active: BOOLEAN
```

## Intelligence Pipeline

### Stage 1: Entry Processing (Synchronous)
1. Save raw entry
2. Return success immediately
3. Queue enrichment job

### Stage 2: Tier 1 Enrichment (Async, <3s)

**Emotion Detection**
- Vocabulary: frustrated, anxious, excited, content, calm, energized, tired, sad, angry, overwhelmed, focused, grateful, contemplative, curious, scattered, accomplished, lonely, bored, neutral
- Method: LLM with fallback to keyword patterns
- Constraints: Single emotion per entry

**Theme Classification**
- Vocabulary: work, personal, health, relationships, finance, creative, tech, learning, leisure, reflection
- Method: LLM with fallback to keyword matching
- Constraints: Maximum 3 themes, ordered by relevance

**People Extraction**
- Method: NER + capitalization patterns + user context
- Enhancement: Track sentiment about person in this entry
- Store: Name + sentiment + context of mention

**Urgency Detection**
- Levels: low, medium, high
- Signals: Time markers, action words, emotional intensity
- Method: Rule-based + LLM validation

**Action Extraction**
- Patterns: "need to", "must", "todo:", "should", "have to"
- Method: Regex + LLM validation
- Output: Array of actionable items

**Question Detection**
- Types: open-ended, yes/no, rhetorical
- Method: Punctuation + sentence structure + LLM
- Track: Question lifecycle (open → answered)

### Stage 3: Tier 2 Event Extraction (Async, <5s)

**Confidence Calculation**
- Base signals:
  - Numbers + units: +0.50
  - Numbers + domain words: +0.35
  - Perfective past tense: +0.25
  - Time duration: +0.25
  - VLP match: +0.30
  - Main clause position: +0.15
- Negative signals:
  - Intent modals (should/planning): -0.50
  - Background subordinators: -0.35
  - Hedges (maybe/might): -0.20

**Extraction Thresholds**
- Extract: confidence ≥ 0.85
- Shadow (learn but don't save): 0.65-0.85
- Ignore: <0.65

**Event Types**
- exercise (subtypes: squat, run, walk, yoga, swim, bike, weights)
- consumption (subtypes: alcohol, caffeine, food, supplements)
- spend (subtypes: groceries, transport, entertainment, bills)
- sleep (metrics: duration, quality)
- meeting (subtypes: 1:1, team, client, interview)
- health (subtypes: symptom, medication, appointment)

### Stage 4: Pattern Detection (Batch, hourly)

**VLP Promotion**
- Trigger: Phrase used 3+ times in 28 days
- Validation: Check for consistency in context
- Auto-promote: If confidence >0.90
- User-promote: Present in UI for confirmation

**Person Relationships**
- Analyze co-occurrence with themes/contexts
- Infer relationship type from interaction patterns
- Calculate average sentiment
- Track interaction frequency

**Temporal Patterns**
- Segment by: hour blocks, day of week
- Calculate: dominant emotions, themes, entry frequency
- Identify: Peak productivity, stress times, reflection periods

**Causal Chains**
- Window: Look for patterns within time windows
- Correlation: Track A→B occurrences
- Threshold: Minimum 3 occurrences for pattern
- Types: stress→coping, activity→mood, trigger→behavior

### Stage 5: Insight Generation (Batch, daily)

**Cross-Pattern Analysis**
- People + emotion correlations
- Time + theme patterns
- Event + outcome chains
- Question → answer paths

**Anomaly Detection**
- Unusual emotion for time period
- Break in established patterns
- New people/contexts appearing
- Urgency spikes

## User Experience

### Entry Flow
1. User types entry
2. Instant save (<100ms)
3. Lightning icon appears (enriching)
4. Check mark appears (2s, then fades)
5. Enrichments silently added to entry

### Command Enhancements

**/context** - Manage user facts
- `/context add [fact]` - Add context
- `/context list` - Show all facts
- `/context remove [id]` - Remove fact
- Categories: work, personal, people, location

**/patterns** - View learned patterns
- Show VLPs with usage count
- Display people relationships
- Reveal temporal patterns
- Surface causal chains
- One-tap validation/rejection

**/events** - View tracked events
- Filter by type/date/person
- Show confidence scores
- Enable bulk validation
- Export to CSV

**/insights** - Higher-order patterns
- Weekly emotion trends
- People correlation insights
- Habit formation tracking
- Question resolution paths

### Pattern Validation UI

**For VLP Detection**
```
💡 Pattern detected: "leg day!" (used 3 times)
Track this as: [Exercise - Leg workout]
[Always track] [Never track] [Ask later]
```

**For Causal Patterns**
```
🔗 Pattern noticed: "stressful meeting" → "whiskey" (within 6 hours)
This happened 4 times in the past month.
[Acknowledge] [Not a pattern] [Show details]
```

### Privacy Controls

**/intelligence** - Manage intelligence settings
- Toggle extraction layers on/off
- Set confidence thresholds
- Clear learned patterns
- Export all intelligence data
- Delete all enrichments

## LLM Integration

### Model Selection
- Primary: Claude 3.5 Sonnet (via Supabase Edge Functions)
- Fallback: Pattern-based extraction (built into Edge Function)
- Constraints: Single API call per entry via serverless function

### Architecture: Supabase Edge Functions Approach

**Why Edge Functions:**
1. **Security**: API keys stored server-side, never exposed to client
2. **Cost Control**: Central API key management, usage monitoring
3. **Performance**: Edge locations for low latency
4. **Reliability**: Built-in fallback when API fails
5. **Scalability**: Serverless auto-scaling

**Implementation:**
```typescript
// /supabase/functions/enrich-entry/index.ts
- Deployed as Supabase Edge Function
- Handles Claude API calls securely
- Returns enrichment or fallback mock data
- Processes in <3s with timeout handling
```

**Client Integration:**
```dart
// Flutter app calls Edge Function
final response = await supabase.functions.invoke(
  'enrich-entry',
  body: {
    'entryText': entry.content,
    'entryId': entry.id,
    'userContext': userFacts, // User's context facts
  }
);
```

### Prompt Engineering

**Current Tier 1 Enrichment Prompt (Production)**
1. User context facts (if any) passed as system context
2. Constrained vocabularies for each field
3. Entry text for analysis
4. JSON schema enforcement
5. Critical instructions to prevent false extractions (especially people names)

**Edge Function Fallback Logic**
- If Claude API fails → return mock enrichment
- Mock uses keyword detection for basic accuracy
- Ensures zero downtime for enrichment pipeline

### Response Parsing
- Edge Function validates JSON response
- Transforms to Flutter-compatible format
- Falls back to mock on parse failure
- Returns success/failure status with enrichment

## Testing Strategy

### Unit Tests
- Emotion detection accuracy
- Theme classification precision
- Event extraction confidence calculation
- VLP promotion logic
- Pattern detection algorithms

### Integration Tests
- Full pipeline processing
- LLM fallback handling
- Database transaction integrity
- Pattern batch processing

### User Acceptance Criteria
- Tier 1 accuracy >85%
- Event extraction precision >90%
- VLP false positive rate <5%
- Pattern relevance >80%
- Processing time <3s for Tier 1, <5s total

## Rollout Plan

### ✅ Phase 1: Foundation (COMPLETED - 2025-10-21)
- ✅ Database schema setup (Supabase + SQLite)
- ✅ Basic enrichment pipeline (queue-based processing)
- ✅ Tier 1 extraction with REAL Claude API (emotion, themes, people, urgency)
- ✅ Visual indicators (⚡ processing → ✅ complete)
- ✅ Enrichment model with all fields from spec
- ✅ Service layer with background processing
- ✅ /context command implementation (add, list, remove, clear)
- ✅ Supabase Edge Functions for secure LLM integration
- ✅ Context persistence across sessions - FIXED

**What's Working:**
- Real-time AI enrichment using Claude 3.5 Sonnet via Edge Functions
- Accurate sentiment detection (contemplative, positive, energized, etc.)
- Smart topic categorization (family, health, work, relationships)
- Reliable people extraction (Mom, Dad, Samantha, Emma, Robert, Chen)
- Priority level assignment based on content
- /context commands persist data across sessions
- Enrichments display as colored tags on entries
- Processing completes in ~2-3 seconds
- Fallback to mock enrichment if API fails

**Live Features:**
- **Sentiment Tags**: Green (positive), Red (negative/anxious), Gray (neutral)
- **Topic Tags**: Blue/Indigo (work, family, health, relationships)
- **People Tags**: Orange/Amber (extracted names)
- **Priority Tags**: Red (high), Orange (medium), Gray (low)
- **/context Command**: Store facts about yourself that enhance AI analysis
  - `/context add I work at Google` - Add personal context
  - `/context list` - View all stored facts
  - `/context remove [id]` - Remove specific fact
  - `/context clear` - Clear all facts

**Fixed Issues:**
- ✅ Context persistence on refresh/restart (loads from Supabase on init)
- ✅ Supabase sync for enrichments and user facts
- ✅ Proper session restoration with context loading

### 🔲 Phase 2: Event Intelligence (Week 3-4)
- Event extraction with confidence scoring
- VLP detection and promotion
- /events command
- Shadow mode for learning

### 🔲 Phase 3: Pattern Recognition (Week 5-6)
- Temporal pattern detection
- Person relationship inference
- Causal chain identification
- /patterns command with validation UI

### 🔲 Phase 4: Advanced Intelligence (Week 7-8)
- Question tracking
- Decision detection
- Insight generation
- /insights command

### 🔲 Phase 5: Optimization (Week 9-10)
- Confidence calibration from user feedback
- Prompt optimization
- Performance tuning
- Privacy controls UI

## Success Metrics

### Accuracy Metrics
- Tier 1 extraction accuracy: >85%
- Event precision: >90%
- VLP validation rate: >70%
- Pattern acceptance rate: >60%

### Performance Metrics
- Enrichment latency: <3s (p95)
- Pattern computation: <60s (hourly batch)
- API cost: <$0.001 per entry

### User Value Metrics
- Insights discovered per user per month: >3
- Pattern validation actions: >1 per week
- Event tracking adoption: >40% of users
- Context facts added: >5 per user

## Configuration

### Environment Variables
```
ANTHROPIC_API_KEY - Claude API access
INTELLIGENCE_ENABLED - Master toggle
DEFAULT_CONFIDENCE_THRESHOLD - Event extraction threshold (0.85)
PATTERN_BATCH_INTERVAL - Pattern detection frequency (3600s)
VLP_PROMOTION_THRESHOLD - Usage count for auto-promotion (3)
VLP_PROMOTION_WINDOW - Time window for usage (28 days)
```

### Feature Flags
- TIER1_ENRICHMENT - Enable basic enrichment
- TIER2_EVENTS - Enable event extraction
- VLP_DETECTION - Enable phrase learning
- PATTERN_DETECTION - Enable pattern recognition
- CAUSAL_CHAINS - Enable causal analysis
- INSIGHT_GENERATION - Enable insight creation

## Security & Privacy

### Data Handling
- All processing happens on user's data only
- No cross-user pattern detection
- User can delete all intelligence data
- Export includes all extracted intelligence

### API Security
- API keys stored encrypted
- Rate limiting per user
- Fallback to local processing
- No PII in logs

## Maintenance

### Monitoring
- Track extraction accuracy weekly
- Monitor API costs daily
- Review failed extractions
- Analyze user validation patterns

### Iteration
- Weekly prompt optimization based on failures
- Monthly vocabulary updates based on usage
- Quarterly pattern algorithm improvements
- Continuous confidence threshold tuning

## Edge Cases

### Handle These Scenarios
- Entries in multiple languages
- Code snippets in entries
- Very long entries (>1000 chars)
- Rapid successive entries
- Offline mode (no API access)
- Users with 10k+ entries
- Timezone changes
- Data export/import cycles

## Implementation Notes

### Critical Principles
1. **Never block entry saving** - Intelligence is always async
2. **Fail gracefully** - Always have fallback extraction
3. **User control** - Every pattern can be rejected
4. **Privacy first** - No data leaves user's control
5. **Conservative extraction** - High precision over recall
6. **Learn from usage** - Patterns improve with feedback
7. **Transparent intelligence** - Show confidence and reasoning

### Development Sequence (Actual Progress)
1. ✅ Build data models (Enrichment class with all fields)
2. ✅ Implement Tier 1 pipeline (queue-based async processing)
3. ✅ Add LLM integration with fallbacks (Claude API via Edge Functions)
4. ✅ Create /context command (user facts management)
5. ✅ Fix session persistence and restoration
6. ✅ Deploy enrichment system to production
7. 🔲 Add /patterns command interface
8. 🔲 Create VLP detection system
9. 🔲 Build event extraction with confidence
10. 🔲 Add pattern detection batch jobs
11. 🔲 Implement validation UI
12. 🔲 Add privacy controls

## Implementation Details (Flutter/Dart)

### Database Schema Created
```sql
-- Supabase enrichments table
CREATE TABLE enrichments (
    id UUID PRIMARY KEY,
    entry_id UUID REFERENCES entries(id),
    user_id UUID REFERENCES auth.users(id),
    emotion TEXT,
    themes TEXT[],
    people JSONB,
    urgency TEXT DEFAULT 'none',
    actions TEXT[],
    questions JSONB,
    decisions JSONB,
    confidence_scores JSONB,
    enrichment_version TEXT DEFAULT '1.0',
    processing_status TEXT DEFAULT 'pending',
    processing_time_ms INTEGER,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Files Created/Modified
- `/lib/models/enrichment.dart` - Enrichment model with all fields
- `/lib/services/enrichment_service.dart` - Queue processing, mock enrichment
- `/lib/services/supabase_service.dart` - Added enrichment CRUD methods
- `/lib/services/database_service.dart` - Added local enrichments table
- `/lib/widgets/entry_widget.dart` - Visual status indicators, enriched badges
- `/lib/services/entry_provider.dart` - Auto-queue on entry save
- `/supabase/migrations/001_create_enrichments_table.sql` - Schema migration

### Mock Enrichment Detection (Current)
**Emotions:** happy/great → excited, sad/down → sad, stress/anxious → anxious
**Themes:** work/meeting → work, exercise/gym → health, money/budget → finance
**Urgency:** urgent/asap → high, soon/today → medium
**People:** Capitalized names (John, Sarah, etc.)

## Next Small Steps

### ✅ Phase 1 Complete! AI Enrichment is Live

The intelligence system is now operational with:
- Real-time Claude AI enrichment
- Persistent user context (/context command)
- Accurate extraction of sentiment, topics, people, and priority
- Beautiful tag-based visualization
- Session persistence and restoration

### Next Implementation: Phase 2 - Event Intelligence (2-3 hours)
1. **Add /patterns Command** (1 hour)
   - Display most common emotions/themes from enrichments
   - Show frequently mentioned people
   - Basic statistics view from enriched data
   - Timeline of sentiment trends

2. **Technology Extraction Enhancement** (30 min)
   - Update Edge Function prompt to extract technologies as separate field
   - Add blue tags for: Python, React, Kubernetes, etc.
   - Store in enrichment.technologies array

3. **Event Detection Foundation** (1-2 hours)
   - Detect quantifiable events: "ran 5km", "spent $50", "slept 7 hours"
   - Build confidence scoring engine
   - Create events table and model

### Phase 2: Event Intelligence (Next Week)
1. **Confidence Scoring Implementation**
   - Build confidence calculation engine
   - Implement extraction thresholds (≥0.85 for save)
   - Add shadow mode (0.65-0.85 for learning)

2. **Event Extraction**
   - Detect: exercise, consumption, spend, sleep, meetings
   - Extract metrics: duration_min, amount, distance_km
   - Store in events table with confidence scores

3. **VLP (Validated Logger Phrases)**
   - Track repeated phrases in entries
   - Auto-promote after 3 uses in 28 days
   - Build validation UI (accept/reject patterns)

### Phase 3: Pattern Recognition (Week 3-4)
1. **Temporal Patterns**
   - Analyze entry timing (morning/afternoon/evening)
   - Track emotion/theme patterns by time
   - Identify peak productivity periods

2. **Person Relationships**
   - Track sentiment when people are mentioned
   - Infer relationship types from context
   - Build interaction frequency heatmaps

3. **Causal Chains**
   - Detect A→B patterns (stress→coping, activity→mood)
   - Require 3+ occurrences for pattern confirmation
   - Surface insights to user

### Testing Checklist
- [x] Mock enrichment processes entries
- [x] Visual indicators work (⚡ → ✅)
- [x] Badges display enriched data
- [x] /context commands work (add/list/remove/clear)
- [x] Edge Function deployed and callable
- [x] Context facts persist after logout/login
- [x] Real LLM API returns valid enrichments
- [x] Enrichments sync to Supabase properly
- [x] Session restoration with context loading
- [x] Accurate sentiment detection
- [x] Proper people extraction
- [x] Topic categorization working
- [x] Priority level assignment
- [ ] /patterns command shows insights
- [ ] Event extraction with confidence scores
- [ ] VLP detection and promotion

This specification provides complete implementation guidance for building Lean's intelligence system from scratch, focusing on practical extraction, user trust, and meaningful insights.
