import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class JournalEntry {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var date: Date = Date()
    private var tagsJSON: String = "[]"
    var tags: [String] {
        get {
            guard let data = tagsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set { tagsJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]" }
    }
    var mood: String?
    var location: String?
    var isPrivate: Bool = false
    var audioURL: URL?
    var audioTranscript: String? // Speech-to-text transcript of audio recording
    var photoURLs: [URL] = []
    var drawingData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(title: String, content: String, tags: [String] = [], mood: String? = nil, location: String? = nil, isPrivate: Bool = false) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.date = Date()
        self.tagsJSON = (try? JSONEncoder().encode(tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.mood = mood
        self.location = location
        self.isPrivate = isPrivate
        self.photoURLs = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 