# Faith Journal - macOS App Store Screenshot Automation

Professional screenshots for the Mac App Store: captures **only the app window** (no desktop, dock, or menus) at **1280×800px**. Images are **scaled to fit** with letterboxing so no content is cut off.

## Quick Start

### Option A: Full automation (recommended)

```bash
cd "/Users/ronellbradley/Projects/Faith Journal/scripts"
./capture_screenshots.sh
```

This will:
1. Build Faith Journal macOS
2. Launch the app
3. Run the capture script
4. Prompt you to navigate and capture each screen
5. Save to `~/Desktop/AppStore-Screenshots/`

### Option B: Quick single capture

When Faith Journal macOS is already open and showing the screen you want:

1. Bring Faith Journal to the front
2. Run: `osascript capture_quick_screenshot.applescript`
3. Screenshot saves automatically (1280×800)

### Option C: Run AppleScript only (app already running)

```bash
osascript capture_macos_screenshots.applescript
```

## Output

- **Location:** `~/Desktop/AppStore-Screenshots/`
- **Dimensions:** 1280×800px (App Store compliant)
- **Format:** PNG
- **Content:** App window only (clean, no desktop clutter)

## Tips for professional screenshots

1. **Use sample data** – Ensure the app has journal entries, devotionals, etc. so screens look complete
2. **Consistent window size** – Resize the app window to a good aspect before capturing
3. **Navigate first** – For the guided flow, have each target screen ready before clicking "Capture More"
4. **Dark/Light mode** – Pick one and stick with it for consistency

## Required permissions

- **Accessibility** – **Required.** System Settings → Privacy & Security → Accessibility → turn **ON** for **Terminal** (or **Script Editor** if you run the .applescript from there). Without this, the script cannot see the app window and will report "Could not find Faith Journal macOS window."
- **Screen Recording** – macOS may prompt when capturing; allow for the script/terminal.
- **Automation** – When prompted, allow Terminal/Script Editor to control Faith Journal.
