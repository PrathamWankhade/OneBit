# F1 — Design Foundation & Visual Language

## Brand Character

**Personality:** private, technical, terminal aesthetic, trustworthy, minimal, precise, decentralized, resilient

**Avoid:** cybersecurity dashboard, cyberpunk, excessive neon, glassmorphism everywhere, giant gradients, overly rounded social-media UI

**Feel like:** IBM 5153 terminal — serious communication infrastructure with retro-computing aesthetic

---

## Color System

### IBM 5153 Terminal Palette

All values are sRGB hex. Dark-only — no light theme.

#### Backgrounds

| Token | Hex | Usage |
|-------|-----|-------|
| `bgBase` | `#000000` | Pure black background |
| `bgSurface` | `#0A0A0A` | Elevated surfaces |
| `bgElevated` | `#111111` | Cards, sheets, dialogs |
| `bgOverlay` | `#1A1A1A` | Hover states, pressed states |
| `bgMuted` | `#222222` | Disabled backgrounds, code blocks |

#### Text

| Token | Hex | Usage |
|-------|-----|-------|
| `textPrimary` | `#FFFFFF` | Primary text — bright white |
| `textSecondary` | `#AAAAAA` | Secondary text — muted gray |
| `textTertiary` | `#555555` | Tertiary text, placeholders |
| `textDisabled` | `#333333` | Disabled text |
| `textInverse` | `#000000` | Text on light/accent backgrounds |

#### Accent — IBM Cyan

| Token | Hex | Usage |
|-------|-----|-------|
| `accent` | `#00AAAA` | Primary accent — IBM cyan |
| `accentMuted` | `#008888` | Hover, pressed accent |
| `accentSubtle` | `rgba(0,170,170,0.12)` | Accent backgrounds, tints |

#### Standard Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `red` | `#AA0000` | Errors, danger |
| `green` | `#00AA00` | Success, online |
| `yellow` | `#AA5500` | Warnings |
| `blue` | `#0000AA` | Informational |
| `magenta` | `#AA00AA` | Optional accent |
| `cyan` | `#00AAAA` | Active indicators |
| `white` | `#AAAAAA` | Body text |

#### Bright Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `brightRed` | `#FF5555` | Bright errors |
| `brightGreen` | `#55FF55` | Bright success |
| `brightYellow` | `#FFFF55` | Bright warnings |
| `brightBlue` | `#5555FF` | Bright info |
| `brightMagenta` | `#FF55FF` | Bright accent |
| `brightCyan` | `#55FFFF` | Bright active |
| `brightWhite` | `#FFFFFF` | Primary text |

### Color Usage Rules

1. **Pure black backgrounds.** `#000000` everywhere — no charcoal, no warm blacks.
2. **Color communicates state, not decoration.** Every colored element conveys meaning.
3. **Accent appears sparingly.** Primary actions, selected states, active indicators.
4. **Semantic colors are contextual.** Green = verified. Red = destructive. Amber = warning.
5. **Text contrast minimum 4.5:1** for body text against `#000000`.

---

## Typography

### Typeface

| Role | Typeface | Fallback |
|------|----------|----------|
| **All UI** | Consolas | SF Mono, Fira Code, monospace |

Consolas is used for all text — UI labels, body text, technical content. No Inter, no sans-serif.

### Type Scale

All sizes in logical pixels.

| Name | Size | Weight | Line Height | Letter Spacing | Usage |
|------|------|--------|-------------|----------------|-------|
| **Display** | 28px | 700 (Bold) | 36px | -0.02em | Hero text, onboarding |
| **Headline** | 20px | 600 (SemiBold) | 28px | -0.01em | Screen titles |
| **Title** | 16px | 600 (SemiBold) | 22px | 0 | Section titles |
| **Body Large** | 16px | 400 (Regular) | 22px | 0 | Primary content |
| **Body** | 14px | 400 (Regular) | 20px | 0 | Secondary content |
| **Body Small** | 13px | 400 (Regular) | 18px | 0.01em | Compact body |
| **Label** | 12px | 500 (Medium) | 16px | 0.02em | Labels, badges |
| **Caption** | 11px | 400 (Regular) | 14px | 0.02em | Timestamps |
| **Technical** | 13px | 400 (Regular) | 18px | 0.01em | Fingerprints, IDs |
| **Technical Small** | 11px | 400 (Regular) | 14px | 0.01em | Hashes, packet IDs |

