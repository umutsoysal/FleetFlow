# Publishing Checklist

Use this checklist when `marine_ais` is ready to go live on `pub.dev` and GitHub Releases.

## Final Metadata

1. Confirm the public package name `marine_ais` is still the one you want.
2. Add `repository`, `homepage`, and `issue_tracker` fields to `pubspec.yaml` once the public repository URL is final.
3. Bump the version in `pubspec.yaml` and add release notes to `CHANGELOG.md`.
4. Make sure the git tag you plan to push matches `marine_ais-v{{version}}`.

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

This repo includes [publish-marine-ais.yml](/Users/umutsoysal/Projects/FleetFlow/.github/workflows/publish-marine-ais.yml), which is designed to:

- publish `marine_ais` to `pub.dev`
- create a matching GitHub Release

It triggers when you push a tag like `marine_ais-v0.1.0`.

When the dry run is clean and the package version is final:

```bash
git tag marine_ais-v0.1.0
git push origin marine_ais-v0.1.0
```

## Post-Publish

1. Confirm the GitHub Actions run succeeded.
2. Confirm the GitHub Release was created.
3. Replace FleetFlow's path dependency with the published semver version when you want the app to consume the public package instead of the local path.
4. Run `flutter pub get` at the repo root after switching dependency style.
