#!/bin/bash
# Faith Journal macOS - Automated Screenshot Capture for App Store
# Builds app, launches it, and runs AppleScript to capture professional window-only screenshots

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$HOME/Desktop/AppStore-Screenshots"

echo "📸 Faith Journal - App Store Screenshot Automation"
echo "=================================================="

# Step 1: Build the macOS app
echo ""
echo "1️⃣  Building Faith Journal macOS..."
cd "$PROJECT_DIR"
xcodebuild -scheme "Faith Journal macOS" -destination "platform=macOS" -configuration Debug build -quiet 2>/dev/null || {
    echo "❌ Build failed. Make sure Xcode and the project are set up correctly."
    exit 1
}
echo "   ✓ Build complete"

# Find the built app (prefer Build/Products/Debug, skip Index.noindex)
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "Faith Journal macOS.app" -type d 2>/dev/null | grep -v "Index.noindex" | head -1)
if [ -z "$APP_PATH" ]; then
    APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "Faith Journal macOS.app" -type d 2>/dev/null | head -1)
fi
if [ -z "$APP_PATH" ] || [ ! -x "$APP_PATH/Contents/MacOS/Faith Journal macOS" ]; then
    echo "❌ Could not find built app or executable missing"
    exit 1
fi

# Launch the app first (so we can check for its window)
echo ""
echo "2️⃣  Launching Faith Journal macOS..."
osascript -e 'tell application "Faith Journal macOS" to quit' 2>/dev/null || true
sleep 2
open "$APP_PATH"
sleep 3
echo "   ✓ App launched"

# Check: can we see the app window? (Accessibility must be enabled for Terminal/Cursor)
echo ""
echo "3️⃣  Checking Accessibility (required to capture window)..."
WINDOW_CHECK=$(osascript -e '
tell application "Faith Journal macOS" to activate
delay 2
try
    tell application "System Events"
        repeat with p in (every process where background only is false)
            try
                if (bundle identifier of p) is "com.ronellbradley.FaithJournal.macOS" then
                    if (count of windows of p) > 0 then
                        return "ok"
                    end if
                end if
            end try
        end repeat
    end tell
end try
return "no_window"
' 2>/dev/null || echo "no_access")
if [ "$WINDOW_CHECK" != "ok" ]; then
    echo ""
    echo "   ⚠️  Cannot see Faith Journal window (Accessibility is off for this app)."
    echo ""
    echo "   Fix: System Settings → Privacy & Security → Accessibility"
    echo "   → Turn ON for the app you used to run this script:"
    echo "      • Terminal (if you ran from Terminal.app)"
    echo "      • Cursor (if you ran from Cursor)"
    echo ""
    echo "   Then run this script again."
    echo ""
    exit 1
fi
echo "   ✓ Accessibility OK"

# Run the AppleScript capture (user will navigate and capture interactively)
echo ""
echo "4️⃣  Starting screenshot capture..."
echo "   • App will activate - navigate to the screen you want"
echo "   • Dialog will prompt you to capture"
echo "   • Capture multiple screens by navigating and clicking 'Capture More'"
echo ""

osascript "$SCRIPT_DIR/capture_macos_screenshots.applescript" "$OUTPUT_DIR"

# Open output folder
echo ""
echo "5️⃣  Opening output folder..."
open "$OUTPUT_DIR"
echo ""
echo "✅ Done! Screenshots saved to: $OUTPUT_DIR"
echo "   All images are 1280×800px (App Store compliant)"
