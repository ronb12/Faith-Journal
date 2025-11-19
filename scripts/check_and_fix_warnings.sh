#!/bin/bash

# Script to check for Xcode warnings and automatically fix common ones
# Usage: ./check_and_fix_warnings.sh [--fix] [--strict]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_PATH="$(dirname "$0")/../Faith Journal/Faith Journal.xcodeproj"
SCHEME="Faith Journal"
BUILD_DIR="/tmp/FaithJournalWarnings"
FIX_MODE=false
STRICT_MODE=false
WARNINGS_FILE="/tmp/xcode_warnings.txt"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX_MODE=true
            shift
            ;;
        --strict)
            STRICT_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--fix] [--strict]"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Xcode Warnings Checker & Fixer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Xcode project exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}Error: Xcode project not found at $PROJECT_PATH${NC}"
    exit 1
fi

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo -e "${BLUE}Building project to check for warnings...${NC}"
echo ""

# Build and capture warnings
cd "$(dirname "$PROJECT_PATH")/.."

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$BUILD_DIR" \
    clean build 2>&1 | tee "$WARNINGS_FILE" | grep -E "(warning:|error:)" || true

# Extract warnings
WARNINGS=$(grep -E "warning:" "$WARNINGS_FILE" || true)
ERRORS=$(grep -E "error:" "$WARNINGS_FILE" || true)

# Count warnings
WARNING_COUNT=$(echo "$WARNINGS" | grep -c "warning:" 2>/dev/null || echo "0" | head -1)
ERROR_COUNT=$(echo "$ERRORS" | grep -c "error:" 2>/dev/null || echo "0" | head -1)

# Clean up counts (remove newlines)
WARNING_COUNT=$(echo "$WARNING_COUNT" | tr -d '\n' | head -1)
ERROR_COUNT=$(echo "$ERROR_COUNT" | tr -d '\n' | head -1)

# Ensure counts are numeric
WARNING_COUNT=${WARNING_COUNT:-0}
ERROR_COUNT=${ERROR_COUNT:-0}

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Warnings: ${YELLOW}$WARNING_COUNT${NC}"
echo -e "Errors: ${RED}$ERROR_COUNT${NC}"
echo ""

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${RED}Errors found. Please fix errors before addressing warnings.${NC}"
    echo ""
    echo -e "${RED}Errors:${NC}"
    echo "$ERRORS" | head -10
    exit 1
fi

