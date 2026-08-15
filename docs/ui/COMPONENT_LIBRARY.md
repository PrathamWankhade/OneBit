# Component Library

## Overview

Every component lives in `lib/shared/design_system/components/` and is a thin
tokenized facade over Material 3. Components are state-agnostic: selection,
controllers and callbacks are owned by callers.

Import components by file — the design system barrel intentionally does not
export them.

```dart
import 'package:onebit/shared/design_system/components/onebit_button.dart';
```

---

## OneBitButton

Tokenized Material 3 button with variants and loading state.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `label` | `String` | required | Button text |
| `onPressed` | `VoidCallback?` | required | Tap handler; `null` disables |
| `variant` | `OneBitButtonVariant` | `primary` | Visual variant |
| `size` | `OneBitButtonSize` | `medium` | Geometric size |
| `icon` | `IconData?` | `null` | Optional leading icon |
| `loading` | `bool` | `false` | Shows spinner, ignores taps |

**Variants:** `primary` (filled), `secondary` (outlined), `tonal` (filled
tonal), `text` (text-only), `destructive` (error-colored filled).

**Sizes:** `small` (32dp), `medium` (40dp), `large` (48dp) — minimum
heights; buttons grow with text scaling.

```dart
OneBitButton(
  label: 'Send',
  icon: Icons.send,
  onPressed: () => send(),
)

OneBitButton(
  label: 'Delete',
  variant: OneBitButtonVariant.destructive,
  onPressed: () => delete(),
)
```

**Accessibility:** Minimum height grows with text scaling. Loading state
announces `"$label loading"` via live semantics region.

---

## OneBitOutlinedButton

Convenience alias for `OneBitButton` with `variant: secondary`. Identical
tokens, tighter call-site semantics.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `label` | `String` | required | Button text |
| `onPressed` | `VoidCallback?` | required | Tap handler; `null` disables |
| `size` | `OneBitButtonSize` | `medium` | Geometric size |
| `icon` | `IconData?` | `null` | Optional leading icon |
| `loading` | `bool` | `false` | Shows spinner, ignores taps |

---

## OneBitCard

Tokenized surface container with hairline border.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `child` | `Widget` | required | Card body |
| `onTap` | `VoidCallback?` | `null` | Tap handler (adds ripple) |
| `onLongPress` | `VoidCallback?` | `null` | Long-press handler |
| `compact` | `bool` | `false` | Compact padding/radius |
| `outlined` | `bool` | `false` | Stronger outlined surface |
| `padding` | `EdgeInsetsGeometry?` | `null` | Override token padding |

```dart
OneBitCard(
  onTap: () => openDetails(),
  child: Text('Channel info'),
)

OneBitCard(
  compact: true,
  child: Row(children: [Text('Status'), Spacer(), OneBitBadge(count: 3)]),
)
```

**Accessibility:** Adds `button` and `enabled` semantics when interactive.

---

## OneBitIconButton

Icon button with guaranteed 48dp interactive target.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `icon` | `IconData` | required | Icon glyph |
| `onPressed` | `VoidCallback?` | required | Tap handler; `null` disables |
| `tooltip` | `String?` | `null` | Tooltip and semantic label |
| `size` | `double` | `m` | Icon size in dp |

```dart
OneBitIconButton(
  icon: Icons.settings,
  tooltip: 'Settings',
  onPressed: () => openSettings(),
)
```

**Accessibility:** 48dp minimum target enforced via constraints. Tooltip
doubles as semantic label for screen readers.

---

## OneBitDivider

Theme-colored divider. Only length overrides.

```dart
OneBitDivider()
OneBitDivider(indent: 16, endIndent: 16)
```

---

## OneBitBadge

Count badge for unread counts and pending items. Hides when `count` is
`null` or zero (unless `showZero`). Counts above 99 display as "99+".

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `count` | `int?` | `null` | Number to display; `null` hides |
| `showZero` | `bool` | `false` | Show for zero count |
| `semanticsLabel` | `String?` | `null` | Custom semantic label |

```dart
OneBitBadge(count: 5)
OneBitBadge(count: 0, showZero: true, semanticsLabel: 'No new messages')
```

**Accessibility:** Container semantics with label; inner text excluded to
avoid doubled announcement.

---

## OneBitStatusChip

Pill-shaped status indicator with tone.

| Tone | Usage |
| --- | --- |
| `neutral` | Default / idle |
| `success` | Connected / online / complete |
| `warning` | Degraded / limited |
| `error` | Failed / disconnected |
| `info` | Transient / informational |

---

## OneBitTextField

