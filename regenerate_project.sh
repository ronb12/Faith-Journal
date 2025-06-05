#!/bin/bash

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "XcodeGen not found. Installing via Homebrew..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install XcodeGen
    brew install xcodegen
fi

# Backup the current project file
if [ -d "Faith Journal.xcodeproj" ]; then
    echo "Backing up current project..."
    cp -r "Faith Journal.xcodeproj" "Faith Journal.xcodeproj.backup"
fi

# Remove the current project file
rm -rf "Faith Journal.xcodeproj"

# Generate new project
echo "Generating new Xcode project..."
xcodegen generate

# Open the project in Xcode
echo "Opening project in Xcode..."
open "Faith Journal.xcodeproj"

echo "Project regenerated successfully!" 