import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class BibleReadingHistory {
    var id: UUID = UUID()
    var book: String = ""
    var chapter: Int = 1
    var lastVerseRead: Int = 1
    var translation: String = "NIV"
    var lastReadDate: Date = Date()
    var readingProgress: Double = 0.0 // 0.0 to 1.0
    
    init(book: String, chapter: Int, lastVerseRead: Int = 1, translation: String = "NIV") {
        self.id = UUID()
        self.book = book
        self.chapter = chapter
        self.lastVerseRead = lastVerseRead
        self.translation = translation
        self.lastReadDate = Date()
        self.readingProgress = 0.0
    }
}

