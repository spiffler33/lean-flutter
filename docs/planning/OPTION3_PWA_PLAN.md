# Option 3: Lean v2 - Local-First PWA with Optional Sync

## Executive Summary
Transform Lean into a modern local-first PWA that:
- ✅ Works 100% offline (preserves core philosophy)
- ✅ Optionally syncs across devices (shareability)
- ✅ Perfect mobile experience (PWA)
- ✅ Monetizable (freemium model)
- ✅ Voice-ready architecture (future)

## Recommended Architecture: **PocketBase + Static PWA**

### Why This Stack?
1. **PocketBase Backend**: Go-based, single binary, SQLite-backed, real-time sync built-in
2. **Static PWA Frontend**: Vanilla JS/TypeScript, works offline, deploys free on Vercel
3. **IndexedDB**: Local storage on device (matches your current SQLite approach)
4. **Freemium Model**: Free = local-only, Pro = sync + cloud backup

---

## Implementation Plan

### **PHASE 1: Static PWA Foundation** (2-3 weeks)
Convert current Lean to offline-first PWA without backend dependency.

**Architecture:**
```
index.html (entry point)
├── src/
│   ├── lib/
│   │   ├── db.ts           # IndexedDB wrapper (replaces SQLite)
│   │   ├── storage.ts      # Local storage utilities
│   │   └── export.ts       # Client-side markdown export
│   ├── components/
│   │   ├── EntryInput.ts   # Smart input component
│   │   ├── EntryList.ts    # Entry rendering
│   │   └── Modal.ts        # Stats/Export modals
│   ├── app.ts              # Main app logic (port from current JS)
│   └── sw.ts               # Service Worker (offline support)
├── public/
│   ├── manifest.json       # PWA manifest
│   └── icons/              # App icons (512x512, etc.)
└── vite.config.ts          # Build tool
```

**Key Tasks:**
1. ✅ Port current UI to work with IndexedDB instead of SQLite
2. ✅ Add Service Worker for offline caching
3. ✅ Create PWA manifest for mobile installation
4. ✅ Keep ALL current features (search, tags, export, stats, commands)
5. ✅ Maintain <100ms save speed
6. ✅ Deploy to Vercel (static site, free tier)

**Output:** Lean works 100% offline, installable on mobile, no backend needed

---

### **PHASE 2: PocketBase Sync Backend** (2-3 weeks)
Add optional cloud sync for multi-device use.

**PocketBase Setup:**
```javascript
// Collections (like SQLite tables)
entries {
  user: relation(users)       // Multi-user support
  content: text
  created_at: datetime
  tags: json
  mood: text
  actions: json
  themes: json
  people: json
  urgency: text
  synced: boolean
}

user_facts {
  user: relation(users)
  fact_text: text
  fact_category: text
  active: boolean
}
```

**Sync Engine:**
```typescript
class SyncEngine {
  // 1. Push local changes to cloud
  // 2. Pull remote changes
  // 3. Resolve conflicts (last-write-wins)
  // 4. Real-time subscriptions
}
```

**Auth Options:**
- Magic link (passwordless, simple)
- OAuth (Google, GitHub)
- Guest mode (no signup, local-only)

**Deployment:**
- Self-host PocketBase (Fly.io, Railway)
- OR use PocketHost (managed PocketBase, $10-30/mo)

**Output:** Users can optionally sign in to sync across devices

---

### **PHASE 3: Mobile Polish** (1-2 weeks)
Perfect the mobile experience.

**Mobile Optimizations:**
1. ✅ Touch targets: 44x44px minimum
2. ✅ Swipe gestures (swipe-to-delete entries)
3. ✅ Pull-to-refresh
4. ✅ Haptic feedback on actions
5. ✅ iOS-specific PWA tags
6. ✅ Keyboard optimization (auto-capitalize, smart punctuation)

**Testing:**
- Install as PWA on iOS (Home Screen)
- Install as PWA on Android
- Test offline scenarios
- Test sync across devices

**Output:** Lean feels native on mobile

---

### **PHASE 4: Ollama Integration Strategy**
Handle the local LLM features in new architecture.

**Options:**
1. **Browser-only AI** (No Ollama dependency)
   - Use local pattern matching (your fallback functions work well)
   - Add optional Claude API integration (pro feature)
   - Simpler for users, works everywhere

2. **Hybrid approach**
   - Free tier: Pattern matching only
   - Pro tier: Cloud AI (Claude API)
   - Self-hosted: Ollama integration (advanced users)

**Recommendation:** Start with #1, add #2 as pro feature

---

### **PHASE 5: Voice Integration** (Future)
Add voice-first entry creation.

