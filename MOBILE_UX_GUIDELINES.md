# Lean Flutter - Mobile UX Guidelines

## Philosophy
Mobile-first, frictionless, instant. Every interaction should feel natural on a 4-6" touchscreen.

---

## 1. Touch Targets

### Minimum Sizes (Apple & Material Design Standards)
- **Minimum**: 44x44pt (iOS) / 48x48dp (Android)
- **Comfortable**: 48x48pt minimum for primary actions
- **Spacing**: 8pt minimum between targets

### Current Issues
- ✗ Checkbox tap area too small (text-based, ~16x16pt)
- ✗ Auth button too small (~30x20pt)
- ✗ Todo counter too small (~40x24pt)
- ✗ Edit/delete icons need larger hit areas

### Solutions
- ✓ Wrap all interactive text in `GestureDetector` with `behavior: HitTestBehavior.opaque`
- ✓ Add `padding` to expand hit area without changing visual size
- ✓ Minimum 48x48pt for all buttons/checkboxes
- ✓ Use `InkWell` or `Material` for visual feedback (ripple effect)

---

## 2. Gestures

### Swipe to Delete
- **Pattern**: Swipe left on entry → Shows delete button → Confirm tap to delete
- **Library**: Use `Dismissible` widget (built-in Flutter)
- **Direction**: Left swipe only (matches iOS Mail, Messages)
- **Visual**: Red background with trash icon revealed on swipe
- **Threshold**: 40% of width to trigger action

### Pull to Refresh (Future)
- Not needed yet (auto-sync handles this)
- Could add later for manual sync trigger

### Long Press
- **Entry**: Long-press entry → Show context menu (Edit, Delete, Copy)
- **Input box**: Long-press for paste/select (native behavior)

---

## 3. Keyboard Handling

### Current Issues
- ✗ Keyboard doesn't dismiss when scrolling entries
- ✗ No visual indication when keyboard is up
- ✗ Input box doesn't adjust when keyboard appears

### Solutions
- ✓ Dismiss keyboard on scroll (use `NotificationListener<ScrollNotification>`)
- ✓ Auto-scroll to input when keyboard shows
- ✓ Add "Done" button on iOS keyboard toolbar
- ✓ Tap outside input → dismiss keyboard

### Platform Differences
- **iOS**:
  - Shows "Done" button on keyboard
  - Keyboard slides up smoothly
  - Safe area insets respected

- **Android**:
  - Shows "Enter" action key
  - System back button dismisses keyboard
  - Navigation bar overlap handled

---

## 4. Responsive Layout

### Breakpoints
- **Mobile Portrait**: < 600px width (primary target)
- **Mobile Landscape**: 600-900px width
- **Tablet**: > 900px width (desktop-like)

### Layout Adjustments
- **< 600px**:
  - Reduce horizontal padding (20px → 16px)
  - Stack auth button below logo on very narrow screens
  - Hide decorative elements (━━━ line shortened)
  - FAB for commands (replaces inline commands)

- **600-900px**:
  - Current layout works well
  - Optional: Two-column layout for entries

- **> 900px**:
  - Max width 680px (current)
  - Centered layout (current)
  - Full keyboard shortcuts

### Font Scaling
- Respect user's system font size settings
- Use `MediaQuery.textScaleFactorOf(context)`
- Test with iOS "Larger Text" and Android "Font Size"

---

## 5. FAB (Floating Action Button)

### When to Show
- **Mobile only**: Show FAB when screen width < 600px
- **Hide on scroll down**: Hide FAB when scrolling down (more content visible)
- **Show on scroll up**: Reveal FAB when scrolling up (user looking for actions)

### FAB Actions
- **Primary**: Quick command menu (most common commands)
- **Options**:
  - Search (magnifying glass icon)
  - Export (download icon)
  - Stats (chart icon)
  - Theme (palette icon)

### Design
- **Position**: Bottom-right, 16px from edges
- **Size**: 56x56dp (Material standard)
- **Icon**: `Icons.add` or `Icons.more_horiz`
- **Color**: Theme accent color
- **Elevation**: 6dp (raised)
- **Animation**: Scale in/out, rotate on open

### Interaction
- **Tap**: Opens speed dial (mini FABs for each action)
- **Long press**: Shows tooltip "Quick Actions"

---

## 6. Platform-Specific Behaviors

### iOS
- **Navigation**: Swipe from left edge to go back (not needed - single screen)
- **Scroll**: Bouncy scroll with overscroll
- **Haptics**: Light impact on todo toggle, entry save
- **Safe Area**: Respect notch/island/home indicator
- **Keyboard**: "Done" toolbar button
- **Styling**: Use `CupertinoApp` widgets for native feel (optional)

### Android
- **Navigation**: System back button (handled by Flutter)
- **Scroll**: Overscroll glow indicator
- **Material**: Ripple effects on all touchable elements
- **Safe Area**: Respect navigation bar
- **Keyboard**: "Enter" action key
- **Styling**: Material Design 3 components

