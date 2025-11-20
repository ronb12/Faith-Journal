#!/bin/bash

# App Store Screenshot Script for Faith Journal
# This script automates taking screenshots for App Store submission
# Requirements: Xcode Command Line Tools, simulator must be booted

set -e

echo "📸 Faith Journal - App Store Screenshot Generator"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_BUNDLE_ID="com.ronellbradley.FaithJournal"
OUTPUT_DIR="$HOME/Desktop/Faith Journal Screenshots"
SCREENSHOT_BASE_NAME="faith_journal"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}📁 Output directory: ${OUTPUT_DIR}${NC}"
echo ""

# Function to take screenshot
take_screenshot() {
    local device_name=$1
    local screen_name=$2
    local output_file="$OUTPUT_DIR/${SCREENSHOT_BASE_NAME}_${screen_name}.png"
    
    echo -e "${YELLOW}📱 Taking screenshot: ${screen_name} on ${device_name}${NC}"
    
    # Take screenshot
    xcrun simctl io booted screenshot "$output_file"
    
    if [ -f "$output_file" ]; then
        echo -e "${GREEN}✅ Saved: ${output_file}${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to save: ${output_file}${NC}"
        return 1
    fi
}

# Function to wait for user interaction
wait_for_navigation() {
    local screen_name=$1
    echo -e "${BLUE}⏳ Navigate to: ${screen_name}${NC}"
    echo "   Press Enter when ready..."
    read -r
}

# Check if simulator is booted
echo "🔍 Checking simulator status..."
BOOTED_DEVICE=$(xcrun simctl list devices | grep "(Booted)" | head -1)

if [ -z "$BOOTED_DEVICE" ]; then
    echo "❌ No booted simulator found!"
    echo "Please boot a simulator first:"
    echo "  xcrun simctl boot 'iPhone 16 Pro'"
    exit 1
fi

echo -e "${GREEN}✅ Simulator is running${NC}"
echo ""

# Check if app is installed
echo "🔍 Checking if app is installed..."
if ! xcrun simctl listapps booted | grep -q "$APP_BUNDLE_ID"; then
    echo "⚠️  App not found in simulator"
    echo "Please install the app first"
    exit 1
fi

echo -e "${GREEN}✅ App is installed${NC}"
echo ""

# Launch the app
echo "🚀 Launching Faith Journal..."
xcrun simctl launch booted "$APP_BUNDLE_ID" > /dev/null 2>&1
sleep 3

echo ""
echo -e "${BLUE}=================================================="
echo "Screenshot Guide"
echo "==================================================${NC}"
echo ""
echo "For each screen:"
echo "1. Navigate to the screen in the app"
echo "2. Wait for it to fully load"
echo "3. Press Enter when ready for screenshot"
echo ""

# Required App Store Screenshots (iPhone 6.7" - iPhone 16 Pro Max, iPhone 15 Pro Max)
# Apple requires:
# - iPhone 6.7" display (iPhone 14 Pro Max, iPhone 15 Pro Max, iPhone 16 Pro Max)
# - At least 3 screenshots, maximum 10

echo -e "${YELLOW}📋 Recommended Screenshots for App Store:${NC}"
echo ""
echo "1. Home Screen - Shows Bible verse of the day and quick actions"
echo "2. Journal Entry - Shows journaling interface"
echo "3. Prayer Requests - Shows prayer tracking"
echo "4. Bible Study - Shows study topics and progress"
echo "5. Live Sessions - Shows community features"
echo "6. Devotionals - Shows daily devotionals"
echo "7. Statistics - Shows user progress and analytics"
echo ""

# Screenshots list
screenshots=(
    "01_home_screen:Home Screen"
    "02_journal:Journal Entry Screen"
    "03_prayer:Prayer Requests"
    "04_bible_study:Bible Study Topics"
    "05_bible_study_detail:Bible Study Topic Detail"
    "06_live_sessions:Live Sessions"
    "07_devotionals:Devotionals"
    "08_statistics:Statistics Dashboard"
)

# Take screenshots
for screenshot_info in "${screenshots[@]}"; do
    IFS=':' read -r filename description <<< "$screenshot_info"
    wait_for_navigation "$description"
    take_screenshot "$BOOTED_DEVICE" "$filename"
    echo ""
done

# Create a summary
echo ""
echo -e "${GREEN}=================================================="
echo "✅ Screenshot Session Complete!"
echo "==================================================${NC}"
echo ""
echo "Screenshots saved to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Review screenshots in the output folder"
echo "2. Required sizes for App Store:"
echo "   - iPhone 6.7\" (1290 x 2796 pixels) - Portrait"
echo "   - iPhone 6.5\" (1284 x 2778 pixels) - Portrait (optional)"
echo ""
echo "3. If screenshots need resizing, you can use:"
echo "   sips -z 2796 1290 input.png --out output.png"
echo ""
echo "4. Upload to App Store Connect:"
echo "   - Go to App Store Connect"
echo "   - Select your app"
echo "   - Go to App Store tab"
echo "   - Scroll to Screenshots"
echo "   - Upload your images"
echo ""

# Optional: Open the output folder
read -p "Would you like to open the screenshots folder? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$OUTPUT_DIR"
fi

echo ""
echo -e "${GREEN}🎉 Done!${NC}"

