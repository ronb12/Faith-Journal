#!/bin/bash

# Faith Journal - Xcode Error Auto-Fix Script
# Easy wrapper script to fix common compilation errors

set -e  # Exit on any error

echo "🙏 Faith Journal - Xcode Error Auto-Fixer"
echo "========================================"

# Check if we're in the right directory
if [ ! -d "Faith Journal" ]; then
    echo "Error: This script should be run from the project root directory."
    echo "Expected to find 'Faith Journal' folder in current directory."
    exit 1
fi

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    echo "Please install Python 3 and try again."
    exit 1
fi

# Check if Xcode command line tools are installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode command line tools are required."
    echo "Please install with: xcode-select --install"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Make the Python script executable
chmod +x fix_xcode_errors.py

# Run the error fixer
echo "🔧 Running error fixes..."
python3 fix_xcode_errors.py .

echo ""
echo "🎯 Quick manual checks to perform:"
echo "1. Open the project in Xcode"
echo "2. Check project settings > Deployment Target (iOS 17.0+)"
echo "3. Verify signing & capabilities"
echo "4. Add any missing frameworks in project settings:"
echo "   - SwiftUI"
echo "   - SwiftData"
echo "   - Charts"
echo "   - PencilKit"
echo "   - AVFoundation"
echo "   - UserNotifications"
echo "   - LocalAuthentication"
echo ""
echo "📱 To test the app:"
echo "   1. Select a simulator (iPhone 15 recommended)"
echo "   2. Press Cmd+R to build and run"
echo ""
echo "✨ Faith Journal error fixing complete!" 