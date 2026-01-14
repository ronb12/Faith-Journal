import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class BibleNote {
    var id: UUID = UUID()
    var verseReference: String = "" // e.g., "John 3:16"
    var verseText: String = ""
    var translation: String = "NIV"
    var noteText: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(verseReference: String, verseText: String, translation: String = "NIV", noteText: String = "") {
        self.id = UUID()
        self.verseReference = verseReference
        self.verseText = verseText
        self.translation = translation
        self.noteText = noteText
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

