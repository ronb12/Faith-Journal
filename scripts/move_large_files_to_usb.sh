#!/bin/bash

# Script to move large files to USB drive to free up space
# This will move approximately 768MB of files

echo "Large Files Move Script"
echo "======================"

# Check if USB drive is mounted
if [ ! -d "/Volumes/WINDOWS11" ]; then
    echo "Please connect your USB drive and mount it as 'WINDOWS11'"
    echo "Or modify this script to use your USB drive's actual name"
    echo ""
    echo "Available drives:"
    ls /Volumes/
    exit 1
fi

# Create backup directory on USB
BACKUP_DIR="/Volumes/WINDOWS11/Large_Files_Backup_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

echo "Moving large files to: $BACKUP_DIR"

# Move Faith Journal project
if [ -d "/Users/ronellbradley/Desktop/Faith Journal" ]; then
    echo "Moving Faith Journal project (325MB)..."
    cp -R "/Users/ronellbradley/Desktop/Faith Journal" "$BACKUP_DIR/"
fi

# Move Godot.app
if [ -d "/Users/ronellbradley/Downloads/Godot.app" ]; then
    echo "Moving Godot.app (287MB)..."
    cp -R "/Users/ronellbradley/Downloads/Godot.app" "$BACKUP_DIR/"
fi

# Move Epic Installer DMGs
if [ -f "/Users/ronellbradley/Downloads/EpicInstaller-18.7.0-unrealEngine-3272b9ca39484bdb9f7e196206fce6b2.dmg" ]; then
    echo "Moving Epic Installer DMG (59MB)..."
    cp "/Users/ronellbradley/Downloads/EpicInstaller-18.7.0-unrealEngine-3272b9ca39484bdb9f7e196206fce6b2.dmg" "$BACKUP_DIR/"
fi

if [ -f "/Users/ronellbradley/Downloads/EpicInstaller-18.7.0-unrealEngine-3272b9ca39484bdb9f7e196206fce6b2 (1).dmg" ]; then
    echo "Moving Epic Installer DMG copy (59MB)..."
    cp "/Users/ronellbradley/Downloads/EpicInstaller-18.7.0-unrealEngine-3272b9ca39484bdb9f7e196206fce6b2 (1).dmg" "$BACKUP_DIR/"
fi

# Move Projects folder
if [ -d "/Users/ronellbradley/Desktop/Projects" ]; then
    echo "Moving Projects folder (34MB)..."
    cp -R "/Users/ronellbradley/Desktop/Projects" "$BACKUP_DIR/"
fi

# Move Bradley's Travel Planner
if [ -d "/Users/ronellbradley/Desktop/Bradley's Travel Planner" ]; then
    echo "Moving Bradley's Travel Planner (4.6MB)..."
    cp -R "/Users/ronellbradley/Desktop/Bradley's Travel Planner" "$BACKUP_DIR/"
fi

echo ""
echo "File move complete!"
echo "Moved files to: $BACKUP_DIR"
echo "Total space freed: ~768MB"
echo ""
echo "To delete the original files after verifying the copy:"
echo "rm -rf '/Users/ronellbradley/Desktop/Faith Journal'"
echo "rm -rf '/Users/ronellbradley/Downloads/Godot.app'"
echo "rm '/Users/ronellbradley/Downloads/EpicInstaller-18.7.0-unrealEngine-3272b9ca39484bdb9f7e196206fce6b2.dmg'"
echo "rm '/Users/ronellbradley/Downloads/EpicInstaller-18.7.0-unrealEngine-3272b9ca39484bdb9f7e196206fce6b2 (1).dmg'"
echo "rm -rf '/Users/ronellbradley/Desktop/Projects'"
echo "rm -rf '/Users/ronellbradley/Desktop/Bradley'\''s Travel Planner'" 