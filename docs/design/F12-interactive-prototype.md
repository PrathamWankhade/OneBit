# F12 — Complete Interactive Prototype

## Primary User Journey

### Complete Flow

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  App Launch                                                 │
│    ↓                                                        │
│  Onboarding (if first run)                                  │
│    ↓                                                        │
│  Welcome → How it works → Create identity → Ready           │
│    ↓                                                        │
│  Home (Conversations)                                       │
│    ↓                                                        │
│  Discover nearby peer (via FAB or Nearby tab)               │
│    ↓                                                        │
│  Peer discovered → View peer identity                       │
│    ↓                                                        │
│  Verify identity → Fingerprint compare → Verified           │
│    ↓                                                        │
│  Start conversation → Chat screen                           │
│    ↓                                                        │
│  Send message → Delivery confirmed                          │
│    ↓                                                        │
│  Open attachment → Send file/image                          │
│    ↓                                                        │
│  View media/file → Full screen viewer                       │
│    ↓                                                        │
│  Return to conversation                                     │
│    ↓                                                        │
│  Open peer profile → View security info                     │
│    ↓                                                        │
│  Return home                                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Screen-by-Screen Prototype

### 1. App Launch
- **Frame:** Splash screen with OneBit logo (◆ icon)
- **Duration:** 1.5 seconds
- **Transition:** Fade to onboarding (if first run) or home

### 2. Onboarding
- **Frames:** 5 screens (Welcome → How It Works → Create → Generating → Ready)
- **Transitions:** Slide left (300ms)
- **Interaction:** Type name, tap avatar, tap CTAs

### 3. Home (Conversations)
- **Frame:** Empty state or conversation list
- **Interaction:** Tap FAB, tap search, tap conversation
- **Transitions:** FAB → bottom sheet, search → full screen, conversation → push

### 4. Nearby Discovery
- **Frame:** Scanning state → peers found
- **Interaction:** Auto-scan, tap peer
- **Transitions:** Scanning animation → peer list, tap peer → push

### 5. Peer Detail
- **Frame:** Peer profile with identity, connection, security info
- **Interaction:** Tap "Start conversation", tap "Verify"
- **Transitions:** Tap action → push or bottom sheet

### 6. Verification Flow
- **Frame:** Fingerprint comparison → success
- **Interaction:** Confirm match or mismatch
- **Transitions:** Compare → success, success → dismiss

### 7. Conversation
- **Frame:** Chat with messages, composer
- **Interaction:** Type message, tap send, long-press message
- **Transitions:** Send → message appears, long-press → bottom sheet

### 8. Attachment
- **Frame:** Bottom sheet → media picker → preview
- **Interaction:** Select media, add caption, send
- **Transitions:** Tap attachment → sheet, select → preview, send → message

### 9. Media Viewer
- **Frame:** Full-screen image/video
- **Interaction:** Pinch zoom, swipe, back
- **Transitions:** Tap image → full screen, back → conversation

### 10. Peer Profile (from conversation)
- **Frame:** Peer identity, connection, security
- **Interaction:** Tap actions
- **Transitions:** Tap back → conversation

### 11. Settings
- **Frame:** Settings list → category → detail
- **Interaction:** Tap items, toggle switches
- **Transitions:** Tap → push, toggle → immediate

---

## Transition Specifications

### Push (Screen → Detail)
- **Animation:** Slide from right (300ms, ease-out)
- **Exit:** Previous screen slides left slightly (parallax)
- **Back:** Reverse animation

### Bottom Sheet
- **Animation:** Slide up (250ms, ease-out)
- **Overlay:** Fade in `rgba(0,0,0,0.4)` (200ms)
- **Dismiss:** Slide down + overlay fade out

### Full-Screen Search
- **Animation:** Scale up from search bar (200ms)
- **Exit:** Scale down to search bar

### Tab Switch
- **Animation:** Crossfade (200ms)
- **No slide** — instant tab content swap

### Dialog
- **Animation:** Fade in (150ms) + scale from 0.95 to 1.0
- **Overlay:** Fade in `rgba(0,0,0,0.5)` (150ms)

### Snackbar
- **Animation:** Slide up from bottom (200ms)
- **Auto-dismiss:** Slide down after 3 seconds

---

## Interaction States

### Every Screen Must Have

| State | Description |
|-------|-------------|
| Loading | Skeleton/shimmer while data loads |
| Empty | No content — informative message + CTA |
| Normal | Standard content display |
| Active | Current selection/action |
| Error | Something went wrong + retry |
| Offline | Network unavailable |

### Loading Patterns
| Context | Pattern |
|---------|---------|
| Screen load | Skeleton shimmer (3 rows) |
| Action | Inline spinner on button |
| File transfer | Progress bar |
| Scanning | Animated node/rings |
| Connecting | Pulsing dot |

---

## Prototype Wiring

### Figma Prototype Settings
| Setting | Value |
|---------|-------|
| Device | iPhone 14 Pro (390 × 844) |
| Prototype type | Device + Status bar |
| Starting frame | App launch / Onboarding |
| Interactions | On tap, On drag |
| Transitions | Smart animate (where possible) |

### Connection Map

| From | To | Trigger |
|------|----|---------|
| Launch | Onboarding | First run |
| Launch | Home | Returning user |
| Onboarding → | Identity Ready | Complete flow |
| Identity Ready | Home | "Start using" |
| Home → FAB | New conversation sheet | Tap |
| Home → Conversation | Chat screen | Tap |
| Home → Nearby | Discovery screen | Tab |
| Home → Identity | My identity | Tab |
| Home → More | Settings | Tab |
| Chat → Attachment | Attachment sheet | Tap 📎 |
| Chat → Message actions | Context sheet | Long press |
| Chat → Peer profile | Profile screen | Tap header |
| Discovery → Peer | Peer detail | Tap peer |
| Peer → Verify | Verification flow | Tap "Verify" |
| Verify → Success | Success screen | Confirm |
| Settings → Category | Detail screen | Tap |

---

## Quality Checklist

- [ ] All transitions are smooth and consistent
- [ ] No jarring animations
- [ ] Keyboard state handled in chat/search
- [ ] Loading states for all async actions
- [ ] Empty states for all list screens
- [ ] Error states with retry where appropriate
- [ ] Back navigation works everywhere
- [ ] Bottom sheets dismiss on outside tap (except destructive)
- [ ] Dialogs require explicit action
- [ ] Snackbars auto-dismiss
- [ ] Touch targets ≥ 44px
- [ ] Text contrast meets WCAG AA
- [ ] All icons consistent style
- [ ] Spacing follows 4px grid
