# Motion

## Tokens

All timing lives in `lib/shared/design_system/animations/onebit_motion.dart`.
No widget in the codebase uses a literal `Duration(...)` — every transition
sources its timing from here.

Durations (normal window 150–250ms):

| Token | Duration | Role |
| --- | --- | --- |
| `fastest` | 75ms | micro-feedback (ink flashes) |
| `fast` | 150ms | state toggles, icon swaps |
| `medium` | 250ms | default in/out transitions |
| `slow` | 350ms | larger container transitions |
| `verySlow` | 600ms | hero-scale choreography |

Curves:

| Token | Curve | Role |
| --- | --- | --- |
| `standard` | `easeInOutCubic` | default in/out |
| `emphasized` | `easeOutCubic` | snappy entrance for emphasis |
| `linearCurve` | `linear` | mechanical motion (indeterminate progress) |

## Reduced motion

Every animated widget routes durations through
`OneBitMotion.resolve(context, duration)` or `context.motionDuration(...)`.
When the platform requests reduced motion (`MediaQuery.disableAnimationsOf`),
durations collapse to `Duration.zero`, so transitions become instant instead
of animated. This is a design-system guarantee — screens do not implement
their own reduced-motion checks.

## Supported capabilities

The foundation is built to support, as component/screen choreography arrives:

- fades (`AnimatedOpacity`, `AnimatedSwitcher` — used by
  `OneBitAnimatedProgress`)
- scale (`AnimatedScale`)
- slide (`AnimatedSlide`, `SlideTransition`)
- shared axis (vertical/horizontal shared-element transitions)
- container transforms (`AnimatedContainer`, `AnimatedSize`)
- hero transitions (`Hero`)
- ripple (Material `InkRipple.splashFactory` bound in `OneBitThemeData`)

Page transitions are restrained: forward fades on Android/macOS/Windows/
Linux, native transitions on iOS (see `THEME_SYSTEM.md`).

## Rules

1. Source every duration and curve from `OneBitMotion` — no literal timing.
2. Route durations through `OneBitMotion.resolve` so reduced motion is
   honored automatically.
3. Avoid excessive animation: one transition per state change, no bouncing,
   no gratuitous entrances.
4. Indeterminate progress (spinners) is exempt from the duration tokens but
   must remain interruptible; tests use bounded `pump(duration)` instead of
   `pumpAndSettle` around them.
5. Screen-specific motion is composed from these tokens; the tokens
   themselves never change per screen.
