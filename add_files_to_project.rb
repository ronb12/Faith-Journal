#!/usr/bin/env ruby
require 'xcodeproj'

# Open the Xcode project
project_path = 'Faith Journal/Faith Journal.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
main_target = project.targets.first

# Get the Views group
views_group = project.main_group.find_subpath('Views', true)
components_group = views_group.find_subpath('Components', true)

# List of view files to add
view_files = [
  'OnboardingView.swift',
  'FaithStatsView.swift',
  'DevotionalsView.swift',
  'PrayerRequestsView.swift',
  'BadgesView.swift',
  'AudioRecordingView.swift',
  'DrawingView.swift',
  'NewJournalEntryView.swift',
  'BiometricLockView.swift',
  'JournalFilterView.swift',
  'VerseMemorizationView.swift',
  'BibleReadingPlanView.swift'
]

# List of component files to add
component_files = [
  'UserAvatarView.swift',
  'AttachmentSelectionView.swift',
  'TemplateSelectionView.swift',
  'TagPickerView.swift'
]

# Add view files
view_files.each do |file|
  file_path = "Faith Journal/Views/#{file}"
  if File.exist?(file_path)
    file_ref = views_group.new_reference(file_path)
    main_target.add_file_references([file_ref])
    puts "Added #{file} to project"
  else
    puts "Warning: #{file} not found"
  end
end

# Add component files
component_files.each do |file|
  file_path = "Faith Journal/Views/Components/#{file}"
  if File.exist?(file_path)
    file_ref = components_group.new_reference(file_path)
    main_target.add_file_references([file_ref])
    puts "Added #{file} to project"
  else
    puts "Warning: #{file} not found"
  end
end

# Save the project
project.save 