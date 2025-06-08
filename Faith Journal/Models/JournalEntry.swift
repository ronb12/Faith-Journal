import Foundation
import SwiftData

@Model
final class JournalEntry {
    var title: String
    var content: String
    var date: Date
    var mood: String?
    var isPrivate: Bool
    var photos: [Data]?
    var audioURL: URL?
    var location: String?
    var tags: [String]
    var weather: String?
    
    init(
        title: String,
        content: String,
        date: Date = Date(),
        mood: String? = nil,
        isPrivate: Bool = false,
        photos: [Data]? = nil,
        audioURL: URL? = nil,
        location: String? = nil,
        tags: [String] = [],
        weather: String? = nil
    ) {
        self.title = title
        self.content = content
        self.date = date
        self.mood = mood
        self.isPrivate = isPrivate
        self.photos = photos
        self.audioURL = audioURL
        self.location = location
        self.tags = tags
        self.weather = weather
    }
} 