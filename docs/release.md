# Release checklist

OneBit ships from `main`, and the version number in `pubspec.yaml` is the
release switch. There is no hand-made tag to forget and no separate
"version" to keep in sync: the tag, the file name, and the number the app
reports all come from that one line.

```yaml
# pubspec.yaml
version: 1.1.0+2
#        ^     ^
#        |     build number, must increase for every published APK
#        release name
```

## Cutting a release

1. **Choose the number.** Bump the release name for anything a user would
   notice (features, fixes), and always increase the build number — Android
   refuses to install an APK whose `versionCode` did not go up.
2. **Update `AppVersion.fallback`** in `lib/core/version/app_version.dart`
   to the same string. A test (`test/app_update_watcher_test.dart`) reads
   `pubspec.yaml` and fails if the two drift apart; this is what stops the
   endless "update available" loop.
3. **Open the pull request.** CI runs `flutter analyze` (zero issues),
   `flutter test --coverage`, both APK builds, and the Kotlin unit tests.
   All of it must be green before merging.
4. **Merge to `main`.** The `release` workflow starts on the `pubspec.yaml`
   change and does the rest:
   - re-runs analyze, the Dart tests, the release APK build and the native
     tests on the merge commit;
   - fails if the version-stamped APK (`OneBit-<version>-release.apk`) is
     missing;
   - creates the tag `v<version>` at that commit and publishes a GitHub
     release with the APK attached and generated notes.
5. **Verify the release, not just the workflow.** Download the APK from the
   Releases page, install it over the previous build, and check that
   **Settings → App update** shows the new version and **Settings → About**
   shows the same name and build.

A push that touches `pubspec.yaml` without moving the version, or a re-run
of a job that already published, is a no-op: the workflow asks whether
`v<version>` is already tagged and skips publishing if it is.

## What the pipeline guarantees

| Guarantee | Where |
| --- | --- |
| Nothing publishes that fails analysis or tests | `release.yml`, steps before `Publish GitHub release` |
| Native (Kotlin) tests run on the published commit too | `release.yml`, "Native (Kotlin) unit tests" |
| The APK on the release carries the version in its name | `release.yml`, "Verify versioned artifact" |
| The tag points at the commit the APK was built from | `gh release create --target "$GITHUB_SHA"` |
| The app reports the version Gradle stamped, not a Dart copy | `AppVersion.load` via the `update` channel |
| A version bump cannot skip the test gate | `release.yml` runs the same gates as `ci.yml` |

Every push also uploads an installable release APK as a workflow artifact
(`onebit-release-<version>`, retained 30 days), so there is something to
install between tagged releases.

## Signing — what this build is and is not

`android/app/build.gradle.kts` signs both debug and release builds with a
**debug keystore that is committed on purpose** (`android/app/debug.keystore`,
see `android/.gitignore` for the reasoning). That is what lets a newer APK
install over an older one without uninstalling, which the in-app updater
depends on.

It is **not** a Play Store identity. Publishing to Google Play would
require a real upload key, Play App Signing, and a secret store for the
credential — none of which exists in this repository, and none of which
should be invented for a debug-signed build.

## Not covered here

- **Google Play.** Releases are GitHub releases with an APK. There is no
  store listing, no staged rollout, no review process.
- **Rollback.** Re-publishing an older version is blocked by Android's
  `versionCode` rule; the fix-forward path is a higher build number.
- **Hardware verification.** A release is not a claim that the matrix in
  [device-matrix.md](device-matrix.md) has been run. What has actually
  been tested on a phone is recorded in
  [device-evidence.md](device-evidence.md).
