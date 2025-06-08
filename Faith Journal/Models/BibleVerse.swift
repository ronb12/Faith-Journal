import Foundation
import SwiftData

@Model
final class BibleVerse {
    var reference: String
    var text: String
    var translation: String
    var isMemorized: Bool
    var lastReviewed: Date?
    var notes: String?
    var isHighlighted: Bool
    var highlightColor: String?
    var tags: [String]
    var crossReferences: [String]
    
    init(
        reference: String,
        text: String,
        translation: String,
        isMemorized: Bool = false,
        lastReviewed: Date? = nil,
        notes: String? = nil,
        isHighlighted: Bool = false,
        highlightColor: String? = nil,
        tags: [String] = [],
        crossReferences: [String] = []
    ) {
        self.reference = reference
        self.text = text
        self.translation = translation
        self.isMemorized = isMemorized
        self.lastReviewed = lastReviewed
        self.notes = notes
        self.isHighlighted = isHighlighted
        self.highlightColor = highlightColor
        self.tags = tags
        self.crossReferences = crossReferences
    }
} 