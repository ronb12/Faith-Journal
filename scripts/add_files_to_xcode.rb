#!/usr/bin/env ruby

require 'xcodeproj'

puts "Adding files back to Xcode project..."

# Project paths
project_path = 'Faith Journal/Faith Journal.xcodeproj'
source_dir = 'Faith Journal/Faith Journal'

# Open the project
project = Xcodeproj::Project.open(project_path)
main_target = project.targets.find { |t| t.name == 'Faith Journal' }

if main_target.nil?
  puts "Error: Could not find 'Faith Journal' target"
  exit 1
end

# Find or create the main group
main_group = project.main_group.find_subpath('Faith Journal', true)

# Files to add
files_to_add = [
  # Swift files
  'Faith Journal/Faith Journal/Faith_JournalApp.swift',
  'Faith Journal/Faith Journal/ContentView.swift',
  'Faith Journal/Faith Journal/JournalView.swift',
  'Faith Journal/Faith Journal/NewJournalEntryView.swift',
  'Faith Journal/Faith Journal/PrayerView.swift',
  'Faith Journal/Faith Journal/NewPrayerRequestView.swift',
  'Faith Journal/Faith Journal/SearchView.swift',
  'Faith Journal/Faith Journal/SettingsView.swift',
  'Faith Journal/Faith Journal/VoiceToTextView.swift',
  'Faith Journal/Faith Journal/MoodHistoryView.swift',
  'Faith Journal/Faith Journal/BibleVerseView.swift',
  'Faith Journal/Faith Journal/BibleVerseOfTheDayManager.swift',
  'Faith Journal/Faith Journal/ThemeManager.swift',
  'Faith Journal/Faith Journal/PrayerReminderManager.swift',
  'Faith Journal/Faith Journal/DevotionalManager.swift',
  'Faith Journal/Faith Journal/WebRTCManager.swift',
  'Faith Journal/Faith Journal/LiveStreamView.swift',
  'Faith Journal/Faith Journal/LiveStreamsView.swift',
  'Faith Journal/Faith Journal/LiveStreamManager.swift',
  'Faith Journal/Faith Journal/SharedComponents.swift',
  
  # Model files
  'Faith Journal/Faith Journal/JournalEntry.swift',
  'Faith Journal/Faith Journal/PrayerRequest.swift',
  'Faith Journal/Faith Journal/Devotional.swift',
  'Faith Journal/Faith Journal/LiveSession.swift',
  'Faith Journal/Faith Journal/UserProfile.swift',
  'Faith Journal/Faith Journal/Subscription.swift',
  'Faith Journal/Faith Journal/MoodEntry.swift',
  'Faith Journal/Faith Journal/LiveSessionParticipant.swift',
  'Faith Journal/Faith Journal/ChatMessage.swift',
  'Faith Journal/Faith Journal/BibleVerseOfTheDay.swift',
  'Faith Journal/Faith Journal/Item.swift',
  
  # Asset catalogs and other resources
  'Faith Journal/Faith Journal/Assets.xcassets',
  'Faith Journal/Faith Journal/Preview Content',
  'Faith Journal/Info.plist'
]

# Add each file
files_to_add.each do |file_path|
  if File.exist?(file_path)
    begin
      # Check if file is already in project
      existing_file = main_group.files.find { |f| f.path == file_path }
      
      if existing_file.nil?
        # Add the file
        file_ref = main_group.new_file(file_path)
        
        # Add to target if it's a source file
        if file_path.end_with?('.swift') || file_path.end_with?('.plist')
          main_target.add_file_references([file_ref])
        end
        
        puts "Added: #{file_path}"
      else
        puts "Already exists: #{file_path}"
      end
    rescue => e
      puts "Error adding #{file_path}: #{e.message}"
    end
  else
    puts "File not found: #{file_path}"
  end
end

# Save the project
project.save
puts "Project saved successfully!"
puts "All files have been added to the Xcode project."
puts "You may need to refresh Xcode (Cmd+R) to see the changes." 