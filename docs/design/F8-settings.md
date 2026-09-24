# F8 — Settings

## Settings Philosophy
MIUI-style layout with colored icon badges. Organized, quiet, technical, easy to scan. All toggles functional.

---

## Settings List

```
┌─────────────────────────────────────────┐
│ Settings                                 │
├─────────────────────────────────────────┤
│                                          │
│ IDENTITY                                 │
│ ┌─────────────────────────────────┐     │
│ │ [👤] My Profile           Edit [→]│    │
│ │ [QR] My QR Code               [→]│    │
│ │ [🔑] Biometric lock      Off  [→]│    │
│ └─────────────────────────────────┘     │
│                                          │
│ PRIVACY & SECURITY                       │
│ ┌─────────────────────────────────┐     │
│ │ [🛡] Verification              [→]│    │
│ │ [🔒] Message encryption  E2EE [→]│    │
│ │ [⛔] Blocked peers             [→]│    │
│ │ [👁] Hide online status   [Toggle]│    │
│ └─────────────────────────────────┘     │
│                                          │
│ MESH & CONNECTIVITY                      │
│ ┌─────────────────────────────────┐     │
│ │ [📡] Nearby discovery     On  [→]│    │
│ │ [🔀] Relay messages       On  [→]│    │
│ │ [🔵] Bluetooth settings      [→]│    │
│ └─────────────────────────────────┘     │
│                                          │
│ NOTIFICATIONS                            │
│ ┌─────────────────────────────────┐     │
│ │ [🔔] Push notifications  [Toggle]│    │
│ │ [🔊] Notification sound  [Toggle]│    │
│ │ [📳] Vibration           [Toggle]│    │
│ └─────────────────────────────────┘     │
│                                          │
│ APPEARANCE                               │
│ ┌─────────────────────────────────┐     │
│ │ [🌙] Theme             Dark  [→]│    │
│ │ [🎨] Accent color          [→]  │    │
│ │ [Aa] Font size        Medium [→]│    │
│ │ [⏰] Show timestamps  [Toggle]  │    │
│ │ [📦] Compact mode     [Toggle]  │    │
│ └─────────────────────────────────┘     │
│                                          │
│ DATA & STORAGE                           │
│ ┌─────────────────────────────────┐     │
│ │ [🖼] Media auto-download  On [→]│    │
│ │ [☁] Backup                 [→]  │    │
│ │ [🗑] Clear cache              [→]│    │
│ └─────────────────────────────────┘     │
│                                          │
│ ADVANCED                                 │
│ ┌─────────────────────────────────┐     │
│ │ [🔧] Diagnostics             [→]│    │
│ │ [ℹ] About OneBit      v1.0.0 [→]│    │
│ │ [📄] Licenses                 [→]│    │
│ └─────────────────────────────────┘     │
│                                          │
└─────────────────────────────────────────┘
```

---

## Setting Item Component

### Standard Item
```
┌─────────────────────────────────────────┐
│ [Icon badge]  Title              [Value] [→]│
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Height | 56px |
| Icon badge | 36×36px, 15% opacity bg, 8px radius |
| Title | `bodyMedium`, `brightWhite` |
| Value | `technicalSmall`, `textSecondary` |
| Arrow | 18px chevron, `textTertiary` |
| Padding | 12px horizontal |

### Toggle Item
```
┌─────────────────────────────────────────┐
│ [Icon badge]  Title               [Switch]│
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Switch | `accent` when on, `bgMuted` when off |
| Tap row | Toggles switch |

### Section Header
```
SECTION NAME
```

| Element | Spec |
|---------|------|
| Style | `caption` 12px, `textSecondary`, letter-spacing 1.2 |
| Padding | 4px left, 8px bottom |

---

## Color Badges

Each settings item has a colored icon badge using IBM 5153 bright colors:

| Section | Icon Color |
|---------|------------|
| Identity | `brightCyan`, `brightGreen`, `brightPurple` |
| Privacy | `brightGreen`, `brightCyan`, `brightRed`, `brightYellow` |
| Mesh | `brightGreen`, `yellow`, `brightBlue` |
| Notifications | `brightRed`, `brightGreen`, `brightPurple` |
| Appearance | `brightPurple`, `brightCyan`, `brightYellow`, `brightGreen`, `yellow` |
| Data | `brightPurple`, `brightCyan`, `brightRed` |
| Advanced | `brightBlue`, `brightCyan`, `white` |

---

## Sub-Screens

### Privacy & Security
- Verification settings → push to `/identity/verify`
- Message encryption → info dialog (E2EE always on)
- Blocked peers → placeholder
- Hide online status → toggle (wired to `settingsDiscoveryEnabledProvider`)

### Mesh & Connectivity
- Bluetooth status (info only)
- Nearby discovery → toggle (wired to `settingsDiscoveryEnabledProvider`)
- Relay participation → toggle (wired to `settingsRelayEnabledProvider`)
- Device name (info only)
- Active connections (info only)

### Appearance
- Theme selection (System/Dark/Light)
- Accent color picker (6 colors)
- Font size (Small/Medium/Large)
- Show timestamps → toggle (wired to `settingsShowTimestampsProvider`)
- Compact mode → toggle (wired to `settingsCompactModeProvider`)
- Reduced motion → toggle (wired to `settingsReducedMotionProvider`)

---

## Dialog Patterns

### Info Dialog
```
┌─────────────────────────────────────────┐
│                                          │
│    Title                                  │
│                                          │
│    Description text here.                 │
│                                          │
│                        [OK]              │
│                                          │
└─────────────────────────────────────────┘
```

### Confirmation Dialog
```
┌─────────────────────────────────────────┐
│                                          │
│    Title                                  │
│                                          │
│    Description text here.                 │
│                                          │
│    [Cancel]           [Confirm]          │
│                                          │
└─────────────────────────────────────────┘
```

### Rules
1. **Destructive actions** always require confirmation
2. **Dialog title** states the action
3. **Dialog body** explains the consequence
4. **Cancel** on left, **Confirm** on right

---

## Prototype Connections

| Action | Transition |
|--------|------------|
| Tap profile row | Push → `/identity/edit` |
| Tap QR code | Push → `/identity/qr` |
| Tap verification | Push → `/settings/privacy` |
| Tap mesh items | Push → `/settings/mesh` |
| Tap appearance items | Push → `/settings/appearance` |
| Tap diagnostics | Push → `/settings/routing-diagnostics` |
| Tap about | Push → `/settings/about` |
| Tap licenses | Show license page |
| Toggle switch | Immediate state change + persist |
| Tap info items | Show info dialog |
| Tap backup | Show backup dialog |
| Tap clear cache | Show clear cache dialog |
