# PWA Mobile UX Issues - Critical Audit Needed

## Issue Status: BLOCKING MOBILE LAUNCH
Last Updated: 2025-10-16

## Critical Issues

### 1. AI Badges Not Showing on Mobile ❌ CRITICAL
**Status**: BROKEN - Tried everything (hard refresh, clear cache, logout/login)
**Impact**: Desktop shows badges, mobile shows nothing
**Root Cause**: Unknown - not CSS, possibly:
- Service worker caching old code
- IndexedDB entry format mismatch
- JavaScript bundle not loading correctly
**Next Steps**:
- Check if enrichment is even running on mobile (console logs)
- Verify service worker is updating
- Check if ai.ts is in mobile bundle

### 2. Time Divider Looks Horrible on Mobile 🚨
**Status**: NEEDS REDESIGN
**Issue**: Desktop-optimized design doesn't work on narrow screens
**Example**: "━━━━━━ Thursday, October 16, 4:56 pm ━━━━━━" wraps badly
**Fix Needed**:
- Shorter format for mobile
- Different character (· instead of ━)
- Responsive width calculation

### 3. Help Tooltip Says "Press Esc" on Mobile 🚨
**Status**: CONFUSING
**Issue**: Mobile has no Esc key, but help text says "Press Esc to close"
**Fix Needed**:
- Detect mobile and change text to "Tap anywhere to close"
- Or remove tooltip on mobile entirely
- Or add X button

### 4. FAB /theme Command Requires Typing 🚨
**Status**: POOR UX
**Issue**: Clicking /theme in FAB just types "/theme" into input box
**Expected**: Should show theme picker modal or submenu
**Fix Needed**:
- Create theme picker modal
- Or add submenu with theme options in FAB
- Don't make user type on mobile

### 5. General Mobile UI Audit Needed 🔍
**Not Started**
- Test all commands from FAB
- Test entry creation flow
- Test todo checkboxes on mobile
- Test search on mobile
- Test stats modal on mobile
- Test export modal on mobile
- Verify sync indicator works
- Check auth modal on mobile
- Test keyboard behavior

## Next Priority After Current Fix
Continue with existing todo list items:
- Optimize mobile entry experience (this audit)
- Add voice input UI (Whisper prep)
- Improve AI prompt engineering
