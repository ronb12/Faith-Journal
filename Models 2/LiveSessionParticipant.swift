import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class LiveSessionParticipant {
    var id: UUID = UUID()
    var sessionId: UUID = UUID()
    var userId: String = ""
    var userName: String = ""
    var userAvatarURL: String? // Profile picture URL
    var joinedAt: Date = Date()
    var leftAt: Date?
    var isHost: Bool = false
    var isCoHost: Bool = false
    var isActive: Bool = true
    var isMuted: Bool = false
    var isVideoEnabled: Bool = true
    var isSpeaking: Bool = false
    var connectionQuality: String = "Good"
    var handRaised: Bool = false
    var watchTime: TimeInterval = 0 // Total time watched
    
    init(sessionId: UUID, userId: String, userName: String, isHost: Bool = false) {
        self.id = UUID()
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        self.userAvatarURL = nil
        self.joinedAt = Date()
        self.isHost = isHost
        self.isCoHost = false
        self.isActive = true
        self.isMuted = false
        self.isVideoEnabled = true
        self.isSpeaking = false
        self.connectionQuality = "Good"
        self.handRaised = false
        self.watchTime = 0
    }
} 