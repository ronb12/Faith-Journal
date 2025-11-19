#!/bin/sh

# Xcode Cloud Post-Build Script
# This script runs after Xcode builds your project

set -e

echo "🎉 Starting Xcode Cloud post-build script..."

# Print build information
echo "📦 Build Information:"
echo "  - CI: $CI"
echo "  - BUILD_NUMBER: $CI_BUILD_NUMBER"
echo "  - PRODUCT_BUNDLE_IDENTIFIER: $PRODUCT_BUNDLE_IDENTIFIER"

# Check if build artifacts exist
if [ -d "$CI_ARCHIVE_PATH" ]; then
    echo "✅ Archive created: $CI_ARCHIVE_PATH"
    ls -lh "$CI_ARCHIVE_PATH" || true
else
    echo "⚠️  Archive path not found: $CI_ARCHIVE_PATH"
fi

# Print build summary
echo "📊 Build Summary:"
echo "  - Scheme: $CI_XCODE_SCHEME"
echo "  - Configuration: $CI_XCODEBUILD_CONFIGURATION"
echo "  - Derived Data: $CI_DERIVED_DATA_PATH"

echo "✅ Post-build script completed!"

