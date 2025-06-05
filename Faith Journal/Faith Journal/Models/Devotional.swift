import Foundation
import SwiftData

@Model
final class Devotional: Identifiable {
    var title: String
    var scripture: String
    var reflection: String
    var date: Date
    var tags: [String]
    var mood: String?
    var imageData: Data?
    var audioURL: URL?
    var isPrivate: Bool
    var relatedVerses: [String]
    var prayerPoints: [String]
    
    init(
        title: String,
        scripture: String,
        reflection: String,
        date: Date = Date(),
        tags: [String] = [],
        mood: String? = nil,
        imageData: Data? = nil,
        audioURL: URL? = nil,
        isPrivate: Bool = false,
        relatedVerses: [String] = [],
        prayerPoints: [String] = []
    ) {
        self.title = title
        self.scripture = scripture
        self.reflection = reflection
        self.date = date
        self.tags = tags
        self.mood = mood
        self.imageData = imageData
        self.audioURL = audioURL
        self.isPrivate = isPrivate
        self.relatedVerses = relatedVerses
        self.prayerPoints = prayerPoints
    }
} 