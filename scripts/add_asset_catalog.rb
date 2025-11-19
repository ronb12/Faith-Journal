require 'xcodeproj'

# Path to your Xcode project and asset catalog
xcodeproj_path = 'Faith Journal/Faith Journal.xcodeproj'
asset_catalog_path = 'Faith Journal/Assets.xcassets'

# Open the project
group_name = 'Faith Journal'
project = Xcodeproj::Project.open(xcodeproj_path)

# Find the main group (usually the app name)
main_group = project.main_group.groups.find { |g| g.display_name == group_name }
raise "Could not find group '#{group_name}' in project" unless main_group

# Check if the asset catalog is already added
existing = main_group.files.find { |f| f.path == asset_catalog_path }
if existing
  puts "Asset catalog already added."
else
  # Add the asset catalog to the group
  file_ref = main_group.new_file(asset_catalog_path)
  # Add to the resources build phase of the main target
  target = project.targets.find { |t| t.name == group_name }
  raise "Could not find target '#{group_name}' in project" unless target
  target.resources_build_phase.add_file_reference(file_ref)
  puts "Added asset catalog to project."
  project.save
end 