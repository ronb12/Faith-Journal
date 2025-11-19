#!/usr/bin/env ruby

puts "Adding files manually to project file..."

# Helper function to get file type
def get_file_type(file_path)
  case File.extname(file_path)
  when '.swift'
    'sourcecode.swift'
  when '.plist'
    'text.plist.xml'
  when '.xcassets'
    'folder.assetcatalog'
  when '.storyboard'
    'file.storyboard'
  when '.xib'
    'file.xib'
  else
    'text'
  end
end

# Read the project file
project_file = 'Faith Journal/Faith Journal.xcodeproj/project.pbxproj'
content = File.read(project_file)

# Files to add
files_to_add = [
  'Faith Journal/Faith_JournalApp.swift',
  'Faith Journal/ContentView.swift',
  'Faith Journal/JournalView.swift',
  'Faith Journal/NewJournalEntryView.swift',
  'Faith Journal/PrayerView.swift',
  'Faith Journal/NewPrayerRequestView.swift',
  'Faith Journal/SearchView.swift',
  'Faith Journal/SettingsView.swift',
  'Faith Journal/VoiceToTextView.swift',
  'Faith Journal/MoodHistoryView.swift',
  'Faith Journal/BibleVerseView.swift',
  'Faith Journal/BibleVerseOfTheDayManager.swift',
  'Faith Journal/ThemeManager.swift',
  'Faith Journal/PrayerReminderManager.swift',
  'Faith Journal/DevotionalManager.swift',
  'Faith Journal/WebRTCManager.swift',
  'Faith Journal/LiveStreamView.swift',
  'Faith Journal/LiveStreamsView.swift',
  'Faith Journal/LiveStreamManager.swift',
  'Faith Journal/SharedComponents.swift',
  'Faith Journal/JournalEntry.swift',
  'Faith Journal/PrayerRequest.swift',
  'Faith Journal/Devotional.swift',
  'Faith Journal/LiveSession.swift',
  'Faith Journal/UserProfile.swift',
  'Faith Journal/Subscription.swift',
  'Faith Journal/MoodEntry.swift',
  'Faith Journal/LiveSessionParticipant.swift',
  'Faith Journal/ChatMessage.swift',
  'Faith Journal/BibleVerseOfTheDay.swift',
  'Faith Journal/Item.swift',
  'Faith Journal/Assets.xcassets',
  'Faith Journal/Preview Content',
  'Info.plist'
]

# Generate UUIDs for new file references
require 'securerandom'
def generate_uuid
  SecureRandom.uuid.upcase.gsub('-', '')
end

# Find the main group section
main_group_match = content.match(/(47201AA02E11CDF700540883 \/\* Faith Journal \*\/ = \{[\s\S]*?\};)/)

if main_group_match
  main_group_content = main_group_match[1]
  
  # Add file references to the main group
  file_refs = []
  files_to_add.each do |file_path|
    uuid = generate_uuid
    file_refs << "#{uuid} /* #{File.basename(file_path)} */ = {isa = PBXFileReference; lastKnownFileType = #{get_file_type(file_path)}; name = \"#{File.basename(file_path)}\"; path = \"#{file_path}\"; sourceTree = \"<group>\"; };"
  end
  
  # Insert file references before the main group
  file_refs_section = "/* Begin PBXFileReference section */\n" + file_refs.join("\n") + "\n/* End PBXFileReference section */\n"
  
  # Find where to insert the file references
  if content.include?("/* Begin PBXFileReference section */")
    # Replace existing section
    content.gsub!(/\/\* Begin PBXFileReference section \*\/[\s\S]*?\/\* End PBXFileReference section \*\//, file_refs_section)
  else
    # Insert new section before main group
    content.gsub!(/(47201AA02E11CDF700540883 \/\* Faith Journal \*\/ = \{)/, file_refs_section + "\n" + main_group_match[1])
  end
  
  puts "Added file references to project"
else
  puts "Could not find main group in project file"
  exit 1
end

# Write the updated content back
File.write(project_file, content)
puts "Project file updated successfully!"
puts "Files have been added to the project."
puts "You may need to refresh Xcode (Cmd+R) to see the changes." 