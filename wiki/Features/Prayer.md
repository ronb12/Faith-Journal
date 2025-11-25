# Prayer Features

This document describes the prayer request management functionality in Faith Journal.

## Overview

The prayer feature allows users to create, track, and manage prayer requests with status tracking, answer recording, and organization tools.

## Core Features

### Creating Prayer Requests

Users can create prayer requests with:

- **Title**: Brief title for the request
- **Details**: Detailed description
- **Tags**: Multiple tags for organization
- **Privacy**: Mark as private or shareable
- **Date**: Creation date (automatic)

### Prayer Status Tracking

#### Status Types

1. **Active**: Currently praying for this request
2. **Answered**: Prayer has been answered
3. **Archived**: Request is archived

#### Status Management

- Change status at any time
- Automatic date tracking for status changes
- Visual indicators for each status

### Answer Tracking

When a prayer is answered:

- **Mark as Answered**: Change status to "Answered"
- **Answer Date**: Automatic date recording
- **Answer Notes**: Add notes about how prayer was answered
- **Celebration**: Visual celebration when answered

### Organizing Prayers

#### Search
- Search by title or details
- Search by tags
- Full-text search

#### Filtering
- Filter by status (active, answered, archived)
- Filter by privacy (private/public)
- Filter by tags
- Filter by date range

#### Sorting
- Sort by date (newest/oldest)
- Sort by status
- Sort by title

## User Interface

### Prayer View

The main prayer view displays:

- **Prayer List**: List of all prayer requests
- **Status Tabs**: Quick filter by status
- **Search Bar**: Search functionality
- **New Prayer Button**: Create new request

### Prayer Detail View

Shows full prayer details:

- Title and details
- Status and dates
- Tags
- Answer information (if answered)
- Edit and delete options

### Prayer Editor

Editing interface:

- Title input
- Details editor
- Tag management
- Privacy toggle
- Status selector
- Save and cancel buttons

## Data Model

See [PrayerRequest Model](../Data-Models.md#prayerrequest) for complete data structure.

## Technical Implementation

### SwiftData Integration

```swift
@Query(sort: [SortDescriptor(\PrayerRequest.date, order: .reverse)]) 
var prayers: [PrayerRequest]
```

### Status Management

```swift
enum PrayerStatus: String, CaseIterable, Codable {
    case active = "Active"
    case answered = "Answered"
    case archived = "Archived"
}
```

### CloudKit Sync

Prayer requests sync automatically:
- Private requests sync to private CloudKit database
- Automatic conflict resolution
- Offline support with sync when online

## Statistics

Prayer requests contribute to:

- **Total Requests**: Count of all requests
- **Active Requests**: Currently active prayers
- **Answered Requests**: Count of answered prayers
- **Answer Rate**: Percentage of answered prayers
- **Prayer Streak**: Consecutive days with prayers

## Notifications

### Prayer Reminders

Users can set reminders:

- **Daily Reminders**: Remind to pray daily
- **Request-Specific**: Reminders for specific requests
- **Answer Celebrations**: Notifications when prayers are answered

## Export Functionality

Users can export prayer requests:

- **PDF Export**: Generate PDF report
- **Text Export**: Export as text file
- **Share Sheet**: Share via iOS share sheet
- **Email**: Send requests via email

## Best Practices

### For Users

1. **Be Specific**: Write clear, specific prayer requests
2. **Update Status**: Keep status current
3. **Record Answers**: Document when prayers are answered
4. **Use Tags**: Organize with tags for easy finding

### For Developers

1. **Validate Input**: Always validate user input
2. **Handle Errors**: Gracefully handle save errors
3. **Respect Privacy**: Never share private requests
4. **Update Timestamps**: Automatically update dates

## Related Features

- [Journaling Features](Journaling.md)
- [Statistics View](Statistics.md)
- [Notifications](../Services-and-Managers.md#notificationservice)

## Related Documentation

- [Data Models](../Data-Models.md)
- [Architecture](../Architecture.md)
- [UI Components](../UI-Components.md)

