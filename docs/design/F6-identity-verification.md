# F6 — Identity & Verification

## Screen Purpose
Identity is a core product feature, not a secondary settings page. The experience must communicate: "This device has its own cryptographic identity."

---

## Identity Setup (Onboarding Flow)

### Step 1: Welcome
```
┌─────────────────────────────────────────┐
│                                          │
│                                          │
│         [◆ Key/Diamond icon, 64px]       │
│              accent color                │
│                                          │
│         Welcome to OneBit                │
│                                          │
│    A private, decentralized              │
│    communication platform.               │
│                                          │
│    Your identity lives on your           │
│    device. No account needed.            │
│                                          │
│                                          │
│         [Get started]                    │
│                                          │
│         Already have identity?           │
│         [Import]                         │
│                                          │
└─────────────────────────────────────────┘
```

### Step 2: How It Works
```
┌─────────────────────────────────────────┐
│                                          │
│    How OneBit works                      │
│                                          │
│    ┌────────────────────────────────┐    │
│    │ 1. Create your identity        │    │
│    │    Your device generates a     │    │
│    │    unique cryptographic key.   │    │
│    └────────────────────────────────┘    │
│                                          │
│    ┌────────────────────────────────┐    │
│    │ 2. Discover nearby peers       │    │
│    │    Find other OneBit users     │    │
│    │    directly via Bluetooth.     │    │
│    └────────────────────────────────┘    │
│                                          │
│    ┌────────────────────────────────┐    │
│    │ 3. Communicate privately       │    │
│    │    Messages are encrypted      │    │
│    │    and never leave your        │    │
│    │    device until delivered.     │    │
│    └────────────────────────────────┘    │
│                                          │
│         [Continue]                       │
│                                          │
└─────────────────────────────────────────┘
```

### Step 3: Create Identity
```
┌─────────────────────────────────────────┐
│                                          │
│    Create your identity                  │
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
│         [Create identity]                │
│                                          │
└─────────────────────────────────────────┘
```

### Step 4: Generating
```
┌─────────────────────────────────────────┐
│                                          │
│         [Animated key generation]        │
│                                          │
│      Generating your identity...         │
│                                          │
│    Creating cryptographic keys           │
│    and unique identifiers.               │
│                                          │
└─────────────────────────────────────────┘
```

### Step 5: Identity Ready
```
┌─────────────────────────────────────────┐
│                                          │
│         [◆ Green checkmark]              │
│                                          │
│         Identity created                 │
│                                          │
│         [AVA 64px]                       │
│         Alice                            │
│                                          │
│    OneBit ID                             │
│    ┌────────────────────────────────┐    │
│    │ D1A0:3F2B:8C91:4E5A           │    │
│    └────────────────────────────────┘    │
│                                          │
│    Your identity is stored securely      │
│    on this device.                       │
│                                          │
│         [Start using OneBit]             │
│                                          │
└─────────────────────────────────────────┘
```

---

## Identity Profile (Identity Tab)

```
┌─────────────────────────────────────────┐
│ [←]  My Identity               [✏️] [QR]│
├─────────────────────────────────────────┤
│                                          │
│            [AVA 80px]                    │
│            Alice                         │
│       ● Verified identity               │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ OneBit ID                       │     │
│  │ D1A0:3F2B:8C91:4E5A            │     │
│  │ [📋 Copy]  [📤 Share]           │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Fingerprint                     │     │
│  │ 7a3f 2b8c 914e 5a6d 3f2b 8c91 │     │
│  │ [🔍 View full]  [📋 Copy]       │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Created                         │     │
│  │ January 15, 2026                │     │
│  └─────────────────────────────────┘     │
│                                          │
│  ┌─────────────────────────────────┐     │
│  │ Security                        │     │
│  │ Encryption: Active              │     │
│  │ Keys: 256-bit                   │     │
│  │ [View security details]         │     │
│  └─────────────────────────────────┘     │
│                                          │
└─────────────────────────────────────────┘
```

---

## Fingerprint Component

### Compact (inline)
```
┌─────────────────────────────────────────┐
│ 🔑 7a3f 2b8c 914e 5a6d ...    [📋 Copy]│
└─────────────────────────────────────────┘
```
- Technical/13px, JetBrains Mono
- Groups of 4 characters separated by spaces
- Copy button right-aligned

### Full View
```
┌─────────────────────────────────────────┐
│ Fingerprint                              │
│                                          │
│ 7a3f 2b8c 914e 5a6d                     │
│ 3f2b 8c91 4e5a 6d7f                     │
│ 2b8c 914e 5a6d 3f2b                     │
│ 8c91 4e5a 6d7f 2b8c                     │
│                                          │
│ [📋 Copy]  [📤 Share]  [🔍 Verify]       │
└─────────────────────────────────────────┘
```
- Technical/13px, JetBrains Mono
- 4 groups per line, 4 lines
- Actions below

