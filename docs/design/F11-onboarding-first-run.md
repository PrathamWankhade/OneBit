# F11 — Onboarding & First-Run Experience

## First Impression
Communicate: private, decentralized, no account needed. Terminal boot sequence aesthetic. 5 screens maximum.

---

## Onboarding Flow

### Screen 1: Welcome (Terminal Boot Sequence)
```
┌─────────────────────────────────────────┐
│                                          │
│                                          │
│         [OneBit SVG, 80px]               │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ > initializing onebit v1.0.0... │     │
│  │ > loading cryptographic modules │     │
│  │ > scanning bluetooth interface  │     │
│  │ > mesh network: ready           │     │
│  │ > encryption: AES-256-GCM       │     │
│  │ > identity: null                │     │
│  │                                 │     │
│  │ > ready.                        │     │
│  │ █ (blinking cursor)             │     │
│  └─────────────────────────────────┘     │
│                                          │
│         Welcome to OneBit                │
│    Private, decentralized mesh.          │
│                                          │
│         [> run]                          │
│                                          │
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Logo | 80px SVG, centered |
| Terminal window | `bgSurface`, 1px `borderSubtle`, 4px radius |
| Boot lines | `technical` 13px Consolas |
| Line colors | cyan for commands, green for "ready", yellow for "null" |
| Cursor | Blinking block `█`, 600ms interval |
| Title | `headlineMedium`, `brightWhite` |
| Subtitle | `bodyMedium`, `white` |
| CTA | `FilledButton`, `> run` |
| Background | `bgBase` |

### Animations
- Lines appear sequentially with 200ms delay
- Cursor blinks at 600ms interval (reverse repeat)
- CTA fades in after boot sequence completes (500ms delay)

---

### Screen 2: How It Works
```
┌─────────────────────────────────────────┐
│ [←]  How OneBit works           [Skip]  │
├─────────────────────────────────────────┤
│                                          │
│  ┌─────────────────────────────────┐     │
│  │                                 │     │
│  │    01  Create your identity     │     │
│  │    Your device generates a      │     │
│  │    unique cryptographic key.    │     │
│  │                                 │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │                                 │     │
│  │    02  Discover nearby peers    │     │
│  │    Find other OneBit users      │     │
│  │    directly via Bluetooth.      │     │
│  │                                 │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │                                 │     │
│  │    03  Communicate privately    │     │
│  │    End-to-end encrypted.        │     │
│  │    No servers. No accounts.     │     │
│  │                                 │     │
│  └─────────────────────────────────┘     │
│                                          │
│         [Continue]                       │
│                                          │
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Back | ← icon, top-left |
| Skip | Text button, top-right, `textSecondary` |
| Step cards | `bgSurface`, `radius-md` (8px), 16px padding |
| Step number | `technical` 24px Consolas, `brightCyan` |
| Step title | `bodyMedium` SemiBold, `brightWhite` |
| Step description | `bodyMedium`, `white` |
| Gap between cards | 12px |

---

### Screen 3: Create Identity
```
┌─────────────────────────────────────────┐
│ [←]  Create your identity        [Skip] │
├─────────────────────────────────────────┤
│                                          │
│         ┌──────────────────┐             │
│         │                  │             │
│         │   [AVA 96px]     │             │
│         │   [📷 camera]    │             │
│         │                  │             │
│         └──────────────────┘             │
│       Tap to add profile photo           │
│                                          │
│    Display name                          │
│    ┌────────────────────────────────┐    │
│    │ Enter your name...             │    │
│    └────────────────────────────────┘    │
│                                          │
│    Your identity is created on your      │
│    device. No account required.          │
│                                          │
│         [Create identity]                │
│                                          │
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Avatar placeholder | 96px circle, `bgElevated`, camera icon overlay |
| Input | Text field, full width |
| Input label | `caption` 12px Medium, `textSecondary` |
| Helper text | `caption` 11px, `textTertiary` |
| CTA | `FilledButton`, full width |

### Validation
- Name required (1–32 characters)
- No special characters
- CTA disabled until name entered

---

### Screen 4: Generating (Terminal Log)
```
┌─────────────────────────────────────────┐
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ onebit@mesh:~$                  │     │
│  │ > generating ed25519 keypair... │     │
│  │ > deriving fingerprint...       │     │
│  │ > creating identity certificate │     │
│  │ > signing with private key...   │     │
│  │ > storing in secure enclave...  │     │
│  │                                 │     │
│  │ > identity generated succeed.   │     │
│  │ █                               │     │
│  └─────────────────────────────────┘     │
│                                          │
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Terminal window | `bgSurface`, 1px `borderSubtle`, 4px radius |
| Prompt | `onebit@mesh:~$`, `brightGreen`, `technical` |
| Log lines | `technical` 13px Consolas |
| Line colors | cyan for commands, green for success |
| Cursor | Blinking block `█` |
| Duration | ~3 seconds (400ms per line) |

---

### Screen 5: Identity Ready
```
┌─────────────────────────────────────────┐
│                                          │
│         [✓ Green checkmark, 64px]        │
│                                          │
│         Identity created                 │
│                                          │
│         [AVA 80px]                       │
│         Alice                            │
│                                          │
│    OneBit ID                             │
│    ┌────────────────────────────────┐    │
│    │ D1A0:3F2B:8C91:4E5A           │    │
│    └────────────────────────────────┘    │
│                                          │
│    Your identity is stored securely      │
│    on this device only.                  │
│                                          │
│         [Start using OneBit]             │
│                                          │
└─────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Checkmark | 64px, `brightGreen` |
| Title | `headlineMedium`, `brightWhite` |
| Avatar | 80px circle with initial |
| Name | `titleLarge`, `brightWhite` |
| OneBit ID | `technical` 13px Consolas, `textSecondary` |
| CTA | `FilledButton` |

---

## Visual Style

### Onboarding-Specific
- **Background:** `bgBase` (pure black, consistent throughout)
- **Transitions:** Slide + fade with parallax (350ms `easeOutExpo`)
- **Font:** Consolas monospace throughout
- **Animations:** Terminal boot sequence, blinking cursor, staggered entrance

### What to Avoid
- Space/cyberpunk imagery
- Hacker imagery
- Excessive illustrations
- Giant gradients
- Long text blocks
- Sans-serif fonts

### Preferred
- Terminal/command-prompt aesthetic
- Monospace typography
- Blinking cursors
- Log-style output
- IBM 5153 color palette

---

## Back Navigation
- Tap back arrow → previous screen
- Tap "Skip" → skip to identity creation
- System back → previous screen

## Post-Onboarding
After "Start using OneBit":
1. Navigate to Home (Conversations tab)
2. Show empty state: "No conversations yet"
3. CTA: "Discover nearby peers"

---

## Prototype Connections

| Action | Transition |
|--------|------------|
| Boot sequence completes | CTA fades in |
| Tap "run" | Slide → How it works |
| Tap "Continue" | Slide → Create identity |
| Tap avatar placeholder | Open camera/gallery picker |
| Type name | Enable "Create identity" CTA |
| Tap "Create identity" | Transition → Generating → Identity ready |
| Tap "Start using OneBit" | Navigate → Home (Conversations) |
| Tap "Skip" | Skip to Create identity |
| Tap back | Previous screen |