if [ "$WARNING_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ No warnings found!${NC}"
    exit 0
fi

# Display warnings
echo -e "${YELLOW}Warnings found:${NC}"
echo "$WARNINGS" | head -20
echo ""

if [ "$FIX_MODE" = false ]; then
    echo -e "${YELLOW}Run with --fix to automatically fix common warnings${NC}"
    exit 0
fi

echo -e "${BLUE}Attempting to fix warnings...${NC}"
echo ""

# Function to fix common warning patterns
fix_warnings() {
    local fixed_count=0
    
    # Pattern 1: Unused variable warnings
    # Example: "Immutable value 'createdAt' was never used"
    while IFS= read -r warning; do
        if echo "$warning" | grep -q "was never used"; then
            # Extract file path and line number
            file_path=$(echo "$warning" | sed -n 's/.*\(Faith Journal\/[^:]*\):\([0-9]*\).*/\1/p')
            line_num=$(echo "$warning" | sed -n 's/.*:\([0-9]*\):.*/\1/p')
            var_name=$(echo "$warning" | sed -n "s/.*'\([^']*\)' was never used.*/\1/p")
            
            if [ -n "$file_path" ] && [ -n "$line_num" ] && [ -n "$var_name" ]; then
                full_path="$(dirname "$PROJECT_PATH")/../$file_path"
                if [ -f "$full_path" ]; then
                    # Check if it's a guard statement or let statement
                    line_content=$(sed -n "${line_num}p" "$full_path")
                    
                    # Fix guard statement: let var = ... -> let _ = ...
                    if echo "$line_content" | grep -q "guard let $var_name ="; then
                        sed -i '' "${line_num}s/guard let $var_name =/guard let _ =/g" "$full_path"
                        echo -e "${GREEN}Fixed: $file_path:$line_num - Replaced unused variable in guard${NC}"
                        ((fixed_count++))
                    # Fix let statement: let var = ... -> let _ = ...
                    elif echo "$line_content" | grep -q "let $var_name ="; then
                        sed -i '' "${line_num}s/let $var_name =/let _ =/g" "$full_path"
                        echo -e "${GREEN}Fixed: $file_path:$line_num - Replaced unused variable${NC}"
                        ((fixed_count++))
                    fi
                fi
            fi
        fi
    done <<< "$WARNINGS"
    
    # Pattern 2: Deprecated string interpolation
    # Example: "'appendInterpolation' is deprecated"
    while IFS= read -r warning; do
        if echo "$warning" | grep -q "appendInterpolation.*deprecated"; then
            file_path=$(echo "$warning" | sed -n 's/.*\(Faith Journal\/[^:]*\):\([0-9]*\).*/\1/p')
            line_num=$(echo "$warning" | sed -n 's/.*:\([0-9]*\):.*/\1/p')
            
            if [ -n "$file_path" ] && [ -n "$line_num" ]; then
                full_path="$(dirname "$PROJECT_PATH")/../$file_path"
                if [ -f "$full_path" ]; then
                    line_content=$(sed -n "${line_num}p" "$full_path")
                    
                    # Fix: Text("\(value)") -> Text(String(describing: value))
                    if echo "$line_content" | grep -q 'Text("\\('; then
                        # Extract the variable name
                        var_name=$(echo "$line_content" | sed -n 's/.*Text("\\\(\([^)]*\)\\).*/\1/p')
                        if [ -n "$var_name" ]; then
                            new_line=$(echo "$line_content" | sed "s/Text(\"\\\\($var_name)\\\")/Text(String(describing: $var_name))/g")
                            sed -i '' "${line_num}s|.*|$new_line|" "$full_path"
                            echo -e "${GREEN}Fixed: $file_path:$line_num - Fixed deprecated string interpolation${NC}"
                            ((fixed_count++))
                        fi
                    fi
                fi
            fi
        fi
    done <<< "$WARNINGS"
    
    # Pattern 3: Value defined but never used (boolean test)
    # Example: "Value 'sessionId' was defined but never used"
    while IFS= read -r warning; do
        if echo "$warning" | grep -q "was defined but never used"; then
            file_path=$(echo "$warning" | sed -n 's/.*\(Faith Journal\/[^:]*\):\([0-9]*\).*/\1/p')
            line_num=$(echo "$warning" | sed -n 's/.*:\([0-9]*\):.*/\1/p')
            var_name=$(echo "$warning" | sed -n "s/.*'\([^']*\)' was defined but never used.*/\1/p")
            
            if [ -n "$file_path" ] && [ -n "$line_num" ] && [ -n "$var_name" ]; then
                full_path="$(dirname "$PROJECT_PATH")/../$file_path"
                if [ -f "$full_path" ]; then
                    line_content=$(sed -n "${line_num}p" "$full_path")
                    
                    # Fix guard statement: guard let var = ... -> guard ... != nil
                    if echo "$line_content" | grep -q "guard let $var_name ="; then
                        # Extract the expression after =
                        expr=$(echo "$line_content" | sed -n "s/.*guard let $var_name = \(.*\) else.*/\1/p")
                        if [ -n "$expr" ]; then
                            new_line=$(echo "$line_content" | sed "s/guard let $var_name = \(.*\) else/guard \1 != nil else/g")
                            sed -i '' "${line_num}s|.*|$new_line|" "$full_path"
                            echo -e "${GREEN}Fixed: $file_path:$line_num - Replaced unused variable with boolean check${NC}"
                            ((fixed_count++))
                        fi
                    fi
                fi
            fi
        fi
    done <<< "$WARNINGS"
    
    # Pattern 4: if let unused variable
    # Example: "if let existingParticipant = ..." where existingParticipant is never used
    while IFS= read -r warning; do
        if echo "$warning" | grep -q "was defined but never used"; then
            file_path=$(echo "$warning" | sed -n 's/.*\(Faith Journal\/[^:]*\):\([0-9]*\).*/\1/p')
            line_num=$(echo "$warning" | sed -n 's/.*:\([0-9]*\):.*/\1/p')
            var_name=$(echo "$warning" | sed -n "s/.*'\([^']*\)' was defined but never used.*/\1/p")
            
            if [ -n "$file_path" ] && [ -n "$line_num" ] && [ -n "$var_name" ]; then
                full_path="$(dirname "$PROJECT_PATH")/../$file_path"
                if [ -f "$full_path" ]; then
                    line_content=$(sed -n "${line_num}p" "$full_path")
                    
                    # Fix: if let var = ... -> if (... != nil)
                    if echo "$line_content" | grep -q "if let $var_name ="; then
                        # Extract the expression
                        expr=$(echo "$line_content" | sed -n "s/.*if let $var_name = \(.*\) {.*/\1/p")
                        if [ -n "$expr" ]; then
                            new_line=$(echo "$line_content" | sed "s/if let $var_name = \(.*\) {/if (\1) != nil {/g")
                            sed -i '' "${line_num}s|.*|$new_line|" "$full_path"
                            echo -e "${GREEN}Fixed: $file_path:$line_num - Replaced unused if let with boolean check${NC}"
                            ((fixed_count++))
                        fi
                    fi
                fi
            fi
        fi
    done <<< "$WARNINGS"
    
    echo ""
    echo -e "${GREEN}Fixed $fixed_count warning(s)${NC}"
    return $fixed_count
}

# Run fixes
if [ "$FIX_MODE" = true ]; then
    fix_warnings
    fixed=$?
    
    if [ $fixed -gt 0 ]; then
        echo ""
        echo -e "${BLUE}Rebuilding to verify fixes...${NC}"
        # Rebuild to check if warnings are fixed
        xcodebuild \
            -project "$PROJECT_PATH" \
            -scheme "$SCHEME" \
            -configuration Debug \
            -destination "generic/platform=iOS" \
            -derivedDataPath "$BUILD_DIR" \
            clean build 2>&1 | grep -E "(warning:|error:)" || true
    fi
fi

# Exit with error if strict mode and warnings remain
if [ "$STRICT_MODE" = true ] && [ "$WARNING_COUNT" -gt 0 ]; then
    echo -e "${RED}Strict mode: Exiting with error due to warnings${NC}"
    exit 1
fi

exit 0

