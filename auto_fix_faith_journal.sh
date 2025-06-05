#!/bin/bash

# Auto Fix Faith Journal - Shell Wrapper
# Makes it easy to run the comprehensive Faith Journal auto-fixer

set -e

echo "🚀 Faith Journal Auto-Fix Launcher"
echo "=================================="

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "Please install Python 3 from https://python.org"
    exit 1
fi

# Check if we're in the right directory
if [ ! -d "Faith Journal" ]; then
    echo "❌ Faith Journal directory not found."
    echo "Please run this script from the project root directory."
    exit 1
fi

# Make the Python script executable
chmod +x auto_fix_faith_journal.py

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is required but not found."
    echo "Please install Xcode from the App Store."
    exit 1
fi

# Run the comprehensive auto-fixer
echo "🔧 Running comprehensive auto-fix..."
python3 auto_fix_faith_journal.py

echo ""
echo "✅ Auto-fix process completed!"
echo ""
echo "Next steps:"
echo "1. Open Faith Journal.xcodeproj in Xcode"
echo "2. Build and run the project (⌘+R)"
echo "3. If there are any remaining issues, they will be shown in Xcode"
echo ""
echo "📖 For more help, check the README.md file" 