import Foundation
import SwiftData

@Model
final class MoodEntry {
    var id: UUID = UUID()
    var mood: String = ""
    var intensity: Int = 5
    var notes: String?
    var date: Date = Date()
    var tags: [String] = []
    var createdAt: Date = Date()
    
    init(mood: String, intensity: Int, notes: String? = nil, tags: [String] = []) {
        self.id = UUID()
        self.mood = mood
        self.intensity = max(1, min(10, intensity))
        self.notes = notes
        self.date = Date()
        self.tags = tags
        self.createdAt = Date()
    }
} 