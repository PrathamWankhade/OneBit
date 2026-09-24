# F7 — Profile

## Profile Types
1. **My Profile** — The user's own identity/profile
2. **Peer Profile** — Another user's profile (viewed from conversation or discovery)

---

## My Profile

```
┌─────────────────────────────────────────┐
│ [←]  Profile                    [✏️] [QR]│
├─────────────────────────────────────────┤
│                                          │
│            [AVA 96px]                    │
│            Alice                         │
│       ● Verified identity               │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ About                           │     │
│  │ Privacy-focused communicator    │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Identity                        │     │
│  │ OneBit ID                       │     │
│  │ D1A0:3F2B:8C91:4E5A            │     │
│  │ [📋 Copy]  [📤 Share]           │     │
│  │                                 │     │
│  │ Fingerprint                     │     │
│  │ 7a3f 2b8c 914e 5a6d ...        │     │
│  │ [🔍 View]  [📋 Copy]            │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Verification                    │     │
│  │ ✓ Identity verified             │     │
│  │ Created: January 15, 2026       │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Security                        │     │
│  │ Encryption: Active (256-bit)    │     │
│  │ [View security details]         │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Activity                        │     │
│  │ Messages sent: 142              │     │
│  │ Peers connected: 8              │     │
│  │ Uptime: 3 days                  │     │
│  └─────────────────────────────────┘     │
│                                          │
└─────────────────────────────────────────┘
```

### Identity Card Section
| Field | Display | Style |
|-------|---------|-------|
| OneBit ID | `D1A0:3F2B:8C91:4E5A` | Technical/13px, JetBrains Mono |
| Fingerprint | `7a3f 2b8c 914e 5a6d ...` | Technical/13px, JetBrains Mono |
| Verification | Shield icon + status | Color-coded |
| Created | Date | Body/14px |

---

## Peer Profile

```
┌─────────────────────────────────────────┐
│ [←]  Peer Profile            [💬] [⋮]   │
├─────────────────────────────────────────┤
│                                          │
│            [AVA 80px]                    │
│            ● Connected                   │
│            Alice                         │
│       Verified peer                      │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ About                           │     │
│  │ (Peer's about text if shared)   │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Identity                        │     │
│  │ OneBit ID                       │     │
│  │ D1A0:3F2B:8C91:4E5A            │     │
│  │ [📋 Copy]                       │     │
│  │                                 │     │
│  │ Fingerprint                     │     │
│  │ 7a3f 2b8c 914e 5a6d ...        │     │
│  │ [🔍 Verify identity]            │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Connection                      │     │
│  │ Status: Connected               │     │
│  │ Signal: Strong (-45 dBm)        │     │
│  │ Route: Direct                   │     │
│  │ Last seen: 2 minutes ago        │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Security                        │     │
│  │ ✓ Verified identity             │     │
│  │ 🔒 End-to-end encrypted         │     │
│  │ [View security details]         │     │
│  └─────────────────────────────────┘     │
│                                          │
├─────────────────────────────────────────┤
│ [💬 Message]     [⚠️ Block]    [🗑️ Remove]│
└─────────────────────────────────────────┘
```

### Peer Actions
| Action | Style | Position |
|--------|-------|----------|
| Message | Primary (accent) | Left |
| Block | Destructive (red outline) | Center |
| Remove | Destructive (red text) | Right |

---

## Verification Indicator Component

### Inline Badge
```
[Shield icon] Verified
```
- Icon: 14px
- Text: Caption/11px
- Color: `green` (verified), `amber` (pending), `text-tertiary` (unverified)

### Avatar Ring
| State | Ring | Width |
|-------|------|-------|
| Verified | `green` solid | 2px |
| Unverified | None | — |
| Pending | `amber` dashed | 2px |
| Changed | `amber` with alert | 2px |

---

## Edit Profile

```
┌─────────────────────────────────────────┐
│ [✕]  Edit Profile               [Save]  │
├─────────────────────────────────────────┤
│                                          │
│         ┌──────────────────┐             │
│         │                  │             │
│         │   [AVA 96px]     │             │
│         │   [📷 Change]    │             │
│         │                  │             │
│         └──────────────────┘             │
│                                          │
│    Display name                          │
│    ┌────────────────────────────────┐    │
│    │ Alice                           │    │
│    └────────────────────────────────┘    │
│                                          │
│    About                                 │
│    ┌────────────────────────────────┐    │
│    │ Privacy-focused communicator   │    │
│    │                                │    │
│    └────────────────────────────────┘    │
│    Max 140 characters                    │
│                                          │
└─────────────────────────────────────────┘
```

### Rules
1. **Cannot change OneBit ID** — it's cryptographically tied
2. **Cannot change fingerprint** — it's derived from keys
3. **Display name** — max 32 characters
4. **About** — max 140 characters, optional
5. **Profile photo** — optional, crop to circle

---

## Profile States

| State | Visual |
|-------|--------|
| Online peer | Green dot on avatar |
| Offline peer | No dot |
| Verified | Green shield badge |
| Unverified | Gray shield outline |
| Identity changed | Amber shield alert |
| Blocked | Red "Blocked" badge |
| Self | No dot, verified badge |

---

## Prototype Connections

| Action | Transition |
|--------|------------|
| Tap QR icon | Push → My QR |
| Tap Edit | Push → Edit profile |
| Tap "View fingerprint" | Bottom sheet → Full fingerprint |
| Tap "Verify identity" (peer) | Push → Verification flow |
| Tap "Message" (peer) | Push → Conversation |
| Tap "Block" (peer) | Dialog → Confirm block |
| Tap "Remove" (peer) | Dialog → Confirm remove |
| Tap "Share" | System share sheet |
