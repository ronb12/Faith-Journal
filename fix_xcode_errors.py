#!/usr/bin/env python3
"""
Faith Journal - Xcode Error Auto-Fix Script
Automatically fixes common Xcode compilation errors for Swift projects.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

class XcodeErrorFixer:
    def __init__(self, project_path):
        self.project_path = Path(project_path)
        self.fixed_count = 0
        self.errors_found = []
        
    def run_xcodebuild(self):
        """Run xcodebuild to get compilation errors."""
        try:
            cmd = ['xcodebuild', '-project', f'{self.project_path}/Faith Journal.xcodeproj', 
                   '-scheme', 'Faith Journal', '-destination', 'platform=iOS Simulator,name=iPhone 15']
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.project_path)
            return result.stdout + result.stderr
        except Exception as e:
            print(f"Error running xcodebuild: {e}")
            return ""
    
    def fix_missing_imports(self, file_path, content):
        """Fix missing import statements."""
        fixed = False
        lines = content.split('\n')
        
        # Common imports needed
        import_fixes = {
            'SwiftUI': ['View', 'State', 'Binding', 'NavigationView', 'List', 'VStack', 'HStack'],
            'SwiftData': ['Model', 'Query', 'Environment', 'ModelContext'],
            'Foundation': ['Date', 'UUID', 'Data', 'URL'],
            'Charts': ['Chart', 'BarMark', 'SectorMark'],
            'UserNotifications': ['UNUserNotificationCenter', 'UNNotificationRequest'],
            'LocalAuthentication': ['LAContext'],
            'AVFoundation': ['AVAudioRecorder', 'AVAudioPlayer'],
            'PencilKit': ['PKCanvasView', 'PKDrawing', 'PKToolPicker']
        }
        
        # Check if imports are needed
        imports_to_add = set()
        for import_name, symbols in import_fixes.items():
            if any(symbol in content for symbol in symbols):
                if f'import {import_name}' not in content:
                    imports_to_add.add(import_name)
        
        if imports_to_add:
            # Find where to insert imports
            insert_index = 0
            for i, line in enumerate(lines):
                if line.strip().startswith('import '):
                    insert_index = i + 1
                elif line.strip() and not line.strip().startswith('//'):
                    break
            
            # Insert missing imports
            for import_name in sorted(imports_to_add):
                lines.insert(insert_index, f'import {import_name}')
                insert_index += 1
                fixed = True
                print(f"Added missing import: {import_name}")
        
        return '\n'.join(lines) if fixed else content, fixed
    
    def fix_variable_naming(self, content):
        """Fix common variable naming issues."""
        fixes = [
            # Fix @AppStorage property wrapper syntax
            (r'@AppStorage\(([^)]+)\)\s+var\s+(\w+)\s*=\s*([^;\n]+)', 
             r'@AppStorage(\1) private var \2 = \3'),
            
            # Fix @State property wrapper syntax
            (r'@State\s+var\s+(\w+)', r'@State private var \1'),
            
            # Fix @Query syntax
            (r'@Query\s+var\s+(\w+)', r'@Query private var \1'),
            
            # Fix environment property wrapper
            (r'@Environment\(\\\.(\w+)\)\s+var\s+(\w+)', r'@Environment(\.\1) private var \2'),
        ]
        
        fixed = False
        for pattern, replacement in fixes:
            new_content = re.sub(pattern, replacement, content)
            if new_content != content:
                fixed = True
                content = new_content
        
        return content, fixed
    
    def fix_syntax_errors(self, content):
        """Fix common Swift syntax errors."""
        fixes = [
            # Fix trailing commas in function parameters
            (r',\s*\)', r')'),
            
            # Fix double semicolons
            (r';;', r';'),
            
            # Fix missing self keyword where needed
            (r'(\w+)\.modelContext', r'self.\1.modelContext'),
            
            # Fix incorrect NavigationView usage
            (r'NavigationView\s*\{', r'NavigationStack {'),
            
            # Fix List syntax
            (r'List\s*\{(\s*ForEach)', r'List {\1'),
            
            # Fix button syntax
            (r'Button\(action:\s*([^,]+),\s*label:', r'Button(action: \1) {'),
            
            # Fix sheet presentation
            (r'\.sheet\(isPresented:\s*([^,]+),\s*content:', r'.sheet(isPresented: \1) {'),
        ]
        
        fixed = False
        for pattern, replacement in fixes:
            new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if new_content != content:
                fixed = True
                content = new_content
        
        return content, fixed
    
    def fix_swiftui_issues(self, content):
        """Fix SwiftUI-specific issues."""
        fixes = [
            # Fix Color usage
            (r'Color\(\.(\w+)\)', r'Color.\1'),
            
            # Fix Image system name
            (r'Image\(systemName:\s*"([^"]+)"\)', r'Image(systemName: "\1")'),
            
            # Fix font usage
            (r'\.font\(\.(\w+)\)', r'.font(.\1)'),
            
            # Fix padding usage
            (r'\.padding\((\d+)\)', r'.padding(\1)'),
            
            # Fix frame usage
            (r'\.frame\(width:\s*(\d+),\s*height:\s*(\d+)\)', r'.frame(width: \1, height: \2)'),
        ]
        
        fixed = False
        for pattern, replacement in fixes:
            new_content = re.sub(pattern, replacement, content)
            if new_content != content:
                fixed = True
                content = new_content
        
        return content, fixed
    
    def fix_model_issues(self, content):
        """Fix SwiftData model issues."""
        fixes = [
            # Ensure @Model classes are properly marked
            (r'class\s+(\w+)\s*\{', r'@Model\nfinal class \1 {'),
            
            # Fix model property syntax
            (r'var\s+(\w+):\s*([^=\n]+)\s*=', r'var \1: \2 ='),
            
            # Fix Query syntax
            (r'@Query\s*var\s+(\w+):\s*\[([^\]]+)\]', r'@Query private var \1: [\2]'),
        ]
        
        fixed = False
        for pattern, replacement in fixes:
            new_content = re.sub(pattern, replacement, content)
            if new_content != content:
                fixed = True
                content = new_content
        
        return content, fixed
    
    def fix_file(self, file_path):
        """Fix a single Swift file."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            file_fixed = False
            
            # Apply all fixes
            content, fixed = self.fix_missing_imports(file_path, content)
            file_fixed = file_fixed or fixed
            
            content, fixed = self.fix_variable_naming(content)
            file_fixed = file_fixed or fixed
            
            content, fixed = self.fix_syntax_errors(content)
            file_fixed = file_fixed or fixed
            
            content, fixed = self.fix_swiftui_issues(content)
            file_fixed = file_fixed or fixed
            
            content, fixed = self.fix_model_issues(content)
            file_fixed = file_fixed or fixed
            
            # Write back if changes were made
            if file_fixed and content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                self.fixed_count += 1
                print(f"Fixed: {file_path}")
                return True
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
        
        return False
    
    def fix_all_swift_files(self):
        """Fix all Swift files in the project."""
        swift_files = list(self.project_path.rglob("*.swift"))
        
        for file_path in swift_files:
            # Skip certain directories
            if any(skip in str(file_path) for skip in ['.build', 'DerivedData', '.git']):
                continue
            
            self.fix_file(file_path)
    
    def create_missing_files(self):
        """Create any missing files that are referenced but don't exist."""
        missing_files = [
            # Create Info.plist if missing
            {
                'path': self.project_path / 'Faith Journal' / 'Info.plist',
                'content': '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
    </dict>
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>'''
            }
        ]
        
        for file_info in missing_files:
            file_path = file_info['path']
            if not file_path.exists():
                file_path.parent.mkdir(parents=True, exist_ok=True)
                with open(file_path, 'w') as f:
                    f.write(file_info['content'])
                print(f"Created missing file: {file_path}")
    
    def run_diagnostics(self):
        """Run build diagnostics and show results."""
        print("Running Xcode build diagnostics...")
        build_output = self.run_xcodebuild()
        
        # Parse errors from build output
        error_patterns = [
            r"error:\s+(.+)",
            r"warning:\s+(.+)",
            r"note:\s+(.+)"
        ]
        
        for pattern in error_patterns:
            errors = re.findall(pattern, build_output, re.MULTILINE)
            self.errors_found.extend(errors)
        
        if self.errors_found:
            print(f"Found {len(self.errors_found)} issues:")
            for i, error in enumerate(self.errors_found[:10], 1):  # Show first 10
                print(f"  {i}. {error}")
            if len(self.errors_found) > 10:
                print(f"  ... and {len(self.errors_found) - 10} more")
        else:
            print("No build errors found!")
    
    def run(self):
        """Run the complete fix process."""
        print(f"Starting Xcode error fixing for: {self.project_path}")
        
        # Create missing files first
        self.create_missing_files()
        
        # Fix all Swift files
        self.fix_all_swift_files()
        
        # Run diagnostics
        self.run_diagnostics()
        
        print(f"\nCompleted! Fixed {self.fixed_count} files.")
        
        if self.errors_found:
            print("\nRemaining issues may require manual attention.")
            print("Common manual fixes needed:")
            print("1. Add missing framework dependencies in project settings")
            print("2. Update deployment target if using newer iOS features")
            print("3. Check code signing and provisioning profiles")
            print("4. Verify all asset references exist")
        else:
            print("No errors found - project should build successfully!")

def main():
    if len(sys.argv) > 1:
        project_path = sys.argv[1]
    else:
        project_path = "."
    
    fixer = XcodeErrorFixer(project_path)
    fixer.run()

if __name__ == "__main__":
    main() 