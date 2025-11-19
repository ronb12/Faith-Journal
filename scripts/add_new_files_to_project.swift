#!/usr/bin/env ruby

require 'xcodeproj'

puts "Adding new feature files to Xcode project..."

# Project paths
project_path = 'Faith Journal/Faith Journal.xcodeproj'

# Files to add
new_files = [
    'Faith Journal/Faith Journal/WebRTCManager.swift',
    'Faith Journal/Faith Journal/LiveStreamView.swift',
    'Faith Journal/Faith Journal/SubscriptionManager.swift',
    'Faith Journal/Faith Journal/PremiumFeatureManager.swift',
    'Faith Journal/Faith Journal/CloudBackupManager.swift',
    'Faith Journal/Faith Journal/AnalyticsView.swift'
]

# Open the project
project = Xcodeproj::Project.open(project_path)
main_target = project.targets.find { |t| t.name == 'Faith Journal' }

if main_target.nil?
  puts "Error: Could not find 'Faith Journal' target"
  exit 1
end

# Find the main group (Faith Journal)
main_group = project.main_group.find_subpath('Faith Journal')

if main_group.nil?
  puts "Error: Could not find main group"
  exit 1
end

# Add each file
new_files.each do |file_path|
  if File.exist?(file_path)
    # Create file reference
    file_ref = main_group.new_reference(file_path)
    
    # Add to target
    main_target.add_file_references([file_ref])
    
    puts "Added: #{file_path}"
  else
    puts "Warning: File not found: #{file_path}"
  end
end

# Save the project
project.save

puts "Files added successfully!"
puts "You may need to clean and rebuild the project." 