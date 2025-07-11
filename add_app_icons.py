#!/usr/bin/env python3
"""
Script to add Assets.xcassets and app icons to Xcode project
"""

import os
import re
import shutil
import uuid

def generate_uuid():
    """Generate a UUID for Xcode project entries"""
    return str(uuid.uuid4()).upper().replace('-', '')[:24]

def add_assets_to_project():
    """Add Assets.xcassets to the Xcode project file"""
    
    project_file = "Faith Journal.xcodeproj/project.pbxproj"
    backup_file = "Faith Journal.xcodeproj/project.pbxproj.backup"
    
    # Create backup if it doesn't exist
    if not os.path.exists(backup_file):
        shutil.copy2(project_file, backup_file)
        print("Created backup of project file")
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Generate UUIDs for new entries
    assets_uuid = generate_uuid()
    appicon_uuid = generate_uuid()
    appicon_files_uuid = generate_uuid()
    
    # Create the Assets.xcassets reference
    assets_reference = f"""
		47201A9E2E11CDF700540884 /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
"""
    
    # Create the AppIcon.appiconset reference
    appicon_reference = f"""
		47201A9E2E11CDF700540885 /* AppIcon.appiconset */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = AppIcon.appiconset; sourceTree = "<group>"; }};
"""
    
    # Create the app icon file references
    app_icon_files = [
        "AppIcon-1024x1024.png",
        "AppIcon-120x120.png", 
        "AppIcon-152x152.png",
        "AppIcon-167x167.png",
        "AppIcon-180x180.png",
        "AppIcon-20x20.png",
        "AppIcon-29x29.png",
        "AppIcon-40x40.png",
        "AppIcon-58x58.png",
        "AppIcon-60x60.png",
        "AppIcon-76x76.png",
        "AppIcon-80x80.png",
        "AppIcon-87x87.png",
        "AppIcon-83.5x83.5.png",
        "FaithJournalAppIcon.png"
    ]
    
    app_icon_references = ""
    for i, filename in enumerate(app_icon_files):
        file_uuid = generate_uuid()
        app_icon_references += f"""
		47201A9E2E11CDF70054088{6+i} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = image.png; path = "{filename}"; sourceTree = "<group>"; }};
"""
    
    # Add to PBXFileReference section
    pbx_file_ref_pattern = r'(/\* Begin PBXFileReference section \*/)'
    pbx_file_ref_replacement = r'\1' + assets_reference + appicon_reference + app_icon_references
    
    content = re.sub(pbx_file_ref_pattern, pbx_file_ref_replacement, content)
    
    # Create the Assets.xcassets group
    assets_group = f"""
		47201A9E2E11CDF700540890 /* Assets.xcassets */ = {{
			isa = PBXGroup;
			children = (
				47201A9E2E11CDF700540885 /* AppIcon.appiconset */,
			);
			path = Assets.xcassets;
			sourceTree = "<group>";
		}};
"""
    
    # Create the AppIcon.appiconset group with all files
    appicon_group_children = ""
    for i, filename in enumerate(app_icon_files):
        file_uuid = f"47201A9E2E11CDF70054088{6+i}"
        appicon_group_children += f"\n\t\t\t\t\t{file_uuid} /* {filename} */,"
    
    appicon_group = f"""
		47201A9E2E11CDF700540885 /* AppIcon.appiconset */ = {{
			isa = PBXGroup;
			children = ({appicon_group_children}
			);
			path = AppIcon.appiconset;
			sourceTree = "<group>";
		}};
"""
    
    # Add to PBXGroup section
    pbx_group_pattern = r'(/\* Begin PBXGroup section \*/)'
    pbx_group_replacement = r'\1' + assets_group + appicon_group
    
    content = re.sub(pbx_group_pattern, pbx_group_replacement, content)
    
    # Add Assets.xcassets to the main Faith Journal group
    main_group_pattern = r'(47201AA02E11CDF700540883 /\* Faith Journal \*/ = \{[^}]*children = \(([^)]*)\);[^}]*\})'
    
    def add_assets_to_main_group(match):
        children = match.group(2)
        if '47201A9E2E11CDF700540890 /* Assets.xcassets */' not in children:
            children += '\n\t\t\t\t47201A9E2E11CDF700540890 /* Assets.xcassets */,'
        return f'47201AA02E11CDF700540883 /* Faith Journal */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = ({children}\n\t\t\t);\n\t\t\tpath = "Faith Journal";\n\t\t\tsourceTree = "<group>";\n\t\t}};'
    
    content = re.sub(main_group_pattern, add_assets_to_main_group, content)
    
    # Write the modified project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("Successfully added Assets.xcassets and app icons to Xcode project!")
    print("Please refresh Xcode to see the changes.")

if __name__ == "__main__":
    add_assets_to_project() 