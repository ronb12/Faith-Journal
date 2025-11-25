# Services and Managers

This document describes all service classes and managers used in the Faith Journal app.

## Overview

Services and managers encapsulate business logic and provide reusable functionality across the app. They follow the singleton pattern for global access or are injected as dependencies.

## Core Services

### BibleService

Manages Bible verse fetching from external APIs.

**Location**: `Services/BibleService.swift`

**Key Features:**
- Fetches verses by reference (e.g., "John 3:16")
- Supports multiple translations (WEB, NIV, KJV, ESV, NLT, NASB, MSG, AMP, CSB)
- Caches verses locally
- Handles API errors gracefully

**Usage:**
```swift
let service = BibleService.shared
let verse = try await service.fetchVerse(reference: "John 3:16", translation: "NIV")
```

**Properties:**
- `isLoading`: Published boolean indicating loading state
- `errorMessage`: Published optional string for error messages
- `selectedTranslation`: Current translation preference
- `availableTranslations`: Dictionary of available translations

### BibleVerseOfTheDayManager

Manages daily Bible verse display.

**Location**: `Services/BibleVerseOfTheDayManager.swift`

**Key Features:**
- Provides daily verse rotation
- Maintains a collection of curated verses
- Selects verse based on day of year for consistency

**Usage:**
```swift
@StateObject private var manager = BibleVerseOfTheDayManager()
// Access currentVerse property
```

**Properties:**
- `currentVerse`: Published optional BibleVerse
- `isLoading`: Published boolean
- `errorMessage`: Published optional string

**Methods:**
- `loadTodaysVerse()`: Loads today's verse
- `refreshVerse()`: Refreshes the current verse

### DevotionalManager

Manages devotional content.

**Location**: `Services/DevotionalManager.swift`

**Key Features:**
- Provides sample devotionals by category
- Filters devotionals by category
- Tracks completion status

**Usage:**
```swift
@StateObject private var manager = DevotionalManager()
let devotionals = manager.filteredDevotionals()
```

**Properties:**
- `devotionals`: Published array of Devotional objects
- `selectedCategory`: Published string for filtering
- `isLoading`: Published boolean
- `categories`: Array of available categories

**Methods:**
- `loadDevotionals()`: Loads all devotionals
- `filteredDevotionals()`: Returns filtered devotionals
- `markAsCompleted(_:)`: Marks a devotional as completed
- `getTodaysDevotional()`: Returns today's devotional

### BibleStudyService

Manages Bible study topics and content.

**Location**: `Services/BibleStudyService.swift`

**Key Features:**
- Provides Bible study topics
- Manages study progress
- Organizes topics by category

### BibleService_WEB

Web-based Bible service implementation.

**Location**: `Services/BibleService_WEB.swift`

**Key Features:**
- Fetches verses from World English Bible API
- Handles web-specific API calls
- Parses JSON responses

## CloudKit Services

### CloudKitUserService

Manages CloudKit user authentication and data.

**Location**: `Services/CloudKitUserService.swift`

**Key Features:**
- Handles iCloud authentication
- Manages user identity
- Syncs user-specific data

**Usage:**
```swift
let service = CloudKitUserService.shared
let userID = try await service.getCurrentUserID()
```

### CloudKitPublicSyncService

Manages public CloudKit database synchronization.

**Location**: `Services/CloudKitPublicSyncService.swift`

**Key Features:**
- Syncs public content (devotionals, verses)
- Handles public database operations
- Manages shared resources

## Notification Service

### NotificationService

Manages push notifications and local notifications.

**Location**: `Services/NotificationService.swift`

**Key Features:**
- Schedules local notifications
- Handles notification permissions
- Manages notification categories

**Usage:**
```swift
let service = NotificationService.shared
await service.requestAuthorization()
await service.scheduleDailyVerseNotification()
```

**Methods:**
- `requestAuthorization()`: Requests notification permissions
- `scheduleDailyVerseNotification()`: Schedules daily verse notifications
- `schedulePrayerReminder(_:)`: Schedules prayer reminders
- `cancelNotification(_:)`: Cancels a notification

## Prompt Manager

### PromptManager

Manages journal prompts.

**Location**: `Services/PromptManager.swift`

**Key Features:**
- Provides journal prompts
- Tracks prompt usage
- Suggests prompts based on context

**Usage:**
```swift
let manager = PromptManager.shared
let prompt = manager.getRandomPrompt()
```

## Utility Services

### ThemeManager

Manages app theming and appearance.

**Location**: `Utils/ThemeManager.swift`

**Key Features:**
- Provides theme colors
- Manages light/dark mode
- Customizes app appearance

**Usage:**
```swift
@ObservedObject private var themeManager = ThemeManager.shared
// Access theme colors
```

**Properties:**
- `isDarkMode`: Published boolean
- `primaryColor`: Published color
- `accentColor`: Published color

### ErrorHandler

Centralized error handling utility.

**Location**: `Utils/ErrorHandler.swift`

**Key Features:**
- Logs errors consistently
- Provides user-friendly error messages
- Handles different error types

**Usage:**
```swift
ErrorHandler.handle(error, context: "BibleService")
```

**Methods:**
- `handle(_:context:)`: Handles and logs errors
- `userFriendlyMessage(for:)`: Returns user-friendly error message

### ExportHelper

Handles data export functionality.

**Location**: `Utils/ExportHelper.swift`

**Key Features:**
- Exports journal entries
- Exports prayer requests
- Generates PDF reports
- Shares data via share sheet

**Usage:**
```swift
let helper = ExportHelper()
try await helper.exportJournalEntries(entries)
```

**Methods:**
- `exportJournalEntries(_:)`: Exports journal entries
- `exportPrayerRequests(_:)`: Exports prayer requests
- `generatePDFReport(_:)`: Generates PDF report
- `shareData(_:)`: Shares data via share sheet

## Service Lifecycle

### Initialization

Services are initialized in one of three ways:

1. **Singleton Pattern**: `static let shared = ServiceName()`
2. **StateObject**: `@StateObject private var service = ServiceName()`
3. **Dependency Injection**: Passed as parameter

### Memory Management

- Services use `ObservableObject` for reactive updates
- Published properties trigger view updates
- Services are retained by their owners (views or app)

## Best Practices

1. **Single Responsibility**: Each service has one clear purpose
2. **Error Handling**: All services handle errors gracefully
3. **Async/Await**: Use async/await for network operations
4. **Published Properties**: Use `@Published` for reactive state
5. **Thread Safety**: Ensure thread-safe operations

## Testing Services

Services should be testable:

```swift
// Mock service for testing
class MockBibleService: BibleServiceProtocol {
    func fetchVerse(reference: String) async throws -> BibleVerseResponse {
        return BibleVerseResponse(reference: reference, text: "Test", translation: "NIV")
    }
}
```

## Related Documentation

- [Architecture](Architecture.md)
- [Data Models](Data-Models.md)
- [API Documentation](API/Bible-Service.md)
- [Testing Guide](Development/Testing-Guide.md)

