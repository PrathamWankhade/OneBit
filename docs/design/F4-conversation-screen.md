# F4 — Conversation Screen

## Screen Purpose
The one-to-one conversation screen. One of the most important screens in the application. Must communicate security, identity, and connection state subtly while keeping the messaging experience clean and fast.

---

## Screen Layout

```
┌─────────────────────────────────────────┐
│ [←] [AVA] Alice    ● Connected  [📞] [⋮]│  ← Header
│       Verified · Encrypted              │
├─────────────────────────────────────────┤
│                                          │
│           Today, 2:30 PM                │  ← Date divider
│                                          │
│  ┌──────────────────┐                   │
│  │ Hey, are you      │  2:30 PM    ✓✓  │  ← Incoming
│  │ nearby?           │                  │
│  └──────────────────┘                   │
│                                          │
│                   ┌──────────────────┐  │
│                   │ Yes, I'm about   │  │  2:31 PM    ✓✓
│                   │ 2 blocks away    │  │
│                   └──────────────────┘  │
│                                          │
│  ┌──────────────────┐                   │
│  │ [📎] file.pdf    │  2:32 PM    ✓✓  │  ← Incoming attachment
│  │    2.4 MB        │                  │
│  └──────────────────┘                   │
│                                          │
│           ─── Unread messages ───        │  ← Unread divider
│                                          │
│  ┌──────────────────┐                   │
│  │ Can you send the  │  3:15 PM    ✓   │  ← Incoming (new)
│  │ report?           │                  │
│  └──────────────────┘                   │
│                                          │
├─────────────────────────────────────────┤
│ [📎] [···] Type a message...    [🎤] [➤]│  ← Composer
└─────────────────────────────────────────┘
```

---

## Header

### Layout
```
[←] [AVA 28px] Name              [📞] [⋮]
     ● Connected · Encrypted
```

| Element | Spec |
|---------|------|
| Height | 56px (expandable to 72px with subtitle) |
| Back arrow | 24px, `text-secondary` |
| Avatar | 28px circle, no online dot (redundant with status) |
| Name | Body/14px/SemiBold, `text-primary` |
| Status | Caption/11px, `text-secondary` |
| Status dot | 6px circle, color-coded |
| Action icons | 24px, `text-secondary` |

### Status Variants
| State | Dot Color | Text |
|-------|-----------|------|
| Online | `green` | "Connected" |
| Nearby | `accent` | "Nearby" |
| Relay | `amber` | "Connected via relay" |
| Offline | None | "Offline" |
| Connecting | Pulsing `accent` | "Connecting..." |

### Security Subtitle
| State | Icon | Text |
|-------|------|------|
| Verified | Shield check `green` | "Verified" |
| Unverified | Shield outline `text-tertiary` | — |
| Identity changed | Shield alert `amber` | "Identity changed" |

### Header Tap
Tap on name/avatar → Peer Profile screen

---

## Message Timeline

### Scroll Behavior
- Messages load from bottom (newest first)
- Pull up to load older messages
- Unread divider stays visible until all messages above are read
- Scroll-to-bottom FAB appears when scrolled up

### Date Divider
```
        ──── Today, January 15 ────
```
- Caption/11px, `text-tertiary`
- Horizontal rule: 1px `border-subtle`, 32px inset each side
- Vertical padding: 16px top, 8px bottom

### Unread Divider
```
        ──── 3 new messages ────
```
- Same style as date divider
- `accent` color for line and text
- Shows count of unread messages below

---

## Message Bubbles

### Incoming Message
```
┌──────────────────┐
│ Message text      │
│ goes here.        │  2:30 PM   ✓✓
└──────────────────┘
```

| Element | Spec |
|---------|------|
| Max width | 75% of screen width |
| Background | `bg-elevated` |
| Radius | `radius-lg` (12px), top-left `radius-xs` (4px) |
| Padding | 10px horizontal, 8px vertical |
| Text | Body Large/16px, `text-primary` |
| Timestamp | Caption/11px, `text-tertiary` |
| Alignment | Left-aligned |
| Bubble-to-timestamp | 4px gap, bottom-right |

### Outgoing Message
```
                   ┌──────────────────┐
  2:31 PM   ✓✓    │ Message text      │
                   │ goes here.        │
                   └──────────────────┘
```

| Element | Spec |
|---------|------|
| Max width | 75% of screen width |
| Background | `accent-subtle` (rgba(0,212,170,0.12)) |
| Radius | `radius-lg` (12px), top-right `radius-xs` (4px) |
| Padding | 10px horizontal, 8px vertical |
| Text | Body Large/16px, `text-primary` |
| Timestamp | Caption/11px, `text-tertiary` |
| Alignment | Right-aligned |
| Timestamp-to-bubble | 4px gap, bottom-left |

### System Message
```
         ── Alice joined the conversation ──
```
- Centered
- Caption/11px, `text-tertiary`
- No bubble

### Security Event
```
    🔒 Messages are end-to-end encrypted
```
- Centered
- Caption/11px, `accent` at 60%
- Lock icon inline

---

## Message States

### Delivery Status Icons
| Icon | State | Color |
|------|-------|-------|
| Clock | Sending | `text-tertiary` |
| ✓ | Sent | `text-tertiary` |
| ✓✓ | Delivered | `text-tertiary` |
| ✓✓ (filled) | Read | `accent` |
| ⚠ | Failed | `red` |

