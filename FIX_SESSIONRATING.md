# Fix SessionRating Compilation Error

## Problem
`Cannot find type 'SessionRating' in scope` - The file exists but isn't being compiled.

## Solution

### Step 1: Verify File Exists
✅ File exists at: `Faith Journal/Faith Journal/Models/SessionRating.swift`

### Step 2: Add File to Xcode Project

**Option A: Through Xcode UI (Recommended)**
1. Open `Faith Journal.xcodeproj` in Xcode
2. In Project Navigator, find the `Models` folder
3. Right-click `Models` folder
4. Select "Add Files to 'Faith Journal'..."
5. Navigate to: `Faith Journal/Faith Journal/Models/SessionRating.swift`
6. ✅ Ensure "Copy items if needed" is UNCHECKED (file is already in place)
7. ✅ Ensure "Add to targets: Faith Journal" IS CHECKED
8. Click "Add"

**Option B: Verify File System Sync**
Since your project uses File System Synchronization:
1. In Xcode: `Product` > `Clean Build Folder` (Cmd+Shift+K)
2. Quit Xcode completely (Cmd+Q)
3. Reopen the project
4. Build (Cmd+B)

### Step 3: Verify Target Membership
1. Click on `SessionRating.swift` in Project Navigator
2. Open File Inspector (Right panel, first tab)
3. Under "Target Membership", ensure "Faith Journal" is checked

### Step 4: Rebuild
After adding, rebuild the project:
- Press `Cmd+B` or `Product` > `Build`

## Additional Files That May Need Adding

If you see similar errors, also verify these are added:
- `SessionClip.swift` (Models)
- `TranslationService.swift` (Services)  
- `SessionRecommendationService.swift` (Services)
- `WaitingRoomView.swift` (Views)
- `SessionClipsView.swift` (Views)
- `TranslationSettingsView.swift` (Views)

All these files exist and just need to be added to the Xcode project target.
