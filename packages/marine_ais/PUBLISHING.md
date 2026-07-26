# Publishing Checklist

Use this checklist when `marine_ais` is ready to go live on `pub.dev`.

## Final Metadata

1. Confirm the public package name `marine_ais` is still the one you want.
2. Add `repository`, `homepage`, and `issue_tracker` fields to `pubspec.yaml` once the public repository URL is final.
3. Bump the version in `pubspec.yaml` and add release notes to `CHANGELOG.md`.

## Local Validation

Run these commands from `packages/marine_ais`:

```bash
dart pub get
dart format lib test example
dart analyze
dart test
dart run example/decode_sentence.dart
dart pub publish --dry-run
```

## Dry Run Review

Before the real publish:

1. Read every warning from `dart pub publish --dry-run`.
2. Confirm the generated package file list looks correct.
3. Check the README renders cleanly on GitHub and `pub.dev`.
4. Make sure the LICENSE and CHANGELOG are included.

## Publish

When the dry run is clean:

```bash
dart pub publish
```

## Post-Publish

1. Replace FleetFlow's path dependency with the published semver version.
2. Run `flutter pub get` at the repo root.
3. Tag the release in git.
4. Add a short release note to the FleetFlow README or changelog.
