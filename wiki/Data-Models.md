# Data Models

This document describes all SwiftData models used in the Faith Journal app.

## Overview

All data models use SwiftData's `@Model` macro, which provides:
- Automatic persistence
- CloudKit synchronization
- Relationship management
- Change tracking

## Core Models

### JournalEntry

Represents a journal entry created by the user.

```swift
@Model
final class JournalEntry {
    var id: UUID
    var title: String
    var content: String
    var date: Date
    var tags: [String]
    var mood: String?
    var location: String?
    var isPrivate: Bool
    var audioURL: URL?
    var photoURLs: [URL]
    var drawingData: Data?
    var createdAt: Date
    var updatedAt: Date
}
```

**Properties:**
- `id`: Unique identifier
- `title`: Entry title
- `content`: Entry text content
- `date`: Entry date
- `tags`: Array of tags for categorization
- `mood`: Optional mood associated with entry
- `location`: Optional location
- `isPrivate`: Whether entry is private
- `audioURL`: Optional voice note URL
- `photoURLs`: Array of photo URLs
- `drawingData`: Optional drawing data (PencilKit)
- `createdAt`: Creation timestamp
- `updatedAt`: Last update timestamp

### PrayerRequest

Represents a prayer request.

```swift
@Model
final class PrayerRequest {
    var id: UUID
    var title: String
    var details: String
    var date: Date
    var status: PrayerStatus
    var isAnswered: Bool
    var answerDate: Date?
    var answerNotes: String?
    var isPrivate: Bool
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    
    enum PrayerStatus: String, CaseIterable, Codable {
        case active = "Active"
        case answered = "Answered"
        case archived = "Archived"
    }
}
```

**Properties:**
- `status`: Current status (active, answered, archived)
- `isAnswered`: Whether prayer has been answered
- `answerDate`: Date when prayer was answered
- `answerNotes`: Notes about the answer

### UserProfile

Represents user profile information.

```swift
@Model
final class UserProfile {
    var id: UUID
    var name: String
    var email: String?
    var profileImageURL: URL?
    var preferences: [String: String]
    var createdAt: Date
    var updatedAt: Date
}
```

### MoodEntry

Tracks user's mood over time.

```swift
@Model
final class MoodEntry {
    var id: UUID
    var mood: String
    var date: Date
    var notes: String?
    var createdAt: Date
}
```

## Bible Study Models

### BibleVerseOfTheDay

Stores daily Bible verse.

```swift
@Model
final class BibleVerseOfTheDay {
    var id: UUID
    var reference: String
    var text: String
    var translation: String
    var date: Date
    var isBookmarked: Bool
}
```

### BookmarkedVerse

User's bookmarked Bible verses.

```swift
@Model
final class BookmarkedVerse {
    var id: UUID
    var reference: String
    var text: String
    var translation: String
    var notes: String?
    var createdAt: Date
}
```

### Devotional

Represents a devotional entry.

```swift
struct Devotional: Identifiable, Codable {
    var id: UUID
    let title: String
    let scripture: String
    let content: String
    let author: String
    let date: Date
    let category: String
    let isCompleted: Bool
}
```

**Note**: `Devotional` is a struct, not a SwiftData model, as it's fetched from external sources.

### BibleStudyTopic

Represents a Bible study topic.

```swift
@Model
final class BibleStudyTopic {
    var id: UUID
    var title: String
    var description: String
    var verses: [String]
    var notes: String?
    var createdAt: Date
}
```

### ReadingPlan

Represents a Bible reading plan.

```swift
@Model
final class ReadingPlan {
    var id: UUID
    var title: String
    var description: String
    var startDate: Date
    var endDate: Date
    var dailyReadings: [String]
    var progress: [String: Bool]
    var createdAt: Date
}
```

## Social Features Models

### LiveSession

Represents a live faith session.

```swift
@Model
final class LiveSession {
    var id: UUID
    var title: String
    var details: String
    var hostId: String
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    var maxParticipants: Int
    var currentParticipants: Int
    var category: String
    var tags: [String]
    var isPrivate: Bool
    var createdAt: Date
}
```

### LiveSessionParticipant

Represents a participant in a live session.

```swift
@Model
final class LiveSessionParticipant {
    var id: UUID
    var sessionId: UUID
    var userId: String
    var joinedAt: Date
    var role: ParticipantRole
    
    enum ParticipantRole: String, Codable {
        case host = "Host"
        case participant = "Participant"
    }
}
```

### ChatMessage

Represents a chat message in a live session.

```swift
@Model
final class ChatMessage {
    var id: UUID
    var sessionId: UUID
    var userId: String
    var userName: String
    var message: String
    var timestamp: Date
}
```

### SessionInvitation

Represents an invitation to a live session.

```swift
@Model
final class SessionInvitation {
    var id: UUID
    var sessionId: UUID
    var inviterId: String
    var inviteeId: String
    var status: InvitationStatus
    var createdAt: Date
    
    enum InvitationStatus: String, Codable {
        case pending = "Pending"
        case accepted = "Accepted"
        case declined = "Declined"
    }
}
```

## Subscription Model

### Subscription

Represents user subscription information.

```swift
@Model
final class Subscription {
    var id: UUID
    var userId: String
    var planType: SubscriptionPlan
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var autoRenew: Bool
    
    enum SubscriptionPlan: String, Codable {
        case free = "Free"
        case premium = "Premium"
        case lifetime = "Lifetime"
    }
}
```

## Prompt Model

### JournalPrompt

Represents a journal prompt.

```swift
@Model
final class JournalPrompt {
    var id: UUID
    var prompt: String
    var category: String
    var isUsed: Bool
    var usedDate: Date?
    var createdAt: Date
}
```

## Relationships

SwiftData automatically manages relationships between models. Key relationships:

- **UserProfile** → **JournalEntry** (one-to-many)
- **UserProfile** → **PrayerRequest** (one-to-many)
- **UserProfile** → **MoodEntry** (one-to-many)
- **LiveSession** → **LiveSessionParticipant** (one-to-many)
- **LiveSession** → **ChatMessage** (one-to-many)

## CloudKit Schema

All models are automatically synced to CloudKit when:
1. CloudKit capability is enabled
2. Model is included in the SwiftData schema
3. User is signed into iCloud

## Data Validation

Models should validate data in their initializers:

```swift
init(title: String, content: String) {
    guard !title.isEmpty else {
        fatalError("Title cannot be empty")
    }
    self.title = title
    self.content = content
    // ...
}
```

## Migration

When models change, SwiftData handles migration automatically. For complex changes, use:

```swift
let configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .automatic
)
```

## Best Practices

1. **Use UUIDs**: All models use UUID for unique identification
2. **Timestamps**: Include `createdAt` and `updatedAt` for tracking
3. **Optional Properties**: Use optionals for non-required fields
4. **Enums**: Use enums for constrained values (status, type, etc.)
5. **Arrays**: Use arrays for collections (tags, URLs, etc.)

## Related Documentation

- [Architecture](Architecture.md)
- [CloudKit Integration](API/CloudKit-Integration.md)
- [Services and Managers](Services-and-Managers.md)

