#!/bin/bash

# Add files to Xcode project using xcodebuild or manual project file editing
# This script will help identify files that need to be added

PROJECT_PATH="Faith Journal/Faith Journal.xcodeproj"
TARGET="Faith Journal"

echo "Files to add to Xcode project:"
echo ""
echo "Models:"
ls -1 "Faith Journal/Faith Journal/Models/SessionClip.swift" 2>/dev/null && echo "  ✓ SessionClip.swift"
echo ""
echo "Services:"
ls -1 "Faith Journal/Faith Journal/Services/TranslationService.swift" 2>/dev/null && echo "  ✓ TranslationService.swift"
ls -1 "Faith Journal/Faith Journal/Services/SessionRecommendationService.swift" 2>/dev/null && echo "  ✓ SessionRecommendationService.swift"
echo ""
echo "Views:"
ls -1 "Faith Journal/Faith Journal/Views/WaitingRoomView.swift" 2>/dev/null && echo "  ✓ WaitingRoomView.swift"
ls -1 "Faith Journal/Faith Journal/Views/SessionClipsView.swift" 2>/dev/null && echo "  ✓ SessionClipsView.swift"
ls -1 "Faith Journal/Faith Journal/Views/TranslationSettingsView.swift" 2>/dev/null && echo "  ✓ TranslationSettingsView.swift"

echo ""
echo "To add these files in Xcode:"
echo "1. Open the project in Xcode"
echo "2. Right-click on the appropriate folder (Models/Services/Views)"
echo "3. Select 'Add Files to \"Faith Journal\"...'"
echo "4. Select the files and ensure target membership is checked"
