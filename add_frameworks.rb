#!/usr/bin/env ruby
require 'xcodeproj'

# Open the project
project_path = 'Faith Journal.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Add frameworks
frameworks = [
  'SwiftUI',
  'SwiftData',
  'Foundation',
  'AVFoundation',
  'PhotosUI',
  'PencilKit',
  'Charts',
  'LocalAuthentication',
  'UniformTypeIdentifiers'
]

frameworks.each do |framework_name|
  # Create file reference for framework
  framework_ref = project.frameworks_group.new_file("System/Library/Frameworks/#{framework_name}.framework")
  
  # Add framework to target
  target.frameworks_build_phase.add_file_reference(framework_ref)
end

# Save the project
project.save

puts "Frameworks added successfully" 