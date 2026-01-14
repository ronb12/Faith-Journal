#!/usr/bin/env python3
"""
Force add files to Xcode project by modifying project.pbxproj
This handles projects with File System Synchronization
"""

import re
import os
import uuid
from pathlib import Path

def generate_id():
    """Generate Xcode-style 24-char hex ID"""
    return ''.join(format(b, '02X') for b in os.urandom(12))

project_file = Path('Faith Journal.xcodeproj/project.pbxproj')

# Read project
with open(project_file, 'r') as f:
    content = f.read()

# Files to add
files_to_add = [
    'Faith Journal/Faith Journal/Models/SessionRating.swift',
    'Faith Journal/Faith Journal/Models/SessionClip.swift',
    'Faith Journal/Faith Journal/Services/TranslationService.swift',
    'Faith Journal/Faith Journal/Services/SessionRecommendationService.swift',
    'Faith Journal/Faith Journal/Views/WaitingRoomView.swift',
    'Faith Journal/Faith Journal/Views/SessionClipsView.swift',
    'Faith Journal/Faith Journal/Views/TranslationSettingsView.swift',
]

# Verify files exist
missing = []
for fpath in files_to_add:
    if not Path(fpath).exists():
        missing.append(fpath)

if missing:
    print("❌ Missing files:")
    for f in missing:
        print(f"   - {f}")
    exit(1)

# Check if project uses file system sync
if 'PBXFileSystemSynchronizedRootGroup' in content:
    print("✅ Project uses File System Synchronization")
    print("   Files should be automatically detected.")
    print("\n📋 Files that exist and should auto-detect:")
    for fpath in files_to_add:
        filename = os.path.basename(fpath)
        print(f"   ✅ {filename}")
    
    print("\n💡 If files still don't compile:")
    print("   1. In Xcode: Product > Clean Build Folder (Cmd+Shift+K)")
    print("   2. Quit Xcode completely")
    print("   3. Reopen project")
    print("   4. Build again")
    
    # Since it's file system sync, we might need to trigger a rebuild
    # Try touching the files to update modification times
    print("\n🔄 Updating file modification times...")
    for fpath in files_to_add:
        Path(fpath).touch()
        print(f"   ✅ Touched {os.path.basename(fpath)}")
    
    print("\n✅ Done! Files should be detected on next build.")
else:
    print("⚠️  Project does not use File System Synchronization")
    print("   Will need to manually add files via Xcode UI")

