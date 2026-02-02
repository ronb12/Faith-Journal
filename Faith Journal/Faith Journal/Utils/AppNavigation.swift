import SwiftUI

@available(iOS 17.0, *)
@MainActor
public class AppNavigation: ObservableObject {
    @Published public var selectedTab: Int = 0
    @Published public var bibleTarget: BibleTarget? = nil
    
    public func handleDeepLink(_ url: URL) {
        // Handle deep links to navigate to specific parts of the app
        // Example: faithjournal://bible/genesis/1
        guard url.scheme == "faithjournal" else { return }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        if pathComponents.first == "bible" && pathComponents.count >= 3 {
            let book = pathComponents[1]
            if let chapter = Int(pathComponents[2]) {
                let verse = pathComponents.count >= 4 ? Int(pathComponents[3]) : nil
                bibleTarget = BibleTarget(book: book, chapter: chapter, verse: verse)
                selectedTab = 1 // Navigate to Bible view
            }
        }
    }
}

public struct BibleTarget: Equatable {
    public let book: String
    public let chapter: Int
    public let verse: Int?
    public let endChapter: Int? // For ranges like "Psalm 1-10"
    
    public init(book: String, chapter: Int, verse: Int? = nil, endChapter: Int? = nil) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.endChapter = endChapter
    }
}
