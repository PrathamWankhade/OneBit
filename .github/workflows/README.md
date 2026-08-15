# OneBit CI

Runs on every push and pull request:

1. `flutter analyze` (zero issues required)
2. `flutter test`
3. Build matrix across the three product tiers.

Flavors: `dev` (debug), `beta` (debug), `prod` (release APK).
Uploads APKs as workflow artifacts on the `main` branch.
