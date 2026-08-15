# Testing

## Test structure

```
test/
├── app/
│   ├── support/
│   │   ├── app_navigation_support.dart   full-app harness with provider overrides
│   │   └── screen_test_support.dart      screen-level helpers
│   └── app_shell_test.dart               app shell integration tests
├── shared/design/
│   ├── support/
│   │   └── design_support.dart           design-system widget test harness
│   ├── components/                        component tests
│   ├── accessibility_test.dart
│   ├── responsive_test.dart
│   ├── theme_test.dart
│   ├── theme_preference_test.dart
│   ├── tokens_test.dart
│   └── typography_test.dart
├── widget_test.dart                       root smoke tests
└── ...feature tests...
```

## Test harnesses

### Design system tests

For isolated component/widget tests, use the design-system harness in
`test/shared/design/support/design_support.dart`:

```dart
import 'package:onebit/shared/design_system/support/design_support.dart';

// Light theme
await tester.pumpWidget(oneBitApp(MyWidget()));

// Dark theme
await tester.pumpWidget(oneBitDarkApp(MyWidget()));
```

This mounts the widget under a `MaterialApp` with the OneBit theme — no
provider scope needed for pure visual components.

### App integration tests

For tests that exercise the full app shell with navigation and providers,
use `test/app/support/app_navigation_support.dart`:

```dart
import 'app/support/app_navigation_support.dart';

// Fresh install (no identity → onboarding)
await tester.pumpWidget(oneBitApp());

// With an existing identity (lands in shell)
await tester.pumpWidget(oneBitApp(identity: testIdentity()));

// Clean up timers
await disposeApp(tester);
```

This sets up:
- `ProviderScope` with overrides
- `FakeIdentityRepository`
- `InMemoryConnectionFactory` for the database
- `InMemorySharedPreferencesAsync` for preferences

### Test helpers

`testIdentity()` — creates a minimal `NodeIdentity` with a stable
fingerprint (no crypto operations needed).

`FakeIdentityRepository` — in-memory identity repository for tests;
starts with the given identity (null = fresh install) and creates
identities on demand.

`sharedPrefsStore()` — fresh in-memory preferences store. Pass the same
instance across "restarts" to exercise tab restoration.

## Component tests

Located in `test/shared/design/components/`. Key test files:

| File | Coverage |
| --- | --- |
| `button_test.dart` | OneBitButton variants, sizes, loading, disabled |
| `card_test.dart` | OneBitCard variants, tap, compact, outlined |
| `card_family_test.dart` | Card family rendering |
| `icon_button_test.dart` | OneBitIconButton sizing, tooltip |
| `badge_divider_header_test.dart` | OneBitBadge, OneBitDivider, OneBitSectionHeader |
| `text_field_test.dart` | OneBitTextField variants, validation |
| `input_variants_test.dart` | Input field variants |
| `status_chip_test.dart` | OneBitStatusChip tones |
| `progress_test.dart` | OneBitLoadingIndicator, OneBitAnimatedProgress, OneBitProgressBar |
| `states_test.dart` | OneBitEmptyState, OneBitErrorState |
| `feedback_states_test.dart` | Feedback state components |
| `navigation_scaling_test.dart` | Navigation bar/rail text scaling |
| `list_selection_test.dart` | List item selection |
| `dialogs_test.dart` | OneBitDialogs |
| `bottom_sheets_test.dart` | OneBitBottomSheets |
| `channel_transfer_card_test.dart` | Channel and transfer cards |
| `new_components_test.dart` | Recently added components |

## Design system tests

| File | Coverage |
| --- | --- |
| `theme_test.dart` | Theme identity, color scheme |
| `theme_preference_test.dart` | ThemePreference provider |
| `tokens_test.dart` | Component tokens |
| `typography_test.dart` | Type scale, font families |
| `responsive_test.dart` | Breakpoint helpers |
| `accessibility_test.dart` | 48dp targets, semantics |

## Running tests

```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/shared/design/components/button_test.dart

# Run tests matching a name pattern
flutter test --name "OneBitButton"

# Run with coverage
flutter test --coverage

# Run tests in a specific directory
flutter test test/shared/design/
```

## Golden tests

Golden tests compare rendered output against reference images. They are
used for visual regression testing of components.

```bash
# Update golden files
flutter test --update-goldens

# Run golden tests only
flutter test --name "golden"
```

Golden references live alongside the test files. When updating, verify the
new references match the design system tokens.

## Test conventions

1. Every component must have widget tests under
   `test/shared/design/components/`.
2. Mount components under `oneBitApp` / `oneBitDarkApp` — never a bare
   `MaterialApp`.
3. Use `pumpAndSettle` for settled states; use `pump(duration)` around
   indeterminate progress (spinners) to avoid infinite settling.
4. Test both light and dark identities when the component uses semantic
   colors.
5. Test large text scaling (≥2.0) for components with minimum heights.
6. Verify accessibility: semantic labels, 48dp targets, reduced motion.
7. Screens are tested against real design-system widgets — no fake
   repositories inside component tests.

## Smoke tests

`test/widget_test.dart` validates the app root:

- With an identity: lands in `AppShell` → `ChannelsScreen`
- Without an identity: lands on `OnboardingScreen`

These run on every CI build as a fast sanity check.
