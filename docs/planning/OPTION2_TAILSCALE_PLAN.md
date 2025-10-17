# Option 2: Lean + Tailscale (Local-First with Live Sidecars)

## Architecture Overview

```
┌─────────────────┐         Tailscale        ┌──────────────────┐
│  Phone (PWA)    │◄──────── Mesh VPN ───────►│  Laptop/Desktop  │
│                 │      (encrypted p2p)      │                  │
│ - Capture fast  │                           │ - Ollama LLM     │
│ - IndexedDB     │                           │ - FastAPI        │
│ - Works offline │                           │ - SQLite         │
│ - Sync on save  │                           │ - Pattern DB     │
└─────────────────┘                           └──────────────────┘
      ↓                                              ↓
   Saves locally                            Enriches with AI
   immediately                              Returns sidecars
```

**What this feels like:**
- Type on phone → saves instantly (0ms)
- 1-3 seconds later → tags/mood/actions appear
- No internet needed (Tailscale works offline on same WiFi)
- Works anywhere (Tailscale tunnels through any network)

---

## Implementation Plan

### Phase 1: Mobile PWA (Week 1-2)
Build the capture interface that works 100% offline.

**Tech Stack:**
```
- Vanilla JS/TypeScript (keep it simple)
- IndexedDB (Dexie.js wrapper)
- Service Worker (offline-first)
- Vite (build tool)
```

**Key Features:**
- Input box → Enter → saved to IndexedDB
- All current Lean commands
- Search, tags, export
- Works 100% offline
- Install as PWA

**New: Sync Queue**
```typescript
// When online, push to laptop
class SyncQueue {
  async push(entry) {
    // Save locally first (instant)
    await db.entries.add(entry);

    // Queue for sync to laptop
    if (navigator.onLine) {
      await this.syncToLaptop(entry);
    }
  }

  async syncToLaptop(entry) {
    // Hit your Tailscale IP
    const response = await fetch('http://100.x.y.z:8000/sync', {
      method: 'POST',
      body: JSON.stringify(entry)
    });

    // Get back enriched version
    const enriched = await response.json();
    await db.entries.update(entry.id, enriched);
  }
}
```

### Phase 2: Laptop Backend (Week 2-3)
Enhance your existing `main.py` to work as Tailscale backend.

**Changes to main.py:**
```python
# Add CORS for your PWA
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # Local dev
        "http://100.*.*.*:3000",  # Tailscale network
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# New sync endpoint
@app.post("/sync")
async def sync_entry(entry: dict):
    """
    Receive entry from mobile, enrich with Ollama, return sidecars.
    """
    # Save to laptop's SQLite
    saved_entry = save_entry(entry)

    # Process with Ollama (background)
    enriched = await process_entry_with_llm(
        saved_entry['id'],
        saved_entry['content']
    )

    return enriched
```

**What you already have:**
- ✅ Ollama integration (working)
- ✅ Pattern learning (working)
- ✅ Context system (working)

**What you need to add:**
- Sync endpoint (30 lines)
- CORS middleware (5 lines)
- Mobile authentication (optional, later)

### Phase 3: Tailscale Setup (30 minutes)
Connect phone → laptop securely.

**On Laptop:**
```bash
# Install Tailscale
brew install tailscale

# Start service
sudo tailscale up

# Get your IP (e.g., 100.64.0.2)
tailscale ip -4
```

**On Phone:**
1. Install Tailscale app (iOS/Android)
2. Login with same account
3. Access laptop at `http://100.x.y.z:8000`

**Test:**
```bash
# On phone, open browser to:
http://100.64.0.2:8000

# Should see Lean desktop UI
```

### Phase 4: PWA Installation (Week 3-4)
Make it installable on phone.

**Create manifest.json:**
```json
{
  "name": "Lean",
  "short_name": "Lean",
  "description": "Private thought capture with live AI",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#fafafa",
  "theme_color": "#4CAF50",
  "icons": [
    {
      "src": "/icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

**Service Worker (sw.js):**
```javascript
// Cache static assets
const CACHE = 'lean-v1';
const FILES = ['/', '/index.html', '/style.css', '/app.js'];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE).then(cache => cache.addAll(FILES))
  );
});

