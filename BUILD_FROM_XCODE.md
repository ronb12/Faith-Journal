# Build and Launch from Xcode (Recommended)

## Issue
Command line builds are failing due to file system timeouts (disk is 94% full). Building from Xcode GUI may work better.

## Steps to Build and Launch in Xcode

### 1. Open Project in Xcode
- File → Open
- Navigate to: `Faith Journal/Faith Journal.xcodeproj`
- Click Open

### 2. Select iPhone 16 Pro Max Simulator
- At the top of Xcode, click the device selector (next to the scheme)
- Select: **iPhone 16 Pro Max** (or any available simulator)

### 3. Build the Project
- Press **Cmd + B** (or Product → Build)
- Wait for build to complete

### 4. Launch the App
- Press **Cmd + R** (or Product → Run)
- The app will build and launch in the simulator

## Alternative: Free Up Disk Space

Your disk is 94% full, which is causing file system timeouts. To fix:

1. **Run the cleanup script:**
   ```bash
   cd "/Users/ronellbradley/Desktop/Faith Journal"
   ./cleanup.sh
   ```

2. **Or manually clean:**
   - Empty Trash
   - Delete old Xcode derived data
   - Remove unused apps/files
   - Free up at least 10-20GB

## If Xcode Also Times Out

If Xcode has the same timeout issues:

1. **Restart your Mac** - This can clear file system locks
2. **Check disk health** - Run Disk Utility First Aid
3. **Free up disk space** - Critical for file system performance

## Quick Test

Try opening a Swift file directly:
- In Xcode: File → Open
- Navigate to: `Faith Journal/Faith Journal/Views/JournalView.swift`
- If it opens, files are accessible
- If it times out, you need to free disk space or restart

