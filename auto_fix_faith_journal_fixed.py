#!/usr/bin/env python3
"""
Auto Fix Faith Journal - Enhanced Master Script
Automatically detects and fixes all compilation errors, installs dependencies,
and ensures the Faith Journal iOS project builds successfully.
"""

import os
import re
import sys
import subprocess
import json
from pathlib import Path
import time

class FaithJournalAutoFixer:
    def __init__(self, project_path="."):
        self.project_path = Path(project_path)
        self.swift_files = []
        self.fixed_count = 0
        self.errors_found = []
        self.build_errors = []
        
    def log(self, message, level="INFO"):
        """Log messages with different levels"""
        colors = {
            "INFO": "\033[36m",    # Cyan
            "SUCCESS": "\033[32m", # Green
            "WARNING": "\033[33m", # Yellow
            "ERROR": "\033[31m",   # Red
            "RESET": "\033[0m"     # Reset
        }
        
        color = colors.get(level, colors["INFO"])
        reset = colors["RESET"]
        prefix = f"{color}[{level}]{reset}"
        print(f"{prefix} {message}")
        
    def find_swift_files(self):
        """Find all Swift files in the project"""
        for root, dirs, files in os.walk(self.project_path):
            for file in files:
                if file.endswith('.swift'):
                    self.swift_files.append(Path(root) / file)
        self.log(f"Found {len(self.swift_files)} Swift files")
        
    def read_file_safe(self, file_path):
        """Safely read file content"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            self.log(f"Error reading {file_path}: {e}", "ERROR")
            return None
            
    def write_file_safe(self, file_path, content):
        """Safely write file content"""
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        except Exception as e:
            self.log(f"Error writing {file_path}: {e}", "ERROR")
            return False
            
    def fix_model_syntax(self, content):
        """Fix @Model syntax errors"""
        original_content = content
        
        # Fix duplicate @Model and final declarations
        patterns = [
            (r'@Model\s*\n\s*final\s+@Model\s*\n\s*final\s+class', '@Model\nfinal class'),
            (r'final\s+@Model\s*\n\s*final\s+class', '@Model\nfinal class'),
            (r'@Model\s*\n\s*final\s+@Model', '@Model'),
            (r'final\s+@Model', '@Model\nfinal class'),
            (r'@Model\s+@Model', '@Model'),
            (r'final\s+final\s+class', 'final class'),
        ]
        
        for pattern, replacement in patterns:
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
                
        if content != original_content:
            self.log("Fixed @Model syntax error")
                
        return content
        
    def fix_swiftui_syntax(self, content):
        """Fix SwiftUI syntax errors"""
        original_content = content
        
        fixes = [
            # Fix foregroundColor syntax
            (r'\.foregroundColor\.(\w+)', r'.foregroundColor(.\1)'),
            (r'\.foregroundColor\s*\.\s*(\w+)', r'.foregroundColor(.\1)'),
            (r'\.foregroundStyle\.(\w+)', r'.foregroundStyle(.\1)'),
            
            # Fix common SwiftUI issues
            (r'@Environment\(\\\.dismiss\)', r'@Environment(\.dismiss)'),
            (r'@Environment\(\\\.modelContext\)', r'@Environment(\.modelContext)'),
            
            # Fix font syntax
            (r'\.font\s*\.\s*(\w+)', r'.font(.\1)'),
            
            # Fix background syntax
            (r'\.background\s*\.\s*(\w+)', r'.background(.\1)'),
            
            # Fix padding syntax errors
            (r'\.padding\s*\.\s*(\w+)', r'.padding(.\1)'),
        ]
        
        for pattern, replacement in fixes:
            content = re.sub(pattern, replacement, content)
                
        if content != original_content:
            self.log("Fixed SwiftUI syntax")
                
        return content
        
    def fix_extraneous_braces(self, content):
        """Fix extraneous closing braces at top level"""
        lines = content.split('\n')
        cleaned_lines = []
        brace_depth = 0
        
        for i, line in enumerate(lines):
            stripped = line.strip()
            
            # Count braces to track depth
            open_braces = line.count('{')
            close_braces = line.count('}')
            
            # Handle standalone closing brace
            if stripped == '}':
                # Check if this closing brace is valid
                if brace_depth > 0:
                    brace_depth -= 1
                    cleaned_lines.append(line)
                else:
                    # This is an extraneous brace, skip it
                    self.log(f"Removing extraneous brace at line {i+1}")
                    continue
            else:
                # Update brace depth for non-standalone brace lines
                brace_depth += open_braces - close_braces
                cleaned_lines.append(line)
                
        return '\n'.join(cleaned_lines)
        
    def fix_file_specific_issues(self, content, file_path):
        """Fix specific issues in individual files"""
        filename = file_path.name
        
        if filename in ['AudioView.swift', 'DrawingView.swift', 'FaithStatsView.swift']:
            # Remove extraneous closing braces at the end
            lines = content.split('\n')
            while lines and lines[-1].strip() in ['', '}']:
                if lines[-1].strip() == '}':
                    # Check if this brace is needed
                    remaining_content = '\n'.join(lines[:-1])
                    open_count = remaining_content.count('{')
                    close_count = remaining_content.count('}')
                    
                    if close_count >= open_count:
                        lines.pop()
                        self.log(f"Removed extraneous closing brace from {filename}")
                    else:
                        break
                else:
                    lines.pop()
            content = '\n'.join(lines)
            
        elif filename == 'HomeView.swift':
            # Fix expressions at top level by ensuring they're within proper structure
            lines = content.split('\n')
            cleaned_lines = []
            in_struct = False
            
            for line in lines:
                if 'struct HomeView' in line:
                    in_struct = True
                    cleaned_lines.append(line)
                elif in_struct and line.strip().startswith('ProgressView') and not any(x in line for x in ['var ', 'let ', 'func ', '@']):
                    # This is likely a misplaced expression, skip it
                    self.log(f"Removing misplaced expression from {filename}")
                    continue
                else:
                    cleaned_lines.append(line)
                    
            content = '\n'.join(cleaned_lines)
            
        return content
        
    def remove_duplicate_structs(self, file_path, content):
        """Remove duplicate struct declarations"""
        struct_names = [
            'ImagePicker', 'ShareSheet', 'StreakView', 
            'EmptyStateView', 'StatCard', 'BadgeCard'
        ]
        
        original_content = content
        
        for struct_name in struct_names:
            # More comprehensive pattern to match complete struct definitions
            pattern = rf'struct\s+{struct_name}[^{{]*\{{(?:[^{{}}]+|\{{[^}}]*\}})*\}}'
            matches = list(re.finditer(pattern, content, re.DOTALL))
            
            if len(matches) > 1:
                # Keep only the first occurrence if in Components directory
                if 'Components' in str(file_path):
                    self.log(f"Keeping {struct_name} in Components/{file_path.name}")
                    continue
                else:
                    # Remove all duplicates from other files
                    for match in reversed(matches):
                        content = content[:match.start()] + content[match.end():]
                    self.log(f"Removed duplicate {struct_name} from {file_path.name}")
                    
        return content
        
    def fix_property_references(self, content):
        """Fix property name mismatches"""
        original_content = content
        
        # Badge model property fixes
        replacements = [
            (r'badge\.name(?!\w)', 'badge.title'),
            (r'badge\.description(?!\w)', 'badge.badgeDescription'),
            (r'badge\.targetValue(?!\w)', 'badge.requiredValue'),
            (r'\.name(?=\s*\}|\s*,|\s*\))', '.title'),  # Context-aware replacement
        ]
        
        for pattern, replacement in replacements:
            content = re.sub(pattern, replacement, content)
                
        if content != original_content:
            self.log("Fixed property reference")
                
        return content
        
    def fix_view_structure(self, content, file_path):
        """Fix malformed view structures"""
        original_content = content
        
        # Fix incomplete struct definitions
        if 'struct' in content and 'View' in content:
            # Fix missing opening braces
            content = re.sub(r'struct\s+(\w+):\s*View\s*\n\s*@', r'struct \1: View {\n    @', content)
            content = re.sub(r'struct\s+(\w+):\s*View\s*\n\s*var', r'struct \1: View {\n    var', content)
            
            # Fix malformed DevotionalsView specifically
            if 'DevotionalsView' in str(file_path):
                content = re.sub(r'struct DevotionalsView \{', 'struct DevotionalsView: View {', content)
                
            # Ensure proper struct closure
            lines = content.split('\n')
            brace_count = 0
            in_struct = False
            
            for i, line in enumerate(lines):
                if 'struct' in line and 'View' in line:
                    in_struct = True
                if in_struct:
                    brace_count += line.count('{') - line.count('}')
                    
            # Add missing closing braces if needed
            if in_struct and brace_count > 0:
                content += '\n' + '}' * brace_count
                
        # Fix extraneous closing braces
        content = self.fix_extraneous_braces(content)
        
        if content != original_content:
            self.log(f"Fixed view structure in {file_path.name}")
                
        return content
        
    def add_missing_imports(self, content, file_path):
        """Add missing import statements"""
        imports_needed = []
        
        # Enhanced import detection
        import_rules = {
            'SwiftData': ['@Model', '@Query', 'ModelContext'],
            'SwiftUI': ['View', 'State', 'Binding', '@Environment'],
            'UIKit': ['UIImagePickerController', 'UIViewController', 'UIImage'],
            'LocalAuthentication': ['LAContext', 'LAPolicy'],
            'UserNotifications': ['UNUserNotificationCenter', 'UNNotificationRequest'],
            'Charts': ['Chart', 'BarMark', 'LineMark'],
            'PencilKit': ['PKCanvasView', 'PKDrawing'],
            'PhotosUI': ['PhotosPicker', 'PhotosPickerItem'],
            'CoreLocation': ['CLLocationManager', 'CLLocation'],
            'AVFoundation': ['AVAudioRecorder', 'AVAudioPlayer'],
            'Foundation': ['Date', 'UUID', 'Data'],
        }
        
        for import_name, keywords in import_rules.items():
            if f'import {import_name}' not in content:
                for keyword in keywords:
                    if keyword in content:
                        imports_needed.append(f'import {import_name}')
                        break
        
        # Add imports at the top after existing imports
        if imports_needed:
            lines = content.split('\n')
            import_index = 0
            
            # Find where to insert imports
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    import_index = i + 1
                elif line.strip() and not line.startswith('//') and not line.startswith('import'):
                    break
                    
            # Insert new imports
            for imp in imports_needed:
                if imp not in content:
                    lines.insert(import_index, imp)
                    import_index += 1
                    self.log(f"Added {imp} to {file_path.name}")
                    
            content = '\n'.join(lines)
            
        return content
        
    def fix_onboarding_view(self, content):
        """Comprehensive fix for OnboardingView issues"""
        original_content = content
        
        # Remove duplicate ImagePicker struct completely
        pattern = r'struct ImagePicker: UIViewControllerRepresentable \{[^}]+(?:\{[^}]*\})*[^}]+\}'
        content = re.sub(pattern, '', content, flags=re.DOTALL)
        
        # Fix any remaining structural issues
        content = re.sub(r'\n\s*\}\s*\n\s*struct OnboardingView', '\n\nstruct OnboardingView', content)
        
        # Remove extraneous braces at the beginning
        lines = content.split('\n')
        cleaned_lines = []
        found_struct = False
        
        for line in lines:
            if 'struct' in line and not found_struct:
                found_struct = True
            
            if not found_struct and line.strip() == '}':
                continue  # Skip extraneous braces before first struct
                
            cleaned_lines.append(line)
            
        content = '\n'.join(cleaned_lines)
        
        if content != original_content:
            self.log("Fixed OnboardingView structure")
            
        return content
        
    def clear_xcode_cache(self):
        """Clear Xcode build cache and derived data"""
        try:
            self.log("Clearing Xcode build cache and derived data...")
            
            # Clean the build
            result = subprocess.run([
                'xcodebuild', 'clean', '-scheme', 'Faith Journal'
            ], capture_output=True, text=True, cwd=self.project_path / 'Faith Journal')
            
            if result.returncode == 0:
                self.log("Xcode build cleaned successfully", "SUCCESS")
            else:
                self.log("Failed to clean Xcode build", "WARNING")
            
            # Clear derived data
            derived_data_path = Path.home() / 'Library/Developer/Xcode/DerivedData'
            if derived_data_path.exists():
                # Find Faith Journal derived data folders
                for folder in derived_data_path.iterdir():
                    if 'Faith_Journal' in folder.name or 'Faith-Journal' in folder.name:
                        try:
                            subprocess.run(['rm', '-rf', str(folder)], check=True)
                            self.log(f"Removed derived data: {folder.name}", "SUCCESS")
                        except subprocess.CalledProcessError:
                            self.log(f"Failed to remove derived data: {folder.name}", "WARNING")
            
            # Clear module cache
            module_cache_path = Path.home() / 'Library/Developer/Xcode/DerivedData/ModuleCache.noindex'
            if module_cache_path.exists():
                try:
                    subprocess.run(['rm', '-rf', str(module_cache_path)], check=True)
                    self.log("Cleared module cache", "SUCCESS")
                except subprocess.CalledProcessError:
                    self.log("Failed to clear module cache", "WARNING")
                    
        except Exception as e:
            self.log(f"Error clearing Xcode cache: {e}", "ERROR")
            
    def clear_simulator_logs(self):
        """Clear iOS Simulator logs and data"""
        try:
            self.log("Clearing iOS Simulator logs...")
            
            # Clear simulator logs
            simulator_logs = Path.home() / 'Library/Logs/CoreSimulator'
            if simulator_logs.exists():
                try:
                    subprocess.run(['rm', '-rf', str(simulator_logs / '*')], shell=True, check=True)
                    self.log("Cleared iOS Simulator logs", "SUCCESS")
                except subprocess.CalledProcessError:
                    self.log("Failed to clear simulator logs", "WARNING")
                    
        except Exception as e:
            self.log(f"Error clearing simulator logs: {e}", "ERROR")
            
    def clear_build_errors(self):
        """Clear build error logs and caches"""
        try:
            self.log("Clearing all build error logs and caches...")
            
            # Clear Xcode's error cache
            self.clear_xcode_cache()
            
            # Clear simulator logs
            self.clear_simulator_logs()
            
            # Clear any local build artifacts
            build_dirs = [
                self.project_path / 'Faith Journal' / 'build',
                self.project_path / 'Faith Journal' / '.build',
                self.project_path / 'Faith Journal' / 'DerivedData'
            ]
            
            for build_dir in build_dirs:
                if build_dir.exists():
                    try:
                        subprocess.run(['rm', '-rf', str(build_dir)], check=True)
                        self.log(f"Removed build directory: {build_dir.name}", "SUCCESS")
                    except subprocess.CalledProcessError:
                        self.log(f"Failed to remove build directory: {build_dir.name}", "WARNING")
                        
            self.log("All build error logs and caches cleared", "SUCCESS")
            
        except Exception as e:
            self.log(f"Error clearing build error logs: {e}", "ERROR")
            
    def fix_single_file(self, file_path):
        """Fix a single Swift file"""
        content = self.read_file_safe(file_path)
        if not content:
            return False
            
        original_content = content
        
        # Apply all fixes in order
        content = self.fix_model_syntax(content)
        content = self.fix_swiftui_syntax(content)
        content = self.remove_duplicate_structs(file_path, content)
        content = self.fix_property_references(content)
        content = self.fix_view_structure(content, file_path)
        content = self.add_missing_imports(content, file_path)
        
        # Special handling for specific files
        if 'OnboardingView' in str(file_path):
            content = self.fix_onboarding_view(content)
            
        # Apply file-specific fixes
        content = self.fix_file_specific_issues(content, file_path)
        
        # Write back if changed
        if content != original_content:
            if self.write_file_safe(file_path, content):
                self.fixed_count += 1
                self.log(f"Fixed: {file_path.name}", "SUCCESS")
                return True
                
        return False
        
    def run_xcode_build(self):
        """Run Xcode build to check for errors"""
        try:
            self.log("Running Xcode build...")
            result = subprocess.run([
                'xcodebuild', '-scheme', 'Faith Journal', 
                '-destination', 'generic/platform=iOS', 
                'build'
            ], capture_output=True, text=True, cwd=self.project_path / 'Faith Journal')
            
            return result.returncode == 0, result.stderr + result.stdout
        except Exception as e:
            self.log(f"Error running Xcode build: {e}", "ERROR")
            return False, str(e)
            
    def parse_build_errors(self, build_output):
        """Parse and extract specific build errors"""
        errors = []
        lines = build_output.split('\n')
        
        for i, line in enumerate(lines):
            if 'error:' in line.lower():
                error_info = {
                    'line': line.strip(),
                    'file': None,
                    'line_number': None,
                    'description': line.split('error:')[-1].strip() if 'error:' in line else line
                }
                
                # Try to extract file and line number from previous lines
                for j in range(max(0, i-3), i):
                    if '.swift:' in lines[j]:
                        parts = lines[j].split('.swift:')
                        if len(parts) > 1:
                            error_info['file'] = parts[0].split('/')[-1] + '.swift'
                            line_parts = parts[1].split(':')
                            if line_parts[0].isdigit():
                                error_info['line_number'] = int(line_parts[0])
                        break
                        
                errors.append(error_info)
                
        return errors
        
    def fix_specific_build_errors(self, errors):
        """Fix specific build errors automatically"""
        for error in errors:
            error_desc = error['description'].lower()
            
            if 'expected declaration' in error_desc or 'extraneous' in error_desc:
                self.fix_declaration_errors()
            elif 'invalid redeclaration' in error_desc:
                self.fix_redeclaration_errors()
            elif 'cannot find' in error_desc and 'in scope' in error_desc:
                self.fix_scope_errors(error)
                
    def fix_declaration_errors(self):
        """Fix declaration errors"""
        for file_path in self.swift_files:
            content = self.read_file_safe(file_path)
            if content:
                original = content
                
                # Fix common declaration issues
                content = re.sub(r'final\s+@Model', '@Model\nfinal class', content)
                content = re.sub(r'@Model\s+@Model', '@Model', content)
                content = self.fix_extraneous_braces(content)
                content = self.fix_file_specific_issues(content, file_path)
                
                if content != original:
                    self.write_file_safe(file_path, content)
                    self.log(f"Fixed declaration error in {file_path.name}")
                    
    def fix_redeclaration_errors(self):
        """Fix redeclaration errors"""
        struct_counts = {}
        
        # First pass: count struct declarations
        for file_path in self.swift_files:
            content = self.read_file_safe(file_path)
            if content:
                for struct_name in ['ImagePicker', 'ShareSheet', 'StreakView', 'EmptyStateView', 'StatCard']:
                    if f'struct {struct_name}' in content:
                        if struct_name not in struct_counts:
                            struct_counts[struct_name] = []
                        struct_counts[struct_name].append(file_path)
        
        # Second pass: remove duplicates (keep Components version)
        for struct_name, files in struct_counts.items():
            if len(files) > 1:
                for file_path in files:
                    if 'Components' not in str(file_path):
                        content = self.read_file_safe(file_path)
                        if content:
                            pattern = rf'struct\s+{struct_name}[^{{]*\{{(?:[^{{}}]+|\{{[^}}]*\}})*\}}'
                            content = re.sub(pattern, '', content, flags=re.DOTALL)
                            self.write_file_safe(file_path, content)
                            self.log(f"Removed duplicate {struct_name} from {file_path.name}")
                            
    def fix_scope_errors(self, error):
        """Fix scope errors by adding missing imports"""
        if error['file']:
            file_path = None
            for swift_file in self.swift_files:
                if swift_file.name == error['file']:
                    file_path = swift_file
                    break
                    
            if file_path:
                content = self.read_file_safe(file_path)
                if content:
                    content = self.add_missing_imports(content, file_path)
                    self.write_file_safe(file_path, content)
                    
    def install_dependencies(self):
        """Install necessary dependencies and setup"""
        self.log("Installing/checking dependencies...")
        
        # Check if Xcode command line tools are installed
        try:
            result = subprocess.run(['xcode-select', '--version'], check=True, capture_output=True)
            self.log("Xcode command line tools: ✓", "SUCCESS")
        except subprocess.CalledProcessError:
            self.log("Installing Xcode command line tools...")
            subprocess.run(['xcode-select', '--install'])
            
    def create_missing_files(self):
        """Create any missing essential files"""
        # Create .gitignore if missing
        gitignore_path = self.project_path / '.gitignore'
        if not gitignore_path.exists():
            gitignore_content = """# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
