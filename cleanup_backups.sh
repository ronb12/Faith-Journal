#!/bin/bash
# Cleanup script for Faith Journal project
# Removes backup files and consolidates duplicate projects

echo "🧹 Starting cleanup of Faith Journal project..."

# Remove backup files
echo "📦 Removing backup files..."
find "/Users/ronellbradley/Desktop/Faith Journal" -type f \( -name "*.backup*" -o -name "*.bak" \) ! -path "*/DerivedData/*" ! -path "*/.git/*" -print -delete

# Remove backup project directories
echo "🗂️  Removing backup project directories..."
rm -rf "/Users/ronellbradley/Desktop/Faith Journal/Faith Journal.xcodeproj.backup_20260111_102325"
rm -rf "/Users/ronellbradley/Desktop/Faith Journal/Faith Journal/backup"

# Note: Keep duplicate projects for now (Faith Journal 2, Faith Journal New)
# Review manually before removing
echo "⚠️  Note: Duplicate projects (Faith Journal 2, Faith Journal New) kept for manual review"

# Remove build artifacts
echo "🗑️  Cleaning build artifacts..."
rm -rf "/Users/ronellbradley/Desktop/Faith Journal/Faith Journal/build"
rm -rf "/Users/ronellbradley/Desktop/Faith Journal/DerivedData"

echo "✅ Cleanup complete! Please review before committing."