**Web Speech API:**
```typescript
// Voice recording
const recognition = new webkitSpeechRecognition();
recognition.continuous = true;
recognition.interimResults = true;

// Voice commands
"New entry" → Start recording
"Save" → Save entry
"Search for work" → Filter entries
```

**Smart Features:**
- Extract #tags from speech
- Detect intent (entry vs command)
- Natural language parsing

**Output:** Speak to capture thoughts

---

### **PHASE 6: Monetization & Launch**

**Freemium Model:**

| Feature | Free (Local) | Pro ($5/mo or $50/yr) |
|---------|--------------|----------------------|
| Unlimited entries | ✅ | ✅ |
| Works offline | ✅ | ✅ |
| Sync across devices | ❌ | ✅ |
| Cloud backup | ❌ | ✅ |
| AI features (Claude) | ❌ | ✅ |
| Voice input | ❌ | ✅ |
| Export to write.as | ✅ | ✅ |
| Theme support | ✅ | ✅ |

**Self-Hosted Option:** $99 one-time
- Complete source code
- PocketBase setup guide
- Docker compose file
- Your own domain

**Payment:** Stripe subscriptions

**Distribution:**
- Web: lean.app (Vercel free tier)
- iOS: Submit PWA (via PWA builder)
- Android: Trusted Web Activity (Google Play)

**Marketing:**
- Product Hunt launch
- Show HN (Hacker News)
- Twitter/X threads about local-first philosophy
- Blog: "Why local-first matters"

---

## Timeline & Milestones

**Month 1-2:** Phase 1 (PWA Foundation)
- Week 1-2: Set up project, IndexedDB, core features
- Week 3-4: Port all features, test offline, deploy

**Month 2-3:** Phase 2 (Sync Backend)
- Week 5-6: PocketBase setup, auth flow
- Week 7-8: Sync engine, conflict resolution, testing

**Month 3-4:** Phase 3-4 (Mobile + Polish)
- Week 9-10: Mobile optimizations, PWA perfection
- Week 11-12: AI strategy, payment integration

**Month 4-5:** Phase 6 (Launch)
- Week 13-14: Marketing prep, beta testing
- Week 15-16: Public launch, iterate on feedback

**Future:** Voice (Phase 5) based on user demand

---

## Technical Decisions

### Build Tools
- **Vite**: Fast, modern, great for PWAs
- **TypeScript**: Type safety, better DX
- **Dexie.js**: Excellent IndexedDB wrapper

### Database
- **Local**: IndexedDB (via Dexie)
- **Backend**: PocketBase (SQLite)
- **Sync**: Real-time subscriptions

### Hosting
- **Frontend**: Vercel (free)
- **Backend**: Fly.io or PocketHost ($10-30/mo)

### Dependencies (Minimal)
```json
{
  "dexie": "^3.x",           // IndexedDB
  "pocketbase": "^0.x",      // Sync client
  "marked": "^x",            // Markdown (export)
  "fuse.js": "^x"            // Search
}
```

---

## Why This Approach Wins

### ✅ Preserves Lean's Core Values
- Speed unchanged (<100ms saves)
- Works offline always
- Privacy by default (local-first)
- Simple, focused UX

### ✅ Enables Growth
- Multi-user ready
- Mobile-first
- Shareable
- Monetizable

### ✅ Modern Stack
- PWA = install anywhere
- PocketBase = simple backend
- Local-first = competitive advantage

### ✅ Sellable Product
- Clean architecture
- Growing market (Obsidian, Notion, Linear all successful)
- Clear value proposition

---

## Next Steps

1. **Create new repo**: `lean-v2` or `lean-pwa`
2. **Set up Vite + TypeScript project**
3. **Port core features to IndexedDB**
4. **Build PWA foundation**
5. **Deploy to Vercel**
6. **Test with friends** (beta testers)
7. **Add PocketBase sync** (when ready for multi-device)
8. **Launch!**

---

## Key Questions to Consider

1. **Timeline**: Want to move fast or take time to perfect each phase?
2. **AI Strategy**: Keep Ollama (complex) or move to Claude API (simple)?
3. **Pricing**: $5/mo feel right? Or $3/mo to start?
4. **Self-hosted**: Include from day 1 or add later?
5. **Voice**: Priority feature or nice-to-have?

---

## Alternative Approaches to Research

Before committing, you may want to explore:

1. **Supabase instead of PocketBase** (more mature, PostgreSQL-based)
2. **ElectricSQL** (local-first sync, cutting edge)
3. **Pure P2P sync** (no central server, via WebRTC)
4. **Tauri** (desktop app instead of web)
5. **Capacitor** (native iOS/Android instead of PWA)

Each has tradeoffs. PocketBase recommended for simplicity + SQLite compatibility.

---

*Saved: 2025-10-15*
*Status: Option under consideration*
