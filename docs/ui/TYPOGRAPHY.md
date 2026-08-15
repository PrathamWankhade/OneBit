# Typography

## Families

| Family | Role | Source |
| --- | --- | --- |
| **Inter** (`OneBitTypography.primaryFamily`) | all UI text | bundled variable font `assets/fonts/Inter-Variable.ttf` (declared in `pubspec.yaml`) |
| **Consolas** (`OneBitTypography.technicalFamily`) | technical values only | platform system font; falls back to `monospace` where unavailable |

**Inter** is the only font for interface text. **Consolas** is reserved
exclusively for:

- node IDs
- fingerprints
- packet IDs
- logs
- diagnostics
- the developer console
- any technical value

Technical text is rendered with `OneBitTypography.technicalStyle()` — never
through the `TextTheme`, which always carries Inter.

## Type scale

Tokens in `OneBitTypography` (pixels):

| Token | Size | Usage |
| --- | --- | --- |
| `display` | 32 | hero moments |
| `headline` | 24 | screen-level headings |
| `title` | 20 | card/row titles |
| `body` | 16 | default reading text |
| `label` | 14 | buttons, input labels |
| `caption` | 12 | supporting text |
| `overline` | 10 | section headers, eyebrows (tracked 1.2) |
| `technical` | 13 | mono technical values |

Weights: `regular` w400, `medium` w500, `semibold` w600, `bold` w700.

Display and headline pairs receive slight negative tracking
(`-0.5` / `-0.25`); overlines receive positive tracking (`1.2`).

## TextTheme

`OneBitTypography.buildTextTheme(ColorScheme)` produces the Material 3
`TextTheme` for both identities. Every style:

- carries the Inter family
- resolves its color from the scheme (`onSurface`, `onSurfaceVariant`)
- is built once in `OneBitThemeData`; screens never assemble styles manually

## Usage rules

1. Screens read styles from `Theme.of(context).textTheme` — never construct
   `TextStyle` literals.
2. Overrides are allowed only for font weight or color from the scheme;
   sizes come from the token scale.
3. Technical values always use `OneBitTypography.technicalStyle()`.
4. All text must scale with the platform text scaler — components reserve
   growth instead of fixed heights (see `ACCESSIBILITY.md`).
5. Letter-spacing for display/overline pairs follows the tokens; do not add
   custom tracking.