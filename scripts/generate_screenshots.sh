#!/bin/bash

# Script to generate App Store Connect screenshots using iOS Simulator
# Usage: ./generate_screenshots.sh [device-type] [scheme]
# Example: ./generate_screenshots.sh iPhone-15-Pro "Faith Journal"

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SCHEME="${2:-Faith Journal}"
PROJECT_PATH="${PROJECT_PATH:-$(dirname "$0")/../Faith Journal/Faith Journal.xcodeproj}"
OUTPUT_DIR="${OUTPUT_DIR:-$(dirname "$0")/../screenshots}"
DEVICE_TYPE="${1:-iPhone-15-Pro}"

# App Store Connect screenshot requirements
# iPhone sizes (in points, we'll capture at @3x for retina)
declare -A IPHONE_SIZES=(
    ["iPhone-15-Pro"]="393x852"
    ["iPhone-15-Pro-Max"]="430x932"
    ["iPhone-15"]="393x852"
    ["iPhone-14-Pro"]="393x852"
    ["iPhone-14-Pro-Max"]="430x932"
    ["iPhone-13-Pro"]="390x844"
    ["iPhone-13-Pro-Max"]="428x926"
    ["iPhone-12-Pro"]="390x844"
    ["iPhone-12-Pro-Max"]="428x926"
    ["iPhone-11-Pro"]="375x812"
    ["iPhone-11-Pro-Max"]="414x896"
    ["iPhone-8-Plus"]="414x736"
    ["iPhone-SE-3rd-generation"]="375x667"
)

# iPad sizes
declare -A IPAD_SIZES=(
    ["iPad-Pro-12.9-inch"]="1024x1366"
    ["iPad-Pro-11-inch"]="834x1194"
    ["iPad-Air"]="820x1180"
    ["iPad"]="810x1080"
    ["iPad-mini"]="744x1133"
)

# Screens to capture (tab indices: 0=Home, 1=Journal, 2=Prayer, 3=Devotionals, 4=Statistics, 5=Live, 6=Settings)
SCREENS=(
    "Home:0"
    "Journal:1"
    "Prayer:2"
    "Devotionals:3"
    "Statistics:4"
    "Live:5"
    "Settings:6"
)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Faith Journal Screenshot Generator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

# Check if simctl is available
if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}Error: xcrun not found. Please install Xcode Command Line Tools.${NC}"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR/$DEVICE_TYPE"
echo -e "${GREEN}Output directory: $OUTPUT_DIR/$DEVICE_TYPE${NC}"
echo ""

# Get available simulators
echo -e "${BLUE}Checking available simulators...${NC}"
AVAILABLE_DEVICES=$(xcrun simctl list devices available | grep "$DEVICE_TYPE" | head -1)

if [ -z "$AVAILABLE_DEVICES" ]; then
    echo -e "${YELLOW}Warning: $DEVICE_TYPE not found. Available devices:${NC}"
    xcrun simctl list devices available | grep -E "iPhone|iPad" | head -10
    echo ""
    echo -e "${YELLOW}Using first available iPhone device...${NC}"
    DEVICE_TYPE=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/.*(\(.*\))/\1/' | tr -d ' ')
    if [ -z "$DEVICE_TYPE" ]; then
        echo -e "${RED}Error: No iPhone simulators available.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Using device: $DEVICE_TYPE${NC}"
echo ""

# Boot the simulator
echo -e "${BLUE}Booting simulator...${NC}"
DEVICE_UDID=$(xcrun simctl list devices available | grep "$DEVICE_TYPE" | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')

if [ -z "$DEVICE_UDID" ]; then
    echo -e "${RED}Error: Could not find device UDID for $DEVICE_TYPE${NC}"
    exit 1
fi

xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || echo -e "${YELLOW}Simulator already booted${NC}"
sleep 3

# Open Simulator app
open -a Simulator
sleep 2

# Build and install the app
echo -e "${BLUE}Building and installing app...${NC}"
cd "$(dirname "$PROJECT_PATH")/.."

xcodebuild -scheme "$SCHEME" \
    -configuration Release \
    -destination "id=$DEVICE_UDID" \
    -derivedDataPath /tmp/FaithJournalScreenshots \
    clean build install 2>&1 | grep -E "(BUILD|error|warning)" | tail -5

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}Error: Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}App installed successfully${NC}"
echo ""

