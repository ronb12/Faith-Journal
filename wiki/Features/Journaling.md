# Journaling Features

This document describes the journaling functionality in Faith Journal.

## Overview

The journaling feature allows users to create, organize, and manage personal journal entries with rich media support, mood tracking, and privacy controls.

## Core Features

### Creating Journal Entries

Users can create journal entries with:

- **Text Content**: Rich text journal entries
- **Title**: Optional entry title
- **Tags**: Multiple tags for organization
- **Mood**: Associate mood with entry
- **Location**: Optional location information
- **Privacy**: Mark entries as private (Face ID protected)
- **Media**: Attach photos, voice notes, and drawings

### Media Support

#### Photos
- Take photos with camera
- Select from photo library
- Multiple photos per entry
- Automatic compression and optimization

#### Voice Notes
- Record voice notes
- Attach to journal entries
- Playback within entry view

#### Drawings
- Create drawings with PencilKit
- Save drawings as part of entry
- Edit drawings later

### Organizing Entries

#### Search
- Full-text search across entries
- Search by title, content, or tags
- Case-insensitive search

#### Filtering
- Filter by privacy status (private/public)
- Filter by mood
- Filter by media type (with photos, with audio, with drawings)
- Filter by date range

#### Sorting
- Sort by date (newest/oldest first)
- Sort by title (alphabetical)
- Sort by mood

### Privacy Features

#### Private Entries
- Mark entries as private
- Face ID/Touch ID protection
- Private entries excluded from sharing

#### Data Security
- Local encryption for private entries
- CloudKit encryption for synced data
- No data sharing without user consent

## User Interface

### Journal View

The main journal view displays:

- **Entry List**: Chronological list of entries
- **Search Bar**: Quick search functionality
- **Filter Button**: Access to filtering options
- **New Entry Button**: Create new entry

### Entry Detail View

Shows full entry details:

- Entry title and content
- Date and time
- Tags and mood
- Attached media (photos, audio, drawings)
- Edit and delete options

### Entry Editor

Rich editing interface:

- Title input
- Content editor (supports formatting)
- Tag management
- Mood selector
- Media attachment buttons
- Privacy toggle
- Save and cancel buttons

## Data Model

See [JournalEntry Model](Data-Models.md#journalentry) for complete data structure.

## Technical Implementation

### SwiftData Integration

```swift
@Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) 
var entries: [JournalEntry]
```

### CloudKit Sync

Journal entries automatically sync via CloudKit:
- Private entries sync to private CloudKit database
- Public entries sync to public database (if applicable)
- Automatic conflict resolution

### Performance

- **Lazy Loading**: Entries load on demand
- **Pagination**: Large entry lists are paginated
- **Image Caching**: Photos are cached locally
- **Background Sync**: CloudKit syncs in background

## Export Functionality

Users can export journal entries:

- **PDF Export**: Generate PDF of entries
- **Text Export**: Export as plain text
- **Share Sheet**: Share via iOS share sheet
- **Email**: Send entries via email

## Statistics

Journal entries contribute to:

- **Entry Count**: Total number of entries
- **Writing Streak**: Consecutive days with entries
- **Mood Trends**: Mood analytics over time
- **Tag Usage**: Most used tags

## Best Practices

### For Users

1. **Regular Journaling**: Write regularly for best experience
2. **Use Tags**: Organize entries with tags
3. **Track Mood**: Associate moods for analytics
4. **Backup**: Entries sync automatically to iCloud

### For Developers

1. **Validate Input**: Always validate user input
2. **Handle Errors**: Gracefully handle save errors
3. **Optimize Images**: Compress images before saving
4. **Respect Privacy**: Never share private entries

## Related Features

- [Prayer Features](Prayer.md)
- [Mood Analytics](Mood-Analytics.md)
- [Statistics View](../Features/Statistics.md)

## Related Documentation

- [Data Models](../Data-Models.md)
- [Architecture](../Architecture.md)
- [UI Components](../UI-Components.md)

