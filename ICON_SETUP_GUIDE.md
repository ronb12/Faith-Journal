# App Icon Setup Guide - Praying Hands Icon

## Quick Setup Instructions

### Option 1: Download from Free Resources (Recommended)

1. **Visit one of these free icon resources:**
   - **UXWing** (Free, no attribution needed): https://uxwing.com/hands-praying-icon/
   - **Iconduck** (CC BY 4.0): https://iconduck.com/icons/22269/praying-hands
   - **Flaticon** (Free with attribution): https://www.flaticon.com/free-icon/praying-hands_85327

2. **Download a high-resolution PNG (1024x1024 or larger)**

3. **Use the resize script:**
   - Save the downloaded icon as `praying-hands-1024.png` in the project root
   - Run: `./resize_icons.sh praying-hands-1024.png`
   - This will create all required sizes automatically

### Option 2: Manual Setup

If you already have a praying hands icon, place it in these sizes:

**Required Icon Sizes:**
- AppIcon-20x20.png (20x20 pixels)
- AppIcon-20x20@2x.png (40x40 pixels)
- AppIcon-29x29.png (29x29 pixels)
- AppIcon-29x29@2x.png (58x58 pixels)
- AppIcon-29x29@3x.png (87x87 pixels)
- AppIcon-40x40.png (40x40 pixels)
- AppIcon-40x40@2x.png (80x80 pixels)
- AppIcon-40x40@3x.png (120x120 pixels)
- AppIcon-60x60@2x.png (120x120 pixels)
- AppIcon-60x60@3x.png (180x180 pixels)
- AppIcon-76x76.png (76x76 pixels)
- AppIcon-76x76@2x.png (152x152 pixels)
- AppIcon-83.5x83.5@2x.png (167x167 pixels)
- AppIcon-1024x1024.png (1024x1024 pixels - App Store)

**Location:**
`Faith Journal/Faith Journal/Resources/Assets.xcassets/AppIcon.appiconset/`

### Option 3: Using Xcode

1. Open the project in Xcode
2. Navigate to `Assets.xcassets` > `AppIcon` in the Project Navigator
3. Drag and drop your praying hands icon into each size slot
4. Or use the "All Sizes" slot to set one image for all sizes (Xcode will auto-resize)

## After Setting Up Icons

1. Clean build folder: `Product > Clean Build Folder` (Cmd+Shift+K)
2. Delete the app from simulator
3. Rebuild and reinstall the app

The praying hands icon should now appear on the home screen!