# Launch the app
echo -e "${BLUE}Launching app...${NC}"
BUNDLE_ID="com.ronellbradley.FaithJournal"
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || {
    echo -e "${YELLOW}Warning: Could not launch via simctl, app may already be running${NC}"
}
sleep 5

# Function to take screenshot
take_screenshot() {
    local screen_name=$1
    local tab_index=$2
    local filename="${screen_name// /_}.png"
    local output_path="$OUTPUT_DIR/$DEVICE_TYPE/$filename"
    
    echo -e "${BLUE}Capturing: $screen_name (Tab $tab_index)...${NC}"
    
    # Note: We can't programmatically switch tabs in SwiftUI from command line
    # So we'll take screenshots of the current state
    # User may need to manually navigate or we can use UI automation
    
    xcrun simctl io "$DEVICE_UDID" screenshot "$output_path" 2>/dev/null
    
    if [ -f "$output_path" ]; then
        echo -e "${GREEN}✓ Saved: $filename${NC}"
        
        # Get image dimensions
        if command -v sips &> /dev/null; then
            DIMENSIONS=$(sips -g pixelWidth -g pixelHeight "$output_path" 2>/dev/null | grep -E "pixelWidth|pixelHeight" | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
            echo -e "  Dimensions: $DIMENSIONS"
        fi
    else
        echo -e "${RED}✗ Failed to capture: $screen_name${NC}"
    fi
    echo ""
}

# Take screenshots for each screen
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Capturing Screenshots${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Note: This script captures the current screen state.${NC}"
echo -e "${YELLOW}For best results, manually navigate to each screen or use UI automation.${NC}"
echo ""

# Take initial screenshot (Home screen should be default)
take_screenshot "01_Home" "0"

# Instructions for manual navigation
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Manual Navigation Required${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Please navigate to each screen in the app, then press Enter to capture:"
echo ""

for screen_info in "${SCREENS[@]}"; do
    IFS=':' read -r screen_name tab_index <<< "$screen_info"
    
    if [ "$screen_name" != "Home" ]; then
        echo -e "${BLUE}Ready to capture: $screen_name${NC}"
        echo "1. Navigate to the '$screen_name' tab in the app"
        echo "2. Wait for the screen to fully load"
        echo "3. Press Enter to capture screenshot"
        read -r
        
        take_screenshot "$screen_name" "$tab_index"
    fi
done

# Create a summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Screenshot Generation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Screenshots saved to: $OUTPUT_DIR/$DEVICE_TYPE"
echo ""
echo "Files created:"
ls -lh "$OUTPUT_DIR/$DEVICE_TYPE"/*.png 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""

# Optional: Create App Store Connect ready folders
echo -e "${BLUE}Creating App Store Connect folder structure...${NC}"
mkdir -p "$OUTPUT_DIR/AppStoreConnect/iPhone"
mkdir -p "$OUTPUT_DIR/AppStoreConnect/iPad"

# Copy screenshots to App Store Connect folders
cp "$OUTPUT_DIR/$DEVICE_TYPE"/*.png "$OUTPUT_DIR/AppStoreConnect/iPhone/" 2>/dev/null || true

echo -e "${GREEN}✓ App Store Connect folders created${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Review screenshots in: $OUTPUT_DIR/$DEVICE_TYPE"
echo "2. Upload to App Store Connect: $OUTPUT_DIR/AppStoreConnect"
echo "3. Required sizes for App Store Connect:"
echo "   - iPhone 6.7\" Display: 1290 x 2796 pixels"
echo "   - iPhone 6.5\" Display: 1284 x 2778 pixels"
echo "   - iPhone 5.5\" Display: 1242 x 2208 pixels"
echo "   - iPad Pro 12.9\": 2048 x 2732 pixels"
echo ""

# Shutdown simulator (optional)
read -p "Shutdown simulator? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    xcrun simctl shutdown "$DEVICE_UDID"
    echo -e "${GREEN}Simulator shut down${NC}"
fi

echo -e "${GREEN}Done!${NC}"

