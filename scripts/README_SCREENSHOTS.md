# Screenshot Generation Scripts

This directory contains scripts to automate screenshot generation for App Store Connect.

## Scripts

### 1. `generate_screenshots.sh` (Interactive)
Manual navigation version - prompts you to navigate to each screen.

**Usage:**
```bash
./generate_screenshots.sh [device-type] [scheme]
```

**Examples:**
```bash
# Use default iPhone 15 Pro
./generate_screenshots.sh

# Use iPhone 15 Pro Max
./generate_screenshots.sh iPhone-15-Pro-Max

# Use specific scheme
./generate_screenshots.sh iPhone-15-Pro "Faith Journal"
```

**Features:**
- Builds and installs the app automatically
- Launches the simulator
- Prompts you to navigate to each screen
- Captures screenshots at full resolution
- Creates organized output folders

### 2. `generate_screenshots_automated.sh` (Automated)
Fully automated version - attempts to navigate using coordinate taps.

**Usage:**
```bash
./generate_screenshots_automated.sh [scheme] [device-type]
```

**Examples:**
```bash
./generate_screenshots_automated.sh "Faith Journal" iPhone-15-Pro
```

**Note:** This version uses coordinate-based tapping which may need adjustment for different device sizes.

## App Store Connect Requirements

### iPhone Screenshot Sizes (Required)
- **6.7" Display** (iPhone 15 Pro Max, 14 Pro Max, etc.): 1290 x 2796 pixels
- **6.5" Display** (iPhone 11 Pro Max, XS Max): 1284 x 2778 pixels  
- **5.5" Display** (iPhone 8 Plus): 1242 x 2208 pixels
- **6.1" Display** (iPhone 14, 13, 12): 1179 x 2556 pixels
- **5.8" Display** (iPhone X, XS): 1125 x 2436 pixels

### iPad Screenshot Sizes (Optional)
- **12.9" iPad Pro**: 2048 x 2732 pixels
- **11" iPad Pro**: 1668 x 2388 pixels
- **10.5" iPad**: 1668 x 2224 pixels
- **9.7" iPad**: 1536 x 2048 pixels

## Screens to Capture

The scripts capture these screens:
1. **Home** - Welcome screen with Bible verse and devotionals
2. **Journal** - Journal entries list
3. **Prayer** - Prayer requests
4. **Devotionals** - Devotional content
5. **Statistics** - Analytics and charts
6. **Live Sessions** - Community features
7. **Settings** - App settings and profile

## Output Structure

```
screenshots/
├── iPhone-15-Pro/
│   ├── 01_Home.png
│   ├── 02_Journal.png
│   ├── 03_Prayer.png
│   ├── 04_Devotionals.png
│   ├── 05_Statistics.png
│   ├── 06_Live_Sessions.png
│   └── 07_Settings.png
└── AppStoreConnect/
    ├── iPhone/
    └── iPad/
```

## Manual Steps After Generation

1. **Review Screenshots**: Check that all screenshots look good
2. **Resize if Needed**: Use image editing tools to match exact App Store Connect requirements
3. **Add Text/Graphics** (Optional): Add marketing text or highlights
4. **Upload to App Store Connect**:
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Select your app
   - Navigate to the version
   - Upload screenshots in the "App Preview and Screenshots" section

## Troubleshooting

### Simulator Not Booting
```bash
# List available devices
xcrun simctl list devices available

# Boot manually
xcrun simctl boot <UDID>
```

### App Not Installing
- Check that the scheme name matches: `"Faith Journal"`
- Verify bundle identifier: `com.ronellbradley.FaithJournal`
- Ensure Xcode project builds successfully

### Screenshots Are Wrong Size
- Screenshots are captured at the device's native resolution
- Use image editing tools (Preview, Photoshop, etc.) to resize
- Or use `sips` command: `sips -Z 2796 screenshot.png`

### Coordinate Tapping Not Working
- The automated script uses approximate coordinates
- Adjust `x_positions` array in the script for your device
- Or use the interactive script instead

## Tips

1. **Use Real Device**: For best quality, consider using a physical device
2. **Multiple Devices**: Run the script for different device types to get all required sizes
3. **Clean State**: Start with a fresh simulator or reset content
4. **Add Sample Data**: Ensure the app has sample data to show in screenshots
5. **Marketing Text**: Consider adding text overlays highlighting key features

## Example Workflow

```bash
# 1. Make scripts executable
chmod +x scripts/generate_screenshots.sh
chmod +x scripts/generate_screenshots_automated.sh

# 2. Run interactive script
cd "/Users/ronellbradley/Desktop/Faith Journal"
./scripts/generate_screenshots.sh iPhone-15-Pro-Max

# 3. Navigate through each screen when prompted

# 4. Review screenshots
open screenshots/iPhone-15-Pro-Max/

# 5. Upload to App Store Connect
```

## Additional Resources

- [App Store Connect Screenshot Requirements](https://developer.apple.com/app-store/product-page/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [App Store Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/)

