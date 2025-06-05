#!/usr/bin/env python3
"""
Fix Invalid Resource Reference in Xcode Project
Remove the problematic Faith Journal.xcodeproj resource reference
"""

import os
import re

def fix_resource_reference():
    """Remove the invalid Faith Journal.xcodeproj resource reference"""
    
    project_path = "Faith Journal.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_path):
        print("❌ Error: project.pbxproj not found")
        return False
    
    print("🔧 Removing invalid Faith Journal.xcodeproj resource reference...")
    
    # Read the project file
    with open(project_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create backup
    backup_path = project_path + '.backup3'
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"📦 Backup created: {backup_path}")
    
    original_content = content
    
    # Remove the specific problematic resource references
    problematic_entries = [
        '730FF2C46029B89DF88C5636 /* Faith Journal.xcodeproj in Resources */',
        '672A9D46C2F018ADE6E613FB /* Faith Journal.xcodeproj */'
    ]
    
    for entry in problematic_entries:
        # Remove the build file reference
        pattern = r'\s*' + re.escape(entry) + r',?\s*\n'
        content = re.sub(pattern, '', content)
        print(f"✅ Removed resource reference: {entry.split('/*')[1].split('*/')[0].strip()}")
    
    # Also remove the file reference entry
    file_ref_pattern = r'[A-F0-9]{24} /\* Faith Journal\.xcodeproj \*/ = \{isa = PBXFileReference[^}]+\};'
    content = re.sub(file_ref_pattern, '', content)
    print("✅ Removed PBXFileReference for Faith Journal.xcodeproj")
    
    # Clean up any orphaned entries
    content = re.sub(r',(\s*\);)', r'\1', content)
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    if content != original_content:
        # Write the fixed content
        with open(project_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("✅ Successfully removed invalid resource reference")
        return True
    else:
        print("ℹ️  No changes needed")
        return False

def main():
    print("=" * 60)
    print("Faith Journal Resource Reference Fixer")
    print("=" * 60)
    
    if fix_resource_reference():
        print("\n🎉 SUCCESS: Fixed invalid resource reference!")
        print("The build should now complete without the 'No such file' error.")
        print("\nTest with:")
        print("xcodebuild -project \"Faith Journal.xcodeproj\" -scheme \"Faith Journal\" build")
    else:
        print("\n⚠️  No changes made")

if __name__ == "__main__":
    main() 