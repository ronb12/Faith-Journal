#!/usr/bin/env python3
"""
Fix Xcode Project File References
Removes invalid test file references from the main app target
"""

import os
import sys
import subprocess
import re

def fix_xcode_project():
    """Fix the Xcode project file by removing invalid test file references"""
    
    project_path = "Faith Journal.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_path):
        print("Error: project.pbxproj not found")
        return False
    
    print("🔧 Fixing Xcode project file references...")
    
    # Read the project file
    with open(project_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Remove references to the misplaced test files
    invalid_files = [
        'Faith Journal/Utils/Faith JournalTests/Faith_JournalTests.swift',
        'Faith Journal/Utils/Faith JournalUITests/Faith_JournalUITests.swift', 
        'Faith Journal/Utils/Faith JournalUITests/Faith_JournalUITestsLaunchTests.swift'
    ]
    
    files_removed = 0
    
    for invalid_file in invalid_files:
        # Remove file references
        file_ref_pattern = r'[A-F0-9]{24} /\* [^/]+ \*/ = \{isa = PBXFileReference[^}]+path = "' + re.escape(invalid_file) + r'"[^}]+\};'
        content = re.sub(file_ref_pattern, '', content)
        
        # Remove from build file references
        build_file_pattern = r'[A-F0-9]{24} /\* [^/]+ in Sources \*/ = \{isa = PBXBuildFile[^}]+fileRef = [A-F0-9]{24}[^}]+\};'
        content = re.sub(build_file_pattern, '', content)
        
        # Remove from file lists
        content = re.sub(r'[A-F0-9]{24} /\* [^/]*' + re.escape(os.path.basename(invalid_file)) + r'[^,]*\*/,?\s*', '', content)
        
        if invalid_file in original_content:
            files_removed += 1
            print(f"✅ Removed reference to {os.path.basename(invalid_file)}")
    
    # Clean up any orphaned entries
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)  # Remove extra blank lines
    content = re.sub(r',\s*,', ',', content)  # Remove double commas
    content = re.sub(r',(\s*\))', r'\1', content)  # Remove trailing commas before closing parens
    
    if content != original_content:
        # Backup original
        backup_path = project_path + '.backup'
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(original_content)
        print(f"📦 Backup created: {backup_path}")
        
        # Write fixed content
        with open(project_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Fixed {files_removed} file references in project.pbxproj")
        return True
    else:
        print("ℹ️  No changes needed to project file")
        return True

def clean_build_artifacts():
    """Clean build artifacts to force a fresh build"""
    print("🧹 Cleaning build artifacts...")
    
    # Remove build folder
    if os.path.exists("build"):
        subprocess.run(["rm", "-rf", "build"], check=False)
        print("✅ Removed local build folder")
    
    # Clean Xcode derived data for this project
    derived_data_pattern = os.path.expanduser("~/Library/Developer/Xcode/DerivedData/Faith_Journal-*")
    subprocess.run(f"rm -rf {derived_data_pattern}", shell=True, check=False)
    print("✅ Cleaned Xcode derived data")

def test_build():
    """Test if the project builds correctly"""
    print("🔨 Testing build...")
    
    try:
        result = subprocess.run([
            "xcodebuild", "-project", "Faith Journal.xcodeproj",
            "-target", "Faith Journal", "-configuration", "Debug",
            "-arch", "x86_64", "-sdk", "iphonesimulator",
            "build", "CODE_SIGN_IDENTITY=", "CODE_SIGNING_REQUIRED=NO"
        ], capture_output=True, text=True, timeout=120)
        
        if result.returncode == 0:
            print("✅ Build test PASSED")
            return True
        else:
            print("❌ Build test FAILED")
            if "Build input files cannot be found" in result.stderr:
                print("⚠️  Still have missing file references")
            print(f"Error: {result.stderr[:200]}...")
            return False
            
    except subprocess.TimeoutExpired:
        print("⏱️  Build test timed out")
        return False
    except Exception as e:
        print(f"❌ Build test error: {e}")
        return False

def main():
    print("=" * 60)
    print("Faith Journal Xcode Project Fixer")
    print("=" * 60)
    
    # Check if we're in the right directory
    if not os.path.exists("Faith Journal.xcodeproj"):
        print("❌ Error: Must run from Faith Journal project root directory")
        return 1
    
    # Step 1: Fix project file
    if not fix_xcode_project():
        print("❌ Failed to fix project file")
        return 1
    
    # Step 2: Clean build artifacts
    clean_build_artifacts()
    
    # Step 3: Test build
    if test_build():
        print("\n🎉 SUCCESS: Project is now building correctly!")
        print("\n📋 Summary:")
        print("   • Fixed invalid test file references")
        print("   • Cleaned build artifacts")
        print("   • Verified successful build")
        print("\n💡 You can now:")
        print("   • Open the project in Xcode")
        print("   • Run builds successfully")
        print("   • Continue development")
    else:
        print("\n⚠️  WARNING: Build still has issues")
        print("   • Project file was fixed")
        print("   • But build test failed")
        print("   • Manual investigation may be needed")
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 