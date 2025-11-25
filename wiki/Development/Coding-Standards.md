# Coding Standards

This document outlines the coding standards and best practices for Faith Journal development.

## Swift Style Guide

### General Principles

1. **Clarity**: Code should be clear and readable
2. **Consistency**: Follow established patterns
3. **Simplicity**: Prefer simple solutions
4. **Documentation**: Document complex logic

### Naming Conventions

#### Types
```swift
// ✅ Good
class JournalEntry { }
struct PrayerRequest { }
enum PrayerStatus { }

// ❌ Bad
class journalEntry { }
struct prayer_request { }
```

#### Variables and Functions
```swift
// ✅ Good
var journalEntry: JournalEntry
func createJournalEntry() { }

// ❌ Bad
var JournalEntry: JournalEntry
func CreateJournalEntry() { }
```

#### Constants
```swift
// ✅ Good
let maxEntries = 100
let defaultTheme = "light"

// ❌ Bad
let MAX_ENTRIES = 100
let DefaultTheme = "light"
```

### Code Organization

#### File Structure
```swift
// 1. Imports
import SwiftUI
import SwiftData

// 2. Type definition
struct JournalView: View {
    // 3. Properties
    @Query var entries: [JournalEntry]
    
    // 4. Body
    var body: some View {
        // ...
    }
    
    // 5. Private methods
    private func filterEntries() { }
}
```

#### Property Order
1. `@State` properties
2. `@StateObject` properties
3. `@ObservedObject` properties
4. `@Query` properties
5. `@Environment` properties
6. Regular properties
7. Computed properties

### SwiftUI Best Practices

#### View Composition
```swift
// ✅ Good: Break into smaller views
struct JournalView: View {
    var body: some View {
        VStack {
            HeaderView()
            EntryListView()
            FooterView()
        }
    }
}

// ❌ Bad: Everything in one view
struct JournalView: View {
    var body: some View {
        VStack {
            // 500 lines of code...
        }
    }
}
```

#### State Management
```swift
// ✅ Good: Use appropriate property wrappers
@State private var searchText = ""
@StateObject private var viewModel = JournalViewModel()
@Query var entries: [JournalEntry]

// ❌ Bad: Overuse of @StateObject
@StateObject private var searchText = "" // Should be @State
```

### SwiftData Best Practices

#### Model Definition
```swift
// ✅ Good: Clear model with proper types
@Model
final class JournalEntry {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var date: Date = Date()
}

// ❌ Bad: Unclear types
@Model
final class JournalEntry {
    var id: Any
    var title: Any
}
```

#### Queries
```swift
// ✅ Good: Clear query with sorting
@Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) 
var entries: [JournalEntry]

// ❌ Bad: No sorting
@Query var entries: [JournalEntry]
```

### Error Handling

#### Async/Await
```swift
// ✅ Good: Proper error handling
func fetchVerse() async throws -> BibleVerse {
    do {
        return try await service.fetchVerse(reference: "John 3:16")
    } catch {
        ErrorHandler.handle(error, context: "BibleService")
        throw error
    }
}

// ❌ Bad: Ignoring errors
func fetchVerse() async -> BibleVerse? {
    return try? await service.fetchVerse(reference: "John 3:16")
}
```

### Documentation

#### Function Documentation
```swift
/// Fetches a Bible verse by reference.
/// - Parameters:
///   - reference: The verse reference (e.g., "John 3:16")
///   - translation: Optional translation (defaults to selected translation)
/// - Returns: A BibleVerseResponse containing the verse
/// - Throws: An error if the fetch fails
func fetchVerse(reference: String, translation: String? = nil) async throws -> BibleVerseResponse {
    // Implementation
}
```

### Comments

#### When to Comment
- Complex algorithms
- Business logic that's not obvious
- Workarounds for bugs
- Public API documentation

#### Comment Style
```swift
// ✅ Good: Clear, concise comments
// Calculate the verse index based on day of year
let verseIndex = (dayOfYear - 1) % verses.count

// ❌ Bad: Obvious comments
// Set the verse index
let verseIndex = (dayOfYear - 1) % verses.count
```

### Performance

#### Lazy Loading
```swift
// ✅ Good: Lazy loading for expensive operations
lazy var expensiveComputation: String = {
    // Expensive computation
    return result
}()

// ❌ Bad: Eager computation
var expensiveComputation: String {
    // Expensive computation - runs every time
    return result
}
```

#### Image Optimization
```swift
// ✅ Good: Compress images before saving
func saveImage(_ image: UIImage) {
    guard let compressed = image.jpegData(compressionQuality: 0.8) else { return }
    // Save compressed data
}

// ❌ Bad: Save full resolution
func saveImage(_ image: UIImage) {
    // Saves full resolution - wastes space
}
```

### Testing

#### Test Naming
```swift
// ✅ Good: Descriptive test names
func testJournalEntryCreationWithValidData() { }
func testPrayerRequestStatusUpdate() { }

// ❌ Bad: Unclear test names
func test1() { }
func testEntry() { }
```

#### Test Structure
```swift
// ✅ Good: Arrange-Act-Assert pattern
func testJournalEntryCreation() {
    // Arrange
    let title = "Test Entry"
    let content = "Test Content"
    
    // Act
    let entry = JournalEntry(title: title, content: content)
    
    // Assert
    XCTAssertEqual(entry.title, title)
    XCTAssertEqual(entry.content, content)
}
```

## Code Review Checklist

- [ ] Follows naming conventions
- [ ] Has appropriate comments
- [ ] Handles errors properly
- [ ] Has tests (if applicable)
- [ ] Updates documentation
- [ ] No performance issues
- [ ] Follows SwiftUI best practices
- [ ] Respects privacy and security

## Tools

### Linting
- Use Xcode's built-in warnings
- Enable all recommended warnings
- Fix warnings before committing

### Formatting
- Use Xcode's automatic formatting (Ctrl+I)
- Consistent indentation (4 spaces)
- Remove trailing whitespace

## Related Documentation

- [Architecture](../Architecture.md)
- [Testing Guide](Testing-Guide.md)
- [Contributing](../Contributing.md)