// Serve from cache, fallback to network
self.addEventListener('fetch', (e) => {
  e.respondWith(
    caches.match(e.request).then(res => res || fetch(e.request))
  );
});
```

---

## Folder Structure (Reorganized)

```
lean/
├── backend/              # Your current main.py
│   ├── main.py          # Enhanced with /sync endpoint
│   ├── ai.py
│   ├── lean.db
│   └── requirements.txt
│
├── mobile/               # New PWA frontend
│   ├── public/
│   │   ├── manifest.json
│   │   ├── sw.js
│   │   └── icons/
│   ├── src/
│   │   ├── lib/
│   │   │   ├── db.ts           # IndexedDB
│   │   │   └── sync.ts         # Tailscale sync
│   │   ├── components/
│   │   │   ├── EntryInput.ts
│   │   │   └── EntryList.ts
│   │   └── main.ts
│   ├── index.html
│   ├── vite.config.ts
│   └── package.json
│
├── OPTION2_TAILSCALE_PLAN.md
└── README.md
```

---

## How Friends Use It

### Setup (One-time, 5 minutes)

**You send them:**
```
Hey! Want to try Lean?

1. Install Tailscale: https://tailscale.com/download
2. Join my network: [your invite link]
3. Open: http://100.64.0.2:3000
4. (Optional) "Add to Home Screen" on phone

That's it! Your data stays on your device + my laptop.
Nothing leaves my network.
```

**Their experience:**
- Works like any app
- Fast (your laptop does the AI)
- Private (Tailscale encrypted tunnel)
- No signup, no tracking

**When you're offline:**
- They can still capture (IndexedDB)
- Sidecars delayed until you're back
- Everything syncs when you reconnect

---

## Cost Breakdown

| Component | Cost |
|-----------|------|
| Tailscale | $0 (free up to 100 devices) |
| Hosting | $0 (your laptop) |
| Domain (optional) | $12/year |
| Ollama | $0 (local) |
| SSL/TLS | $0 (Tailscale handles) |
| **Total** | **$0-12/year** |

---

## Future Upgrades (Optional)

### Level 2: Always-On Mini Server
Replace laptop with $150 Intel NUC or Raspberry Pi at home.

**Pros:**
- Friends get 24/7 access
- Lower power consumption
- Dedicated hardware

**Setup:**
```bash
# On NUC/Pi
sudo apt install docker docker-compose
git clone your-lean-repo
docker-compose up -d
```

### Level 3: Multi-User
Add simple auth so friends have separate spaces.

```python
# main.py
from fastapi import Depends
from fastapi.security import HTTPBearer

security = HTTPBearer()

@app.post("/sync")
async def sync_entry(
    entry: dict,
    token: str = Depends(security)
):
    user_id = verify_token(token)
    # Save to user's DB
    save_entry(user_id, entry)
```

### Level 4: BYO-VPS
Help friends run their own instance.

**One-liner deploy:**
```bash
curl -sL lean.run | bash
# Asks for Tailscale key
# Deploys Docker container
# Done
```

---

## Timeline

### Week 1-2:
- ✅ Mobile PWA working offline
- ✅ Installable on phone
- ✅ Fast local capture

### Week 2-3:
- ✅ Tailscale connected
- ✅ Live sidecars (tags/mood/actions)
- ✅ Sync to laptop

### Week 3-4:
- ✅ Polish UX
- ✅ Invite 5-10 friends
- ✅ Collect feedback

### Week 4+:
- ✅ You're using it daily
- ✅ Friends love it
- ✅ Portfolio piece
- ✅ Deep learning
- ✅ Ready to scale if needed

---

## Street Cred Points

### For Tech Friends:
- "It's a PWA on Tailscale mesh VPN"
- "Zero-trust networking with WireGuard"
- "Client-side first, encrypted tunnel, local LLM"
- "No cloud, no surveillance, no vendor lock-in"

### For Non-Tech Friends:
- "It's like WhatsApp but for your thoughts"
- "Works offline, syncs when I'm online"
- "Your data never leaves my laptop"
- "Free, private, fast"

### For Yourself:
- Built a distributed system with zero ops
- Learned Tailscale/networking
- Solved real problem (thought capture)
- Portfolio piece that shows technical depth
- Actually use it daily

---

*Saved: 2025-10-15*
*Status: Option under consideration*
