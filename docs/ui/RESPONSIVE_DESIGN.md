# Responsive Design

## Model

OneBit derives every layout decision from the available width at build time —
there are no device-specific hard-coded dimensions. The model follows the
Material 3 window classes.

`lib/shared/design_system/responsive/onebit_responsive.dart` defines:

| Breakpoint | Width | Devices |
| --- | --- | --- |
| `compact` | < 600dp | phones in portrait |
| `medium` | 600–839dp | large phones, foldables unfolded, small tablets, phones in landscape |
| `expanded` | ≥ 840dp | tablets, desktop-style windows |

`OneBitBreakpoint.usesBottomNavigation` is true only for `compact` — a hint
for shells that switch from bottom navigation to a side rail/table rail at
larger widths.

## Helpers

- `context.breakpoint` — the current `OneBitBreakpoint`.
- `context.isCompact` — phones in portrait.
- `context.isTablet` — anything at least medium-sized.
- `context.isExpanded` — tablet/desktop widths.
- `OneBitResponsiveLayout` — switch on breakpoint with fallback builders:

```dart
OneBitResponsiveLayout(
  compact: (context) => const CompactLayout(),
  medium: (context) => const MediumLayout(),
  expanded: (context) => const ExpandedLayout(),
)
```

`medium` falls back to `compact` and `expanded` to `medium` then `compact`
when omitted, so new screens can ship a compact layout first and add richer
ones later.

## Tablet layouts

### Master-Detail

`OneBitMasterDetail` provides a side-by-side layout for tablets:

```dart
OneBitMasterDetail(
  master: ChannelList(),
  detail: ChannelDetails(),
  selectedIndex: selectedChannelId,
)
```

On compact viewports, only the master pane is shown. On medium/expanded,
both panes are displayed side-by-side with a divider.

### Responsive Grid

`OneBitResponsiveGrid` adapts column count to viewport width:

```dart
OneBitResponsiveGrid(
  children: items.map((item) => NodeCard(item: item)).toList(),
)
```

- Compact: 1 column
- Medium: 2 columns
- Expanded: 3 columns

Items reflow naturally using `LayoutBuilder` and `Wrap`.

### Screen implementations

- **Channels**: Uses `OneBitMasterDetail` on tablets for channel list +
  conversation preview.
- **Nodes**: Uses `OneBitResponsiveGrid` for node cards on tablets.
- **Mesh**: Uses `OneBitResponsiveGrid` for mesh panels on tablets.

## Rules

1. Layouts are chosen from `MediaQuery.sizeOf(context).width` via the
   helpers — never from `Platform` checks or device-name heuristics.
2. Build for constraint-driven widgets (`LayoutBuilder`,
   `OneBitResponsiveLayout`, `Flexible`/`Expanded`, `GridView` with
   `SliverGridDelegateWithMaxCrossAxisExtent`) instead of fixed pixel sizes.
3. Orientation is handled by width classes, not explicit portrait/landscape
   branches.
4. Never hard-code tablet vs. phone content — prefer density changes
   (padding via tokens, multi-pane layouts at `medium`/`expanded`).
5. Keep touch targets ≥48dp at every breakpoint.
6. The shell composes `OneBitResponsiveLayout`; feature screens stay
   width-aware through the same helpers.
7. Use `OneBitMasterDetail` for master-detail flows on tablets.
8. Use `OneBitResponsiveGrid` for card grids that benefit from multiple
   columns on larger screens.