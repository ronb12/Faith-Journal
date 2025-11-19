# Scripts Directory

This directory contains helper scripts for managing the Faith Journal project.

## Script Categories

### Icon Management
- `create_app_icons.py` - Generate app icons programmatically
- `add_app_icons.py` - Add app icons to Xcode project
- `add_app_icons_to_xcodeproj.rb` - Ruby script for adding icons

### Project Management
- `add_files_to_xcode.rb` - Add files to Xcode project
- `add_files_manual.rb` - Manual file addition script
- `add_asset_catalog.rb` - Add asset catalog to project
- `add_new_files_to_project.swift` - Add new feature files
- `fix_project_file.sh` - Fix project file issues
- `check_asset_catalogs.sh` - Validate asset catalogs

### WebRTC/Dependencies
- `add_webrtc_dependency.sh` - Add WebRTC dependency
- `add_webrtc_manual.sh` - Manual WebRTC setup
- `add_webrtc_package.swift` - WebRTC package configuration
- `fix_webrtc_dependency.sh` - Fix WebRTC issues
- `remove_webrtc_dependency.sh` - Remove WebRTC dependency

### Build & Export
- `build.log` - Build log file
- `ExportOptions.plist` - Export options for App Store submission

### Backup & Archive
- `move_archives_to_usb.sh` - Move archives to USB
- `move_large_files_to_usb.sh` - Move large files to USB
- `move_project_to_usb.sh` - Move entire project to USB
- `move_to_memory_stick.sh` - Move to memory stick

### Validation
- `validate_app_rules.swift` - Validate app rules and configuration

## Usage

Most scripts can be run directly from the project root:
```bash
python3 scripts/create_app_icons.py
ruby scripts/add_files_to_xcode.rb
```

