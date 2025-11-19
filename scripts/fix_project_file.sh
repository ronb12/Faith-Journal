#!/bin/bash

PROJECT_FILE="Faith Journal/Faith Journal.xcodeproj/project.pbxproj"

echo "Fixing corrupted project file..."

# Remove the empty XCRemoteSwiftPackageReference section
sed -i '' '/\/\* Begin XCRemoteSwiftPackageReference section \*\//,/\/\* End XCRemoteSwiftPackageReference section \*\//d' "$PROJECT_FILE"

# Remove the empty XCSwiftPackageProductDependency section
sed -i '' '/\/\* Begin XCSwiftPackageProductDependency section \*\//,/\/\* End XCSwiftPackageProductDependency section \*\//d' "$PROJECT_FILE"

echo "Project file fixed!" 