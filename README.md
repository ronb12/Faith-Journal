# Faith Journal

Faith Journal is an iOS app for journaling, prayer tracking, Bible study, and community features (including live sessions).

## Build

- **Xcode**: Open `Faith Journal.xcworkspace` (preferred) or `Faith Journal.xcodeproj`
- **Requirements**: macOS + Xcode with an iOS 17+ SDK
- **Packages**: Xcode will resolve Swift Package dependencies automatically (or use **File → Packages → Resolve Package Versions**)

## Local secrets (do not commit)

This repo expects a few local-only files. They are ignored by `.gitignore`.

- **Firebase**: `GoogleService-Info.plist`
- **LiveKit**: `LiveKitSecret.plist` / `Faith Journal/LiveKitSecret.plist`
- **Pexels**: `PexelsSecrets.plist` / `Faith Journal/PexelsSecrets.plist`
- **Agora**: `AgoraSecrets.plist` / `Faith Journal/AgoraSecrets.plist`

## Repo layout

- **App source (canonical)**: `Faith Journal/Faith Journal/`
- **Docs**: `docs/`
- **Scripts**: `scripts/`
- **Archived duplicates/backups** (kept for reference): `archive/`

