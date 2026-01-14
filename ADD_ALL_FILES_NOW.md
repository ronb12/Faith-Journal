# 🚨 IMPORTANT: Add These Files to Xcode Project

## Current Status
The code has been updated to **compile without errors** by temporarily commenting out code that depends on files not yet added to the Xcode project. However, **full functionality requires adding these files**.

## Files That MUST Be Added to Xcode Project

### 1. Models/
**File:** `Faith Journal/Faith Journal/Models/SessionRating.swift`
- **Status:** ✅ File exists, needs to be added to project
- **Error if missing:** "Cannot find type 'SessionRating' in scope"
- **How to add:**
  1. Right-click `Models` folder in Xcode
  2. "Add Files to 'Faith Journal'..."
  3. Select `SessionRating.swift`
  4. Check "Add to targets: Faith Journal"
  5. Click "Add"

### 2. Services/
**Files:**
- `Faith Journal/Faith Journal/Services/TranslationService.swift`
- `Faith Journal/Faith Journal/Services/SessionRecommendationService.swift`

**How to add:**
1. Right-click `Services` folder in Xcode
2. "Add Files to 'Faith Journal'..."
3. Select both files
4. Check "Add to targets: Faith Journal"
5. Click "Add"

### 3. Views/
**Files:**
- `Faith Journal/Faith Journal/Views/WaitingRoomView.swift`
- `Faith Journal/Faith Journal/Views/SessionClipsView.swift`
- `Faith Journal/Faith Journal/Views/TranslationSettingsView.swift`

**How to add:**
1. Right-click `Views` folder in Xcode
2. "Add Files to 'Faith Journal'..."
3. Select all three files
4. Check "Add to targets: Faith Journal"
5. Click "Add"

## After Adding Files

Once all files are added, you need to **uncomment the code** in:

### LiveSessionsView.swift
1. Line ~40: Uncomment `@Query var allRatings: [SessionRating]`
2. Line ~1521: Uncomment `@Query var ratings: [SessionRating]`
3. Line ~2986: Uncomment `@Query var allRatings: [SessionRating]`
4. Line ~184-193: Update `getRecommendations()` to use SessionRecommendationService
5. Line ~2313-2318: Update to use actual `WaitingRoomView` and `SessionClipsView`
6. Line ~3483-3485: Update to use actual `TranslationSettingsView`

### BroadcastStreamView_HLS.swift
1. Line ~2361: Uncomment `private let translationService = TranslationService.shared`
2. Line ~2390-2408: Uncomment translation button code
3. Line ~2437-2453: Uncomment `translateMessage()` function
4. Line ~2121-2125: Uncomment translation settings button
5. Line ~2160-2163: Uncomment translation settings sheet

## Quick Verification

After adding files and uncommenting code, build:
```bash
xcodebuild -project "Faith Journal.xcodeproj" -scheme "Faith Journal" build
```

## Summary

✅ **Current:** Code compiles (with features temporarily disabled)
✅ **Next Step:** Add 6 files to Xcode project
✅ **Then:** Uncomment code to enable full functionality

All files exist and are ready - they just need to be added to the Xcode project target!
