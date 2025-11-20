import Foundation
import SwiftData

@Model
final class LiveSessionParticipant {
    var id: UUID = UUID()
    var sessionId: UUID = UUID()
    var userId: String = ""
    var userName: String = ""
    var joinedAt: Date = Date()
    var leftAt: Date?
    var isHost: Bool = false
    var isActive: Bool = true
    
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