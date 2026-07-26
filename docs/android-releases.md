# Android Releases

FleetFlow can publish signed Android APKs to GitHub Releases.

## What visitors get

- A downloadable Android APK attached to a GitHub Release
- A stable release tag such as `fleetflow-v1.0.0`

## Required GitHub Actions secrets

Add these repository secrets before triggering the Android release workflow:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

## Preparing the keystore secret

Convert your upload keystore into a base64 string:

```bash
base64 -i /path/to/your-upload-keystore.jks | pbcopy
```

Then paste that value into the `ANDROID_KEYSTORE_BASE64` repository secret.

## Release flow

1. Bump the app version in `pubspec.yaml`.
2. Commit and push the version bump.
3. Create and push a tag like `fleetflow-v1.0.0`.
4. GitHub Actions builds a signed APK and attaches it to the matching GitHub Release.

## Notes

- Android downloads are well suited to GitHub Releases.
- iOS public distribution should use TestFlight or the App Store rather than raw downloadable binaries from GitHub.
