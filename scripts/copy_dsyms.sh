#!/bin/bash

# Script to copy dSYM files from Swift Package dependencies to the archive
# This fixes the "Upload Symbols Failed" warnings for third-party frameworks

set -e

echo "🔍 [dSYM] Starting dSYM copy script..."

# Get the archive dSYMs path (where dSYMs should be copied)
ARCHIVE_DSYMS_PATH="${ARCHIVE_DSYMS_PATH:-${DWARF_DSYM_FOLDER_PATH}}"

# For archiving, use the archive's dSYMs folder
if [ -n "${ARCHIVE_PRODUCTS_PATH}" ]; then
    ARCHIVE_DSYMS_PATH="${ARCHIVE_PRODUCTS_PATH}/dSYMs"
fi

if [ -z "$ARCHIVE_DSYMS_PATH" ] || [ ! -d "$ARCHIVE_DSYMS_PATH" ]; then
    # Try alternative paths
    if [ -n "${BUILT_PRODUCTS_DIR}" ]; then
        ARCHIVE_DSYMS_PATH="${BUILT_PRODUCTS_DIR}/../dSYMs"
    fi
fi

if [ ! -d "$ARCHIVE_DSYMS_PATH" ]; then
    echo "⚠️ [dSYM] Archive dSYMs folder not found, creating: $ARCHIVE_DSYMS_PATH"
    mkdir -p "$ARCHIVE_DSYMS_PATH" 2>/dev/null || true
fi

echo "📦 [dSYM] Archive dSYMs path: $ARCHIVE_DSYMS_PATH"

# Find all frameworks in the app bundle
APP_FRAMEWORKS="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"

if [ -d "$APP_FRAMEWORKS" ]; then
    echo "🔍 [dSYM] Searching for framework dSYMs in: $APP_FRAMEWORKS"
    
    # Copy dSYMs for each framework
    find "$APP_FRAMEWORKS" -name "*.framework" -type d | while read framework_path; do
        framework_name=$(basename "$framework_path" .framework)
        framework_binary="$framework_path/$framework_name"
        
        if [ ! -f "$framework_binary" ]; then
            continue
        fi
        
        # Look for dSYM in common locations
        dsym_paths=(
            "${framework_path}.dSYM"
            "${BUILT_PRODUCTS_DIR}/${framework_name}.framework.dSYM"
            "${DWARF_DSYM_FOLDER_PATH}/${framework_name}.framework.dSYM"
            "${BUILT_PRODUCTS_DIR}/../${framework_name}.framework.dSYM"
        )
        
        for dsym_path in "${dsym_paths[@]}"; do
            if [ -d "$dsym_path" ]; then
                echo "✅ [dSYM] Found dSYM for $framework_name at: $dsym_path"
                # Copy to archive dSYMs folder
                cp -R "$dsym_path" "$ARCHIVE_DSYMS_PATH/" 2>/dev/null && echo "✅ [dSYM] Copied $framework_name.dSYM" || echo "⚠️ [dSYM] Failed to copy $framework_name.dSYM"
                break
            fi
        done
    done
fi

# Check Swift Package Manager build directory
SPM_BUILD_DIR="${BUILD_DIR}/SourcePackages/checkouts"
if [ -d "$SPM_BUILD_DIR" ]; then
    echo "🔍 [dSYM] Checking Swift Package Manager build directory..."
    find "$SPM_BUILD_DIR" -name "*.dSYM" -type d 2>/dev/null | while read dsym_path; do
        dsym_name=$(basename "$dsym_path")
        echo "✅ [dSYM] Found SPM dSYM: $dsym_name"
        cp -R "$dsym_path" "$ARCHIVE_DSYMS_PATH/" 2>/dev/null && echo "✅ [dSYM] Copied $dsym_name" || echo "⚠️ [dSYM] Failed to copy $dsym_name"
    done
fi

# Check DerivedData for dSYMs
DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
if [ -d "$DERIVED_DATA" ]; then
    echo "🔍 [dSYM] Checking DerivedData for dSYMs..."
    find "$DERIVED_DATA" -name "*.framework.dSYM" -type d 2>/dev/null | head -20 | while read dsym_path; do
        framework_name=$(basename "$dsym_path" .framework.dSYM)
        # Only copy if it's one of our dependencies
        if [[ "$framework_name" == *"Agora"* ]] || [[ "$framework_name" == *"Firebase"* ]] || [[ "$framework_name" == *"absl"* ]] || [[ "$framework_name" == *"grpc"* ]]; then
            echo "✅ [dSYM] Found dependency dSYM: $framework_name"
            cp -R "$dsym_path" "$ARCHIVE_DSYMS_PATH/" 2>/dev/null && echo "✅ [dSYM] Copied $framework_name.dSYM" || true
        fi
    done
fi

echo "✅ [dSYM] dSYM copy script completed"
