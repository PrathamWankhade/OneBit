# Design System

## Identity

OneBit does not imitate WhatsApp, Telegram, Discord or Messenger. The
character is:

**Professional, minimal, technical, premium, calm, monochrome,
developer-friendly, offline-first.** The app should feel like a
communication operating system.

The visual language is deliberately restrained:

- flat surfaces
- subtle hairline borders
- strong typography
- whitespace and monochrome contrast
- **no** gradients, neon colors, glassmorphism, glossy effects or
  skeuomorphism
- **no** chromatic accents — every hue is derived from the neutral scale
  plus restrained semantic states (success, warning, error, info)

## Layout of the design system

`lib/shared/design_system/` is the single source of every visual decision:

```
design_system/
├── design_system.dart          barrel (tokens only)
├── colors/
│   ├── onebit_palette.dart     raw hex values — the ONLY color literals
│   └── onebit_color_schemes.dart   ColorScheme + OneBitThemeExtension
├── typography/
│   └── onebit_typography.dart  type scale + TextTheme builder
├── spacing/
│   ├── onebit_spacing.dart     8dp scale
│   ├── onebit_radius.dart      corner-radius scale
│   └── onebit_elevation.dart   shadow levels
├── animations/
│   └── onebit_motion.dart     durations + curves + reduced-motion resolve
├── icons/
│   └── onebit_icons.dart       product iconography
├── responsive/
│   └── onebit_responsive.dart  breakpoints + layout helpers
├── accessibility/
│   └── onebit_accessibility.dart   48dp targets, semantics helpers
├── tokens/
│   └── onebit_component_tokens.dart  button/input/card/navigation/
│                                     shape/status/icon geometry
├── themes/
│   └── onebit_theme_data.dart  tokens → ThemeData (component themes)
└── components/
    ├── onebit_app_bar.dart             OneBitAppBar
    ├── onebit_badge.dart               OneBitBadge
    ├── onebit_bottom_sheets.dart       OneBitBottomSheets
    ├── onebit_button.dart              OneBitButton, OneBitOutlinedButton
    ├── onebit_card.dart                OneBitCard
    ├── onebit_channel_card.dart        OneBitChannelCard
    ├── onebit_diagnostic_card.dart     OneBitDiagnosticCard
    ├── onebit_dialogs.dart             OneBitDialogs
    ├── onebit_divider.dart             OneBitDivider
    ├── onebit_empty_state.dart         OneBitEmptyState
    ├── onebit_error_state.dart         OneBitErrorState
    ├── onebit_filter_field.dart        OneBitFilterField
    ├── onebit_icon_button.dart         OneBitIconButton
    ├── onebit_inline_error.dart        OneBitInlineError
    ├── onebit_list_item.dart           OneBitListItem
    ├── onebit_loading_indicator.dart   OneBitLoadingIndicator,
    │                                   OneBitAnimatedProgress
    ├── onebit_message_bubble.dart      OneBitMessageBubble
    ├── onebit_message_input.dart       OneBitMessageInput
    ├── onebit_mesh_card.dart           OneBitMeshCard
    ├── onebit_navigation_bar.dart      OneBitNavigationBar
    ├── onebit_navigation_rail.dart     OneBitNavigationRail
    ├── onebit_node_card.dart           OneBitNodeCard
    ├── onebit_offline_banner.dart      OneBitOfflineBanner
    ├── onebit_offline_state.dart       OneBitOfflineState
    ├── onebit_panel.dart               OneBitPanel
    ├── onebit_permission_state.dart    OneBitPermissionState
    ├── onebit_progress.dart            OneBitProgress
    ├── onebit_progress_bar.dart        OneBitProgressBar
    ├── onebit_search_field.dart        OneBitSearchField
    ├── onebit_section_header.dart      OneBitSectionHeader
    ├── onebit_selection_controls.dart  OneBitSelectionControls
    ├── onebit_settings_card.dart       OneBitSettingsCard
    ├── onebit_snackbar.dart            OneBitSnackBar
    ├── onebit_status_chip.dart         OneBitStatusChip
    ├── onebit_status_indicator.dart    OneBitStatusIndicator
    ├── onebit_technical_card.dart      OneBitTechnicalCard
    ├── onebit_technical_field.dart     OneBitTechnicalField
    ├── onebit_terminal_label.dart      OneBitTerminalLabel
    ├── onebit_terminal_line.dart       OneBitTerminalLine
    ├── onebit_text_field.dart          OneBitTextField
    └── onebit_transfer_card.dart       OneBitTransferCard
```

