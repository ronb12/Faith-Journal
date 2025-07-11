#!/bin/bash

echo "🔍 Checking Asset Catalogs for Missing or Empty Contents.json Files"
echo "=================================================================="

# Function to check an asset catalog
check_asset_catalog() {
    local catalog_path="$1"
    local catalog_name="$2"
    
    echo "📁 Checking: $catalog_name"
    
    if [ ! -d "$catalog_path" ]; then
        echo "   ❌ Asset catalog not found: $catalog_path"
        return
    fi
    
    # Check if Contents.json exists and is valid
    local contents_file="$catalog_path/Contents.json"
    if [ ! -f "$contents_file" ]; then
        echo "   ❌ Missing Contents.json in $catalog_name"
        return
    fi
    
    # Check if Contents.json is empty or invalid
    if [ ! -s "$contents_file" ]; then
        echo "   ❌ Empty Contents.json in $catalog_name"
        return
    fi
    
    # Check if Contents.json has valid JSON structure
    if ! python3 -m json.tool "$contents_file" > /dev/null 2>&1; then
        echo "   ❌ Invalid JSON in Contents.json for $catalog_name"
        return
    fi
    
    echo "   ✅ $catalog_name is healthy"
}

# Check main asset catalog
check_asset_catalog "Faith Journal/Faith Journal/Assets.xcassets" "Assets.xcassets"

# Check preview assets
check_asset_catalog "Faith Journal/Faith Journal/Preview Content/Preview Assets.xcassets" "Preview Assets.xcassets"

echo ""
echo "🎯 Summary:"
echo "If you see any ❌ errors above, those need to be fixed."
echo "✅ means the asset catalog is healthy."
echo ""
echo "💡 To fix issues:"
echo "1. Open the problematic asset set in Xcode"
echo "2. Delete and recreate the asset set if needed"
echo "3. Or restore the Contents.json from a backup" 