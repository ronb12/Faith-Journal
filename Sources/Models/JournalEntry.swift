import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var title: String
    var content: String
    var date: Date
    var tags: [String]
    var mood: String?
    var location: String?
    var isPrivate: Bool
    var audioURL: URL?
    var photoURLs: [URL]
    var drawingData: Data?
    var createdAt: Date
    var updatedAt: Date
    
    init(title: String, content: String, tags: [String] = [], mood: String? = nil, location: String? = nil, isPrivate: Bool = false) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.date = Date()
        self.tags = tags
        self.mood = mood
        self.location = location
        self.isPrivate = isPrivate
        self.photoURLs = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 