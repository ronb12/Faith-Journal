import Foundation
import SwiftData

@Model
final class PrayerRequest {
    var id: UUID
    var title: String
    var description: String
    var date: Date
    var status: PrayerStatus
    var isAnswered: Bool
    var answerDate: Date?
    var answerNotes: String?
    var isPrivate: Bool
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    
    enum PrayerStatus: String, CaseIterable, Codable {
        case active = "Active"
        case answered = "Answered"
        case archived = "Archived"
    }
    
    init(title: String, description: String, tags: [String] = [], isPrivate: Bool = false) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.date = Date()
        self.status = .active
        self.isAnswered = false
        self.isPrivate = isPrivate
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 