# F5 — Peer Discovery / BLE Mesh Experience

## Screen Purpose
The decentralized peer discovery experience. Where OneBit becomes visibly different from WhatsApp and Telegram. Communicates: nearby peers, connection quality, mesh routes, relay availability, signal strength — without requiring technical knowledge.

---

## Discovery Screen Layout

### Scanning State
```
┌─────────────────────────────────────────┐
│ [←]  Nearby Devices              [⟳]    │
├─────────────────────────────────────────┤
│                                          │
│         [Animated node icon, 64px]       │
│                                          │
│      Discovering nearby OneBit nodes     │
│                                          │
│    ●  Scanning for nearby devices...     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │  [脉冲动画 rings]                │     │
│  └─────────────────────────────────┘     │
│                                          │
│    OneBit communicates directly with     │
│    nearby devices. No internet needed.   │
│                                          │
├─────────────────────────────────────────┤
│ [Advertise]                    [Stop adv]│  ← Bottom actions
└─────────────────────────────────────────┘
```

### Peers Found State
```
┌─────────────────────────────────────────┐
│ [←]  Nearby Devices              [⟳]    │
├─────────────────────────────────────────┤
│ 2 nearby                                │
│ ┌─────────────────────────────────┐     │
│ │ [AVA] Alice         ●  Strong  │     │
│ │        Verified · 2m ago        │     │
│ └─────────────────────────────────┘     │
│ ┌─────────────────────────────────┐     │
│ │ [AVA] Bob           ◐  Weak    │     │
│ │        Unverified · 5m ago      │     │
│ └─────────────────────────────────┘     │
│                                          │
│ ─── Network topology ───                 │
│                                          │
│         [You]                            │
│          │                               │
│     ┌────┴────┐                          │
│   Alice     Bob                          │
│    ●         ◐                           │
│                                          │
├─────────────────────────────────────────┤
│ [Advertise]                    [Stop adv]│
└─────────────────────────────────────────┘
```

### No Peers State
```
┌─────────────────────────────────────────┐
│ [←]  Nearby Devices              [⟳]    │
├─────────────────────────────────────────┤
│                                          │
│         [Node icon, 48px, muted]         │
│                                          │
│      No OneBit nodes nearby              │
│                                          │
│   OneBit communicates directly with      │
│   nearby devices. Try moving closer      │
│   to other OneBit users.                 │
│                                          │
│           [Scan again]                   │
│                                          │
├─────────────────────────────────────────┤
│ [Advertise]                    [Stop adv]│
└─────────────────────────────────────────┘
```

---

## Peer Card

