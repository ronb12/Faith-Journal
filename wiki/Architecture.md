# Architecture

This document provides an overview of the Faith Journal app architecture, design patterns, and code organization.

## Overview

Faith Journal follows a **MVVM (Model-View-ViewModel)** architecture pattern with SwiftUI, leveraging SwiftData for data persistence and CloudKit for cloud synchronization.

## Architecture Layers

```
┌─────────────────────────────────────┐
│         Presentation Layer           │
│  (SwiftUI Views, ViewModels)         │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│         Business Logic Layer         │
│  (Services, Managers, ViewModels)    │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│         Data Layer                   │
│  (SwiftData Models, CloudKit)         │
└─────────────────────────────────────┘
```

## Project Structure

```
Faith Journal/
├── Faith Journal/
│   ├── Faith_JournalApp.swift        # App entry point
│   ├── Models/                        # SwiftData models
│   │   ├── JournalEntry.swift
│   │   ├── PrayerRequest.swift
│   │   ├── UserProfile.swift
│   │   └── ...
│   ├── Views/                         # SwiftUI views
│   │   ├── ContentView.swift
│   │   ├── JournalView.swift
│   │   ├── PrayerView.swift
│   │   └── ...
│   ├── Services/                      # Business logic services
│   │   ├── BibleService.swift
│   │   ├── DevotionalManager.swift
│   │   ├── CloudKitUserService.swift
│   │   └── ...
│   └── Utils/                         # Utilities
│       ├── ThemeManager.swift
│       ├── ErrorHandler.swift
│       └── ExportHelper.swift
├── Faith JournalTests/                # Unit tests
└── Faith JournalUITests/              # UI tests
```

## Design Patterns

### 1. MVVM (Model-View-ViewModel)

- **Models**: SwiftData `@Model` classes representing data entities
- **Views**: SwiftUI views that display UI
- **ViewModels**: Observable objects that manage view state and business logic

**Example:**
```swift
// Model
@Model
final class JournalEntry {
    var title: String
    var content: String
    // ...
}

// ViewModel
class JournalViewModel: ObservableObject {
    @Published var entries: [JournalEntry] = []
    // ...
}

// View
struct JournalView: View {
    @StateObject private var viewModel = JournalViewModel()
    // ...
}
```

### 2. Singleton Pattern

Services that need global access use the singleton pattern:

```swift
class BibleService: ObservableObject {
    static let shared = BibleService()
    private init() {}
}
```

### 3. Service Layer Pattern

Business logic is encapsulated in service classes:

- `BibleService`: Handles Bible verse fetching
- `DevotionalManager`: Manages devotional content
- `CloudKitUserService`: Manages CloudKit synchronization
- `NotificationService`: Handles push notifications

### 4. Repository Pattern (via SwiftData)

SwiftData provides a repository-like interface for data access:

```swift
@Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) 
var entries: [JournalEntry]
```

## Data Flow

### Reading Data

1. **View** requests data from **ViewModel**
2. **ViewModel** queries **SwiftData** via `@Query` or `ModelContext`
3. **SwiftData** returns data from local store or CloudKit
4. **ViewModel** updates `@Published` properties
5. **View** automatically updates via SwiftUI's reactive system

### Writing Data

1. **View** triggers action (e.g., user creates journal entry)
2. **ViewModel** receives action
3. **ViewModel** creates/updates model via `ModelContext`
4. **SwiftData** persists to local store
5. **CloudKit** syncs to cloud (if configured)
6. **View** updates automatically

## State Management

### SwiftUI State

- `@State`: Local view state
- `@StateObject`: Observable object lifecycle managed by view
- `@ObservedObject`: Observable object passed from parent
- `@EnvironmentObject`: Shared observable object via environment
- `@Query`: SwiftData query that automatically updates

### App-Wide State

- `ThemeManager.shared`: Global theme management
- `NotificationService.shared`: Global notification handling
- `PromptManager.shared`: Global prompt management

## CloudKit Integration

### Data Synchronization

1. **Local Storage**: SwiftData stores data locally
2. **CloudKit Sync**: Automatic sync when CloudKit is enabled
3. **Conflict Resolution**: Handled by CloudKit automatically
4. **Offline Support**: App works offline, syncs when online

### CloudKit Schema

The app uses two CloudKit databases:

- **Private Database**: User-specific data (journal entries, prayer requests)
- **Public Database**: Shared content (devotionals, Bible verses)

## Dependency Injection

Dependencies are injected through:

1. **Initializers**: Services passed to view models
2. **Environment Objects**: Shared services via `@EnvironmentObject`
3. **Singletons**: Global services via static shared instances

## Error Handling

Errors are handled through:

1. **ErrorHandler**: Centralized error handling utility
2. **Try-Catch**: Async/await error handling
3. **User Feedback**: Alerts and error messages in UI

## Testing Strategy

- **Unit Tests**: Test business logic in services and view models
- **UI Tests**: Test user interactions and flows
- **Integration Tests**: Test CloudKit synchronization

## Performance Considerations

1. **Lazy Loading**: Views load data on demand
2. **Pagination**: Large lists are paginated
3. **Image Caching**: Images are cached locally
4. **Background Sync**: CloudKit syncs in background

## Security

1. **Data Encryption**: CloudKit encrypts data in transit and at rest
2. **User Privacy**: Private entries are user-specific
3. **Authentication**: iCloud authentication required for sync
4. **Face ID**: Optional biometric authentication for private entries

## Future Improvements

- [ ] Add dependency injection container
- [ ] Implement repository pattern abstraction
- [ ] Add more comprehensive error handling
- [ ] Improve test coverage
- [ ] Add analytics and crash reporting

## Related Documentation

- [Data Models](Data-Models.md)
- [Services and Managers](Services-and-Managers.md)
- [UI Components](UI-Components.md)
- [CloudKit Integration](API/CloudKit-Integration.md)

