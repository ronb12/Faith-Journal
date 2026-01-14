# Add New Files to Xcode Project

## Quick Summary

Your project uses **File System Synchronization** (PBXFileSystemSynchronizedRootGroup), which means files in the `Faith Journal/Faith Journal/` directory should be automatically detected. However, if you're seeing compilation errors, follow these steps:

## Files to Add (All Already Created)

### ✅ Models/
- `SessionClip.swift` - Located at: `Faith Journal/Faith Journal/Models/SessionClip.swift`

### ✅ Services/
- `TranslationService.swift` - Located at: `Faith Journal/Faith Journal/Services/TranslationService.swift`
- `SessionRecommendationService.swift` - Located at: `Faith Journal/Faith Journal/Services/SessionRecommendationService.swift`

### ✅ Views/
- `WaitingRoomView.swift` - Located at: `Faith Journal/Faith Journal/Views/WaitingRoomView.swift`
- `SessionClipsView.swift` - Located at: `Faith Journal/Faith Journal/Views/SessionClipsView.swift`
- `TranslationSettingsView.swift` - Located at: `Faith Journal/Faith Journal/Views/TranslationSettingsView.swift`

## Method 1: Automatic (File System Sync)

Since your project uses file system synchronization:

1. **Clean Build Folder**: In Xcode, press `Cmd+Shift+K` or go to `Product > Clean Build Folder`
2. **Close Xcode**: Quit Xcode completely
3. **Reopen Xcode**: Open the project again
4. **Build**: Press `Cmd+B` to build

Files should be automatically detected.

## Method 2: Manual Addition (If Method 1 Doesn't Work)

1. Open `Faith Journal.xcodeproj` in Xcode
2. For each file, right-click the appropriate folder in Project Navigator:
   - **Models folder** → Add `SessionClip.swift`
   - **Services folder** → Add `TranslationService.swift` and `SessionRecommendationService.swift`
   - **Views folder** → Add `WaitingRoomView.swift`, `SessionClipsView.swift`, and `TranslationSettingsView.swift`
3. When adding:
   - ✅ Check "Copy items if needed" (though files are already in place)
   - ✅ Check "Add to targets: Faith Journal"
   - Click "Add"

## Method 3: Verify File Locations

All files should be in these locations relative to project root:

```
Faith Journal/
  └── Faith Journal/
      ├── Models/
      │   └── SessionClip.swift
      ├── Services/
      │   ├── TranslationService.swift
      │   └── SessionRecommendationService.swift
      └── Views/
          ├── WaitingRoomView.swift
          ├── SessionClipsView.swift
          └── TranslationSettingsView.swift
```

## Verify After Adding

After adding files, verify in Xcode:
1. Files appear in Project Navigator
2. Right-click each file → Get Info → Target Membership
3. Ensure "Faith Journal" target is checked

## Build and Test

```bash
# Build the project
xcodebuild -project "Faith Journal.xcodeproj" -scheme "Faith Journal" -sdk iphonesimulator build
```

All compilation errors related to missing files should be resolved.

## Troubleshooting

If files still don't appear:
- Check that files are in the correct directory structure
- Ensure file extensions are `.swift` (not `.swift.txt`)
- Try removing derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Restart Xcode
