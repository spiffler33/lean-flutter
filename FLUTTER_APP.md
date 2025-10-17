# Lean Flutter - Native Mobile Rebuild

## Philosophy: Steve Jobs Frictionless
Type → Save → Search. Zero chrome, zero friction, zero compromises.

**What we're building**: Native mobile app that feels instant, works offline, respects minimalism. Input always focused. <100ms saves. ASCII aesthetic. Clean, powerful, yours.

**Why Flutter over PWA**:
- Full screen (no browser chrome eating 15%)
- True native keyboard control
- Reliable background sync
- Deep system integration
- Consistent behavior (iOS = Android)
- Professional app experience

**What we're NOT building**:
- App Store presence (just a link to install)
- Multi-user features
- Cloud-first architecture
- Complex animations
- Feature bloat

---

## Effort Estimate

### Core Flutter Migration (Phase 1-3)
**~40-60 hours** | Backend agent + Frontend agent
- Project setup & Supabase SDK: 4-6h
- Core UI (input, entries, save): 12-16h
- Commands system (/search, /today, etc.): 8-10h
- Todo checkboxes & counter: 4-6h
- Time dividers & themes: 6-8h
- Export & stats: 4-6h
- Testing & polish: 8-12h

### LLM Prompt Engineering (Phase 4)
**~15-25 hours** | AI agent
- Context extraction improvement: 8-12h
- Multi-model support (Claude/Gemini/local): 4-6h
- Enrichment UI polish: 3-5h
- Testing & fine-tuning: 4-6h

### Whisper Voice Input (Optional Phase 5)
**~20-30 hours** | Backend agent + Frontend agent
- iOS/Android audio recording: 6-8h
- Whisper API integration: 4-6h
- Edit-before-enrich flow: 6-8h
- Voice button UI: 2-3h
- Testing both platforms: 6-9h

**Total Estimate**: 75-115 hours (core + LLM + Whisper)
**Without Whisper**: 55-85 hours

---

## Implementation Plan

### Phase 0: Branch & Setup [Backend Agent]
- Create `flutter-rebuild` branch
- Install Flutter SDK (verify `flutter doctor`)
- Create Flutter project: `flutter create lean_flutter`
- Add Supabase Flutter SDK to `pubspec.yaml`
- Configure for web + iOS + Android deployment
- Set up folder structure (lib/screens, lib/widgets, lib/services)

### Phase 1: Core Architecture [Backend Agent → Frontend Agent]
**Backend Agent**:
- Supabase service layer (auth, entries CRUD, sync)
- Local SQLite fallback (offline-first with `sqflite`)
- State management (Provider or Riverpod for simplicity)

**Frontend Agent**:
- Main screen: TextField (always focused) + Entry list
- Optimistic UI: instant save + green flash
- Entry widget: ASCII checkboxes (□/☑), tap to toggle
- Character counter, time dividers

### Phase 2: Commands & Features [Frontend Agent]
- Command parser: detect `/search`, `/today`, `/essay`, etc.
- Search & filtering (tags, dates)
- Export modal (markdown download)
- Stats modal (entry counts, streaks)
- Theme switcher (5 minimal themes)
- Keyboard shortcuts (hardware keyboard support)

### Phase 3: Mobile Polish [Design Agent → Frontend Agent]
**Design Agent**: Audit mobile UX, create guidelines for:
- Touch targets (44x44pt minimum)
- Gesture controls (swipe to delete?)
- FAB or bottom bar for commands
- Input handling (mobile keyboard dismiss)

**Frontend Agent**: Implement design specs
- Responsive layouts (narrow screens)
- Platform-specific behaviors (iOS vs Android)
- Smooth animations (hero transitions?)
- Error states & empty states

### Phase 4: LLM Intelligence [AI Agent]
- Improve prompt engineering (better context extraction)
- Multi-model support: Claude API, Gemini, Ollama
- Enrichment badges (⚡ visual indicator)
- Background enrichment queue
- Settings: enable/disable, model selection

### Phase 5: Whisper Voice (Optional) [Backend Agent + Frontend Agent]
**Backend Agent**:
- Whisper API integration (OpenAI or local)
- Audio file handling & transcription
- Error handling (network, permissions)

**Frontend Agent**:
- Voice button UI (hold to record?)
- Audio recording (platform audio capture)
- Edit-then-enrich flow: transcribe → show in input → user edits → save → optionally enrich

