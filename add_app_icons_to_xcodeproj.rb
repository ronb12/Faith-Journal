require 'xcodeproj'

project_path = 'Faith Journal.xcodeproj'
assets_path = 'Faith Journal/Assets.xcassets'

project = Xcodeproj::Project.open(project_path)

# Find the main group for your app source files
main_group = project.groups.find { |g| g.display_name == 'Faith Journal' }
assets_group = main_group.groups.find { |g| g.display_name == 'Assets.xcassets' } ||
               main_group.new_group('Assets.xcassets', assets_path)

# Add the asset catalog folder if not present
unless assets_group.files.any? { |f| f.path == 'AppIcon.appiconset' }
  assets_group.new_file(File.join(assets_path, 'AppIcon.appiconset'))
end

# Add all PNGs in AppIcon.appiconset
iconset_path = File.join(assets_path, 'AppIcon.appiconset')
Dir.glob(File.join(iconset_path, '*.png')).each do |icon_path|
  filename = File.basename(icon_path)
  unless assets_group.files.any? { |f| f.path == File.join('AppIcon.appiconset', filename) }
    assets_group.new_file(File.join('AppIcon.appiconset', filename))
  end
end

# Add the asset catalog to the resources build phase if not present
target = project.targets.find { |t| t.name == 'Faith Journal' }
unless target.resources_build_phase.files_references.any? { |f| f.path == assets_path }
  target.add_resources([assets_group])
end

project.save
puts "✅ App icons and asset catalog added to Xcode project!" 