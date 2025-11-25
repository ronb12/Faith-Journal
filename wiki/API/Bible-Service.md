# Bible Service API

This document describes the Bible Service API used in Faith Journal.

## Overview

The Bible Service provides functionality to fetch Bible verses from external APIs with support for multiple translations.

## Service Class

**Location**: `Services/BibleService.swift`

**Singleton Access**:
```swift
let service = BibleService.shared
```

## Available Translations

The service supports the following translations:

| Code | Full Name |
|------|-----------|
| WEB | World English Bible |
| NIV | New International Version |
| KJV | King James Version |
| ESV | English Standard Version |
| NLT | New Living Translation |
| NASB | New American Standard Bible |
| MSG | The Message |
| AMP | Amplified Bible |
| CSB | Christian Standard Bible |

## API Methods

### fetchVerse(reference:translation:)

Fetches a Bible verse by reference.

**Signature**:
```swift
func fetchVerse(reference: String, translation: String? = nil) async throws -> BibleVerseResponse
```

**Parameters**:
- `reference`: Verse reference (e.g., "John 3:16", "Romans 8:28")
- `translation`: Optional translation code (defaults to `selectedTranslation`)

**Returns**: `BibleVerseResponse` containing:
- `reference`: The verse reference
- `text`: The verse text
- `translation`: The translation used

**Throws**: Error if fetch fails

**Example**:
```swift
do {
    let verse = try await BibleService.shared.fetchVerse(
        reference: "John 3:16",
        translation: "NIV"
    )
    print(verse.text)
} catch {
    print("Error fetching verse: \(error)")
}
```

## Response Model

### BibleVerseResponse

```swift
struct BibleVerseResponse: Codable {
    let reference: String
    let text: String
    let translation: String
}
```

## Properties

### Published Properties

- `isLoading: Bool`: Indicates if a request is in progress
- `errorMessage: String?`: Contains error message if request fails
- `selectedTranslation: String`: Currently selected translation (default: "WEB")

### Available Translations

- `availableTranslations: [String: String]`: Dictionary mapping translation codes to full names

## Error Handling

The service handles various error conditions:

1. **Network Errors**: Connection failures, timeouts
2. **API Errors**: Invalid responses, rate limiting
3. **Parsing Errors**: Malformed JSON responses
4. **Invalid References**: Unparseable verse references

**Error Handling Example**:
```swift
do {
    let verse = try await service.fetchVerse(reference: "John 3:16")
} catch {
    // Handle error
    if let error = error as? BibleServiceError {
        switch error {
        case .networkError:
            // Handle network error
        case .invalidReference:
            // Handle invalid reference
        case .apiError(let message):
            // Handle API error
        }
    }
}
```

## Caching

The service implements caching to:

- Reduce API calls
- Improve performance
- Work offline with cached data

## Rate Limiting

The service respects API rate limits:

- Automatic retry with exponential backoff
- Rate limit detection and handling
- User-friendly error messages

## Usage in Views

### SwiftUI Integration

```swift
struct VerseView: View {
    @StateObject private var service = BibleService.shared
    @State private var verse: BibleVerseResponse?
    
    var body: some View {
        VStack {
            if service.isLoading {
                ProgressView()
            } else if let verse = verse {
                Text(verse.text)
            } else if let error = service.errorMessage {
                Text("Error: \(error)")
            }
        }
        .task {
            do {
                verse = try await service.fetchVerse(reference: "John 3:16")
            } catch {
                // Handle error
            }
        }
    }
}
```

## Best Practices

1. **Error Handling**: Always handle errors appropriately
2. **Loading States**: Show loading indicators during requests
3. **Caching**: Leverage caching for better performance
4. **Translation Selection**: Allow users to choose translation
5. **Offline Support**: Handle offline scenarios gracefully

## External APIs

The service may use multiple API sources:

1. **World English Bible API**: Primary source for WEB translation
2. **ESV API**: For ESV translation (requires API key)
3. **Fallback Sources**: Additional sources for reliability

## Configuration

### API Keys

Some translations require API keys:

- **ESV**: Requires API key from Crossway
- Configure in app settings or environment variables

### Base URLs

API endpoints are configured internally and may change. Check the service implementation for current endpoints.

## Testing

### Unit Tests

```swift
func testFetchVerse() async throws {
    let service = BibleService.shared
    let verse = try await service.fetchVerse(reference: "John 3:16")
    XCTAssertEqual(verse.reference, "John 3:16")
    XCTAssertFalse(verse.text.isEmpty)
}
```

### Mock Service

For testing, use a mock service:

```swift
class MockBibleService: BibleServiceProtocol {
    func fetchVerse(reference: String, translation: String?) async throws -> BibleVerseResponse {
        return BibleVerseResponse(
            reference: reference,
            text: "Test verse text",
            translation: translation ?? "WEB"
        )
    }
}
```

## Related Documentation

- [Services and Managers](../Services-and-Managers.md)
- [Architecture](../Architecture.md)
- [Development Guide](../Development/)