### Typography Rules

1. **Maximum 3 weights per screen.** Regular (400), Medium (500), SemiBold (600). Bold (700) for display only.
2. **Monospace everywhere.** All text is Consolas — no sans-serif.
3. **Text color from the token system.** Never manually choose text colors.
4. **No ALL CAPS.** Use letter-spacing on labels instead.

---

## Spacing Scale

Base unit: **4px**

| Token | Value | Usage |
|-------|-------|-------|
| `space-0` | 0px | No spacing |
| `space-1` | 4px | Tight internal padding |
| `space-2` | 8px | Compact gaps, icon-to-text |
| `space-3` | 12px | Standard internal padding |
| `space-4` | 16px | Standard component padding |
| `space-5` | 20px | Comfortable spacing |
| `space-6` | 24px | Section spacing |
| `space-8` | 32px | Large section spacing |
| `space-10` | 40px | Screen-level vertical spacing |
| `space-12` | 48px | Hero spacing |
| `space-16` | 64px | Maximum spacing |

### Layout Constants

| Constant | Value | Usage |
|----------|-------|-------|
| Screen horizontal padding | 16px | Left/right padding on all screens |
| List item height | 56px | Standard list item |
| List item height compact | 48px | Dense list items |
| List item height large | 72px | Avatar-forward list items |
| App bar height | 56px | Top app bar |
| Bottom nav height | 64px | Bottom navigation bar |
| FAB size | 56px | Floating action button |
| FAB icon | 24px | Icon inside FAB |
| Touch target minimum | 44px | Minimum tappable area |

---

## Shape Language

### Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| `radius-none` | 0px | No rounding |
| `radius-xs` | 4px | Terminal containers, small controls |
| `radius-sm` | 6px | Inputs, compact surfaces |
| `radius-md` | 8px | Buttons, list items |
| `radius-lg` | 12px | Cards, grouped sections |
| `radius-xl` | 16px | Dialogs, bottom sheets |
| `radius-full` | 9999px | Pills — status badges, filters only |

### Shape Rules

1. **Default radius: 4px.** Terminal aesthetic — minimal rounding.
2. **Pills are reserved.** Status badges, filter chips, selected categories. Not for buttons.
3. **No perfectly sharp corners** except dividers and full-bleed elements.
4. **Consistent within groups.** All items in a list share the same radius.

---

## Elevation

Dark-first elevation uses opacity overlays, not drop shadows.

| Level | Value | Usage |
|-------|-------|-------|
| `elevation-0` | None | Base surface |
| `elevation-1` | `rgba(255,255,255,0.03)` overlay | Subtle lift — cards in lists |
| `elevation-2` | `rgba(255,255,255,0.06)` overlay | Medium lift — dialogs, sheets |
| `elevation-3` | `rgba(255,255,255,0.09)` overlay | High lift — FAB, snackbars |

**No drop shadows on dark backgrounds.** Use background color differentiation instead.

---

## Iconography

### Style

- **Outline style** — 1.5px stroke weight
- **Consistent 24x24 grid** for standard icons
- **Geometric, technical feel** — clean angles, minimal curves
- **No filled icons** except for selected/active states (use accent fill)

### Icon Sizes

| Token | Size | Usage |
|-------|------|-------|
| `icon-xs` | 16px | Inline icons in text |
| `icon-sm` | 20px | Compact list items |
| `icon-md` | 24px | Standard — buttons, nav, app bar |
| `icon-lg` | 32px | Feature icons, empty states |
| `icon-xl` | 48px | Hero icons, onboarding |

### OneBit-Specific Icons

Design dedicated symbols for:

