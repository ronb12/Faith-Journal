import Foundation
import SwiftData

@Model
final class LiveSession {
    var id: UUID
    var title: String
    var details: String
    var hostId: String
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    var maxParticipants: Int
    var currentParticipants: Int
    var category: String
    var tags: [String]
    var isPrivate: Bool
    var createdAt: Date
    
    init(title: String, description: String, hostId: String, category: String, maxParticipants: Int = 10, tags: [String] = []) {
        self.id = UUID()
        self.title = title
        self.details = description
        self.hostId = hostId
        self.startTime = Date()
        self.isActive = true
        self.maxParticipants = maxParticipants
        self.currentParticipants = 1
        self.category = category
        self.tags = tags
        self.isPrivate = false
        self.createdAt = Date()
    }
} 