#!/bin/bash

# Automated screenshot generation using UI automation
# This version uses AppleScript to automate navigation

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCHEME="${1:-Faith Journal}"
PROJECT_PATH="${PROJECT_PATH:-$(dirname "$0")/../Faith Journal/Faith Journal.xcodeproj}"
OUTPUT_DIR="${OUTPUT_DIR:-$(dirname "$0")/../screenshots}"
DEVICE_TYPE="${2:-iPhone-15-Pro}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Automated Screenshot Generator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR/$DEVICE_TYPE"

# Get device UDID
DEVICE_UDID=$(xcrun simctl list devices available | grep "$DEVICE_TYPE" | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')

if [ -z "$DEVICE_UDID" ]; then
    echo -e "${RED}Error: Device $DEVICE_TYPE not found${NC}"
    exit 1
fi

# Boot simulator
echo -e "${BLUE}Booting simulator...${NC}"
xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
sleep 3
open -a Simulator
sleep 2

# Build and install
echo -e "${BLUE}Building app...${NC}"
cd "$(dirname "$PROJECT_PATH")/.."

xcodebuild -scheme "$SCHEME" \
    -configuration Release \
    -destination "id=$DEVICE_UDID" \
    -derivedDataPath /tmp/FaithJournalScreenshots \
    clean build 2>&1 | grep -E "(BUILD|error)" | tail -3

# Install app
BUNDLE_ID="com.ronellbradley.FaithJournal"
APP_PATH="/tmp/FaithJournalScreenshots/Build/Products/Release-iphonesimulator/Faith Journal.app"

if [ -d "$APP_PATH" ]; then
    xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
    echo -e "${GREEN}App installed${NC}"
else
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    exit 1
fi

# Launch app
echo -e "${BLUE}Launching app...${NC}"
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID"
sleep 5

# Function to tap at coordinates (approximate tab bar positions for iPhone)
tap_tab() {
    local tab_index=$1
    # Tab bar is typically at bottom, tabs are evenly spaced
    # For iPhone 15 Pro (393x852): tabs are around y=800, x positions vary
    local x_positions=(196 98 196 294 392 490 588)  # Approximate centers
    local y=800
    local x=${x_positions[$tab_index]}
    
    xcrun simctl io "$DEVICE_UDID" tap "$x" "$y"
    sleep 2
}

# Function to take screenshot
capture_screen() {
    local name=$1
    local path="$OUTPUT_DIR/$DEVICE_TYPE/${name}.png"
    xcrun simctl io "$DEVICE_UDID" screenshot "$path"
    echo -e "${GREEN}✓ Captured: $name${NC}"
    sleep 1
}

# Navigate and capture
echo -e "${BLUE}Capturing screenshots...${NC}"

# Home (already on it)
capture_screen "01_Home"

# Journal
tap_tab 1
capture_screen "02_Journal"

# Prayer
tap_tab 2
capture_screen "03_Prayer"

# Devotionals
tap_tab 3
capture_screen "04_Devotionals"

# Statistics
tap_tab 4
capture_screen "05_Statistics"

# Live Sessions
tap_tab 5
capture_screen "06_Live_Sessions"

# Settings
tap_tab 6
capture_screen "07_Settings"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All screenshots captured!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Screenshots saved to: $OUTPUT_DIR/$DEVICE_TYPE"
ls -lh "$OUTPUT_DIR/$DEVICE_TYPE"/*.png 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""

