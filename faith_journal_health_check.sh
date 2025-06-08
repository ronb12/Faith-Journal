#!/bin/bash

# Faith Journal Project Health Check
# Comprehensive validation script that runs all available tools with 12 workers
# Provides a complete assessment of project health and recommendations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project paths
PROJECT_DIR="$(pwd)"
REPORTS_DIR="$PROJECT_DIR/health_check_reports"

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}                Faith Journal Project Health Check                    ${NC}"
echo -e "${BLUE}             Comprehensive validation with 12 workers                ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo ""

# Create reports directory
mkdir -p "$REPORTS_DIR"

# Function to print status
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "PASS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "FAIL") 
            echo -e "${RED}❌ $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check if script exists and is executable
check_script() {
    local script=$1
    if [[ -f "$script" && -x "$script" ]]; then
        return 0
    else
        return 1
    fi
}

echo -e "${YELLOW}Phase 1: Project Structure Validation${NC}"
echo "----------------------------------------"

# Check basic project structure
if [[ -d "Faith Journal.xcodeproj" ]]; then
    print_status "PASS" "Xcode project file exists"
else
    print_status "FAIL" "Xcode project file missing"
    exit 1
fi

if [[ -d "Faith Journal" ]]; then
    print_status "PASS" "Main app folder exists"
else
    print_status "FAIL" "Main app folder missing"
    exit 1
fi

# Count Swift files
swift_count=$(find "Faith Journal" -name "*.swift" 2>/dev/null | wc -l)
print_status "INFO" "Found $swift_count Swift files"

# Check key folders
folders=("Views" "Models" "Components" "Services" "Utils")
for folder in "${folders[@]}"; do
    if [[ -d "Faith Journal/$folder" ]]; then
        file_count=$(find "Faith Journal/$folder" -name "*.swift" 2>/dev/null | wc -l)
        print_status "PASS" "$folder folder exists ($file_count files)"
    else
        print_status "WARN" "$folder folder missing"
    fi
done

echo ""
echo -e "${YELLOW}Phase 2: Xcode Project Validation${NC}"
echo "-----------------------------------"

# Run Xcode project validator if available
if check_script "./xcode_project_validator.py"; then
    print_status "INFO" "Running Xcode project validator with 12 workers..."
    if python3 "./xcode_project_validator.py" "$PROJECT_DIR" > "$REPORTS_DIR/xcode_validation.log" 2>&1; then
        print_status "PASS" "Xcode validation completed"
        
        # Check if build was successful
        if grep -q '"build_success": true' "$PROJECT_DIR/xcode_validation_report.json" 2>/dev/null; then
            print_status "PASS" "Project builds successfully"
        else
            print_status "FAIL" "Project has build issues"
        fi
    else
        print_status "FAIL" "Xcode validation failed"
    fi
else
    print_status "WARN" "Xcode project validator not found"
    
    # Fall back to basic xcodebuild test
    print_status "INFO" "Running basic build test..."
    if xcodebuild -project "Faith Journal.xcodeproj" -list > /dev/null 2>&1; then
        print_status "PASS" "Project file is readable by Xcode"
    else
        print_status "FAIL" "Project file has issues"
    fi
fi

echo ""
echo -e "${YELLOW}Phase 3: Enhanced Code Analysis${NC}"
echo "-------------------------------"

# Run enhanced assistant if available
if check_script "./enhanced_faith_journal_assistant.py"; then
    print_status "INFO" "Running enhanced assistant with 12 workers..."
    if python3 "./enhanced_faith_journal_assistant.py" "$PROJECT_DIR" > "$REPORTS_DIR/enhanced_analysis.log" 2>&1; then
        print_status "PASS" "Enhanced analysis completed"
        
        # Extract key metrics from report
        if [[ -f "$PROJECT_DIR/enhanced_analysis_report.json" ]]; then
            fixes_applied=$(grep -o '"fixes_applied": [0-9]*' "$PROJECT_DIR/enhanced_analysis_report.json" | cut -d' ' -f2 || echo "0")
            files_processed=$(grep -o '"files_processed": [0-9]*' "$PROJECT_DIR/enhanced_analysis_report.json" | cut -d' ' -f2 || echo "0")
            
            print_status "INFO" "Processed $files_processed files, applied $fixes_applied fixes"
            
            if [[ $fixes_applied -gt 0 ]]; then
                print_status "PASS" "Applied $fixes_applied automated fixes"
            fi
        fi
    else
        print_status "FAIL" "Enhanced analysis failed"
    fi
