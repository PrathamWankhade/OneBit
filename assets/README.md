# Assets

Static assets live here, grouped by kind.

- `fonts/` — custom typeface binaries (`.ttf`/`.otf`). Declare under
  `flutter.fonts` in `pubspec.yaml` and reference the family through
  `AppTypography.buildTextTheme(fontFamily: ...)`.
- `icons/` — the app-icon master, kept as SVG only (no raster sources):
  - `onebit.svg` — the official logo artwork: white mesh on a
    deep-black rounded-rect background baked into the SVG. This is the single
    source of truth for the icon.
  - Regenerate the icon layers with `..\..\tool\generate_icons.py`. It parses
    the master's paths (transforms incl. `matrix()` y-flips) and converts
    them **verbatim** into Android adaptive-icon vectors
    (`ic_launcher_foreground.xml`, `ic_launcher_monochrome.xml`). No PNGs are
    produced anywhere — the launcher icon is vector end-to-end, so it stays
    crisp at any size.
- `images/` — raster artwork (launcher overlays, onboarding).

## App icon system

| Layer | Where | Notes |
| --- | --- | --- |
| Background | `res/values/colors.xml` (`ic_launcher_background`) | always `#000000` |
| Foreground | `res/drawable/ic_launcher_foreground.xml` | white logo, 108dp canvas, 60dp content width centred (24dp side margins) |
| Monochrome | `res/drawable/ic_launcher_monochrome.xml` | Android 13+ themed (dynamic) icons |
| Adaptive | `res/mipmap-anydpi-v26/ic_launcher{,_round}.xml` | shape follows each launcher's mask |

The black background is fixed across every theme; only the `monochrome` layer
may be tinted by the OS wallpaper colors (Android 13+ "themed icons").
The icon is vector-only: adaptive icon (API 26+) requires no raster files, and
no legacy PNGs are shipped — on pre-8.0 devices the launcher falls back to the
system default icon.
