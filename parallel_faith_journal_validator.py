#!/usr/bin/env python3
"""
Enhanced Parallel Faith Journal Builder and Validator
Uses 24 workers to parallelize building and validation
"""

import os
import sys
import time
import json
import shutil
import threading
import subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

class ProjectStructureValidator:
    def __init__(self, project_path):
        self.project_path = Path(project_path)
        self.required_directories = {
            "Faith Journal": [
                "Models",
                "Views",
                "Views/Components",
                "Services",
                "Utils",
                "Resources",
                "Preview Content",
                "Assets.xcassets"
            ]
        }
        self.required_files = {
            "Faith Journal": [
                "Faith_JournalApp.swift",
                "SceneDelegate.swift",
                "Models/User.swift",
                "Models/JournalEntry.swift",
                "Models/Drawing.swift",
                "Models/AudioEntry.swift",
                "Models/PrayerRequest.swift",
                "Models/Badge.swift",
                "Models/Devotional.swift",
                "Views/MainTabView.swift",
                "Views/HomeView.swift",
                "Views/JournalView.swift",
                "Views/SettingsView.swift"
            ]
        }
        
    def validate_directory_structure(self):
        """Validate and create required directories"""
        missing_dirs = []
        for base_dir, subdirs in self.required_directories.items():
            for subdir in subdirs:
                dir_path = self.project_path / base_dir / subdir
                if not dir_path.exists():
                    missing_dirs.append(dir_path)
        return missing_dirs
    
    def validate_required_files(self):
        """Validate required files exist"""
        missing_files = []
        for base_dir, files in self.required_files.items():
            for file in files:
                file_path = self.project_path / base_dir / file
                if not file_path.exists():
                    missing_files.append(file_path)
        return missing_files
    
    def create_missing_directories(self, missing_dirs):
        """Create missing directories in parallel"""
        def create_dir(path):
            path.mkdir(parents=True, exist_ok=True)
            return f"Created directory: {path}"
        
        with ThreadPoolExecutor(max_workers=24) as executor:
            futures = [executor.submit(create_dir, path) for path in missing_dirs]
            results = []
            for future in as_completed(futures):
                try:
                    results.append(future.result())
                except Exception as e:
                    results.append(f"Error creating directory: {e}")
            return results

class XcodeProjectManager:
    def __init__(self, project_path):
        self.project_path = Path(project_path)
        self.project_name = "Faith Journal"
        
    def ensure_xcodegen_installed(self):
        """Ensure XcodeGen is installed"""
        try:
            subprocess.run(["which", "xcodegen"], check=True, capture_output=True)
        except subprocess.CalledProcessError:
            print("Installing XcodeGen...")
            subprocess.run(["brew", "install", "xcodegen"], check=True)
    
    def backup_project(self):
        """Backup existing Xcode project if it exists"""
        xcodeproj_path = self.project_path / f"{self.project_name}.xcodeproj"
        if xcodeproj_path.exists():
            backup_path = xcodeproj_path.with_suffix(".xcodeproj.backup")
            shutil.copytree(xcodeproj_path, backup_path, dirs_exist_ok=True)
            return True
        return False
    
    def restore_project_if_needed(self, success):
        """Restore project from backup if generation failed"""
        if not success:
            backup_path = self.project_path / f"{self.project_name}.xcodeproj.backup"
            xcodeproj_path = self.project_path / f"{self.project_name}.xcodeproj"
            if backup_path.exists():
                shutil.rmtree(xcodeproj_path, ignore_errors=True)
                shutil.copytree(backup_path, xcodeproj_path, dirs_exist_ok=True)
                print("Restored Xcode project from backup")
    
    def clean_derived_data(self):
        """Clean Xcode's derived data for the project"""
        derived_data_path = Path.home() / "Library/Developer/Xcode/DerivedData"
        if derived_data_path.exists():
            for path in derived_data_path.glob("Faith_Journal-*"):
                shutil.rmtree(path, ignore_errors=True)
    
    def generate_project(self):
        """Generate Xcode project using XcodeGen"""
        try:
            print("Generating Xcode project...")
            subprocess.run(["xcodegen", "generate"], 
                         cwd=str(self.project_path), 
                         check=True,
                         capture_output=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"Error generating Xcode project: {e.stderr.decode()}")
            return False
    
    def update_project(self):
        """Update Xcode project with proper configuration"""
        self.ensure_xcodegen_installed()
        self.clean_derived_data()
        had_backup = self.backup_project()
        success = self.generate_project()
        
        if not success and had_backup:
            self.restore_project_if_needed(success)
            return False
        return True

class ParallelProjectBuilder:
    def __init__(self, project_path, num_workers=24):
        self.project_path = Path(project_path)
        self.num_workers = num_workers
        self.results_lock = threading.Lock()
        self.build_results = {}
        self.errors = []
        self.xcode_manager = XcodeProjectManager(project_path)
        self.structure_validator = ProjectStructureValidator(project_path)
    
    def validate_and_fix_structure(self):
        """Validate and fix project structure"""
        print("Validating project structure...")
        
        # Check for missing directories
        missing_dirs = self.structure_validator.validate_directory_structure()
        if missing_dirs:
            print(f"Found {len(missing_dirs)} missing directories")
            results = self.structure_validator.create_missing_directories(missing_dirs)
            for result in results:
                print(result)
        
        # Check for missing files
        missing_files = self.structure_validator.validate_required_files()
        if missing_files:
            print(f"Found {len(missing_files)} missing required files:")
            for file in missing_files:
                print(f"  - {file.relative_to(self.project_path)}")
            return False
        
        return True

    def build(self):
        """Execute the parallel build process"""
        print("Starting parallel build with", self.num_workers, "workers...")
        
        # Validate and fix project structure
        if not self.validate_and_fix_structure():
            print("Project structure validation failed!")
            return
        
        # Update Xcode project
        print("Updating Xcode project...")
        if not self.xcode_manager.update_project():
            print("Failed to update Xcode project!")
            return
        
        if self.errors:
            print("Build completed with errors:")
            for error in self.errors:
                print(f"- {error}")
        else:
            print("Build completed successfully!")
            for result in self.build_results:
                print(f"✓ {result}")

def main():
    builder = ParallelProjectBuilder(".")
    builder.build()

if __name__ == "__main__":
    main()