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
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup_$(date +%s)"

# Create a frameworks build phase UUID that we'll use consistently
FRAMEWORK_PHASE_UUID=$(uuidgen | tr -d '-')

# First, find the main target section and its UUID
TARGET_UUID="0667FA2AE1ED61C1EDAFC816"

if [ -z "$TARGET_UUID" ]; then
    echo "Could not find main target UUID"
    exit 1
fi

echo "Found target UUID: $TARGET_UUID"

# Add frameworks build phase if it doesn't exist
if ! grep -q "Begin PBXFrameworksBuildPhase section" "$PROJECT_FILE"; then
    echo "Adding Frameworks Build Phase..."
    sed -i '' '/Begin PBXProject section/i\
/* Begin PBXFrameworksBuildPhase section */\
		'"$FRAMEWORK_PHASE_UUID"' /* Frameworks */ = {\
			isa = PBXFrameworksBuildPhase;\
			buildActionMask = 2147483647;\
			files = (\
			);\
			runOnlyForDeploymentPostprocessing = 0;\
		};\
/* End PBXFrameworksBuildPhase section */\
' "$PROJECT_FILE"

    # Add the build phase to the target
    sed -i '' '/buildPhases = (/a\
				'"$FRAMEWORK_PHASE_UUID"' /* Frameworks */,' "$PROJECT_FILE"
fi

# Add frameworks group if it doesn't exist
FRAMEWORKS_GROUP_UUID=$(uuidgen | tr -d '-')
if ! grep -q "/* Frameworks */ = {" "$PROJECT_FILE"; then
    echo "Adding Frameworks Group..."
    sed -i '' '/Begin PBXGroup section/a\
		'"$FRAMEWORKS_GROUP_UUID"' /* Frameworks */ = {\
			isa = PBXGroup;\
			children = (\
			);\
			name = Frameworks;\
			sourceTree = "<group>";\
		};' "$PROJECT_FILE"

    # Add frameworks group to main group
    sed -i '' '/mainGroup = /,/children = (/s/children = (/children = (\
				'"$FRAMEWORKS_GROUP_UUID"' \/* Frameworks *\/,/' "$PROJECT_FILE"
fi

# Add each framework
for framework in "${FRAMEWORKS[@]}"; do
    echo "Adding $framework..."
    
    # Generate consistent UUIDs
    FILE_UUID=$(uuidgen | tr -d '-')
    BUILD_UUID=$(uuidgen | tr -d '-')
    
    # Add framework reference to Frameworks group
    sed -i '' '/\/\* Frameworks \*\/ = {/,/sourceTree = "<group>";/{/children = (/a\
				'"$FILE_UUID"' /* '"$framework"'.framework */,
}' "$PROJECT_FILE"
    
    # Add to PBXFileReference section
    sed -i '' '/Begin PBXFileReference section/a\
		'"$FILE_UUID"' /* '"$framework"'.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = '"$framework"'.framework; path = System/Library/Frameworks/'"$framework"'.framework; sourceTree = SDKROOT; };' "$PROJECT_FILE"
    
    # Add to PBXBuildFile section
    sed -i '' '/Begin PBXBuildFile section/a\
		'"$BUILD_UUID"' /* '"$framework"'.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = '"$FILE_UUID"' /* '"$framework"'.framework */; };' "$PROJECT_FILE"
    
    # Add to frameworks build phase
    sed -i '' '/buildActionMask = 2147483647;/,/runOnlyForDeploymentPostprocessing = 0;/{/files = (/a\
				'"$BUILD_UUID"' /* '"$framework"'.framework in Frameworks */,
}' "$PROJECT_FILE"
done

# Add frameworks to target dependencies
sed -i '' '/dependencies = (/a\
				'"$FRAMEWORKS_GROUP_UUID"' /* Frameworks */,' "$PROJECT_FILE"

echo "Frameworks added successfully" 