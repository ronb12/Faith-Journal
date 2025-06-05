#!/usr/bin/env python3
"""
Xcode Project Validator for Faith Journal
Specialized script with 12 workers for comprehensive Xcode project validation
Checks build settings, configurations, file references, and project integrity
"""

import os
import sys
import json
import time
import threading
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import plistlib
from typing import Dict, List, Tuple, Optional

class XcodeProjectValidator:
    def __init__(self, project_path: str, num_workers: int = 12):
        self.project_path = Path(project_path)
        self.num_workers = num_workers
        self.results_lock = threading.Lock()
        self.validation_results = {
            'timestamp': time.time(),
            'project_path': str(project_path),
            'validations': {},
            'issues': [],
            'recommendations': [],
            'build_settings': {},
            'file_references': {}
        }
        
    def log(self, message: str, level: str = "INFO"):
        """Thread-safe logging"""
        with self.results_lock:
            timestamp = time.strftime("%H:%M:%S")
            thread_name = threading.current_thread().name
            print(f"[{timestamp}] [{level}] [{thread_name}] {message}")
    
    def find_xcodeproj(self) -> Optional[Path]:
        """Find the .xcodeproj file"""
        xcodeproj_files = list(self.project_path.glob("*.xcodeproj"))
        if not xcodeproj_files:
            self.log("No .xcodeproj file found", "ERROR")
            return None
        elif len(xcodeproj_files) > 1:
            self.log(f"Multiple .xcodeproj files found: {xcodeproj_files}", "WARNING")
        
        return xcodeproj_files[0]
    
    def validate_project_structure(self) -> Dict[str, bool]:
        """Validate basic Xcode project structure"""
        xcodeproj_path = self.find_xcodeproj()
        if not xcodeproj_path:
            return {'xcodeproj_exists': False}
        
        validations = {
            'xcodeproj_exists': True,
            'pbxproj_exists': (xcodeproj_path / "project.pbxproj").exists(),
            'xcschemes_exists': (xcodeproj_path / "xcshareddata" / "xcschemes").exists() or 
                               (xcodeproj_path / "xcuserdata").exists(),
            'info_plist_exists': any(self.project_path.rglob("Info.plist")),
            'swift_files_exist': bool(list(self.project_path.rglob("*.swift"))),
            'assets_exist': bool(list(self.project_path.rglob("*.xcassets")))
        }
        
        self.log(f"Project structure validation: {sum(validations.values())}/{len(validations)} checks passed")
        return validations
    
    def parse_pbxproj(self) -> Dict:
        """Parse the project.pbxproj file"""
        xcodeproj_path = self.find_xcodeproj()
        if not xcodeproj_path:
            return {}
        
        pbxproj_path = xcodeproj_path / "project.pbxproj"
        if not pbxproj_path.exists():
            self.log("project.pbxproj file not found", "ERROR")
            return {}
        
        try:
            with open(pbxproj_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Extract basic information
            project_info = {
                'file_references': content.count('PBXFileReference'),
                'build_files': content.count('PBXBuildFile'),
                'groups': content.count('PBXGroup'),
                'targets': content.count('PBXNativeTarget'),
                'configurations': content.count('XCBuildConfiguration'),
                'schemes': content.count('XCScheme')
            }
            
            self.log(f"Project contains: {project_info['targets']} targets, {project_info['file_references']} file references")
            return project_info
            
        except Exception as e:
            self.log(f"Error parsing project.pbxproj: {e}", "ERROR")
            return {}
    
    def validate_build_settings(self) -> Dict:
        """Validate Xcode build settings"""
        try:
            result = subprocess.run([
                'xcodebuild', '-project', str(self.find_xcodeproj()),
                '-showBuildSettings'
            ], capture_output=True, text=True, cwd=self.project_path, timeout=120)
            
            if result.returncode != 0:
                self.log(f"Failed to get build settings: {result.stderr}", "ERROR")
                return {'error': result.stderr}
            
            # Parse build settings
            settings = {}
            current_target = None
            
            for line in result.stdout.split('\n'):
                line = line.strip()
                if line.startswith('Build settings for action build and target'):
                    current_target = line.split('"')[1] if '"' in line else 'Unknown'
                    settings[current_target] = {}
                elif '=' in line and current_target:
                    key, value = line.split('=', 1)
                    settings[current_target][key.strip()] = value.strip()
            
            self.log(f"Extracted build settings for {len(settings)} targets")
            return settings
            
        except subprocess.TimeoutExpired:
            self.log("Build settings extraction timed out", "ERROR")
            return {'error': 'Timeout'}
        except Exception as e:
            self.log(f"Error getting build settings: {e}", "ERROR")
            return {'error': str(e)}
    
    def validate_info_plist(self) -> List[Dict]:
        """Validate Info.plist files"""
        plist_files = list(self.project_path.rglob("Info.plist"))
        validations = []
        
        for plist_path in plist_files:
            try:
                with open(plist_path, 'rb') as f:
                    plist_data = plistlib.load(f)
                
                validation = {
                    'path': str(plist_path),
                    'valid': True,
                    'bundle_id': plist_data.get('CFBundleIdentifier', 'Missing'),
                    'version': plist_data.get('CFBundleShortVersionString', 'Missing'),
                    'build': plist_data.get('CFBundleVersion', 'Missing'),
                    'display_name': plist_data.get('CFBundleDisplayName', 'Missing'),
                    'issues': []
                }
                
                # Check for required keys
                required_keys = [
                    'CFBundleIdentifier',
                    'CFBundleShortVersionString',
                    'CFBundleVersion',
                    'CFBundleDisplayName'
                ]
                
                for key in required_keys:
                    if key not in plist_data:
                        validation['issues'].append(f"Missing required key: {key}")
                
                # Check for privacy usage descriptions if needed
                privacy_keys = [
                    'NSMicrophoneUsageDescription',
                    'NSCameraUsageDescription',
                    'NSPhotoLibraryUsageDescription'
                ]
                
                for key in privacy_keys:
                    if key in plist_data:
                        if not plist_data[key] or len(plist_data[key]) < 10:
                            validation['issues'].append(f"Insufficient privacy description for {key}")
                
                validations.append(validation)
                self.log(f"Validated Info.plist: {plist_path.name}")
                
            except Exception as e:
                validations.append({
                    'path': str(plist_path),
                    'valid': False,
                    'error': str(e)
                })
                self.log(f"Error validating {plist_path}: {e}", "ERROR")
        
        return validations
    
    def check_file_references(self) -> Dict:
        """Check for missing or orphaned file references"""
        xcodeproj_path = self.find_xcodeproj()
        if not xcodeproj_path:
            return {}
        
        try:
            # Get list of files in project
            result = subprocess.run([
                'find', str(xcodeproj_path), '-name', '*.pbxproj', '-exec',
                'grep', '-o', r'[a-zA-Z0-9_/.-]*\.swift', '{}', ';'
            ], capture_output=True, text=True)
            
            referenced_files = set(result.stdout.strip().split('\n')) if result.stdout.strip() else set()
            
            # Get actual Swift files
            actual_files = {str(f.relative_to(self.project_path)) for f in self.project_path.rglob("*.swift")}
            
            missing_refs = actual_files - referenced_files
            orphaned_refs = referenced_files - actual_files
            
            return {
                'referenced_files': len(referenced_files),
                'actual_files': len(actual_files),
                'missing_references': list(missing_refs),
                'orphaned_references': list(orphaned_refs)
            }
            
        except Exception as e:
            self.log(f"Error checking file references: {e}", "ERROR")
            return {'error': str(e)}
    
    def validate_schemes(self) -> List[Dict]:
        """Validate Xcode schemes"""
        try:
            result = subprocess.run([
                'xcodebuild', '-project', str(self.find_xcodeproj()),
                '-list'
            ], capture_output=True, text=True, cwd=self.project_path)
            
            if result.returncode != 0:
                return [{'error': result.stderr}]
            
            schemes = []
            in_schemes_section = False
            
            for line in result.stdout.split('\n'):
                line = line.strip()
                if line == 'Schemes:':
                    in_schemes_section = True
                    continue
                elif in_schemes_section and line and not line.startswith('If no'):
                    schemes.append({'name': line, 'valid': True})
                elif line.startswith('If no') or not line:
                    in_schemes_section = False
            
            self.log(f"Found {len(schemes)} schemes")
            return schemes
            
        except Exception as e:
            self.log(f"Error validating schemes: {e}", "ERROR")
            return [{'error': str(e)}]
    
    def run_build_test(self) -> Dict:
        """Run a test build to check for compilation issues"""
        try:
            self.log("Starting test build...")
            result = subprocess.run([
                'xcodebuild', '-project', str(self.find_xcodeproj()),
                '-scheme', 'Faith Journal',
                '-configuration', 'Debug',
                'clean', 'build',
                '-destination', 'generic/platform=iOS Simulator'
            ], capture_output=True, text=True, cwd=self.project_path, timeout=600)
            
            build_result = {
                'success': result.returncode == 0,
                'return_code': result.returncode,
                'stdout_lines': len(result.stdout.split('\n')),
                'stderr_lines': len(result.stderr.split('\n')),
                'errors': [],
                'warnings': []
            }
            
            # Parse errors and warnings
            for line in result.stderr.split('\n'):
                if 'error:' in line.lower():
                    build_result['errors'].append(line.strip())
                elif 'warning:' in line.lower():
                    build_result['warnings'].append(line.strip())
            
            if build_result['success']:
                self.log("Build test PASSED", "SUCCESS")
            else:
                self.log(f"Build test FAILED with {len(build_result['errors'])} errors", "ERROR")
            
            return build_result
            
        except subprocess.TimeoutExpired:
            self.log("Build test timed out", "ERROR")
            return {'success': False, 'error': 'Build timeout'}
        except Exception as e:
            self.log(f"Build test error: {e}", "ERROR")
            return {'success': False, 'error': str(e)}
    
    def validate_app_icons(self) -> Dict:
        """Validate app icon assets"""
        icon_validations = []
        
        for assets_dir in self.project_path.rglob("*.xcassets"):
            appicon_dir = assets_dir / "AppIcon.appiconset"
            if appicon_dir.exists():
                contents_json = appicon_dir / "Contents.json"
                if contents_json.exists():
                    try:
                        with open(contents_json, 'r') as f:
                            contents = json.load(f)
                        
                        images = contents.get('images', [])
                        missing_icons = []
                        
                        for image in images:
                            filename = image.get('filename')
                            if filename:
                                icon_path = appicon_dir / filename
                                if not icon_path.exists():
                                    missing_icons.append(filename)
                        
                        icon_validations.append({
                            'path': str(appicon_dir),
                            'total_icons': len(images),
                            'missing_icons': missing_icons,
                            'valid': len(missing_icons) == 0
                        })
                        
                    except Exception as e:
                        icon_validations.append({
                            'path': str(appicon_dir),
                            'error': str(e),
                            'valid': False
                        })
        
        return {'app_icons': icon_validations}
    
    def worker_validation_task(self, task_name: str, task_func) -> Dict:
        """Worker function for parallel validation tasks"""
        try:
            start_time = time.time()
            result = task_func()
            duration = time.time() - start_time
            
            return {
                'task': task_name,
                'result': result,
                'duration': duration,
                'status': 'success'
            }
        except Exception as e:
            self.log(f"Error in task {task_name}: {e}", "ERROR")
            return {
                'task': task_name,
                'error': str(e),
                'status': 'error'
            }
    
    def run_parallel_validation(self) -> Dict:
        """Run all validations in parallel with 12 workers"""
        self.log(f"Starting parallel validation with {self.num_workers} workers")
        
        validation_tasks = [
            ('project_structure', self.validate_project_structure),
            ('pbxproj_parsing', self.parse_pbxproj),
            ('build_settings', self.validate_build_settings),
            ('info_plist', self.validate_info_plist),
            ('file_references', self.check_file_references),
            ('schemes', self.validate_schemes),
            ('app_icons', self.validate_app_icons),
            ('build_test', self.run_build_test)
        ]
        
        results = {}
        
        with ThreadPoolExecutor(max_workers=min(self.num_workers, len(validation_tasks))) as executor:
            # Submit all validation tasks
            future_to_task = {
                executor.submit(self.worker_validation_task, task_name, task_func): task_name
                for task_name, task_func in validation_tasks
            }
            
            # Collect results
            for future in as_completed(future_to_task):
                task_name = future_to_task[future]
                try:
                    result = future.result()
                    results[task_name] = result
                    
                    if result['status'] == 'success':
                        self.log(f"Completed {task_name} in {result['duration']:.2f}s")
                    else:
                        self.log(f"Failed {task_name}: {result.get('error', 'Unknown error')}", "ERROR")
                        
                except Exception as e:
                    self.log(f"Exception in {task_name}: {e}", "ERROR")
                    results[task_name] = {
                        'task': task_name,
                        'error': str(e),
                        'status': 'exception'
                    }
        
        return results
    
    def generate_recommendations(self, validation_results: Dict) -> List[str]:
        """Generate recommendations based on validation results"""
        recommendations = []
        
        # Check build test results
        if 'build_test' in validation_results:
            build_result = validation_results['build_test'].get('result', {})
            if not build_result.get('success', False):
                recommendations.append("Fix compilation errors before proceeding with development")
                if build_result.get('errors'):
                    recommendations.append("Review build errors in the detailed report")
        
        # Check file references
        if 'file_references' in validation_results:
            file_refs = validation_results['file_references'].get('result', {})
            if file_refs.get('missing_references'):
                recommendations.append("Add missing Swift files to Xcode project")
            if file_refs.get('orphaned_references'):
                recommendations.append("Remove orphaned file references from project")
        
        # Check Info.plist
        if 'info_plist' in validation_results:
            plist_results = validation_results['info_plist'].get('result', [])
            for plist in plist_results:
                if plist.get('issues'):
                    recommendations.append(f"Fix Info.plist issues in {plist['path']}")
        
        # Check app icons
        if 'app_icons' in validation_results:
            icon_results = validation_results['app_icons'].get('result', {})
            for icon_set in icon_results.get('app_icons', []):
                if not icon_set.get('valid', True):
                    recommendations.append("Add missing app icon assets")
        
        # Add general recommendations
        recommendations.extend([
            "Consider using SwiftUI previews for faster development",
            "Implement comprehensive unit tests",
            "Set up continuous integration for automated testing",
            "Review and optimize build settings for release builds",
            "Ensure proper code signing configuration"
        ])
        
        return recommendations
    
    def run_complete_validation(self) -> Dict:
        """Run complete Xcode project validation"""
        self.log("Starting comprehensive Xcode project validation")
        start_time = time.time()
        
        # Run parallel validations
        validation_results = self.run_parallel_validation()
        
        # Generate recommendations
        recommendations = self.generate_recommendations(validation_results)
        
        # Compile final report
        final_report = {
            'timestamp': time.time(),
            'duration': time.time() - start_time,
            'project_path': str(self.project_path),
            'validation_results': validation_results,
            'recommendations': recommendations,
            'summary': {
                'total_validations': len(validation_results),
                'successful_validations': len([r for r in validation_results.values() if r.get('status') == 'success']),
                'failed_validations': len([r for r in validation_results.values() if r.get('status') != 'success']),
                'build_success': validation_results.get('build_test', {}).get('result', {}).get('success', False)
            }
        }
        
        # Save report
        report_path = self.project_path / 'xcode_validation_report.json'
        with open(report_path, 'w') as f:
            json.dump(final_report, f, indent=2, default=str)
        
        self.log(f"Validation complete in {final_report['duration']:.2f}s. Report saved to {report_path}")
        return final_report

def main():
    if len(sys.argv) > 1:
        project_path = sys.argv[1]
    else:
        project_path = "."
    
    validator = XcodeProjectValidator(project_path, num_workers=12)
    
    print("=" * 80)
    print("Xcode Project Validator for Faith Journal")
    print("Multi-threaded validation with 12 workers")
    print("=" * 80)
    
    try:
        results = validator.run_complete_validation()
        
        print("\n" + "=" * 80)
        print("VALIDATION SUMMARY")
        print("=" * 80)
        print(f"Total validations: {results['summary']['total_validations']}")
        print(f"Successful: {results['summary']['successful_validations']}")
        print(f"Failed: {results['summary']['failed_validations']}")
        print(f"Build successful: {results['summary']['build_success']}")
        print(f"Duration: {results['duration']:.2f} seconds")
        
        if results['summary']['build_success']:
            print("\n✅ Project builds successfully!")
        else:
            print("\n❌ Project has build issues - check the report")
        
        print(f"\n📊 Detailed report saved to: xcode_validation_report.json")
        print(f"🔧 {len(results['recommendations'])} recommendations generated")
        
    except KeyboardInterrupt:
        print("\nValidation interrupted by user")
    except Exception as e:
        print(f"Validation failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 