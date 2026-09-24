# F3 — Conversations / Home Screen

## Screen Purpose
The primary home screen. Communicates: who the user can talk to, recent activity, connection state, unread messages, peer reachability.

---

## Screen Layout

```
┌─────────────────────────────────────────┐
│ [◆]  Chats                     [🔍] [⋮] │  ← App Bar
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────┐     │
│ │ 🔍 Search conversations...      │     │  ← Search bar (tap to expand)
│ └─────────────────────────────────┘     │
├─────────────────────────────────────────┤
│ Pinned                                  │  ← Section (if pinned exist)
│ ┌─────────────────────────────────┐     │
│ │ [AVA] Alice        ●  2m  [2]  │     │  ← Pinned + unread
│ │        Hey, are you nearby?     │     │
│ └─────────────────────────────────┘     │
│                                          │
│ Recent                                   │  ← Section
│ ┌─────────────────────────────────┐     │
│ │ [AVA] Bob          ○  1h       │     │  ← Offline peer
│ │        File received ✓✓         │     │
│ └─────────────────────────────────┘     │
│ ┌─────────────────────────────────┐     │
│ │ [AVA] Charlie      ●  3h       │     │  ← Online peer
│ │        Voice message 0:42       │     │
│ └─────────────────────────────────┘┐    │
│ ┌─────────────────────────────────┐     │
│ │ [AVA] Diana        ◐  1d       │     │  ← Relay/weak
│ │        Image                    │     │
│ └─────────────────────────────────┘     │
├─────────────────────────────────────────┤
│                                         │
│              [✏️]                        │  ← FAB
│                                         │
└─────────────────────────────────────────┘
│  [Chats]   [Nearby]   [Identity]  [···]  │  ← Bottom Nav
└─────────────────────────────────────────┘
```

---

## Search Bar (Collapsed)

**Position:** Below app bar, above conversation list

| Property | Value |
|----------|-------|
| Height | 40px |
| Radius | `radius-sm` (6px) |
| Background | `bg-surface` |
| Border | `border-subtle` |
| Placeholder | `text-tertiary` |
| Icon | Search icon, `text-tertiary`, left-aligned |

**Tap behavior:** Expands to full-screen search (Variant 4 app bar)

---

## Conversation Item

### Standard State
```
┌─────────────────────────────────────────┐
│ [AVA]  Name                  2:30 PM    │
│        Last message preview...          │
└─────────────────────────────────────────┘
```

### Properties

| Element | Spec |
|---------|------|
| Height | 72px |
| Horizontal padding | 16px |
| Avatar | 48px circle, left-aligned |
| Avatar-to-text gap | 12px |
| Name | Body/14px/SemiBold, `text-primary` |
| Timestamp | Caption/11px, `text-tertiary`, right-aligned |
| Preview | Body Small/13px, `text-secondary`, single-line ellipsis |
| Unread badge | 20px circle, `accent` bg, white count, right of preview |
| Online indicator | 10px circle, `green`, bottom-right of avatar |
| Muted | Show muted icon, reduce text opacity |

### Avatar Rules
- **With image:** Rounded image fill
- **Without image:** Initials on `bg-elevated`, `text-secondary` text
- **Online:** 10px green dot overlapping bottom-right of avatar
- **Offline:** No dot
- **Relay/weak:** Amber dot

### Unread Badge
- **Count 1–99:** Show number
- **Count 99+:** Show "99+"
- **No unread:** No badge
- **Muted + unread:** Show small gray dot instead of count

### Connection State Indicators
| State | Dot Color | Label (optional) |
|-------|-----------|------------------|
| Online | `green` | — |
| Offline | None | — |
| Relay | `amber` | "via relay" |
| Weak signal | `amber` | — |
| Connecting | Pulsing `accent` | — |

### Message Preview Icons
| Icon | Meaning |
|------|---------|
| ✓ | Sent |
| ✓✓ | Delivered |
| ✓✓ (filled) | Read |
| ⚠ | Failed |
| 📎 | Attachment |
| 🎤 | Voice message |
| 🖼 | Image |

