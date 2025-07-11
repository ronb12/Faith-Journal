#!/bin/bash

# Remove WebRTC dependency from Xcode project file
PROJECT_FILE="Faith Journal/Faith Journal.xcodeproj/project.pbxproj"

echo "Removing WebRTC dependency from project file..."

# Remove the packageProductDependencies line that references WebRTC
sed -i '' '/47201ACE2E11CDFC00540883 \/\* WebRTC \*\/,/d' "$PROJECT_FILE"

# Remove the XCRemoteSwiftPackageReference section for WebRTC
sed -i '' '/47201ACD2E11CDFC00540883 \/\* XCRemoteSwiftPackageReference "WebRTC" \*\/ = {/,/};/d' "$PROJECT_FILE"

# Remove the XCSwiftPackageProductDependency section for WebRTC
sed -i '' '/47201ACE2E11CDFC00540883 \/\* WebRTC \*\/ = {/,/};/d' "$PROJECT_FILE"

echo "WebRTC dependency removed from project file."
echo "You can now build the project without WebRTC." 