Tokenized Material 3 text field.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `controller` | `TextEditingController` | required | Text controller |
| `label` | `String?` | `null` | Floating label |
| `hint` | `String?` | `null` | Hint text |
| `prefixIcon` | `Widget?` | `null` | Prefix icon |
| `suffixIcon` | `Widget?` | `null` | Suffix icon |
| `enabled` | `bool` | `true` | Enabled state |
| `obscureText` | `bool` | `false` | Password mode |
| `keyboardType` | `TextInputType?` | `null` | Keyboard type |
| `textInputAction` | `TextInputAction?` | `null` | Keyboard action |
| `maxLines` | `int` | `1` | Max lines |
| `onChanged` | `ValueChanged<String>?` | `null` | Change callback |
| `onSubmitted` | `ValueChanged<String>?` | `null` | Submit callback |
| `validator` | `FormFieldValidator<String>?` | `null` | Inline validator |
| `autofocus` | `bool` | `false` | Auto-focus on mount |

```dart
final controller = TextEditingController();
OneBitTextField(
  controller: controller,
  label: 'Display name',
  hint: 'Enter your name',
  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
)
```

---

## OneBitSearchField

Search input with prefix icon and clear action.

---

## OneBitSectionHeader

Overline title with optional subtitle and trailing action widget.

---

## OneBitLoadingIndicator

Circular progress indicator with optional label.

---

## OneBitAnimatedProgress

Fades between content and spinner using `AnimatedSwitcher`. Consumes
motion tokens for transition timing.

---

## OneBitEmptyState

Icon + title + message + optional action button. Use when a list or
content area has nothing to display.

---

## OneBitErrorState

Error message + technical detail + retry button. Use for recoverable
error conditions.

---

## OneBitNavigationBar

Tokenized Material 3 bottom navigation bar.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `destinations` | `List<OneBitNavigationDestination>` | required | Tab destinations |
| `selectedIndex` | `int` | required | Active tab index |
| `onDestinationSelected` | `ValueChanged<int>` | required | Tab change handler |

Each `OneBitNavigationDestination` has: `id`, `label`, `icon`,
`selectedIcon`.

```dart
OneBitNavigationBar(
  destinations: shellTabs(l10n).map((t) => t.destination).toList(),
  selectedIndex: currentIndex,
  onDestinationSelected: (i) => navigateTo(i),
)
```

---

## OneBitNavigationRail

Side navigation rail for medium/expanded breakpoints. Same destination
model as `OneBitNavigationBar`.

---

## OneBitAppBar

Tokenized app bar. Provides the standard top chrome for screens within
the shell.

---

## OneBitListItem

Standard list row with leading, title, subtitle, and trailing slots.

---

## OneBitSnackBar

Tokenized snackbar. Floating, inverse surface per theme.

---

## OneBitDialogs

Tokenized dialogs (confirm, info, etc.). Surface from
`surfaceContainerLow`, radius from `OneBitRadius.xl`.

---

## OneBitBottomSheets

Tokenized bottom sheets. Same surface and radius tokens as dialogs.

---

## OneBitProgressBar

Determinate progress bar for transfer progress and similar.

---

## OneBitProgress

Combined progress display (determinate + indeterminate variants).

---

## OneBitTransferCard

Specialized card for file transfer sessions.

---

## OneBitNodeCard

Card for displaying mesh node information.

---

## OneBitMeshCard

Card for mesh network information.

---

## OneBitChannelCard

Card for channel list items.

---

## OneBitDiagnosticCard

Card for diagnostic information display.

---

## OneBitTechnicalCard

Card with technical (monospace) content areas.

---

## OneBitTechnicalField

Read-only field for displaying technical values in monospace.

---

## OneBitTerminalLine

Single line of terminal-style output.

---

## OneBitTerminalLabel

Label for terminal-style sections.

---

## OneBitPanel

Collapsible panel container.

---

## OneBitInlineError

Inline error message display.

---

## OneBitOfflineBanner

Banner shown when the device is offline.

---

## OneBitOfflineState

Full offline state display.

---

## OneBitPermissionState

Permission required state display.

---

## OneBitStatusIndicator

Visual status dot/indicator.

---

## OneBitFilterField

Filter/search input with chip-style filters.

---

## OneBitMessageInput

Message composition input with send button.

---

## OneBitMessageBubble

Chat message bubble.

---

## OneBitSelectionControls

Tokenized selection controls (radio, checkbox).

---

## Adding a new component

1. Place it in `shared/design_system/components/` as `onebit_<name>.dart`.
2. Read every color from the theme; read every size from tokens.
3. Add its geometry to `onebit_component_tokens.dart` (or reuse existing
   tokens) — no magic numbers in the widget.
4. Export nothing from the barrel unless it is a token; components are
   imported by file.
5. Keep it under ~150 lines. Prefer composition over a wall of parameters.
6. Add widget tests under `test/shared/design/components/`.
7. Document product-facing choices here only when they change the language;
   component API details live in the code docs.
