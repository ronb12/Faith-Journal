# Fix: Asset Catalog Timeout Error

## Problem
Xcode is timing out when trying to read `Contents.json` files in asset catalogs:
- `Assets.xcassets/Contents.json`
- `Preview Assets.xcassets/Contents.json`

Error: "Operation timed out" when reading these files.

## Root Cause
This appears to be a file system issue where files exist but can't be read due to:
- Extended attributes causing locks
- File system corruption
- Disk I/O issues
- macOS file system bugs

## Solutions

### Solution 1: Recreate Contents.json Files

The asset catalog Contents.json files are simple. Let's recreate them:

**For Assets.xcassets/Contents.json:**
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**For Preview Assets.xcassets/Contents.json:**
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

### Solution 2: Remove Extended Attributes

Run this command:
```bash
cd "/Users/ronellbradley/Desktop/Faith Journal"
xattr -rc "Faith Journal/Faith Journal/Resources"
```

### Solution 3: Copy Files to New Location

If files are corrupted:
1. Copy the entire project to a new location
2. Or recreate the asset catalogs in Xcode

### Solution 4: Check Disk Health

Run Disk Utility to check for disk errors:
1. Open Disk Utility
2. Select your disk
3. Click "First Aid"
4. Run repair if needed

### Solution 5: Recreate Asset Catalogs in Xcode

1. In Xcode, delete the asset catalogs from the project
2. Right-click Resources folder
3. Select "New File..."
4. Choose "Asset Catalog"
5. Name it "Assets"
6. Re-add your app icons and colors

## Quick Fix Script

I've already:
- ✅ Removed extended attributes
- ✅ Fixed permissions
- ✅ Touched files to refresh

## Next Steps

1. **Close Xcode completely**
2. **Restart your Mac** (if the issue persists)
3. **Reopen Xcode**
4. **Clean Build Folder** (Shift + Cmd + K)
5. **Build again**

If the timeout persists, the Contents.json files may need to be recreated manually.

