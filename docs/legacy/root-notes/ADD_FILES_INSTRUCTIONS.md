# Instructions to Add New Files to Xcode Project

## Files to Add:

### Models/
- SessionClip.swift

### Services/
- TranslationService.swift
- SessionRecommendationService.swift

### Views/
- WaitingRoomView.swift
- SessionClipsView.swift
- TranslationSettingsView.swift

## Steps:

1. Open "Faith Journal.xcodeproj" in Xcode
2. For each file:
   - Right-click on the appropriate folder (Models, Services, or Views) in the Project Navigator
   - Select "Add Files to 'Faith Journal'..."
   - Navigate to and select the file
   - ✅ Ensure "Copy items if needed" is checked
   - ✅ Ensure "Add to targets: Faith Journal" is checked
   - Click "Add"

3. Verify all files are added by checking:
   - Files appear in Project Navigator
   - Files have "Faith Journal" checked in Target Membership (right-click file > Get Info > Target Membership)

## Alternative (Command Line):

If you prefer using command line, you can use:

```bash
# This requires Ruby and xcodeproj gem
gem install xcodeproj
# Then use a Ruby script to add files programmatically
```

## Quick Verification:

After adding files, build the project:
```bash
xcodebuild -project "Faith Journal.xcodeproj" -scheme "Faith Journal" -sdk iphonesimulator build
```

All compilation errors related to missing files should be resolved.
