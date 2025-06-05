#!/usr/bin/env python3
"""
Fix Xcode Project Test File References
Remove test files from main app target build phase
"""

import os
import re

def fix_main_target_sources():
    """Remove test files from the main app target's Sources build phase"""
    
    project_path = "Faith Journal.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_path):
        print("❌ Error: project.pbxproj not found")
        return False
    
    print("🔧 Removing test files from main app target...")
    
    # Read the project file
    with open(project_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create backup
    backup_path = project_path + '.backup2'
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"📦 Backup created: {backup_path}")
    
    # Remove the specific test file entries from the main target's Sources build phase
    test_files_to_remove = [
        'D1CB403F0174B11011B69B6F /* Faith_JournalTests.swift in Sources */',
        'DC39491AB914B5A4266B74E7 /* Faith_JournalUITests.swift in Sources */',
        'F9B3BD5529ADCD03D1DB5984 /* Faith_JournalUITestsLaunchTests.swift in Sources */'
    ]
    
    original_content = content
    
    for test_file_line in test_files_to_remove:
        # Remove the line completely
        pattern = r'\s*' + re.escape(test_file_line) + r',?\s*\n'
        content = re.sub(pattern, '', content)
        print(f"✅ Removed: {test_file_line.split('/*')[1].split('*/')[0].strip()}")
    
    # Clean up any orphaned commas
    content = re.sub(r',(\s*\);)', r'\1', content)
    
    if content != original_content:
        # Write the fixed content
        with open(project_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("✅ Successfully removed test files from main target")
        return True
    else:
        print("ℹ️  No changes needed")
        return False

def main():
    print("=" * 50)
    print("Faith Journal Project Reference Fixer")
    print("=" * 50)
    
    if fix_main_target_sources():
        print("\n🎉 SUCCESS: Fixed project references!")
        print("Now try building again with:")
        print("xcodebuild -project \"Faith Journal.xcodeproj\" -scheme \"Faith Journal\" -configuration Debug build")
    else:
        print("\n⚠️  No changes made")

if __name__ == "__main__":
    main() 