# F9 — Media, Files & Attachment System

## Attachment Menu

### Trigger
Tap attachment icon (📎) in conversation composer.

### Bottom Sheet
```
┌─────────────────────────────────────────┐
│ ───                                        │
├─────────────────────────────────────────┤
│ Send attachment                          │
│                                          │
│ ┌──────┐  ┌──────┐  ┌──────┐            │
│ │  📷  │  │  🎥  │  │  📄  │            │
│ │Camera│  │Gallery│  │ File │            │
│ └──────┘  └──────┘  └──────┘            │
│ ┌──────┐  ┌──────┐  ┌──────┐            │
│ │  🎤  │  │  📍  │  │  👤  │            │
│ │Voice │  │Location│ │Contact│           │
│ └──────┘  └──────┘  └──────┘            │
└─────────────────────────────────────────┘
```

### Grid Layout
- 3 columns
- Icon: 40px circle, `bg-elevated`
- Label: Caption/11px, `text-secondary`
- Gap: 16px horizontal, 16px vertical
- Padding: 24px horizontal, 16px vertical

---

## Media Picker

### Layout
```
┌─────────────────────────────────────────┐
│ [✕]  Select media               [Send]  │
├─────────────────────────────────────────┤
│ Recent    Albums              ▼         │
├─────────────────────────────────────────┤
│ ┌────────┐ ┌────────┐ ┌────────┐        │
│ │        │ │        │ │        │        │
│ │  IMG   │ │  IMG   │ │  VID   │        │
│ │   1    │ │   2    │ │   3    │        │
│ │        │ │ [✓ 1]  │ │        │        │
│ └────────┘ └────────┘ └────────┘        │
│ ┌────────┐ ┌────────┐ ┌────────┐        │
│ │        │ │        │ │        │        │
│ │  IMG   │ │  IMG   │ │  IMG   │        │
│ │   4    │ │   5    │ │   6    │        │
│ │        │ │        │ │        │        │
│ └────────┘ └────────┘ └────────┘        │
├─────────────────────────────────────────┤
│ Selected: 1 item                 [Preview]│
└─────────────────────────────────────────┘
```

### Grid Specs
| Element | Value |
|---------|-------|
| Columns | 3 |
| Gap | 2px |
| Aspect ratio | 1:1 |
| Selection indicator | ✓ badge, top-right, `accent` circle |
| Selected order | Number badge on multi-select |
| Bottom bar | 48px, shows count + preview action |

---

## Image Message

### In Conversation
```
┌─────────────────────────────────────────┐
│ ┌─────────────────────────────┐         │
│ │                             │  3:15 PM│
│ │     [Image preview]         │    ✓✓  │
│ │     max-width: 260px        │         │
│ │     max-height: 200px       │         │
│ │                             │         │
│ └─────────────────────────────┘         │
│ Caption text here                       │
└─────────────────────────────────────────┘
```

### Specs
| Element | Value |
|---------|-------|
| Max width | 260px |
| Max height | 200px |
| Radius | `radius-lg` (12px) |
| Caption | Body/14px, `text-primary`, below image |
| Loading | Skeleton shimmer while loading |
| Failed | Red retry overlay |

### States
| State | Visual |
|-------|--------|
| Loading | Skeleton with spinner |
| Loaded | Image preview |
| Failed | Gray background + retry icon |
| Sending | Semi-transparent overlay + spinner |

---

## File Message

### In Conversation
```
┌─────────────────────────────────────────┐
│ ┌─────────────────────────────┐         │
│ │ 📄  document.pdf     2.4 MB │  3:15 PM│
│ │ [Progress bar ████████░░]   │    ✓✓  │
│ │ [Download]                   │         │
│ └─────────────────────────────┘         │
└─────────────────────────────────────────┘
```

### Specs
| Element | Value |
|---------|-------|
| Height | 72px |
| Background | `bg-elevated` |
| Radius | `radius-md` (8px) |
| File icon | 32px, color by type |
| Filename | Body/14px, `text-primary`, single-line |
| File size | Caption/11px, `text-secondary` |
| Progress | 2px bar, `accent` fill |
| Action button | Text button, right-aligned |

### File Type Icons
| Type | Icon | Color |
|------|------|-------|
| PDF | 📄 | `red` |
| Document | 📝 | `blue` |
| Spreadsheet | 📊 | `green` |
| Presentation | 📊 | `amber` |
| Archive | 📦 | `text-secondary` |
| Code | ⟨/⟩ | `purple` |
| Other | 📎 | `text-secondary` |

### Transfer States
| State | Progress | Action |
|-------|----------|--------|
| Waiting | 0% | "Waiting..." |
| Transferring | 0–100% | Progress bar |
| Complete | 100% | "Open" / "Download" |
| Failed | — | "Retry" |
| Paused | — | "Resume" |

---

## Voice Message

### In Conversation
```
┌─────────────────────────────────────────┐
│ ┌─────────────────────────────┐         │
│ │ [▶]  ▁▂▃▅▃▂▁▂▃▅▇▅▃▂▁   0:42  │  3:15 PM│
│ │                             │    ✓✓  │
│ └─────────────────────────────┘         │
└─────────────────────────────────────────┘
```

### Specs
| Element | Value |
|---------|-------|
| Height | 56px |
| Width | 240px |
| Background | `bg-elevated` |
| Radius | `radius-md` (8px) |
| Play button | 32px circle, `accent` |
| Waveform | 120px wide, `accent` at 60% |
| Duration | Caption/11px, `text-tertiary` |
| Progress | Waveform fills with `accent` as it plays |

### Recording State (in composer)
```
┌─────────────────────────────────────────┐
│ [✕]  ● 0:42    ▁▂▃▅▃▂▁▂▃▅▇▅▃▂▁    [⬆️] │
└─────────────────────────────────────────┘
```
- Red recording indicator
- Live waveform (animated)
- Timer
- Cancel (✕) or Send (⬆️)

---

## Media Viewer (Full Screen)

```
┌─────────────────────────────────────────┐
│ [←]                          [ℹ️] [⋯]  │
├─────────────────────────────────────────┤
│                                          │
│                                          │
│          [Full-screen image]             │
│                                          │
│                                          │
│                                          │
├─────────────────────────────────────────┤
│ Sent by Alice · January 15, 2026         │
│ Encrypted · 2.4 MB                       │
└─────────────────────────────────────────┘
```

### Actions
| Action | Icon | Position |
|--------|------|----------|
| Back | ← | Top-left |
| Info | ℹ️ | Top-right |
| More | ⋯ | Top-right |
| Share | ↗️ | Bottom-left |
| Save | ⬇️ | Bottom-center |
| Forward | ↪️ | Bottom-right |

### Interactions
- Pinch to zoom
- Swipe left/right for multi-image
- Tap to toggle chrome visibility
- Long press for save/share options

---

## Prototype Connections

| Action | Transition |
|--------|------------|
| Tap attachment icon | Bottom sheet → attachment picker |
| Tap Camera | Camera view |
| Tap Gallery | Media picker |
| Tap File | File browser |
| Tap Voice | Recording mode |
| Tap image in conversation | Full-screen media viewer |
| Tap file in conversation | Open/download |
| Long press attachment | Context menu |