### Implementation
- Use `Platform.isIOS` and `Platform.isAndroid` checks
- Use `Theme.of(context).platform` for platform-aware widgets
- Conditionally import `dart:io` (not available on web)

---

## 7. Animations

### Entry Animations
- **Add**: Slide down + fade in (300ms)
- **Delete**: Slide out + fade out (250ms)
- **Edit**: Subtle scale pulse on save (200ms)

### FAB Animations
- **Show/Hide**: Scale + fade (200ms)
- **Speed dial open**: Stagger children (50ms delay each)
- **Speed dial close**: Reverse stagger

### Input Focus
- **On save**: Subtle green glow (300ms) - already implemented
- **On error**: Red shake animation (400ms)

### Transitions
- **Modal dialogs**: Fade + scale from center
- **Bottom sheets**: Slide up from bottom (for mobile commands)

### Performance
- Use `AnimatedContainer`, `AnimatedOpacity`, `SlideTransition`
- Avoid `setState` during animations
- Target 60fps (16ms per frame)

---

## 8. Error States

### Current Issues
- ✗ Generic red SnackBar for errors
- ✗ No offline indicator (beyond sync dot)
- ✗ No loading states for long operations

### Solutions

#### Network Errors
```
┌─────────────────────────┐
│ ⚠ No Internet           │
│ Entries saved locally.  │
│ Will sync when online.  │
└─────────────────────────┘
```

#### Sync Errors
```
┌─────────────────────────┐
│ ⚠ Sync Failed           │
│ Tap to retry            │
└─────────────────────────┘
```

#### Save Errors (rare)
```
┌─────────────────────────┐
│ ✗ Save Failed           │
│ Check storage space     │
│ [Retry]                 │
└─────────────────────────┘
```

### Design
- **Toast position**: Bottom center (above FAB)
- **Duration**: 4s for errors, 2s for success
- **Action**: Include retry button when applicable
- **Colors**: Error red, Warning amber, Info blue

---

## 9. Empty States

### Current State
```
No entries yet.
Start typing above!
```

### Enhanced Mobile Empty States

#### First Launch (No entries ever)
```
┌─────────────────────────┐
│                         │
│         ┌─────┐         │
│         │  □  │         │
│         └─────┘         │
│                         │
│   Welcome to Lean!      │
│                         │
│   Type anything above   │
│   and press Enter       │
│                         │
│   Try /help for         │
│   commands              │
│                         │
└─────────────────────────┘
```

#### Filtered View (No results)
```
┌─────────────────────────┐
│                         │
│   No entries found      │
│                         │
│   Try /clear to see     │
│   all entries           │
│                         │
└─────────────────────────┘
```

#### Offline (No local entries, no internet)
```
┌─────────────────────────┐
│                         │
│   ○ Offline             │
│                         │
│   Start typing to       │
│   create your first     │
│   entry!                │
│                         │
└─────────────────────────┘
```

---

## 10. Implementation Priority

### Phase 3A: Critical Mobile Polish (This Sprint)
1. ✓ Touch target improvements (48x48pt minimum)
2. ✓ Swipe-to-delete gesture
3. ✓ Keyboard dismiss on scroll
4. ✓ FAB for mobile commands
5. ✓ Responsive layout adjustments
6. ✓ Enhanced empty states

### Phase 3B: Platform Polish (Next Sprint)
7. Platform-specific behaviors (iOS haptics, Android ripples)
8. Advanced animations (hero transitions, stagger)
9. Accessibility improvements (VoiceOver, TalkBack)
10. Landscape mode optimization

### Phase 3C: Testing & Refinement
11. Test on actual iOS device
12. Test on actual Android device
13. Test with various screen sizes
14. Test with accessibility features
15. Performance profiling

---

## Success Metrics

- [ ] All touch targets ≥ 48x48pt
- [ ] Smooth 60fps scrolling
- [ ] Keyboard never blocks content
- [ ] Swipe-to-delete feels natural
- [ ] FAB accessible with one thumb
- [ ] Zero layout shifts
- [ ] App feels native on both platforms
- [ ] Passes accessibility audit
- [ ] Zero janky animations

---

## Testing Checklist

### iOS Testing
- [ ] iPhone SE (small screen)
- [ ] iPhone 14 Pro (notch)
- [ ] iPhone 15 Pro Max (large screen)
- [ ] iPad (tablet layout)
- [ ] Dark mode + light mode
- [ ] VoiceOver enabled
- [ ] Larger text sizes

### Android Testing
- [ ] Small phone (5" screen)
- [ ] Mid-range (6" screen)
- [ ] Large phone (6.7" screen)
- [ ] Tablet (10" screen)
- [ ] Various Android versions (11-14)
- [ ] TalkBack enabled
- [ ] Different font scale factors

---

*Last Updated: 2025-10-19*
*Phase 3A Target: Complete by end of sprint*
