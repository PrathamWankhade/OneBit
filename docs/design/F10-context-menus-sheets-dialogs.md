# F10 — Context Menus, Bottom Sheets & Dialogs

## Interaction Language

| Pattern | Usage |
|---------|-------|
| **Bottom sheet** | Multiple contextual actions, pickers, details |
| **Dialog** | Decisions requiring confirmation |
| **Snackbar** | Lightweight feedback (copied, saved, etc.) |
| **Full screen** | Complex tasks (search, media picker, settings) |

---

## Bottom Sheet Component

### Standard Bottom Sheet
```
┌─────────────────────────────────────────┐
│ ───  (handle bar, centered, 40px wide)  │
├─────────────────────────────────────────┤
│                                          │
│  Sheet title (optional)                  │
│                                          │
│  [Icon]  Action 1                   [→]  │
│  [Icon]  Action 2                   [→]  │
│  [Icon]  Action 3                   [→]  │
│                                          │
│  ─── (divider, optional)                 │
│                                          │
│  [Icon]  Destructive action          [→] │
│                                          │
└─────────────────────────────────────────┘
```

### Specs
| Element | Value |
|---------|-------|
| Handle | 40px × 4px, `bg-muted`, centered, radius-full |
| Handle padding | 8px top, 12px bottom |
| Title | Title/18px/SemiBold, `text-primary`, 16px padding |
| Item height | 56px |
| Item padding | 16px horizontal |
| Icon | 24px, `text-secondary`, left |
| Text | Body/14px, `text-primary` |
| Divider | 1px `border-subtle`, 16px inset |
| Background | `bg-elevated` |
| Radius | `radius-xl` (16px) top-left/top-right |
| Max height | 80% of screen |
| Scrolling | Enabled if content exceeds max height |

---

## Context Menu Variants

### Message Actions
```
┌─────────────────────────────────────────┐
│ ───                                        │
├─────────────────────────────────────────┤
│ [↩️]  Reply                             │
│ [↪️]  Forward                           │
│ [📋]  Copy                              │
│ [😀]  React                             │
│ [✏️]  Edit                              │
│ [🗑️]  Delete                            │
│ [ℹ️]  Details                           │
└─────────────────────────────────────────┘
```

### Conversation Actions (long-press on conversation list)
```
┌─────────────────────────────────────────┐
│ ───                                        │
├─────────────────────────────────────────┤
│ [AVA] Alice                             │
│        Last seen 2m ago                  │
├─────────────────────────────────────────┤
│ [📌]  Pin conversation                  │
│ [🔇]  Mute notifications                │
│ [👁️]  Hide conversation                  │
│ [🗑️]  Delete conversation                │
└─────────────────────────────────────────┘
```

### Peer Actions
```
┌─────────────────────────────────────────┐
│ ───                                        │
├─────────────────────────────────────────┤
│ [AVA] Alice                             │
│        Verified · Strong signal          │
├─────────────────────────────────────────┤
│ [💬]  Start conversation                │
│ [🔍]  Verify identity                   │
│ [ℹ️]  View identity                      │
│ [📋]  Copy OneBit ID                    │
│ [⛔]  Block peer                         │
│ [🗑️]  Forget peer                        │
└─────────────────────────────────────────┘
```

### Attachment Picker
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

### Filter/Sort
```
┌─────────────────────────────────────────┐
│ ───                                        │
├─────────────────────────────────────────┤
│ Sort by                                  │
│ ● Most recent                            │
│ ○ Name                                   │
│ ○ Unread first                           │
│                                          │
│ ───                                      │
│                                          │
│ Filter                                   │
│ [✓] All conversations                    │
│ [✓] Unread                               │
│ [✓] Groups                               │
│ [✓] Direct messages                      │
└─────────────────────────────────────────┘
```

---

## Dialog Component

### Confirmation Dialog
```
┌─────────────────────────────────────────┐
│                                          │
│    Dialog title                          │
│                                          │
│    Dialog body text explaining           │
│    what will happen.                     │
│                                          │
│    [Cancel]          [Confirm]           │
│                                          │
└─────────────────────────────────────────┘
```

