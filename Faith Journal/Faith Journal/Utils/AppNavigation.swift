import SwiftUI
import os

// MARK: - App-wide logging (Console / Instruments)

public enum FaithJournalLog: Sendable {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.faithjournal.app"

    public static let navigation = Logger(subsystem: subsystem, category: "navigation")
    public static let bible = Logger(subsystem: subsystem, category: "bible")
    public static let search = Logger(subsystem: subsystem, category: "search")
}

// MARK: - App navigation

/// Drives the root `TabView` in `ContentView` and app-wide deep links.
///
/// **Tab indices** (see `ContentView` `.tag` values): 0 — Home, 1 — Journal, 2 — Prayer, 3 — Devotionals, 4 — More.
@available(iOS 17.0, *)
@MainActor
public class AppNavigation: ObservableObject {
    @Published public var selectedTab: Int = 0
    /// Set this to open the in-app Bible to a specific passage. Cleared by the reader if needed.
    @Published public var bibleTarget: BibleTarget? = nil
    /// When true, More should surface Faith Friends (e.g. notification tap).
    @Published public var navigateToFaithFriends: Bool = false

    public func handleDeepLink(_ url: URL) {
        guard url.scheme == "faithjournal" else { return }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if pathComponents.first == "bible" && pathComponents.count >= 3 {
            let book = pathComponents[1]
            if let chapter = Int(pathComponents[2]) {
                let verse = pathComponents.count >= 4 ? Int(pathComponents[3]) : nil
                bibleTarget = BibleTarget(book: book, chapter: chapter, verse: verse)
                selectedTab = 1
            }
        }
    }
}

public struct BibleTarget: Equatable {
    public let book: String
    public let chapter: Int
    public let verse: Int?
    public let endChapter: Int?

    public init(book: String, chapter: Int, verse: Int? = nil, endChapter: Int? = nil) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.endChapter = endChapter
    }
}
