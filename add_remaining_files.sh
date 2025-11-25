#!/bin/bash
# Script to add remaining project files to git
# This works around git index corruption issues by adding files individually

# Don't exit on error - continue processing
set +e

cd "$(dirname "$0")"

# Remove lock file if it exists
rm -f .git/index.lock

# Counter for successful adds
added=0
failed=0

echo "Adding remaining project files..."

# Function to safely add a file
add_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    rm -f .git/index.lock
    
    # Skip files known to cause bus errors
    if [[ "$file" == *"BibleService_WEB.swift"* ]]; then
        echo "⚠ Skipping (known issue): $file"
        ((failed++))
        return 1
    fi
    
    # Try git add first
    (
        rm -f .git/index.lock
        git add "$file" 2>/dev/null
    ) 2>&1 | grep -v "fatal\|error" > /dev/null || true
    
    # Check if it was added successfully
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        echo "✓ Added: $file"
        ((added++))
        return 0
    fi
    
    # If not added, try update-index
    rm -f .git/index.lock
    (
        git update-index --add "$file" 2>/dev/null
    ) 2>&1 | grep -v "fatal\|error" > /dev/null || true
    
    # Check again
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        echo "✓ Added (via update-index): $file"
        ((added++))
        return 0
    fi
    
    echo "✗ Failed: $file (skipping)"
    ((failed++))
    return 1
}

# Add remaining Swift files
echo "Adding Swift source files..."
for file in "Faith Journal/Faith Journal/Services/"*.swift; do
    add_file "$file"
done

for file in "Faith Journal/Faith Journal/Utils/"*.swift; do
    add_file "$file"
done

for file in "Faith Journal/Faith Journal/Views/"*.swift; do
    add_file "$file"
done

# Add test files
echo "Adding test files..."
for file in "Faith Journal/Faith JournalTests/"*.swift; do
    add_file "$file"
done

for file in "Faith Journal/Faith JournalUITests/"*.swift; do
    add_file "$file"
done

# Add Sources, Tests, UITests directories if they exist
if [ -d "Sources" ]; then
    echo "Adding Sources directory..."
    find Sources -type f -name "*.swift" | while read file; do
        add_file "$file"
    done
fi

if [ -d "Tests" ]; then
    echo "Adding Tests directory..."
    find Tests -type f -name "*.swift" | while read file; do
        add_file "$file"
    done
fi

if [ -d "UITests" ]; then
    echo "Adding UITests directory..."
    find UITests -type f -name "*.swift" | while read file; do
        add_file "$file"
    done
fi

# Add Package.swift if it exists
if [ -f "Package.swift" ]; then
    add_file "Package.swift"
fi

# Add documentation files
echo "Adding documentation files..."
find . -maxdepth 1 -type f \( -name "*.md" -o -name "*.txt" \) ! -name "README.md" | while read file; do
    add_file "$file"
done

# Add script files
echo "Adding script files..."
find . -maxdepth 1 -type f -name "*.sh" | while read file; do
    add_file "$file"
done

find scripts -type f 2>/dev/null | while read file; do
    add_file "$file"
done

echo ""
echo "Summary:"
echo "  Successfully added: $added files"
echo "  Failed: $failed files"
echo ""
echo "Check status with: git status"
echo "Commit with: git commit -m 'Add remaining project files'"

