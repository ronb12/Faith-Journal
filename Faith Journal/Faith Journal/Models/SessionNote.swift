//
//  SessionNote.swift
//  Faith Journal
//
//  Personal notes and takeaways for sessions
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class SessionNote {
    var id: UUID = UUID()
    var sessionId: UUID
    var userId: String = ""
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(sessionId: UUID, userId: String, title: String = "", content: String = "") {
        self.id = UUID()
        self.sessionId = sessionId
        self.userId = userId
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