---

## Sections

### Pinned
- Conversations pinned by the user
- Shown first, always visible
- Pin icon (subtle) on the conversation item

### Recent
- Default section
- Sorted by most recent message

### Rules
1. **No more than 3 sections** on the home screen
2. **Section header:** Label/12px/Medium, `text-tertiary`, left-aligned, 16px horizontal padding, 8px vertical padding
3. **Section separator:** 1px `border-subtle`, 16px inset
4. **Section collapse:** Sections with 0 items are hidden

---

## Empty State

### No Conversations Yet
```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│            [🌐 icon, 48px]              │
│                                         │
│         No conversations yet            │
│                                         │
│   Start by discovering a nearby peer    │
│   or sharing your identity QR.          │
│                                         │
│        [Discover nearby]                │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Icon | 48px, `accent` at 40% opacity |
| Title | Title/18px/SemiBold, `text-primary` |
| Description | Body/14px, `text-secondary`, centered, max-width 280px |
| Action | Primary Button (accent) |

---

## FAB (Floating Action Button)

### Position
- **Bottom-right:** 16px from right edge, 16px above bottom nav
- **Size:** 56px circle
- **Background:** `accent`
- **Icon:** Pencil/compose, 24px, `text-inverse`

### States
| State | Appearance |
|-------|------------|
| Default | `accent` bg, white icon |
| Pressed | `accent-muted` bg |
| Hidden | When search active or scrolling down |

### Tap Action
Opens "New conversation" bottom sheet:
```
┌─────────────────────────────────────────┐
│ New conversation                        │
├─────────────────────────────────────────┤
│ [🔍] Search peers...                    │
│                                          │
│ Nearby                                   │
│ [AVA] Alice      ●  Strong signal       │
│ [AVA] Bob        ○  Offline             │
│                                          │
│ All peers                                │
│ [AVA] Charlie    ●  Online              │
│ [AVA] Diana      ◐  Relay               │
└─────────────────────────────────────────┘
```

---

## App Bar

### Identity Variant (Default on Chats tab)
```
┌─────────────────────────────────────────┐
│ [◆]  Chats                     [🔍] [⋮] │
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Height | 56px |
| Background | `bg-base` |
| Identity icon | 20px diamond/key, `accent` |
| Title | Title/18px/SemiBold, `text-primary` |
| Action icons | 24px, `text-secondary` |
| Bottom border | 1px `border-subtle` |

### Overflow Menu (⋮)
Tap opens dropdown:
```
┌──────────────────┐
│ Mark all read    │
│ pinned chats     │
│ Settings         │
└──────────────────┘
```
- Background: `bg-elevated`
- Radius: `radius-md` (8px)
- Elevation: 2
- Item height: 44px
- Text: Body/14px, `text-primary`

---

## State Variants

### Loading State
- Skeleton shimmer on conversation items
- 3 placeholder rows
- Shimmer: `bg-surface` → `bg-elevated` → `bg-surface` (1.5s loop)

### Offline State
```
┌─────────────────────────────────────────┐
│ ⚠ Offline — local messages only    [✕]  │  ← Amber banner
├─────────────────────────────────────────┤
│ ...conversation list (still functional) │
└─────────────────────────────────────────┘
```
- Banner height: 36px
- Background: `amber-subtle`
- Text: Caption/11px, `amber`
- Dismiss: ✕ button

### Search Active State
- App bar transforms to search bar
- List shows filtered results
- FAB hides
- Keyboard open

### No Unread
- All conversations read
- No badges visible
- Normal list display

---

## Prototype Connections

| Action | Transition |
|--------|------------|
| Tap conversation | Push → Conversation screen |
| Tap FAB | Bottom sheet slides up |
| Tap search bar | Full-screen search |
| Long-press conversation | Context menu (bottom sheet) |
| Pull down | Refresh peers list |
| Tap "Discover nearby" (empty) | Navigate to Nearby tab |
