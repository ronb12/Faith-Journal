import Foundation
import SwiftData

@Model
final class JournalEntry: Identifiable {
    var title: String
    var content: String
    var date: Date
    var mood: String?
    var location: String?
    var imageData: Data?
    var audioURL: URL?
    var drawingData: Data?
    var bibleReference: String?
    var prayerPoints: [String]
    var tags: [String]
    var isPrivate: Bool
    
    init(
        title: String,
        content: String,
        date: Date = Date(),
        mood: String? = nil,
        location: String? = nil,
        imageData: Data? = nil,
        audioURL: URL? = nil,
        drawingData: Data? = nil,
        bibleReference: String? = nil,
        prayerPoints: [String] = [],
        tags: [String] = [],
        isPrivate: Bool = false
    ) {
        self.title = title
        self.content = content
        self.date = date
        self.mood = mood
        self.location = location
        self.imageData = imageData
        self.audioURL = audioURL
        self.drawingData = drawingData
        self.bibleReference = bibleReference
        self.prayerPoints = prayerPoints
        self.tags = tags
        self.isPrivate = isPrivate
    }
} 