### Encryption Indicator
- Small lock icon (12px) next to timestamp
- `accent` at 40% opacity
- Only visible on outgoing messages
- Tap shows security info bottom sheet

---

## Composer

### Layout
```
┌─────────────────────────────────────────┐
│ [📎]  [···]  Type a message...  [🎤] [➤]│
└─────────────────────────────────────────┘
```

### States

#### Empty (Default)
```
[📎]  [···]  Type a message...          [🎤]
```
- Attachment icon left
- Overflow icon left
- Placeholder: `text-tertiary`
- Voice icon right (no send button)

#### With Text
```
[📎]  [···]  Message text here...        [➤]
```
- Send button replaces voice icon
- Send button: `accent` circle, 36px

#### Recording
```
[✕]  ● 0:42                          [⬆️ Send]
```
- Cancel (✕) left
- Red recording dot + timer center
- Send (⬆️) or cancel action right
- Background: `red-subtle`

#### Replying
```
┌─────────────────────────────────────────┐
│ [✕] Replying to Alice                   │  ← Reply preview
│ Hey, are you nearby?                    │
├─────────────────────────────────────────┤
│ [📎]  Message text here...        [➤]   │
└─────────────────────────────────────────┘
```
- Reply preview: 48px height, `bg-surface` background
- Quoted message: truncated, 1 line
- Source name: Label/12px/Medium, `accent`
- Dismiss: ✕ icon

#### Editing
```
┌─────────────────────────────────────────┐
│ [✕] Editing message                     │
├─────────────────────────────────────────┤
│ [📎]  Edited text here...         [✓]   │
└─────────────────────────────────────────┘
```
- Similar to reply but shows "Editing"
- Confirm: checkmark icon instead of send

### Composer Height
| State | Height |
|-------|--------|
| Empty | 56px |
| Single line | 56px |
| Multi-line | Up to 120px, then scroll |
| With reply/edit preview | +48px |

---

## Attachment Previews

### Image Preview
```
┌─────────────────────────────────────────┐
│ [✕]                                     │
│  ┌─────────────────────────────┐        │
│  │     [Image thumbnail]       │        │
│  └─────────────────────────────┘        │
│  Add a caption...                       │
├─────────────────────────────────────────┤
│ [📎]  image.jpg                   [➤]   │
└─────────────────────────────────────────┘
```
- Preview: max 200px height, `radius-md`
- Caption input below preview
- Dismiss: ✕ top-left

### File Preview
```
┌─────────────────────────────────────────┐
│ [✕]                                     │
│ 📄 document.pdf          2.4 MB         │
├─────────────────────────────────────────┤
│ [📎]  document.pdf                [➤]   │
└─────────────────────────────────────────┘
```
- File icon, name, size in a compact row

---

## Context Actions (Long Press)

### Message Actions Bottom Sheet
```
┌─────────────────────────────────────────┐
│ ───                                        │  ← Handle
├─────────────────────────────────────────┤
│ [↩️]  Reply                             │
│ [↪️]  Forward                           │
│ [📋]  Copy                              │
│ [😀]  React                             │
│ [✏️]  Edit                    (outgoing)│
│ [🗑️]  Delete                            │
│ [ℹ️]  Details                           │
└─────────────────────────────────────────┘
```

### Action Visibility
| Action | Incoming | Outgoing |
|--------|----------|----------|
| Reply | ✓ | ✓ |
| Forward | ✓ | ✓ |
| Copy | ✓ | ✓ |
| React | ✓ | ✓ |
| Edit | — | ✓ (within time limit) |
| Delete | — | ✓ |
| Details | ✓ | ✓ |

---

## Scroll-to-Bottom FAB

When scrolled up from the bottom:
- Small 40px circle, `bg-elevated`
- Down arrow icon, `text-secondary`
- Shows unread count if available
- Tap: smooth scroll to bottom

---

## State Variants

### Empty Conversation
```
┌─────────────────────────────────────────┐
│ [←] [AVA] Alice            [📞] [⋮]     │
├─────────────────────────────────────────┤
│                                         │
│      Start a conversation with Alice    │
│                                         │
│    Messages are end-to-end encrypted    │
│                                         │
├─────────────────────────────────────────┤
│ [📎]  Type a message...          [🎤]   │
└─────────────────────────────────────────┘
```
- Centered prompt text
- Encryption notice

### Offline Peer
- Composer shows "Peer is offline. Messages will be sent when connected."
- Send button still available (queue messages)

### Peer Offline + No History
```
Alice is offline

Start a conversation. Messages will be
delivered when Alice comes online.
```

---

## Prototype Connections

| Action | Transition |
|--------|------------|
| Tap back | Pop to Conversations list |
| Tap name/avatar | Push → Peer Profile |
| Tap attachment | Bottom sheet → attachment picker |
| Long-press message | Bottom sheet → message actions |
| Tap reply | Composer enters reply mode |
| Tap forward | Bottom sheet → forward picker |
| Tap security icon | Bottom sheet → security details |
| Scroll to top | Load older messages |
| Tap scroll-down FAB | Scroll to bottom |