| Concept | Description |
|---------|-------------|
| **Identity** | Abstract key/diamond shape |
| **Peer** | Two overlapping circles |
| **Mesh** | Three connected nodes |
| **Connection** | Linked chain segments |
| **Verification** | Shield with checkmark |
| **Fingerprint** | Abstracted fingerprint lines |
| **Encryption** | Lock with subtle node motif |
| **Signal** | Concentric arc segments |
| **Nearby node** | Pulsing circle with center dot |
| **Message** | Rectangular bubble with tail |
| **Attachment** | Paperclip variant |
| **File** | Document with folded corner |
| **Image** | Frame with mountain motif |
| **Voice** | Waveform bars |
| **Settings** | Gear with hexagonal inner |
| **Security** | Shield with keyhole |

---

## Component Library

### Component Inventory

Every component below requires variants for: **default**, **hover/pressed**, **disabled**, **loading** (where applicable).

#### Navigation
- Top App Bar (back, title, search, overflow, identity indicator)
- Bottom Navigation (icon + label, selected state, badge indicator)
- Floating Nav Bar (3 tabs: Chats, Nearby, Identity)

#### Inputs
- Search Field (empty, active, with query, with results)
- Text Field (empty, focused, filled, error, disabled)
- Toggle (on, off, disabled)

#### Buttons
- Primary Button (default, hover, pressed, disabled, loading)
- Secondary/Outline Button (default, hover, pressed, disabled)
- Destructive Button (default, hover, pressed, disabled)
- Icon Button (default, hover, pressed, disabled)
- Text Button (default, hover, pressed, disabled)
- FAB (default, pressed, extended)

#### Display
- Avatar (initials, image, online indicator)
- Identity Avatar (with verification ring)
- Status Badge (online, away, offline)
- Verification Indicator (verified, unverified, pending)
- Signal Indicator (strong, good, weak, none)

#### Lists
- List Item (default, selected, with avatar, with badge)
- Conversation Item (unread, read, muted, pinned, offline)
- Peer Item (discovered, connecting, connected, verified)
- Section Header

#### Feedback
- Snackbar (info, success, warning, error)
- Dialog (confirmation, destructive, informational)
- Bottom Sheet (actions, picker, details)
- Empty State (icon, title, description, action)
- Loading State (spinner, skeleton)
- Error State (icon, title, description, retry)

#### Media
- Image Attachment (preview, caption, progress)
- File Attachment (icon, name, size, progress)
- Voice Message (waveform, duration, play state)

#### Messaging
- Message Bubble (incoming, outgoing)
- System Message
- Date Divider
- Delivery Status (sent, delivered, read, failed)
- Encryption Indicator

---

## Terminal UI

### Boot Sequence (Welcome Screen)

```
> initializing onebit v1.0.0...
> loading cryptographic modules...
> scanning bluetooth interface...
> mesh network: ready
> encryption: AES-256-GCM
> identity: null

> ready.
█ (blinking cursor)
```

- Lines appear one by one with 200ms delay
- Green for "ready", yellow for "null", cyan for others
- Blinking block cursor at bottom
- `$ run` button appears after boot completes

### Generating Screen

```
onebit@mesh:~$
> generating ed25519 keypair...
> deriving fingerprint...
> creating identity certificate...
> signing with private key...
> storing in secure enclave...

> identity generated successfully.
█
```

### Transitions

- **Route push**: 350ms slide+fade with parallax
- **Onboarding pages**: 500ms `easeOutExpo`
- **Entrance animations**: Staggered (200ms offset per element)

---

## Design Tokens Summary

| Collection | Variables |
|------------|-----------|
| **Color/Background** | `bgBase`, `bgSurface`, `bgElevated`, `bgOverlay`, `bgMuted` |
| **Color/Text** | `textPrimary`, `textSecondary`, `textTertiary`, `textDisabled`, `textInverse` |
| **Color/Accent** | `accent`, `accentMuted`, `accentSubtle` |
| **Color/Standard** | `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white` |
| **Color/Bright** | `brightRed`, `brightGreen`, `brightYellow`, `brightBlue`, `brightMagenta`, `brightCyan`, `brightWhite` |
| **Typography** | `Display`, `Headline`, `Title`, `Body-Large`, `Body`, `Body-Small`, `Label`, `Caption`, `Technical`, `Technical-Small` |
| **Spacing** | `space-0` through `space-16` |
| **Radius** | `radius-none` through `radius-full` |
| **Elevation** | `elevation-0` through `elevation-3` |
| **Icon Size** | `icon-xs` through `icon-xl` |