else
    print_status "WARN" "Enhanced assistant not found"
fi

echo ""
echo -e "${YELLOW}Phase 4: Existing Tools Check${NC}"
echo "-----------------------------"

# Check existing helper scripts
scripts=("parallel_faith_journal_fixer.py" "parallel_faith_journal_validator.py" "auto_fix_faith_journal.py")
for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        print_status "PASS" "$script exists"
    else
        print_status "WARN" "$script not found"
    fi
done

echo ""
echo -e "${YELLOW}Phase 5: App-Specific Checks${NC}"
echo "----------------------------"

# Check for AudioRecordingView since it was mentioned
if [[ -f "Faith Journal/Views/AudioRecordingView.swift" ]]; then
    print_status "PASS" "AudioRecordingView.swift exists"
    
    # Check for AVFoundation import
    if grep -q "import AVFoundation" "Faith Journal/Views/AudioRecordingView.swift"; then
        print_status "PASS" "AVFoundation properly imported"
    else
        print_status "WARN" "AVFoundation import missing"
    fi
else
    print_status "WARN" "AudioRecordingView.swift not found"
fi

# Check Info.plist for microphone permissions
if [[ -f "Faith Journal/Info.plist" ]]; then
    if grep -q "NSMicrophoneUsageDescription" "Faith Journal/Info.plist"; then
        print_status "PASS" "Microphone permission properly configured"
    else
        print_status "WARN" "Microphone permission not configured"
    fi
fi

# Check for app icons
if [[ -d "Faith Journal/Assets.xcassets/AppIcon.appiconset" ]]; then
    icon_count=$(find "Faith Journal/Assets.xcassets/AppIcon.appiconset" -name "*.png" 2>/dev/null | wc -l)
    if [[ $icon_count -gt 0 ]]; then
        print_status "PASS" "App icons present ($icon_count icons)"
    else
        print_status "WARN" "App icon assets missing"
    fi
else
    print_status "WARN" "App icon set not found"
fi

echo ""
echo -e "${YELLOW}Phase 6: Summary and Recommendations${NC}"
echo "-----------------------------------"

# Generate summary
total_reports=0
successful_reports=0

for report in "xcode_validation_report.json" "enhanced_analysis_report.json"; do
    if [[ -f "$PROJECT_DIR/$report" ]]; then
        total_reports=$((total_reports + 1))
        # Assume successful if file exists (detailed status checked above)
        successful_reports=$((successful_reports + 1))
    fi
done

print_status "INFO" "Generated $successful_reports/$total_reports validation reports"

# Check if project is ready for development
if [[ -f "$PROJECT_DIR/enhanced_analysis_report.json" ]] && grep -q '"structure_valid": true' "$PROJECT_DIR/enhanced_analysis_report.json" 2>/dev/null; then
    print_status "PASS" "Project structure is valid"
    print_status "PASS" "Project appears ready for development"
else
    print_status "WARN" "Project may need structure fixes"
fi

echo ""
echo -e "${GREEN}Health Check Complete!${NC}"
echo ""
echo "📊 Reports generated in: $REPORTS_DIR/"
echo "📋 Detailed reports available:"

for report in "$PROJECT_DIR"/*_report.json; do
    if [[ -f "$report" ]]; then
        echo "   - $(basename "$report")"
    fi
done

echo ""
echo "🛠️  Available worker scripts (12 workers each):"
echo "   - ./enhanced_faith_journal_assistant.py"
echo "   - ./xcode_project_validator.py"
echo ""

# Generate quick access commands
echo "🚀 Quick commands:"
echo "   Full analysis:     ./enhanced_faith_journal_assistant.py"
echo "   Xcode validation:  ./xcode_project_validator.py"
echo "   Health check:      ./faith_journal_health_check.sh"
echo ""

# Final recommendation
if command -v open >/dev/null 2>&1; then
    echo "💡 To open project in Xcode: open 'Faith Journal.xcodeproj'"
fi

echo -e "${BLUE}======================================================================${NC}" 