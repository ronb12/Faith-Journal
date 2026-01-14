#!/usr/bin/env ruby
# encoding: utf-8

require 'xcodeproj'

begin
  project_path = 'Faith Journal.xcodeproj'
  project = Xcodeproj::Project.open(project_path)
  
  target = project.targets.find { |t| t.name == 'Faith Journal' }
  unless target
    puts "❌ Target 'Faith Journal' not found"
    exit 1
  end
  
  # Files to add with their paths relative to project root
  files_to_add = [
    { path: 'Faith Journal/Faith Journal/Models/SessionRating.swift', group: 'Models' },
    { path: 'Faith Journal/Faith Journal/Models/SessionClip.swift', group: 'Models' },
    { path: 'Faith Journal/Faith Journal/Services/TranslationService.swift', group: 'Services' },
    { path: 'Faith Journal/Faith Journal/Services/SessionRecommendationService.swift', group: 'Services' },
    { path: 'Faith Journal/Faith Journal/Views/WaitingRoomView.swift', group: 'Views' },
    { path: 'Faith Journal/Faith Journal/Views/SessionClipsView.swift', group: 'Views' },
    { path: 'Faith Journal/Faith Journal/Views/TranslationSettingsView.swift', group: 'Views' },
  ]
  
  # Find main group - it's the root group
  main_group = project.main_group
  
  added_count = 0
  skipped_count = 0
  
  files_to_add.each do |file_info|
    file_path = file_info[:path]
    group_name = file_info[:group]
    
    # Check if file exists
    unless File.exist?(file_path)
      puts "⚠️  File does not exist: #{file_path}"
      skipped_count += 1
      next
    end
    
    # Find or create the group
    # Since it's file system synchronized, groups might not exist in traditional sense
    # Try to find the group in the main group
    group = main_group[group_name] || main_group.new_group(group_name, 'Faith Journal/Faith Journal/' + group_name)
    
    # Check if file reference already exists
    file_name = File.basename(file_path)
    existing_ref = group.files.find { |f| f.path == file_name || f.real_path == File.expand_path(file_path) }
    
    if existing_ref
      # Check if it's in the target
      if target.source_build_phase.files.find { |f| f.file_ref == existing_ref }
        puts "✅ #{file_name} already in project and target"
        skipped_count += 1
        next
      else
        # Add to target
        target.add_file_references([existing_ref])
        puts "✅ #{file_name} added to target"
        added_count += 1
        next
      end
    end
    
    # Create file reference (relative to group)
    file_ref = group.new_file(file_path)
    
    # Add to target
    target.add_file_references([file_ref])
    
    puts "✅ Added #{file_name} to #{group_name}/"
    added_count += 1
  end
  
  if added_count > 0 || skipped_count > 0
    project.save
    puts "\n✅ Project saved!"
    puts "   Added: #{added_count} file(s)"
    puts "   Already present: #{skipped_count} file(s)"
  else
    puts "\n⚠️  No files were added"
  end
  
rescue LoadError => e
  puts "❌ xcodeproj gem not installed"
  puts "   Install with: sudo gem install xcodeproj"
  puts "\n   Error: #{e.message}"
  exit 1
rescue => e
  puts "❌ Error: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  exit 1
end
