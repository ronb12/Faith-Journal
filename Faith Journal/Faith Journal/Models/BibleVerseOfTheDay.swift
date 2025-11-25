import Foundation
import SwiftData

@Model
final class BibleVerseOfTheDay {
    var id: UUID = UUID()
    var verse: String = ""
    var reference: String = ""
    var translation: String = "WEB"
    var date: Date = Date()
    var isFavorite: Bool = false
    var notes: String?
    var createdAt: Date = Date()
    
    init(verse: String, reference: String, translation: String = "WEB") {
        self.id = UUID()
        self.verse = verse
        self.reference = reference
        self.translation = translation
        self.date = Date()
        self.isFavorite = false
        self.createdAt = Date()
    }
} 