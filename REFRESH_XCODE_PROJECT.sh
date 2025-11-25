#!/bin/bash
# Script to force Xcode to refresh file system synchronized groups

echo "Refreshing Xcode project..."

PROJECT_PATH="/Users/ronellbradley/Desktop/Faith Journal/Faith Journal/Faith Journal.xcodeproj"
VIEWS_PATH="/Users/ronellbradley/Desktop/Faith Journal/Faith Journal/Faith Journal/Views"

# Close Xcode if open
echo "Closing Xcode..."
killall Xcode 2>/dev/null
sleep 2

# Clear derived data
echo "Clearing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Faith_Journal-*

# Touch all view files to trigger refresh
echo "Touching view files to trigger Xcode refresh..."
find "$VIEWS_PATH" -name "*.swift" -exec touch {} \;

# Clear Xcode caches
echo "Clearing Xcode caches..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*

echo ""
echo "Done! Now:"
echo "1. Open Xcode"
echo "2. Open the project: $PROJECT_PATH"
echo "3. Wait for indexing to complete (check bottom status bar)"
echo "4. Expand 'Faith Journal' folder in Project Navigator"
echo ""
echo "If views still don't appear, try:"
echo "- Product → Clean Build Folder (Shift+Cmd+K)"
echo "- File → Close Project, then reopen"
echo "- Restart Xcode"

