#!/bin/bash

echo "Adding WebRTC dependency to Faith Journal project..."

# Navigate to the project directory
cd "Faith Journal"

# Open Xcode project
open "Faith Journal.xcodeproj"

echo ""
echo "Please follow these steps in Xcode:"
echo "1. Select the 'Faith Journal' project in the navigator"
echo "2. Select the 'Faith Journal' target"
echo "3. Go to the 'General' tab"
echo "4. Scroll down to 'Frameworks, Libraries, and Embedded Content'"
echo "5. Click the '+' button"
echo "6. Search for 'WebRTC'"
echo "7. Select 'WebRTC' and click 'Add'"
echo ""
echo "Alternatively, you can add it via Package Dependencies:"
echo "1. Go to File > Add Package Dependencies..."
echo "2. Enter URL: https://github.com/stasel/WebRTC"
echo "3. Click 'Add Package'"
echo "4. Select the 'Faith Journal' target when prompted"
echo ""
echo "After adding WebRTC, you can build and run the live streaming feature!" 