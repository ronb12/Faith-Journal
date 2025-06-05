#!/bin/bash

# Required frameworks
FRAMEWORKS=(
    "SwiftUI"
    "SwiftData"
    "Foundation"
    "AVFoundation"
    "PhotosUI"
    "PencilKit"
    "Charts"
    "LocalAuthentication"
    "UniformTypeIdentifiers"
)

# Path to project.pbxproj
PROJECT_FILE="Faith Journal.xcodeproj/project.pbxproj"

# Backup the project file
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"

# Create a temporary file
TEMP_FILE=$(mktemp)

# Read the project file
cat "$PROJECT_FILE" > "$TEMP_FILE"

# Find the main target section
TARGET_SECTION=$(grep -n "Begin PBXFrameworksBuildPhase section" "$TEMP_FILE" | head -n 1 | cut -d: -f1)
if [ -z "$TARGET_SECTION" ]; then
    # If no frameworks phase exists, we need to create one
    PHASES_SECTION=$(grep -n "Begin PBXProject section" "$TEMP_FILE" | cut -d: -f1)
    FRAMEWORK_PHASE_UUID=$(uuidgen)
    sed -i '' "${PHASES_SECTION}i\\
/* Begin PBXFrameworksBuildPhase section */\\
		${FRAMEWORK_PHASE_UUID} /* Frameworks */ = {\\
			isa = PBXFrameworksBuildPhase;\\
			buildActionMask = 2147483647;\\
			files = (\\
			);\\
			runOnlyForDeploymentPostprocessing = 0;\\
		};\\
/* End PBXFrameworksBuildPhase section */\\
" "$TEMP_FILE"
fi

# Add framework references
for framework in "${FRAMEWORKS[@]}"; do
    FRAMEWORK_UUID=$(uuidgen)
    BUILD_UUID=$(uuidgen)
    
    # Add to PBXFileReference section
    FILE_REF_SECTION=$(grep -n "Begin PBXFileReference section" "$TEMP_FILE" | cut -d: -f1)
    sed -i '' "${FILE_REF_SECTION}a\\
		${FRAMEWORK_UUID} /* ${framework}.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = ${framework}.framework; path = System/Library/Frameworks/${framework}.framework; sourceTree = SDKROOT; };" "$TEMP_FILE"
    
    # Add to PBXBuildFile section
    BUILD_SECTION=$(grep -n "Begin PBXBuildFile section" "$TEMP_FILE" | cut -d: -f1)
    sed -i '' "${BUILD_SECTION}a\\
		${BUILD_UUID} /* ${framework}.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = ${FRAMEWORK_UUID} /* ${framework}.framework */; };" "$TEMP_FILE"
    
    # Add to Frameworks build phase
    FRAMEWORKS_SECTION=$(grep -n "Begin PBXFrameworksBuildPhase section" "$TEMP_FILE" | cut -d: -f1)
    FILES_LINE=$((FRAMEWORKS_SECTION + 4))
    sed -i '' "${FILES_LINE}i\\
				${BUILD_UUID} /* ${framework}.framework in Frameworks */," "$TEMP_FILE"
done

# Update the project file
mv "$TEMP_FILE" "$PROJECT_FILE"

echo "Frameworks added successfully" 