import Foundation
import SwiftData

@Model
final class BibleVerseOfTheDay {
    var id: UUID
    var verse: String
    var reference: String
    var translation: String
    var date: Date
    var isFavorite: Bool
    var notes: String?
    var createdAt: Date
    
    init(verse: String, reference: String, translation: String = "NIV") {
        self.id = UUID()
        self.verse = verse
        self.reference = reference
        self.translation = translation
        self.date = Date()
        self.isFavorite = false
        self.createdAt = Date()
    }
} 