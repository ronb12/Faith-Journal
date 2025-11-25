#!/bin/bash

# Script to move entire Faith Journal project to USB drive
# This will move approximately 324MB of project files

echo "Faith Journal Project Move Script"
echo "================================="

# Check if USB drive is mounted
if [ ! -d "/Volumes/USB_DRIVE" ]; then
    echo "Please connect your USB drive and mount it as 'USB_DRIVE'"
    echo "Or modify this script to use your USB drive's actual name"
    exit 1
fi

# Create project directory on USB
PROJECT_DIR="/Volumes/USB_DRIVE/Faith_Journal_Project_$(date +%Y%m%d)"
mkdir -p "$PROJECT_DIR"

echo "Moving entire Faith Journal project to: $PROJECT_DIR"

# Copy all project files
cp -R "Faith Journal" "$PROJECT_DIR/"
cp -R "Sources" "$PROJECT_DIR/" 2>/dev/null || true
cp -R "Tests" "$PROJECT_DIR/" 2>/dev/null || true
cp -R "UITests" "$PROJECT_DIR/" 2>/dev/null || true
cp *.swift "$PROJECT_DIR/" 2>/dev/null || true
cp *.rb "$PROJECT_DIR/" 2>/dev/null || true
cp *.py "$PROJECT_DIR/" 2>/dev/null || true
cp *.sh "$PROJECT_DIR/" 2>/dev/null || true
cp *.plist "$PROJECT_DIR/" 2>/dev/null || true
cp *.md "$PROJECT_DIR/" 2>/dev/null || true
cp *.txt "$PROJECT_DIR/" 2>/dev/null || true

echo "Project move complete!"
echo "Project copied to: $PROJECT_DIR"
echo "You can now work on the project from the USB drive." 