### Fingerprint Verification
Compare with peer's fingerprint:
```
┌─────────────────────────────────────────┐
│ Verify fingerprint                       │
│                                          │
│ Your fingerprint:                        │
│ 7a3f 2b8c 914e 5a6d ...                 │
│                                          │
│ Peer's fingerprint:                      │
│ 7a3f 2b8c 914e 5a6d ...                 │
│                                          │
│ [✓ Match]     [✗ Don't match]           │
└─────────────────────────────────────────┘
```

---

## QR Identity

### My QR
```
┌─────────────────────────────────────────┐
│ [←]  My QR Code                         │
├─────────────────────────────────────────┤
│                                          │
│         [AVA 48px]                       │
│         Alice                            │
│                                          │
│    ┌────────────────────────────────┐    │
│    │                                │    │
│    │        [QR Code]               │    │
│    │        200x200px               │    │
│    │                                │    │
│    └────────────────────────────────┘    │
│                                          │
│    D1A0:3F2B:8C91:4E5A                  │
│                                          │
│    Share this QR code to let             │
│    others add you as a peer.             │
│                                          │
│    Your identity is verified             │
│    and encrypted.                        │
│                                          │
│         [Share]  [Save]                  │
│                                          │
└─────────────────────────────────────────┘
```

### Scan QR
```
┌─────────────────────────────────────────┐
│ [←]  Scan QR Code                       │
├─────────────────────────────────────────┤
│                                          │
│  ┌────────────────────────────────┐     │
│  │                                │     │
│  │      [Camera viewfinder]       │     │
│  │                                │     │
│  │         ┌────────┐             │     │
│  │         │  Scan  │             │     │
│  │         │  area  │             │     │
│  │         └────────┘             │     │
│  │                                │     │
│  └────────────────────────────────┘     │
│                                          │
│    Point camera at a OneBit QR code      │
│                                          │
│         [Enter ID manually]              │
│                                          │
└─────────────────────────────────────────┘
```

---

## Verification Flow

### Step 1: Select Peer
```
┌─────────────────────────────────────────┐
│ Verify identity                          │
│                                          │
│ Select the peer you want to verify:      │
│                                          │
│ [AVA] Alice    ●  Strong signal          │
│ [AVA] Bob      ●  Strong signal          │
│ [AVA] Charlie  ◐  Relay                  │
└─────────────────────────────────────────┘
```

### Step 2: Compare Fingerprints
```
┌─────────────────────────────────────────┐
│ Verify Alice's identity                  │
│                                          │
│ Compare this fingerprint with Alice:     │
│                                          │
│ 7a3f 2b8c 914e 5a6d                     │
│ 3f2b 8c91 4e5a 6d7f                     │
│                                          │
│ Ask Alice to show their fingerprint      │
│ and confirm they match.                  │
│                                          │
│ [✓ Fingerprints match]                   │
│ [✗ Don't match]                          │
└─────────────────────────────────────────┘
```

### Step 3: Success
```
┌─────────────────────────────────────────┐
│                                          │
│         [✓ Green checkmark]              │
│                                          │
│     Alice is now verified                │
│                                          │
│   Alice's identity has been              │
│   verified. You can trust that           │
│   messages from Alice are                │
│   genuinely from them.                   │
│                                          │
│         [Done]                           │
│                                          │
└─────────────────────────────────────────┘
```

### Verification States

| State | Badge | Color | Text |
|-------|-------|-------|------|
| Not verified | Shield outline | `text-tertiary` | — |
| Verification pending | Shield outline | `amber` | "Pending" |
| Verified | Shield check | `green` | "Verified" |
| Identity changed | Shield alert | `amber` | "Identity changed" |
| Verification failed | Shield x | `red` | "Failed" |

---

## Security UX Messages

| Scenario | User-facing text |
|----------|-----------------|
| Encrypted | "Messages are end-to-end encrypted" |
| Verified | "This peer's identity is verified" |
| Not verified | "This peer has not been verified" |
| Identity changed | "This peer's identity has changed since you last connected" |
| Verification pending | "Waiting for peer to confirm fingerprint" |
| Verification failed | "Fingerprints do not match. This may indicate a security issue." |

---

## Prototype Connections

| Action | Transition |
|--------|------------|
| Tap "Get started" | Push → How it works |
| Tap "Continue" | Push → Create identity |
| Tap "Create identity" | Loading → Identity ready |
| Tap "Start using OneBit" | Navigate → Home |
| Tap QR icon | Push → My QR |
| Tap Scan QR | Push → Camera/Scan |
| Tap fingerprint "View full" | Bottom sheet → Full fingerprint |
| Tap "Verify" on peer | Push → Verification flow |
| Tap "Match" | Push → Success |
