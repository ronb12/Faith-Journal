#!/usr/bin/env python3
"""
Enhanced Faith Journal Project Assistant
Advanced multi-threaded assistant with 12 workers for comprehensive project management
Validates structure, analyzes code, fixes issues, and optimizes the iOS app
"""

import os
import re
import sys
import time
import json
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import subprocess
import queue
from dataclasses import dataclass
from typing import List, Dict, Optional, Tuple
import hashlib

@dataclass
class ProjectAnalysis:
    structure_valid: bool
    missing_files: List[str]
    invalid_swift_files: List[str]
    compilation_errors: List[str]
    optimization_suggestions: List[str]
    security_issues: List[str]

class EnhancedFaithJournalAssistant:
    def __init__(self, project_path: str, num_workers: int = 12):
        self.project_path = Path(project_path)
        self.num_workers = num_workers
        self.analysis_results = {}
        self.fixes_applied = 0
        self.files_processed = 0
        self.error_queue = queue.Queue()
        self.results_lock = threading.Lock()
        self.report_data = {
            'timestamp': time.time(),
            'workers': num_workers,
            'files_analyzed': 0,
            'issues_found': 0,
            'fixes_applied': 0,
            'recommendations': []
        }
        
    def log(self, message: str, level: str = "INFO"):
        """Thread-safe logging with levels"""
        with self.results_lock:
            timestamp = time.strftime("%H:%M:%S")
            thread_name = threading.current_thread().name
            print(f"[{timestamp}] [{level}] [{thread_name}] {message}")
    
    def validate_project_structure(self) -> Dict[str, bool]:
        """Validate the iOS project structure"""
        required_components = {
            'xcodeproj': (self.project_path / "Faith Journal.xcodeproj").exists(),
            'main_app_folder': (self.project_path / "Faith Journal").exists(),
            'views_folder': (self.project_path / "Faith Journal" / "Views").exists(),
            'models_folder': (self.project_path / "Faith Journal" / "Models").exists(),
            'assets': (self.project_path / "Faith Journal" / "Assets.xcassets").exists(),
            'info_plist': (self.project_path / "Faith Journal" / "Info.plist").exists(),
            'app_file': (self.project_path / "Faith Journal" / "Faith_JournalApp.swift").exists(),
            'tests_folder': (self.project_path / "Faith JournalTests").exists(),
            'ui_tests_folder': (self.project_path / "Faith JournalUITests").exists()
        }
        
        missing = [k for k, v in required_components.items() if not v]
        if missing:
            self.log(f"Missing required components: {missing}", "WARNING")
        else:
            self.log("Project structure validation: PASSED", "SUCCESS")
            
        return required_components
    
    def find_all_files(self) -> Dict[str, List[Path]]:
        """Find and categorize all project files"""
        files = {
            'swift': [],
            'storyboard': [],
            'plist': [],
            'xcassets': [],
            'other': []
        }
        
        for root, dirs, file_list in os.walk(self.project_path):
            # Skip certain directories
            if any(skip in root for skip in ['.git', 'build', 'DerivedData', '.backup']):
                continue
                
            for file in file_list:
                file_path = Path(root) / file
                if file.endswith('.swift'):
                    files['swift'].append(file_path)
                elif file.endswith('.storyboard'):
                    files['storyboard'].append(file_path)
                elif file.endswith('.plist'):
                    files['plist'].append(file_path)
                elif file.endswith('.xcassets'):
                    files['xcassets'].append(file_path)
                else:
                    files['other'].append(file_path)
        
        self.log(f"Found {len(files['swift'])} Swift files, {len(files['storyboard'])} storyboards, {len(files['plist'])} plists")
        return files
    
    def analyze_swift_file(self, file_path: Path) -> Dict[str, any]:
        """Comprehensive analysis of a Swift file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            self.log(f"Error reading {file_path}: {e}", "ERROR")
            return {'error': str(e)}
        
        analysis = {
            'path': str(file_path),
            'lines': len(content.split('\n')),
            'imports': [],
            'classes': [],
            'structs': [],
            'enums': [],
            'protocols': [],
            'functions': [],
            'issues': [],
            'suggestions': []
        }
        
        # Extract imports
        import_pattern = r'^import\s+(\w+)'
        analysis['imports'] = re.findall(import_pattern, content, re.MULTILINE)
        
        # Extract type declarations
        analysis['classes'] = re.findall(r'class\s+(\w+)', content)
        analysis['structs'] = re.findall(r'struct\s+(\w+)', content)
        analysis['enums'] = re.findall(r'enum\s+(\w+)', content)
        analysis['protocols'] = re.findall(r'protocol\s+(\w+)', content)
        analysis['functions'] = re.findall(r'func\s+(\w+)', content)
        
        # Check for common issues
        self._check_common_issues(content, analysis)
        
        # Check for SwiftUI best practices
        if any('SwiftUI' in imp for imp in analysis['imports']):
            self._check_swiftui_practices(content, analysis)
        
        # Check for Core Data issues
        if any('CoreData' in imp for imp in analysis['imports']):
            self._check_coredata_practices(content, analysis)
            
        return analysis
    
    def _check_common_issues(self, content: str, analysis: Dict):
        """Check for common Swift issues"""
        # Check for force unwrapping
        if '!' in content and 'import' not in content.split('!')[0].split('\n')[-1]:
            force_unwraps = len(re.findall(r'\w+!(?!\s*=)', content))
            if force_unwraps > 5:
                analysis['issues'].append(f"High number of force unwraps ({force_unwraps})")
        
        # Check for unused variables
        var_declarations = re.findall(r'let\s+(\w+)\s*=|var\s+(\w+)\s*=', content)
        
        # Check for long functions
        functions = re.findall(r'func\s+\w+[^{]*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}', content, re.DOTALL)
        for func_body in functions:
            if len(func_body.split('\n')) > 50:
                analysis['issues'].append("Function longer than 50 lines detected")
        
        # Check for missing documentation
        if 'class ' in content or 'struct ' in content:
            if '///' not in content and '/**' not in content:
                analysis['suggestions'].append("Consider adding documentation comments")
    
    def _check_swiftui_practices(self, content: str, analysis: Dict):
        """Check SwiftUI best practices"""
        # Check for proper state management
        if '@State' in content and '@StateObject' not in content and 'ObservableObject' in content:
            analysis['suggestions'].append("Consider using @StateObject for ObservableObject instances")
        
        # Check for view complexity
        if content.count('VStack') + content.count('HStack') + content.count('ZStack') > 10:
            analysis['suggestions'].append("Complex view hierarchy - consider breaking into smaller views")
        
        # Check for proper preview implementation
        if 'struct ' in content and 'View' in content and '#Preview' not in content:
            analysis['suggestions'].append("Consider adding #Preview for better development experience")
    
    def _check_coredata_practices(self, content: str, analysis: Dict):
        """Check Core Data best practices"""
        if '@NSManaged' in content and 'NSManagedObject' not in content:
            analysis['issues'].append("@NSManaged property without NSManagedObject inheritance")
        
        if 'NSFetchRequest' in content and 'try?' not in content:
            analysis['suggestions'].append("Consider using try? for fetch requests")
    
    def fix_swift_issues(self, file_path: Path, analysis: Dict) -> int:
        """Apply automated fixes to Swift files"""
        fixes_applied = 0
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            original_content = content
            
            # Fix common Color API issues
            content, color_fixes = self._fix_color_api(content)
            fixes_applied += color_fixes
            
            # Fix import organization
            content, import_fixes = self._fix_imports(content)
            fixes_applied += import_fixes
            
            # Fix trailing whitespace
            lines = content.split('\n')
            cleaned_lines = [line.rstrip() for line in lines]
            if lines != cleaned_lines:
                content = '\n'.join(cleaned_lines)
                fixes_applied += 1
                self.log(f"Fixed trailing whitespace in {file_path.name}")
            
            # Write back if changes were made
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                self.log(f"Applied {fixes_applied} fixes to {file_path.name}")
                
        except Exception as e:
            self.log(f"Error fixing {file_path}: {e}", "ERROR")
            
        return fixes_applied
    
    def _fix_color_api(self, content: str) -> Tuple[str, int]:
        """Fix iOS Color API issues"""
        fixes = 0
        
        # Fix Color.systemBackground -> Color(.systemBackground)
        if 'Color.systemBackground' in content and 'Color(.systemBackground)' not in content:
            content = content.replace('Color.systemBackground', 'Color(.systemBackground)')
            fixes += 1
        
        # Fix Color.secondarySystemBackground -> Color(.systemGray6)
        if 'Color.secondarySystemBackground' in content:
            content = content.replace('Color.secondarySystemBackground', 'Color(.systemGray6)')
            fixes += 1
        
        return content, fixes
    
    def _fix_imports(self, content: str) -> Tuple[str, int]:
        """Organize and fix imports"""
        lines = content.split('\n')
        import_lines = []
        other_lines = []
        fixes = 0
        
        for line in lines:
            if line.strip().startswith('import '):
                import_lines.append(line.strip())
            else:
                other_lines.append(line)
        
        # Remove duplicates and sort
        unique_imports = sorted(list(set(import_lines)))
        
        if len(unique_imports) != len(import_lines):
            fixes += 1
        
        # Rebuild content
        if import_lines:
            # Find where imports should be inserted
            first_non_comment = 0
            for i, line in enumerate(other_lines):
                if line.strip() and not line.strip().startswith('//'):
                    first_non_comment = i
                    break
            
            new_content = '\n'.join(other_lines[:first_non_comment] + unique_imports + [''] + other_lines[first_non_comment:])
            return new_content, fixes
        
        return content, fixes
    
    def run_xcode_analysis(self) -> Dict[str, any]:
        """Run Xcode build analysis"""
        try:
            result = subprocess.run([
                'xcodebuild', '-project', 'Faith Journal.xcodeproj',
                '-scheme', 'Faith Journal',
                '-configuration', 'Debug',
                'clean', 'build'
            ], capture_output=True, text=True, cwd=self.project_path, timeout=300)
            
            return {
                'success': result.returncode == 0,
                'output': result.stdout,
                'errors': result.stderr,
                'compilation_errors': self._parse_compilation_errors(result.stderr)
            }
        except subprocess.TimeoutExpired:
            return {'success': False, 'error': 'Build timeout'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def _parse_compilation_errors(self, stderr: str) -> List[Dict]:
        """Parse Xcode compilation errors"""
        errors = []
        error_pattern = r'(.+?):(\d+):(\d+):\s+(error|warning):\s+(.+)'
        
        for match in re.finditer(error_pattern, stderr):
            errors.append({
                'file': match.group(1),
                'line': int(match.group(2)),
                'column': int(match.group(3)),
                'type': match.group(4),
                'message': match.group(5)
            })
        
        return errors
    
    def generate_project_report(self) -> str:
        """Generate comprehensive project report"""
        report = {
            'project_analysis': self.report_data,
            'structure_validation': self.validate_project_structure(),
            'files_found': {},
            'recommendations': []
        }
        
        # Add file counts
        files = self.find_all_files()
        report['files_found'] = {k: len(v) for k, v in files.items()}
        
        # Generate recommendations
        report['recommendations'] = [
            "Consider implementing SwiftUI previews for all views",
            "Add unit tests for all models and business logic",
            "Implement proper error handling throughout the app",
            "Consider using dependency injection for better testability",
            "Add accessibility labels for better app accessibility",
            "Implement proper data persistence error handling",
            "Consider using structured concurrency (async/await) for network operations"
        ]
        
        return json.dumps(report, indent=2, default=str)
    
    def process_file_worker(self, file_path: Path) -> Dict:
        """Worker function for processing individual files"""
        try:
            analysis = self.analyze_swift_file(file_path)
            fixes = self.fix_swift_issues(file_path, analysis)
            
            with self.results_lock:
                self.files_processed += 1
                self.fixes_applied += fixes
                
            return {
                'file': str(file_path),
                'analysis': analysis,
                'fixes_applied': fixes,
                'status': 'success'
            }
        except Exception as e:
            self.log(f"Error processing {file_path}: {e}", "ERROR")
            return {
                'file': str(file_path),
                'error': str(e),
                'status': 'error'
            }
    
    def run_parallel_analysis(self) -> Dict:
        """Run parallel analysis with 12 workers"""
        self.log(f"Starting parallel analysis with {self.num_workers} workers")
        
        files = self.find_all_files()
        swift_files = files['swift']
        
        if not swift_files:
            self.log("No Swift files found!", "WARNING")
            return {'error': 'No Swift files found'}
        
        results = []
        
        with ThreadPoolExecutor(max_workers=self.num_workers) as executor:
            # Submit all Swift files for processing
            future_to_file = {
                executor.submit(self.process_file_worker, file_path): file_path 
                for file_path in swift_files
            }
            
            # Collect results
            for future in as_completed(future_to_file):
                file_path = future_to_file[future]
                try:
                    result = future.result()
                    results.append(result)
                    
                    if result['status'] == 'success':
                        self.log(f"Processed {file_path.name} - {result['fixes_applied']} fixes applied")
                    else:
                        self.log(f"Failed to process {file_path.name}: {result.get('error', 'Unknown error')}", "ERROR")
                        
                except Exception as e:
                    self.log(f"Exception processing {file_path}: {e}", "ERROR")
                    results.append({
                        'file': str(file_path),
                        'error': str(e),
                        'status': 'exception'
                    })
        
        self.log(f"Analysis complete: {self.files_processed} files processed, {self.fixes_applied} fixes applied")
        
        return {
            'files_processed': self.files_processed,
            'fixes_applied': self.fixes_applied,
            'results': results,
            'summary': self.generate_project_report()
        }
    
    def run_full_analysis(self) -> Dict:
        """Run complete project analysis"""
        self.log("Starting comprehensive Faith Journal project analysis")
        
        # Structure validation
        structure = self.validate_project_structure()
        
        # Parallel file analysis
        analysis_results = self.run_parallel_analysis()
        
        # Xcode build test
        build_results = self.run_xcode_analysis()
        
        # Generate final report
        final_report = {
            'timestamp': time.time(),
            'structure_validation': structure,
            'file_analysis': analysis_results,
            'build_analysis': build_results,
            'summary': {
                'files_processed': self.files_processed,
                'fixes_applied': self.fixes_applied,
                'structure_valid': all(structure.values()),
                'build_successful': build_results.get('success', False)
            }
        }
        
        # Save report
        report_path = self.project_path / 'enhanced_analysis_report.json'
        with open(report_path, 'w') as f:
            json.dump(final_report, f, indent=2, default=str)
        
        self.log(f"Full analysis complete. Report saved to {report_path}")
        return final_report

def main():
    if len(sys.argv) > 1:
        project_path = sys.argv[1]
    else:
        project_path = "."
    
    assistant = EnhancedFaithJournalAssistant(project_path, num_workers=12)
    
    print("=" * 80)
    print("Enhanced Faith Journal Project Assistant")
    print("Multi-threaded analysis and optimization tool")
    print("=" * 80)
    
    start_time = time.time()
    
    try:
        results = assistant.run_full_analysis()
        
        print("\n" + "=" * 80)
        print("ANALYSIS SUMMARY")
        print("=" * 80)
        print(f"Files processed: {results['summary']['files_processed']}")
        print(f"Fixes applied: {results['summary']['fixes_applied']}")
        print(f"Structure valid: {results['summary']['structure_valid']}")
        print(f"Build successful: {results['summary']['build_successful']}")
        print(f"Total time: {time.time() - start_time:.2f} seconds")
        
        if not results['summary']['structure_valid']:
            print("\n⚠️  Project structure issues detected - see report for details")
        
        if not results['summary']['build_successful']:
            print("\n❌ Build failed - see report for compilation errors")
        
        if results['summary']['fixes_applied'] > 0:
            print(f"\n✅ Applied {results['summary']['fixes_applied']} automated fixes")
        
        print(f"\n📊 Detailed report saved to: enhanced_analysis_report.json")
        
    except KeyboardInterrupt:
        print("\nAnalysis interrupted by user")
    except Exception as e:
        print(f"Analysis failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 