# F2 — Information Architecture & Navigation

## Navigation Philosophy

OneBit's navigation reflects its decentralized identity. The primary experience revolves around:
1. **Conversations** — the core communication surface
2. **Nearby** — peer discovery and mesh network
3. **Identity** — the user's cryptographic identity
4. **Settings** — controls and configuration

**Target: 4 primary destinations** in bottom navigation.

---

## Navigation Structure

### Bottom Navigation (4 tabs)

```
┌──────────────────────────────────────────────┐
│  [Conversations]  [Nearby]  [Identity]  [···] │
└──────────────────────────────────────────────┘
```

| Tab | Icon | Label | Badge |
|-----|------|-------|-------|
| Conversations | Chat bubble outline | Chats | Unread count |
| Nearby | Radial nodes outline | Nearby | Peer count when > 0 |
| Identity | Key/diamond outline | Identity | Verification status dot |
| More | Ellipsis horizontal | More | — |

### Tab Behavior
- **Chats** = home. Always first. Tapping selected tab scrolls to top.
- **Nearby** = BLE discovery. Shows peer count badge when peers are discovered.
- **Identity** = own profile, fingerprint, QR. Shows verification status.
- **More** = settings, help, about. Opens as bottom sheet or push, not a tab destination.

### Active State
- Icon: filled variant with `accent` color
- Label: `text-primary` weight 500
- Inactive: `text-tertiary` weight 400

---

## Screen Hierarchy

```
App
├── Onboarding (first run only)
│   ├── Welcome
│   ├── How it works
│   ├── Create identity
│   └── Identity ready
│
├── Main (bottom nav)
│   ├── Conversations (tab)
│   │   ├── Search
│   │   ├── Conversation → Chat screen
│   │   ├── New conversation → Peer picker
│   │   └── Conversation long-press → context menu
│   │
│   ├── Nearby (tab)
│   │   ├── Scanning state
│   │   ├── Peer list
│   │   ├── Peer → Peer detail
│   │   └── Peer → Start conversation
│   │
│   ├── Identity (tab)
│   │   ├── My identity
│   │   ├── My QR
│   │   ├── Scan QR
│   │   ├── Fingerprint detail
│   │   └── Edit identity
│   │
│   └── More (tab)
│       ├── Settings
│       │   ├── Privacy & Security
│       │   ├── Mesh & Connectivity
│       │   ├── Conversations
│       │   ├── Notifications
│       │   ├── Appearance
│       │   ├── Storage
│       │   ├── Advanced
│       │   └── About
│       ├── Help
│       └── Log out / reset
│
└── Overlays
    ├── Global search (full screen)
    ├── Bottom sheets
    ├── Dialogs
    └── Snackbars
```

---

## Top App Bar Variants

### Variant 1: Standard
```
┌─────────────────────────────────────────┐
│ [←]  Screen Title              [🔍] [⋮] │
└─────────────────────────────────────────┘
```
- Back arrow (if navigated)
- Title (left-aligned, Title/18px/SemiBold)
- Search icon
- Overflow menu icon

### Variant 2: Identity Bar
```
┌─────────────────────────────────────────┐
│ [◆]  OneBit              [🔍] [⋮]       │
└─────────────────────────────────────────┘
```
- Identity icon (diamond/key shape)
- App name or identity name
- Search + overflow

### Variant 3: Conversation Header
```
┌─────────────────────────────────────────┐
│ [←]  [AVA] Name         [📞] [⋮]        │
│       ● Connected · Verified            │
└─────────────────────────────────────────┘
```
- Back arrow
- Avatar (28px circle)
- Name (Body/14px/SemiBold)
- Status subtitle (Caption/11px, `text-secondary`)
- Action icons (voice call if supported, overflow)

### Variant 4: Search Active
```
┌─────────────────────────────────────────┐
│ [←]  Search...                    [✕]   │
└─────────────────────────────────────────┘
```
- Back arrow
- Text field (auto-focused)
- Clear button

---

## Global Search

### Trigger
- Search icon in any app bar
- Pull-down on conversation list

### Search Capabilities
| Category | What it finds |
|----------|---------------|
| Conversations | By name, message content |
| People | By display name, OneBit ID |
| Peers | By name, ID, nearby status |
| Messages | Full-text search within conversations |
| Files | Document names, types |

### Search UI
```
┌─────────────────────────────────────────┐
│ [←]  Search conversations...       [✕]  │
├─────────────────────────────────────────┤
│ Recent searches                          │
│   [Chip: "file transfer"]  [Chip: "···"]│
│                                          │
│ Results                                  │
│   [AVA] Alice           Conversation    │
│   [AVA] Bob             Peer            │
│   🔍  "hello world"     Message         │
│   📄  document.pdf      File            │
└─────────────────────────────────────────┘
```

### Search Rules
1. Results grouped by category with section headers
2. Each result shows context (conversation name, peer status, file type)
3. Tap result → navigates to relevant screen
4. Recent searches persisted (last 10)
5. Clear individual or all recent searches

---

## Floating Action Button

### Contextual FAB — Conversations Tab
```
┌──────────────────────┐
│                      │
│              [✏️]    │
│                      │
└──────────────────────┘
```
- **Icon:** Pencil/compose
- **Action:** New conversation → peer picker bottom sheet
- **Hide:** When search is active, when scrolling down

### No FAB on Other Tabs
- **Nearby:** Scan is automatic, no FAB needed
- **Identity:** Static page, no FAB
- **More:** Settings list, no FAB

---

## Global States

### State Definitions

| State | Visual | Message |
|-------|--------|---------|
| Loading | Skeleton shimmer on list items | "Loading..." |
| Offline | Amber banner at top | "Offline — local messages available" |
| No peers nearby | Empty state with scan icon | "No OneBit nodes nearby" |
| No conversations | Empty state with compose icon | "No conversations yet" |
| Searching | Results list with categories | Category-based results |
| Connecting | Animated dots in status bar | "Connecting..." |
| Connection lost | Red status indicator | "Connection lost" |
| Identity not configured | Purple banner + CTA | "Set up your identity" |
| Verification pending | Amber dot on peer | "Verification pending" |
| Verified | Green dot on peer | "Verified" |
| Error | Red banner with retry | "Something went wrong" |

### Rules
1. **One global state at a time.** Don't stack multiple banners.
2. **States don't block content.** Use banners, not full-screen overlays (except error).
3. **States are dismissible** unless blocking a required action.

---

## Prototype Connections

### Primary Flow
```
App Launch → Onboarding → Create Identity → Home (Conversations)
Home → Tap peer → Conversation
Home → FAB → New conversation → Peer picker
Home → Nearby tab → Scanning → Peer found → Peer detail
Home → Identity tab → My identity → QR / Fingerprint
Home → More → Settings → Category → Detail
```

### Transitions
| From | To | Transition |
|------|----|------------|
| Tab switch | Tab content | Crossfade (200ms) |
| Push screen | Detail | Slide from right (300ms) |
| Bottom sheet | Actions | Slide up (250ms) |
| Dialog | Confirmation | Fade in (150ms) |
| Search | Results | Instant filter |
| FAB | Action | Scale + fade (200ms) |
