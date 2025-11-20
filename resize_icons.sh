#!/bin/bash

# Script to resize a single praying hands icon to all required iOS app icon sizes
# Usage: ./resize_icons.sh <input-image.png>

if [ -z "$1" ]; then
    echo "Usage: ./resize_icons.sh <input-image.png>"
    echo "Example: ./resize_icons.sh praying-hands-1024.png"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_DIR="Faith Journal/Faith Journal/Resources/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found!"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory '$OUTPUT_DIR' not found!"
    exit 1
fi

echo "Resizing icons from: $INPUT_FILE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Function to resize using sips (built into macOS)
resize_icon() {
    local size=$1
    local output="$OUTPUT_DIR/$2"
    sips -z $size $size "$INPUT_FILE" --out "$output" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Created: $2 ($size x $size)"
    else
        echo "✗ Failed: $2"
    fi
}

# iPad icons
resize_icon 20 "AppIcon-20x20.png"
resize_icon 40 "AppIcon-20x20@2x.png"
resize_icon 29 "AppIcon-29x29.png"
resize_icon 58 "AppIcon-29x29@2x.png"
resize_icon 40 "AppIcon-40x40.png"
resize_icon 80 "AppIcon-40x40@2x.png"
resize_icon 76 "AppIcon-76x76.png"
resize_icon 152 "AppIcon-76x76@2x.png"
resize_icon 167 "AppIcon-83.5x83.5@2x.png"

# iPhone icons
resize_icon 58 "AppIcon-29x29@2x.png"  # Shared with iPad
resize_icon 87 "AppIcon-29x29@3x.png"
resize_icon 80 "AppIcon-40x40@2x.png"  # Shared with iPad
resize_icon 120 "AppIcon-40x40@3x.png"
resize_icon 120 "AppIcon-60x60@2x.png"
resize_icon 180 "AppIcon-60x60@3x.png"

# App Store icon
resize_icon 1024 "AppIcon-1024x1024.png"

echo ""
echo "Done! All icons have been resized and placed in the AppIcon.appiconset folder."
echo ""
echo "Next steps:"
echo "1. Open the project in Xcode"
echo "2. Clean build folder (Cmd+Shift+K)"
echo "3. Delete app from simulator"
echo "4. Rebuild and reinstall the app"

