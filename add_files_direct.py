#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Add files directly to Xcode project.pbxproj
Works with File System Synchronization projects
"""

import re
import os
import random
import string

def gen_id():
    """24-char hex ID"""
    return ''.join(random.choices(string.ascii_uppercase + '0123456789', k=24))

project_file = 'Faith Journal.xcodeproj/project.pbxproj'

# Read
with open(project_file, 'r', encoding='utf-8') as f:
    content = f.read()

files_to_add = [
    ('Faith Journal/Faith Journal/Models/SessionRating.swift', 'SessionRating.swift'),
    ('Faith Journal/Faith Journal/Models/SessionClip.swift', 'SessionClip.swift'),
    ('Faith Journal/Faith Journal/Services/TranslationService.swift', 'TranslationService.swift'),
    ('Faith Journal/Faith Journal/Services/SessionRecommendationService.swift', 'SessionRecommendationService.swift'),
    ('Faith Journal/Faith Journal/Views/WaitingRoomView.swift', 'WaitingRoomView.swift'),
    ('Faith Journal/Faith Journal/Views/SessionClipsView.swift', 'SessionClipsView.swift'),
    ('Faith Journal/Faith Journal/Views/TranslationSettingsView.swift', 'TranslationSettingsView.swift'),
]

# Check which need adding
needs_adding = []
for full_path, filename in files_to_add:
    if not os.path.exists(full_path):
        print(f"❌ File missing: {full_path}")
        continue
    if filename in content:
        print(f"✅ {filename} already referenced")
    else:
        needs_adding.append((full_path, filename))
        print(f"⚠️  {filename} needs explicit reference")

if not needs_adding:
    print("\n✅ All files are in project or will be auto-detected!")
    print("\nSince project uses File System Synchronization,")
    print("files should be detected automatically.")
    print("\nIf you still get errors:")
    print("  1. Clean Build Folder in Xcode (Cmd+Shift+K)")
    print("  2. Quit Xcode completely")
    print("  3. Reopen and build")
    exit(0)

print(f"\n⚠️  {len(needs_adding)} files need explicit references")
print("However, with File System Sync, Xcode should detect them automatically.")
print("\n💡 Recommendation:")
print("  1. Try building in Xcode - files may auto-detect")
print("  2. If errors persist, manually add files in Xcode UI")
print("     (Right-click folder → Add Files to 'Faith Journal'...)")
print("\nI'll now try to add explicit file references anyway...")

# Generate IDs for new file references
file_refs = {}
build_files = {}

for full_path, filename in needs_adding:
    file_ref_id = gen_id()
    build_file_id = gen_id()
    file_refs[filename] = (file_ref_id, build_file_id, full_path)

# Find insertion points
# PBXFileReference section ends at "/* End PBXFileReference section */"
file_ref_end = content.find('/* End PBXFileReference section */')
if file_ref_end == -1:
    print("❌ Could not find PBXFileReference section end")
    exit(1)

# Find PBXBuildFile section
build_file_end = content.find('/* End PBXBuildFile section */')
if build_file_end == -1:
    print("❌ Could not find PBXBuildFile section end")
    exit(1)

# Find PBXSourcesBuildPhase (where we add build files)
sources_phase_match = re.search(r'/\* Begin PBXSourcesBuildPhase section \*/\s+47365A252F142AD000715470 /\* Sources \*/ = \{.*?files = \((.*?)\);', content, re.DOTALL)
if not sources_phase_match:
    print("❌ Could not find Sources build phase")
    exit(1)

sources_files_start = sources_phase_match.end(1) - len(sources_phase_match.group(1))

# Build new file reference entries
new_file_refs = []
new_build_files = []
new_sources_files = []

for filename, (file_ref_id, build_file_id, full_path) in file_refs.items():
    # File reference
    new_file_refs.append(
        f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{full_path}"; sourceTree = "<group>"; }};'
    )
    # Build file
    new_build_files.append(
        f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};'
    )
    # Sources file
    new_sources_files.append(
        f'\t\t\t\t{build_file_id} /* {filename} in Sources */,'
    )

# Insert file references
if new_file_refs:
    file_ref_insert = file_ref_end
    new_content = content[:file_ref_insert] + '\n' + '\n'.join(new_file_refs) + '\n' + content[file_ref_insert:]
    content = new_content
    
    # Update insertion points
    file_ref_end = content.find('/* End PBXFileReference section */')
    build_file_end = content.find('/* End PBXBuildFile section */')
    sources_phase_match = re.search(r'/\* Begin PBXSourcesBuildPhase section \*/\s+47365A252F142AD000715470 /\* Sources \*/ = \{.*?files = \((.*?)\);', content, re.DOTALL)
    if sources_phase_match:
        sources_files_start = sources_phase_match.end(1) - len(sources_phase_match.group(1))

# Insert build files
if new_build_files:
    build_file_insert = build_file_end
    content = content[:build_file_insert] + '\n' + '\n'.join(new_build_files) + '\n' + content[build_file_insert:]
    
    # Update insertion point
    sources_phase_match = re.search(r'/\* Begin PBXSourcesBuildPhase section \*/\s+47365A252F142AD000715470 /\* Sources \*/ = \{.*?files = \((.*?)\);', content, re.DOTALL)
    if sources_phase_match:
        sources_files_start = sources_phase_match.end(1) - len(sources_phase_match.group(1))

# Insert into Sources build phase
if new_sources_files:
    sources_insert = sources_files_start
    content = content[:sources_insert] + '\n' + '\n'.join(new_sources_files) + '\n' + content[sources_insert:]

# Write back
try:
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"\n✅ Successfully added {len(needs_adding)} file references to project!")
    print("   File references added")
    print("   Build files added")
    print("   Sources phase updated")
except Exception as e:
    print(f"\n❌ Error writing project file: {e}")
    exit(1)

