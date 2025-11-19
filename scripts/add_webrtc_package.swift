#!/usr/bin/env ruby

require 'xcodeproj'

puts "Adding WebRTC package to Xcode project..."

# Project paths
project_path = 'Faith Journal/Faith Journal.xcodeproj'

# Open the project
project = Xcodeproj::Project.open(project_path)
main_target = project.targets.find { |t| t.name == 'Faith Journal' }

if main_target.nil?
  puts "Error: Could not find 'Faith Journal' target"
  exit 1
end

# Add package reference
package_reference = project.new_remote_swift_package_reference(
  'https://github.com/stasel/WebRTC',
  requirement: Xcodeproj::Project::Object::XCRemoteSwiftPackageReference::Requirement.up_to_next_major_version('117.0.0')
)

# Add package product dependency
package_product = main_target.new_swift_package_product_dependency('WebRTC', package_reference)

puts "WebRTC package added successfully!"
puts "You may need to clean and rebuild the project." 