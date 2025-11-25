# CloudKit Integration

This document describes CloudKit integration in Faith Journal.

## Overview

Faith Journal uses CloudKit for data synchronization across devices, providing seamless cloud backup and multi-device access.

## CloudKit Setup

### Capabilities

The app requires the following CloudKit capabilities:

1. **CloudKit**: Enabled in Signing & Capabilities
2. **iCloud**: User must be signed into iCloud
3. **Push Notifications**: For sync notifications

### Container Configuration

**Container ID**: `iCloud.com.ronellbradley.FaithJournal`

Configured in:
- Xcode: Signing & Capabilities
- Entitlements file: `Faith Journal.entitlements`

## Database Types

### Private Database

Stores user-specific data:

- Journal entries (private)
- Prayer requests (private)
- User profile
- Mood entries
- Personal bookmarks

**Access**: Only accessible by the user who created it

### Public Database

Stores shared content:

- Public devotionals
- Bible study topics
- Shared reading plans

**Access**: Readable by all users, writable by authorized users

## SwiftData Integration

### Model Configuration

```swift
let schema = Schema([
    JournalEntry.self,
    PrayerRequest.self,
    UserProfile.self,
    // ... other models
])

let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .automatic
)
```

### Automatic Sync

SwiftData automatically syncs models to CloudKit when:

1. CloudKit capability is enabled
2. User is signed into iCloud
3. Model is included in schema
4. Network connection is available

## Sync Behavior

### Automatic Sync

- **On Save**: Changes sync immediately
- **On Launch**: App syncs on launch
- **Background**: Periodic background sync
- **Push Notifications**: Sync triggered by push notifications

### Conflict Resolution

CloudKit handles conflicts automatically:

- **Last Write Wins**: Most recent change takes precedence
- **Automatic Merging**: Non-conflicting changes are merged
- **User Notification**: Users are notified of conflicts

## Services

### CloudKitUserService

Manages user authentication and identity.

**Location**: `Services/CloudKitUserService.swift`

**Key Methods**:
```swift
func getCurrentUserID() async throws -> String
func checkAuthenticationStatus() async -> Bool
```

### CloudKitPublicSyncService

Manages public database synchronization.

**Location**: `Services/CloudKitPublicSyncService.swift`

**Key Methods**:
```swift
func syncPublicContent() async throws
func fetchPublicDevotionals() async throws -> [Devotional]
```

## Data Models

All SwiftData models automatically sync to CloudKit:

- `JournalEntry`
- `PrayerRequest`
- `UserProfile`
- `MoodEntry`
- `BibleVerseOfTheDay`
- `BookmarkedVerse`
- `LiveSession`
- And more...

## Privacy

### Private Data

- Journal entries marked as private
- Private prayer requests
- User profile information
- Personal mood entries

**Storage**: Private CloudKit database
**Access**: Only the creating user

### Public Data

- Public devotionals
- Shared Bible study topics
- Public reading plans

**Storage**: Public CloudKit database
**Access**: All users (read), authorized users (write)

## Error Handling

### Common Errors

1. **Authentication Required**: User not signed into iCloud
2. **Network Error**: No internet connection
3. **Quota Exceeded**: CloudKit storage quota exceeded
4. **Permission Denied**: Insufficient permissions

### Error Handling Example

```swift
do {
    try await syncData()
} catch {
    if let ckError = error as? CKError {
        switch ckError.code {
        case .notAuthenticated:
            // Prompt user to sign in
        case .networkUnavailable:
            // Show offline message
        case .quotaExceeded:
            // Show storage limit message
        default:
            // Handle other errors
        }
    }
}
```

## Performance

### Optimization

1. **Batch Operations**: Group multiple changes
2. **Lazy Loading**: Load data on demand
3. **Caching**: Cache frequently accessed data
4. **Background Sync**: Sync in background

### Monitoring

Monitor sync performance:

- Sync duration
- Data transfer size
- Error rates
- User experience

## Testing

### Simulator Testing

1. Sign into iCloud on simulator
2. Enable CloudKit in capabilities
3. Test sync between simulators

### Device Testing

1. Test on multiple devices
2. Test offline/online scenarios
3. Test conflict resolution
4. Test large data sets

## Troubleshooting

### Common Issues

1. **Sync Not Working**
   - Check iCloud sign-in
   - Verify CloudKit capability
   - Check network connection

2. **Data Not Appearing**
   - Wait for sync to complete
   - Check CloudKit dashboard
   - Verify model configuration

3. **Conflicts**
   - Review conflict resolution logic
   - Test with multiple devices
   - Check timestamps

## Best Practices

1. **Always Handle Errors**: CloudKit operations can fail
2. **Show Sync Status**: Inform users of sync state
3. **Optimize Data Size**: Keep models efficient
4. **Respect Privacy**: Only sync appropriate data
5. **Test Thoroughly**: Test all sync scenarios

## Related Documentation

- [Data Models](../Data-Models.md)
- [Architecture](../Architecture.md)
- [Services and Managers](../Services-and-Managers.md)

