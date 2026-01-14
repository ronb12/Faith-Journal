import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class BibleHighlight {
    var id: UUID = UUID()
    var verseReference: String = "" // e.g., "John 3:16"
    var verseText: String = ""
    var translation: String = "NIV"
    var colorIndex: Int = 0 // 0-4 for different highlight colors
    var createdAt: Date = Date()
    
    init(verseReference: String, verseText: String, translation: String = "NIV", colorIndex: Int = 0) {
        self.id = UUID()
        self.verseReference = verseReference
        self.verseText = verseText
        self.translation = translation
        self.colorIndex = colorIndex
        self.createdAt = Date()
    }
}