---

## Critical Constraints (Non-Negotiable)

1. **Speed**: Save in <100ms, UI responds instantly
2. **Offline**: Full functionality without network
3. **Simplicity**: No loading spinners, no complexity
4. **ASCII Aesthetic**: □ ☑ ━━━ minimal characters
5. **Frictionless**: Input focused on launch, Enter = save
6. **Data Ownership**: Export to markdown anytime
7. **No Bloat**: Every feature must justify its existence

---

## Agent Assignment Summary

- **Backend Agent**: Supabase, SQLite, sync, audio/Whisper APIs
- **Frontend Agent**: UI, widgets, screens, keyboard handling
- **Design Agent**: Mobile UX audit, touch targets, gesture design
- **AI Agent**: Prompt engineering, enrichment, multi-model support

---

## Branch Strategy
- Main branch: Current PWA (stable)
- `flutter-rebuild`: New Flutter app (parallel development)
- Deployment: Flutter web hosted separately, mobile as direct install link
- No app stores (sideload or TestFlight/Firebase for testing)

---

## Success Metrics
- [ ] App launches in <1 second
- [ ] Save happens in <100ms
- [ ] Works fully offline
- [ ] Zero crashes in 1-week dogfooding
- [ ] Input always focused on fresh launch
- [ ] LLM enrichment feels magical (not janky)
- [ ] Voice input transcribes accurately, edits before save
- [ ] You feel proud showing this to others

---

## Progress Tracking

### ✅ Phase 0: Complete (2025-10-17)
- [x] Created `flutter-rebuild` branch
- [x] Installed Flutter SDK 3.35.6
- [x] Created Flutter project with full platform support
- [x] Added Supabase + SQLite + Provider dependencies
- [x] Set up folder structure (models, services, screens, widgets)
- [x] Commit: `14b421b - Phase 0 Complete`

### ✅ Phase 1: Complete (2025-10-17)
**Backend** (2 hours):
- [x] Entry model with full schema (tags, actions, emotion, themes, people, urgency)
- [x] DatabaseService: SQLite with sqflite (CRUD, search, todos, sync tracking)
- [x] SupabaseService: Auth + CRUD with RLS ready
- [x] EntryProvider: State management with optimistic UI + background sync
- [x] Commits: `5c658ad` (backend), `e8c63e3` (UI)

**Frontend** (done):
- [x] HomeScreen: Input box (always focused) + Entry list
- [x] EntryWidget: ASCII checkboxes (□/☑), relative timestamps, indicators
- [x] Optimistic UI: Instant saves (<100ms to SQLite)
- [x] Green success toast on save
- [x] Entry count in header
- [x] Light/dark themes (monospace aesthetic)

**What Works**:
- Create entries (Enter to save, <100ms)
- Display entries (newest first)
- Todo detection (#todo, #done)
- Offline-first (100% functional without network)
- Background sync ready (10s intervals)

**UI Redesign (2025-10-17):**
- [x] Extracted EXACT colors/styling from original PWA (index.html + lean.css)
- [x] Created AppTheme with dark navy (#111) background
- [x] Beautiful pill-shaped AI badges (emotion, themes, people, urgency)
- [x] "L  E  A  N" header with ━━━━━━━━━ line
- [x] "What's on your mind?" placeholder
- [x] Dark entry cards (#1A1A1A) with 8px radius
- [x] Commit: `b9fafdf - REDESIGN COMPLETE`
- ✅ **App now looks as beautiful as the original!** 🎨

**Not Yet Done**:
- Search/commands UI
- Edit/delete entries
- Export functionality
- Supabase connection (needs credentials)
- Time dividers
- Theme switcher UI

### 🔲 Phase 2: Commands & Features (Next)
- [ ] Command parser (/search, /today, /export)
- [ ] Search UI
- [ ] Edit/delete functionality
- [ ] Export modal
- [ ] Stats modal
- [ ] Theme switcher
- [ ] Connect Supabase for real sync

### 🔲 Phase 3: Mobile Polish (Pending)
### 🔲 Phase 4: LLM Intelligence (Pending)
### 🔲 Phase 5: Whisper Voice (Optional)

---

**Current Status**: Phase 1 complete, ready for Phase 2
**Next Step**: Implement search/commands or connect Supabase sync
