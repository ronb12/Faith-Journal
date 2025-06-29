import Foundation
import SwiftData

@Model
final class LiveSessionParticipant {
    var id: UUID
    var sessionId: UUID
    var userId: String
    var userName: String
    var joinedAt: Date
    var leftAt: Date?
    var isHost: Bool
    var isActive: Bool
    
    init(sessionId: UUID, userId: String, userName: String, isHost: Bool = false) {
        self.id = UUID()
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        self.joinedAt = Date()
        self.isHost = isHost
        self.isActive = true
    }
} 