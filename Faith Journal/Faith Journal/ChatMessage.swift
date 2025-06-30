import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var sessionId: UUID
    var userId: String
    var userName: String
    var message: String
    var timestamp: Date
    var messageType: MessageType
    
    enum MessageType: String, CaseIterable, Codable {
        case text = "Text"
        case prayer = "Prayer"
        case scripture = "Scripture"
        case system = "System"
    }
    
    init(sessionId: UUID, userId: String, userName: String, message: String, messageType: MessageType = .text) {
        self.id = UUID()
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        self.message = message
        self.timestamp = Date()
        self.messageType = messageType
    }
} 