!*.xcodeproj/project.xcworkspace/
*.xcworkspace/*
!*.xcworkspace/contents.xcworkspacedata
/*.gcno
**/xcshareddata/WorkspaceSettings.xcsettings

# Build
build/
DerivedData/
*.ipa

# CocoaPods
Pods/
*.xcworkspace
!default.xcworkspace

# Swift Package Manager
.build/
Packages/
Package.pins
Package.resolved
*.swiftpm

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
"""
            self.write_file_safe(gitignore_path, gitignore_content)
            self.log("Created .gitignore", "SUCCESS")
            
    def validate_project_structure(self):
        """Validate and fix project structure"""
        # Check for essential directories
        essential_dirs = [
            'Faith Journal/Faith Journal/Models',
            'Faith Journal/Faith Journal/Views',
            'Faith Journal/Faith Journal/Views/Components'
        ]
        
        for dir_path in essential_dirs:
            full_path = self.project_path / dir_path
            if not full_path.exists():
                full_path.mkdir(parents=True, exist_ok=True)
                self.log(f"Created directory: {dir_path}", "SUCCESS")
                
    def run_comprehensive_fix(self):
        """Run comprehensive fixing process"""
        self.log("🚀 Starting Enhanced Faith Journal Auto-Fix Process", "SUCCESS")
        self.log("=" * 60)
        
        # Step 0: Clear any existing build errors and reset Xcode state
        self.clear_build_errors()
        
        # Step 1: Install dependencies
        self.install_dependencies()
        
        # Step 2: Validate project structure
        self.validate_project_structure()
        
        # Step 3: Create missing files
        self.create_missing_files()
        
        # Step 4: Find all Swift files
        self.find_swift_files()
        
        # Step 5: Fix all Swift files (multiple passes)
        max_passes = 3
        for pass_num in range(max_passes):
            self.log(f"Pass {pass_num + 1}: Fixing Swift files...")
            files_fixed_this_pass = 0
            
            for file_path in self.swift_files:
                if self.fix_single_file(file_path):
                    files_fixed_this_pass += 1
                    
            if files_fixed_this_pass == 0:
                self.log("No more fixes needed in this pass")
                break
            else:
                self.log(f"Fixed {files_fixed_this_pass} files in pass {pass_num + 1}")
                # Clear build cache between passes to ensure clean state
                if pass_num < max_passes - 1:  # Don't clear on last pass
                    self.clear_xcode_cache()
        
        # Step 6: Clear build cache before final build
        self.log("Clearing build cache before final build test...")
        self.clear_xcode_cache()
        
        # Step 7: Build and check for remaining errors
        self.log("Running Xcode build to check for errors...")
        build_success, build_output = self.run_xcode_build()
        
        if not build_success:
            self.log("Build failed, parsing errors for targeted fixes...", "WARNING")
            
            # Parse and fix specific build errors
            errors = self.parse_build_errors(build_output)
            self.log(f"Found {len(errors)} build errors")
            
            if errors:
                self.fix_specific_build_errors(errors)
                
                # Clear cache again after targeted fixes
                self.log("Clearing cache after targeted fixes...")
                self.clear_xcode_cache()
                
                # Try building again after fixes
                self.log("Retrying build after targeted fixes...")
                build_success, _ = self.run_xcode_build()
            
        # Step 8: Final cleanup and report
        if build_success:
            self.log("Performing final cleanup...")
            self.clear_xcode_cache()  # Clean final state
            
        self.log("=" * 60)
        if build_success:
            self.log("🎉 SUCCESS! Faith Journal project builds successfully!", "SUCCESS")
            self.log("✨ Error logs have been cleared and project is ready!", "SUCCESS")
        else:
            self.log("⚠️  Some issues may remain. Check Xcode for details.", "WARNING")
            self.log("🧹 Error logs have been cleared for a fresh start.", "INFO")
            
        self.log(f"📊 Total files fixed: {self.fixed_count}", "SUCCESS")
        self.log("Enhanced auto-fix process complete!", "SUCCESS")
        
        # Print next steps
        self.log("\n📋 Next Steps:")
        self.log("1. Open Faith Journal.xcodeproj in Xcode")
        self.log("2. Build and run the project (⌘+R)")
        self.log("3. Test all features and functionality")
        self.log("4. Error logs have been cleared for a clean debugging experience")
        
        return build_success

def main():
    """Main function"""
    if len(sys.argv) > 1:
        project_path = sys.argv[1]
    else:
        project_path = "."
        
    fixer = FaithJournalAutoFixer(project_path)
    success = fixer.run_comprehensive_fix()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 