### Standard Peer Card
```
┌─────────────────────────────────────────┐
│ [AVA]  Alice                  ●  Strong │
│        Verified · Last seen 2m ago      │
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Height | 72px |
| Avatar | 48px circle |
| Name | Body/14px/SemiBold, `text-primary` |
| Status | Caption/11px, `text-secondary` |
| Signal indicator | Right-aligned |
| Verification badge | Inline after name |
| Tap action | Push → Peer Detail |
| Long press | Bottom sheet → peer actions |

### Peer Card States

| State | Avatar Ring | Signal | Status Text |
|-------|-------------|--------|-------------|
| Discovered | None | Signal bars | "Last seen Xm ago" |
| Connecting | Pulsing `accent` | — | "Connecting..." |
| Connected | `accent` ring | Signal bars | "Connected" |
| Verified | `green` ring | Signal bars | "Verified" |
| Unverified | None | Signal bars | "Unverified" |
| Weak signal | None | Weak bars | "Weak signal" |
| Relay | `amber` ring | — | "Via relay" |
| Unavailable | Muted | None | "Unavailable" |

### Signal Strength Indicator

```
Strong  ██████  (3 bars, `green`)
Good    ████░░  (3 bars, `green`)
Fair    ██░░░░  (2 bars, `amber`)
Weak    █░░░░░  (1 bar, `amber`)
None    ░░░░░░  (0 bars, `text-tertiary`)
```

| Level | Bars | Color | RSSI Range |
|-------|------|-------|------------|
| Strong | 3 filled | `green` | -50 to 0 dBm |
| Good | 3 (2 filled) | `green` | -65 to -50 dBm |
| Fair | 3 (1 filled) | `amber` | -80 to -65 dBm |
| Weak | 3 (1 filled, dim) | `amber` | -90 to -80 dBm |
| None | 0 | `text-tertiary` | < -90 dBm |

---

## Peer Detail

```
┌─────────────────────────────────────────┐
│ [←]  Peer Identity                      │
├─────────────────────────────────────────┤
│                                          │
│            [AVA 80px]                    │
│              ● Online                    │
│                                          │
│            Alice                         │
│         Verified peer                    │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ OneBit ID                       │     │
│  │ D1A0:3F2B:8C91:4E5A            │     │
│  │ [📋 Copy]                       │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Fingerprint                     │     │
│  │ 7a3f 2b8c 914e 5a6d ...        │     │
│  │ [📋 Copy] [🔍 Verify]           │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Connection                      │     │
│  │ Signal: Strong (-45 dBm)        │     │
│  │ Last seen: 2 minutes ago        │     │
│  │ Route: Direct                   │     │
│  └─────────────────────────────────┘     │
│                                          │
├─────────────────────────────────────────┤
│ [💬 Message]          [⚠️ Block]         │
└─────────────────────────────────────────┘
```

### Identity Card
| Field | Display |
|-------|---------|
| OneBit ID | Monospace/Technical, split into groups of 4 |
| Fingerprint | Monospace, grouped with spaces |
| Verification state | Color-coded badge |
| Connection info | Standard body text |

---

## Network Topology Visualization

### Minimal Representation
```
         [You]
          │
     ┌────┴────┐
   Alice     Bob
    ●         ◐
```

### Visual Rules
1. **"You" node** at top center, `accent` circle with identity initial
2. **Direct peers** connected by vertical lines
3. **Relay peers** connected via dashed lines
4. **Node indicators:** Same colors as signal strength (green/amber/red)
5. **No complex graphs.** Tree structure only, max 2 levels deep
6. **Lines:** 1px, `border-default` color
7. **Nodes:** 32px circles with initials

### Topology States
| Route | Line Style | Color |
|-------|-----------|-------|
| Direct | Solid | `border-default` |
| Relay | Dashed | `amber` |
| Multi-hop | Dotted | `text-tertiary` |

---

## Peer Actions Bottom Sheet

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

### Action Visibility
| Action | Discovered | Connected | Verified |
|--------|------------|-----------|----------|
| Start conversation | ✓ | ✓ | ✓ |
| Verify identity | ✓ | ✓ | — |
| View identity | ✓ | ✓ | ✓ |
| Copy OneBit ID | ✓ | ✓ | ✓ |
| Block peer | ✓ | ✓ | ✓ |
| Forget peer | ✓ | — | ✓ |

---

## Empty State

### No Peers Nearby
```
┌─────────────────────────────────────────┐
│                                          │
│         [Node icon, 48px]                │
│                                          │
│      No OneBit nodes nearby              │
│                                          │
│   OneBit communicates directly with      │
│   nearby devices.                        │
│                                          │
│   Try moving closer to other OneBit      │
│   users or wait for peers to appear.     │
│                                          │
│           [Scan again]                   │
│                                          │
└─────────────────────────────────────────┘
```

### No Peers After Scan
```
Same as above but with:
"Scan completed. No OneBit nodes found nearby."
```

---

## Prototype States

### State Machine
```
Idle → Scanning → Peers Found → Peer Selected → Conversation
                 ↓
              No Peers
                 ↓
              Scan Again → Scanning
```

### Transitions
| From | To | Trigger |
|------|----|---------|
| Idle | Scanning | Auto on screen enter, or "Scan again" tap |
| Scanning | Peers Found | Peer discovered |
| Scanning | No Peers | Scan timeout (30s) |
| Peers Found | Peer Detail | Tap peer card |
| Peer Detail | Conversation | "Start conversation" |
| Peer Detail | Verify | "Verify identity" |
| Scanning | Connecting | "Connect" action |
| Connecting | Connected | Connection success |
| Connecting | Error | Connection failure |
