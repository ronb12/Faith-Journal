#!/usr/bin/env bash
# Repackage Agora macOS xcframework so the module is named AgoraRtcKit1 (matches SPM target name).
# Run from repo root or from AgoraRtcEngine_macOS_1/. Output: AgoraRtcKit1.xcframework in this package dir.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR"
OUT_XCFWK="$PKG_DIR/AgoraRtcKit1.xcframework"
URL="https://download.agora.io/swiftpm/AgoraRtcEngine_macOS/4.6.2/AgoraRtcKit.xcframework.zip"
WORK="/tmp/agora_repackage_$$"

echo "Downloading AgoraRtcKit.xcframework.zip..."
mkdir -p "$WORK"
curl -sL -o "$WORK/zip" "$URL"
unzip -q -o "$WORK/zip" -d "$WORK"

SRC="$WORK/AgoraRtcKit.xcframework"
MACOS_SLICE="$SRC/macos-arm64_x86_64"
FRAMEWORK_ORIG="$MACOS_SLICE/AgoraRtcKit.framework"
FRAMEWORK_NEW="$MACOS_SLICE/AgoraRtcKit1.framework"

if [[ ! -d "$FRAMEWORK_ORIG" ]]; then
  echo "Expected framework not found at $FRAMEWORK_ORIG"
  exit 1
fi

echo "Renaming framework and binary to AgoraRtcKit1..."
mv "$FRAMEWORK_ORIG" "$FRAMEWORK_NEW"
mv "$FRAMEWORK_NEW/Versions/A/AgoraRtcKit" "$FRAMEWORK_NEW/Versions/A/AgoraRtcKit1"

echo "Updating module.modulemap..."
sed -i '' 's/framework module AgoraRtcKit/framework module AgoraRtcKit1/' "$FRAMEWORK_NEW/Versions/A/Modules/module.modulemap"

echo "Updating umbrella headers (#import <AgoraRtcKit/ -> <AgoraRtcKit1/)..."
HDR="$FRAMEWORK_NEW/Versions/A/Headers"
for f in "$HDR/AgoraRtcKit.h" "$HDR/AgoraRteKit.h"; do
  [[ -f "$f" ]] && sed -i '' 's|<AgoraRtcKit/|<AgoraRtcKit1/|g' "$f"
done

echo "Updating framework Info.plist..."
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable AgoraRtcKit1" "$FRAMEWORK_NEW/Versions/A/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName AgoraRtcKit1" "$FRAMEWORK_NEW/Versions/A/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier io.agora.AgoraRtcKit1" "$FRAMEWORK_NEW/Versions/A/Resources/Info.plist"

echo "Updating xcframework root Info.plist..."
/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:0:LibraryPath AgoraRtcKit1.framework" "$SRC/Info.plist"
/usr/libexec/PlistBuddy -c "Set :AvailableLibraries:0:BinaryPath AgoraRtcKit1.framework/Versions/A/AgoraRtcKit1" "$SRC/Info.plist"

echo "Fixing top-level framework symlink (executable name must match bundle)..."
rm -f "$FRAMEWORK_NEW/AgoraRtcKit"
ln -s Versions/Current/AgoraRtcKit1 "$FRAMEWORK_NEW/AgoraRtcKit1"

echo "Fixing binary install name (dyld load path)..."
BINARY="$FRAMEWORK_NEW/Versions/A/AgoraRtcKit1"
install_name_tool -id "@rpath/AgoraRtcKit1.framework/Versions/A/AgoraRtcKit1" "$BINARY"

echo "Installing to $OUT_XCFWK..."
rm -rf "$OUT_XCFWK"
mv "$SRC" "$OUT_XCFWK"

rm -rf "$WORK"
echo "Done. AgoraRtcKit1.xcframework is at $OUT_XCFWK"
ls -la "$OUT_XCFWK"