## Token hierarchy

1. **Raw tokens** — `OneBitPalette`, `OneBitSpacing`, `OneBitRadius`,
   `OneBitElevation`, `OneBitMotion`, `OneBitTypography`,
   `OneBitIconSize`. These hold literal values and are the only place
   literals exist.
2. **Semantic tokens** — the `ColorScheme`/`OneBitThemeExtension` built from
   raw palette values, and `OneBitShapeTokens`/`OneBitComponentTokens`
   built from raw geometry.
3. **Theme binding** — `OneBitThemeData` maps semantic tokens onto Material 3
   component themes.
4. **Components** — consume only semantic tokens and the ambient theme.

## Consumption rules

1. Widgets read semantic colors from `Theme.of(context).colorScheme` or
   `context.oneBitColors` — **never** from `OneBitPalette`.
2. Sizes and radii come from tokens (`OneBitSpacing`, `OneBitShapeTokens`,
   component tokens) — **never** literal numbers.
3. All icons resolve through `OneBitIcons` so iconography changes in one
   place.
4. All user-facing strings are localizable (ARB).

## Components

Every component is a thin tokenized facade over Material 3. Components are
state-agnostic: selection, controllers and callbacks are owned by callers.

| Component | Material 3 basis | Notes |
| --- | --- | --- |
| `OneBitButton` | `FilledButton`/`OutlinedButton`/`TextButton` | variants: primary, secondary, tonal, text, destructive; loading state; minimum height grows with text scaling |
| `OneBitOutlinedButton` | `OutlinedButton` | convenience alias for secondary variant |
| `OneBitCard` | `Material` + `InkWell` | flat tinted surface with hairline border; `compact` and `outlined` variants |
| `OneBitIconButton` | `IconButton` | 48dp minimum target, tooltip → semantics |
| `OneBitDivider` | `Divider` | theme colors/thickness; only length overrides |
| `OneBitBadge` | — | count badge; hides for 0 unless `showZero`; custom semantics label |
| `OneBitStatusChip` | — | pill with tone (neutral/success/warning/error/info) |
| `OneBitTextField` | `TextField` | shared dressing; validator inline |
| `OneBitSearchField` | `TextField` | search prefix + clear action |
| `OneBitSectionHeader` | — | overline title + subtitle + trailing action |
| `OneBitLoadingIndicator` | `CircularProgressIndicator` | optional label |
| `OneBitAnimatedProgress` | `AnimatedSwitcher` | fades content ↔ spinner per motion tokens |
| `OneBitEmptyState` | — | icon + title + message + optional action |
| `OneBitErrorState` | — | message + technical detail + retry |
| `OneBitNavigationBar` | `NavigationBar` | tokenized height, indicator, labels |
| `OneBitNavigationRail` | `NavigationRail` | side rail for medium/expanded layouts |
| `OneBitAppBar` | `AppBar` | tokenized top chrome |
| `OneBitListItem` | — | standard list row with leading/title/subtitle/trailing |
| `OneBitSnackBar` | `SnackBar` | floating, inverse surface |
| `OneBitDialogs` | `Dialog` | confirm/info dialogs, surfaceContainerLow |
| `OneBitBottomSheets` | `BottomSheet` | tokenized bottom sheets |
| `OneBitProgressBar` | `LinearProgressIndicator` | determinate progress |
| `OneBitProgress` | — | combined determinate + indeterminate |
| `OneBitTransferCard` | — | file transfer session card |
| `OneBitNodeCard` | — | mesh node information card |
| `OneBitMeshCard` | — | mesh network card |
| `OneBitChannelCard` | — | channel list card |
| `OneBitDiagnosticCard` | — | diagnostic information card |
| `OneBitTechnicalCard` | — | monospace technical content card |
| `OneBitTechnicalField` | — | read-only monospace field |
| `OneBitTerminalLine` | — | single terminal output line |
| `OneBitTerminalLabel` | — | terminal section label |
| `OneBitPanel` | — | collapsible panel container |
| `OneBitInlineError` | — | inline error message |
| `OneBitOfflineBanner` | — | offline status banner |
| `OneBitOfflineState` | — | full offline state display |
| `OneBitPermissionState` | — | permission required display |
| `OneBitStatusIndicator` | — | visual status dot |
| `OneBitFilterField` | — | filter input with chip filters |
| `OneBitMessageInput` | — | message composition input |
| `OneBitMessageBubble` | — | chat message bubble |
| `OneBitSelectionControls` | — | tokenized radio/checkbox |
| `OneBitSettingsCard` | — | settings row card |

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
