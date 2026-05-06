# AgoraRtcEngine_macOS_1

Local Swift package that provides the Agora RTC SDK for macOS with **renamed targets** (suffix `1`) so the same Xcode project can use both the official Agora iOS package and this Mac package without “multiple similar targets” errors.

## After cloning the repo

The repackaged xcframework is **not** committed (it’s large and in `.gitignore`). Generate it once:

```bash
# From the repo root
./AgoraRtcEngine_macOS_1/repackage_agora_macos.sh
```

This downloads the official Agora macOS xcframework, renames the module to **AgoraRtcKit1**, and writes `AgoraRtcKit1.xcframework` into this directory. The **Faith Journal (Mac)** scheme will then build and full live sessions will work on macOS.

## What the script does

- Downloads `AgoraRtcKit.xcframework.zip` from Agora
- Renames the macOS slice so the module is `AgoraRtcKit1` (framework name, binary, `module.modulemap`, umbrella headers, `Info.plist`s)
- Fixes the top-level framework symlink for the executable
- Outputs `AgoraRtcKit1.xcframework` in this package directory

You can re-run the script anytime (e.g. after a clean) to regenerate the xcframework.
