#!/bin/bash

# Script to move Faith Journal archive files to USB drive
# This will free up approximately 200MB+ of space

echo "Faith Journal Archive Cleanup Script"
echo "===================================="

# Check if USB drive is mounted
if [ ! -d "/Volumes/USB_DRIVE" ]; then
    echo "Please connect your USB drive and mount it as 'USB_DRIVE'"
    echo "Or modify this script to use your USB drive's actual name"
    exit 1
fi

# Create backup directory on USB
BACKUP_DIR="/Volumes/USB_DRIVE/Faith_Journal_Archives_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

echo "Moving archive files to: $BACKUP_DIR"

# Move all .xcarchive files
find "Faith Journal" -name "*.xcarchive" -type d -exec mv {} "$BACKUP_DIR/" \;

# Move TestFlight folders
find "Faith Journal" -name "*_TestFlight" -type d -exec mv {} "$BACKUP_DIR/" \;

# Move IPA files
find "Faith Journal" -name "*.ipa" -type f -exec mv {} "$BACKUP_DIR/" \;

# Move build folder
if [ -d "Faith Journal/build" ]; then
    mv "Faith Journal/build" "$BACKUP_DIR/"
fi

echo "Archive cleanup complete!"
echo "Moved files to: $BACKUP_DIR"
echo "You can now safely delete this backup if needed." 