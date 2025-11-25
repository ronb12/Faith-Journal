#!/bin/bash
# Alternative method to add files using git hash-object and update-index
# This bypasses some git index corruption issues

cd "$(dirname "$0")"

rm -f .git/index.lock

added=0
failed=0
skipped=0

echo "Adding files using alternative method (hash-object + update-index)..."

add_file_alternative() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Skip empty files
    if [ ! -s "$file" ]; then
        echo "⚠ Skipping empty file: $file"
        ((skipped++))
        return 1
    fi
    
    # Skip if already tracked
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        return 0
    fi
    
    rm -f .git/index.lock
    
    # Try method 1: hash-object + update-index
    local hash=$(git hash-object -w "$file" 2>/dev/null)
    if [ -n "$hash" ]; then
        # Get file mode (100644 for regular files, 100755 for executables)
        local mode="100644"
        if [ -x "$file" ]; then
            mode="100755"
        fi
        
        if git update-index --add --cacheinfo "$mode,$hash,$file" 2>/dev/null; then
            echo "✓ Added: $file"
            ((added++))
            return 0
        fi
    fi
    
    # Try method 2: direct update-index with --add flag
    rm -f .git/index.lock
    if git update-index --add "$file" 2>/dev/null; then
        if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            echo "✓ Added (direct): $file"
            ((added++))
            return 0
        fi
    fi
    
    # Try method 3: Check if file might be binary or have issues
    if file "$file" | grep -q "text"; then
        # File is text, but still failed - might be corrupted
        echo "✗ Failed (text file): $file"
    else
        # Might be binary, try anyway
        echo "⚠ Warning (possibly binary): $file"
    fi
    
    ((failed++))
    return 1
}

# Add documentation files
echo ""
echo "=== Adding documentation files ==="
find . -maxdepth 1 -type f \( -name "*.md" -o -name "*.txt" \) ! -name "README.md" | while read file; do
    add_file_alternative "$file"
done

# Add script files
echo ""
echo "=== Adding script files ==="
find . -maxdepth 1 -type f -name "*.sh" | while read file; do
    add_file_alternative "$file"
done

find scripts -type f \( -name "*.sh" -o -name "*.py" -o -name "*.rb" -o -name "*.swift" -o -name "*.js" \) 2>/dev/null | while read file; do
    add_file_alternative "$file"
done

# Add Sources directory files
echo ""
echo "=== Adding Sources directory ==="
find Sources -type f 2>/dev/null | while read file; do
    add_file_alternative "$file"
done

# Add Tests directory files
echo ""
echo "=== Adding Tests directory ==="
find Tests -type f 2>/dev/null | while read file; do
    add_file_alternative "$file"
done

# Add UITests directory files
echo ""
echo "=== Adding UITests directory ==="
find UITests -type f 2>/dev/null | while read file; do
    add_file_alternative "$file"
done

# Add Package.swift if it exists
echo ""
echo "=== Adding Package.swift ==="
if [ -f "Package.swift" ]; then
    add_file_alternative "Package.swift"
fi

# Add .github directory files (excluding problematic ones)
echo ""
echo "=== Adding .github directory ==="
find .github -type f 2>/dev/null | while read file; do
    # Skip empty files
    if [ -s "$file" ]; then
        add_file_alternative "$file"
    fi
done

# Add .xcode-version if it exists and has content
if [ -f ".xcode-version" ] && [ -s ".xcode-version" ]; then
    add_file_alternative ".xcode-version"
fi

# Add remaining files from Faith Journal that might have been missed
echo ""
echo "=== Adding remaining Faith Journal files ==="
find "Faith Journal" -type f -name "*.swift" 2>/dev/null | while read file; do
    if ! git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        add_file_alternative "$file"
    fi
done

echo ""
echo "=== Summary ==="
echo "  Successfully added: $added files"
echo "  Failed: $failed files"
echo "  Skipped (empty): $skipped files"
echo ""
echo "Check status: git status"
echo "Commit when ready: git commit -m 'Add remaining files using alternative method'"