### Specs
| Element | Value |
|---------|-------|
| Width | 312px (or 80% of screen, whichever is smaller) |
| Background | `bg-elevated` |
| Radius | `radius-xl` (16px) |
| Padding | 24px |
| Title | Title/18px/SemiBold, `text-primary` |
| Body | Body/14px, `text-secondary`, 8px below title |
| Actions | Right-aligned, 16px gap |
| Overlay | `rgba(0,0,0,0.6)` |

### Destructive Dialog
```
┌─────────────────────────────────────────┐
│                                          │
│    Delete conversation?                  │
│                                          │
│    This will permanently delete all      │
│    messages in this conversation.        │
│    This action cannot be undone.         │
│                                          │
│    [Cancel]          [Delete]            │
│                      (red text)          │
│                                          │
└─────────────────────────────────────────┘
```

### Security Warning Dialog
```
┌─────────────────────────────────────────┐
│                                          │
│    ⚠️  Identity changed                  │
│                                          │
│    Alice's identity has changed          │
│    since you last verified it.           │
│                                          │
│    This could mean Alice reinstalled     │
│    OneBit, or it could indicate a        │
│    security issue.                       │
│                                          │
│    [Ignore]        [Verify identity]     │
│                                          │
└─────────────────────────────────────────┘
```

### Identity Verification Dialog
```
┌─────────────────────────────────────────┐
│                                          │
│    Verify Alice's identity?              │
│                                          │
│    Compare the fingerprint shown         │
│    with Alice's device.                  │
│                                          │
│    7a3f 2b8c 914e 5a6d                  │
│    3f2b 8c91 4e5a 6d7f                  │
│                                          │
│    [Cancel]        [Verify]              │
│                                          │
└─────────────────────────────────────────┘
```

---

## Snackbar Component

### Standard Snackbar
```
┌─────────────────────────────────────────┐
│ [ℹ️]  Message text here            [✕]  │
└─────────────────────────────────────────┘
```

### Specs
| Element | Value |
|---------|-------|
| Height | 48px |
| Background | `bg-elevated` |
| Radius | `radius-md` (8px) |
| Margin | 16px all sides, 8px above bottom nav |
| Icon | 20px, left |
| Text | Body/14px, `text-primary` |
| Dismiss | ✕ icon, right |
| Duration | 3 seconds auto-dismiss |
| Position | Bottom of screen, above bottom nav |

### Variants
| Type | Icon | Color |
|------|------|-------|
| Info | ℹ️ | `text-secondary` |
| Success | ✓ | `green` |
| Warning | ⚠ | `amber` |
| Error | ✕ | `red` |

### Messages
| Action | Message |
|--------|---------|
| Copy | "Copied to clipboard" |
| Save | "Saved to device" |
| Verify | "Identity verified" |
| Block | "Peer blocked" |
| Delete | "Message deleted" |
| Restore | "Connection restored" |
| Send | "Message sent" |
| Failed | "Failed to send" |

---

## Interaction Rules

1. **Bottom sheets** for: multiple actions, pickers, detail views, settings
2. **Dialogs** for: confirmations, warnings, destructive actions, critical decisions
3. **Snackbars** for: feedback, status updates, undo actions
4. **Full screens** for: search, media picker, settings, complex tasks
5. **Never stack** multiple bottom sheets or dialogs
6. **Dismiss on outside tap** for bottom sheets (unless critical)
7. **Never dismiss on outside tap** for destructive dialogs

---

## Prototype Connections

| Action | Transition |
|--------|------------|
| Long-press message | Bottom sheet → message actions |
| Long-press conversation | Bottom sheet → conversation actions |
| Tap attachment | Bottom sheet → attachment picker |
| Tap block/destructive | Dialog → confirm |
| Copy text | Snackbar → "Copied" |
| Save file | Snackbar → "Saved" |
| Send message | Snackbar → "Sent" (brief) |
