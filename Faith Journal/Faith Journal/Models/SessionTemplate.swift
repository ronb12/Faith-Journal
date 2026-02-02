//
//  SessionTemplate.swift
//  Faith Journal
//
//  Reusable session templates for quick session creation
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class SessionTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var title: String = ""
    var details: String = ""
    var category: String = ""
    var tags: [String] = []
    var maxParticipants: Int = 10
    var isPrivate: Bool = false
    var agenda: String = ""
    var relatedResources: [String] = []
    var createdAt: Date = Date()
    var lastUsed: Date?
    var useCount: Int = 0
    
    init(name: String, title: String, details: String, category: String, maxParticipants: Int = 10, tags: [String] = [], isPrivate: Bool = false, agenda: String = "", relatedResources: [String] = []) {
        self.id = UUID()
        self.name = name
        self.title = title
        self.details = details
        self.category = category
        self.maxParticipants = maxParticipants
        self.tags = tags
        self.isPrivate = isPrivate
        self.agenda = agenda
        self.relatedResources = relatedResources
        self.createdAt = Date()
        self.lastUsed = nil
        self.useCount = 0
    }
    
    // Create a session from this template
    func createSession(hostId: String, hostName: String) -> LiveSession {
        let session = LiveSession(
            title: self.title,
            description: self.details,
            hostId: hostId,
            category: self.category,
            maxParticipants: self.maxParticipants,
            tags: self.tags
        )
        session.isPrivate = self.isPrivate
        session.hostName = hostName
        session.agenda = self.agenda
        session.relatedResources = self.relatedResources
        
        // Update template usage stats
        self.lastUsed = Date()
        self.useCount += 1
        
        return session
    }
}
