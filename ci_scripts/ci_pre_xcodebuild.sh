#!/bin/sh

# Xcode Cloud Pre-Build Script
# This script runs before Xcode builds your project

set -e

echo "🚀 Starting Xcode Cloud pre-build script..."

# Print environment information
echo "📱 Xcode Cloud Environment:"
echo "  - CI: $CI"
echo "  - XCODE_CLOUD: $XCODE_CLOUD"
echo "  - BUILD_NUMBER: $CI_BUILD_NUMBER"
echo "  - WORKSPACE: $CI_WORKSPACE"

# Verify required tools
echo "🔍 Checking required tools..."
which swift || { echo "❌ Swift not found"; exit 1; }
which xcodebuild || { echo "❌ xcodebuild not found"; exit 1; }

# Print Swift version
swift --version

# Print Xcode version
xcodebuild -version

# Check project structure
echo "📁 Checking project structure..."
if [ ! -d "Faith Journal/Faith Journal.xcodeproj" ]; then
    echo "❌ Xcode project not found"
    exit 1
fi

echo "✅ Pre-build checks passed!"

