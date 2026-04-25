import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class ChatMessage {
    var id: UUID = UUID()
    var sessionId: UUID = UUID()
    var userId: String = ""
    var userName: String = ""
    var userAvatarURL: String?
    var message: String = ""
    var timestamp: Date = Date()
    var messageType: MessageType = ChatMessage.MessageType.text
    var reactions: [String] = [] // Emoji reactions: ["👍", "❤️", "🙏"]
    var mentionedUserIds: [String] = [] // @mentions
    var attachedFileURL: String? // For file sharing
    var attachedImageURL: String? // For image sharing
    var voiceMessageURL: String? // For voice messages
    var bibleVerseReference: String? // For shared Bible verses
    
    enum MessageType: String, CaseIterable, Codable {
        case text = "Text"
        case prayer = "Prayer"
        case scripture = "Scripture"
        case system = "System"
        case voice = "Voice"
        case file = "File"
        case image = "Image"
    }
    
    init(sessionId: UUID, userId: String, userName: String, message: String, messageType: MessageType = .text) {
        self.id = UUID()
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        self.userAvatarURL = nil
        self.message = message
        self.timestamp = Date()
        self.messageType = messageType
        self.reactions = []
        self.mentionedUserIds = []
    }
} 