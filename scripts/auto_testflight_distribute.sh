#!/bin/bash

# Script to automatically distribute to TestFlight after successful build
# This script should be called from ci_post_xcodebuild.sh
# Prerequisites: Xcode Cloud must be configured with TestFlight distribution

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TestFlight Auto-Distribution${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if we're in Xcode Cloud
if [ -z "$CI" ] || [ "$CI" != "true" ]; then
    echo -e "${YELLOW}⚠️  Not running in CI environment. Skipping TestFlight distribution.${NC}"
    echo "   (This script is designed for Xcode Cloud)"
    exit 0
fi

# Check if archive exists
if [ -z "$CI_ARCHIVE_PATH" ] || [ ! -d "$CI_ARCHIVE_PATH" ]; then
    echo -e "${RED}❌ Archive path not found: $CI_ARCHIVE_PATH${NC}"
    echo "   Cannot distribute to TestFlight without archive"
    exit 1
fi

# Check for errors and warnings from build
WARNINGS_FILE="/tmp/xcode_warnings.txt"
if [ -f "$WARNINGS_FILE" ]; then
    ERROR_COUNT=$(grep -c "error:" "$WARNINGS_FILE" 2>/dev/null || echo "0")
    WARNING_COUNT=$(grep -c "warning:" "$WARNINGS_FILE" 2>/dev/null || echo "0")
    
    # Remove newlines and ensure numeric
    ERROR_COUNT=$(echo "$ERROR_COUNT" | tr -d '\n' | head -1)
    WARNING_COUNT=$(echo "$WARNING_COUNT" | tr -d '\n' | head -1)
    ERROR_COUNT=${ERROR_COUNT:-0}
    WARNING_COUNT=${WARNING_COUNT:-0}
    
    echo -e "${BLUE}Build Status:${NC}"
    echo -e "  Errors: ${RED}$ERROR_COUNT${NC}"
    echo -e "  Warnings: ${YELLOW}$WARNING_COUNT${NC}"
    echo ""
    
    # Fail if errors exist
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${RED}❌ Build has errors. Cannot distribute to TestFlight.${NC}"
        exit 1
    fi
    
    # Warn if warnings exist (but don't block)
    if [ "$WARNING_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Build has warnings. Continuing with distribution...${NC}"
    else
        echo -e "${GREEN}✅ Build is clean (no errors, no warnings)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Warning file not found. Proceeding with distribution...${NC}"
fi

# Note: In Xcode Cloud, TestFlight distribution is configured in the workflow settings
# This script just verifies conditions are met
echo ""
echo -e "${BLUE}📦 Archive Information:${NC}"
echo "  Path: $CI_ARCHIVE_PATH"
if [ -d "$CI_ARCHIVE_PATH" ]; then
    echo "  Size: $(du -sh "$CI_ARCHIVE_PATH" | cut -f1)"
    echo "  ✅ Archive exists and is ready"
fi

echo ""
echo -e "${GREEN}✅ Conditions met for TestFlight distribution${NC}"
echo ""
echo -e "${BLUE}ℹ️  Note: TestFlight distribution is handled by Xcode Cloud workflow settings.${NC}"
echo "   To enable automatic distribution:"
echo "   1. Go to App Store Connect > Xcode Cloud"
echo "   2. Select your workflow"
echo "   3. Configure 'Distribute' action"
echo "   4. Enable 'Distribute to TestFlight'"
echo ""

exit 0

