# AgoraMacPackage — module aliases (suffix "1")

This local Swift package depends on **AgoraRtcEngine_macOS** and applies **module aliases** so every conflicting target name gets a `1` suffix (e.g. `aosl` → `aosl1`, `AgoraRtcKit` → `AgoraRtcKit1`). That avoids duplicate target names when both Agora iOS and Agora macOS would otherwise be in the same dependency graph.

## Building this package alone

```bash
cd AgoraMacPackage && swift build
```

This succeeds: only the macOS Agora SDK is in the graph, and the aliases are applied.

## Why the main app still can’t use it for Mac

The **Faith Journal** Xcode project depends on both:

- **AgoraRtcEngine_iOS** (for the iOS app), and  
- **AgoraRtcEngine_macOS** (for the macOS app).

Swift Package Manager resolves the **entire** dependency graph for the project once. As soon as both Agora iOS and Agora macOS are present (either directly or via this package), the resolver sees duplicate target names (`aosl`, `AgoraRtcKit`, etc.) and fails with “multiple similar targets … appear in package 'agorartcengine_ios' and 'agorartcengine_macos'”.

Module aliases in this package only affect how **this** package sees the macOS SDK. They do not change the fact that both Agora packages are still in the same resolved graph with their original target names, so the duplicate-target error remains.

## What would actually fix the duplicate-target issue

To really “modify the target names and add a 1” so both can coexist in one project, the names must be different **in the package manifests** that SPM resolves:

1. **Fork** [AgoraInfra_macOS](https://github.com/AgoraIO/AgoraInfra_macOS) and [AgoraRtcEngine_macOS](https://github.com/AgoraIO/AgoraRtcEngine_macOS).
2. In both forks, rename every target in `Package.swift` with a `1` suffix (e.g. `aosl` → `aosl1`, `AgoraRtcKit` → `AgoraRtcKit1`, etc.).
3. In the app project, remove the official Agora macOS package and add your forks (or a single wrapper package that depends only on the forks).
4. In the app, on macOS only, `import AgoraRtcKit1` (and use the same API types from that module).

Until then, the macOS app cannot build from the same Xcode project as the iOS app when both Agora SDKs are referenced; building/running the Mac app from Xcode’s GUI may still work in some versions.
