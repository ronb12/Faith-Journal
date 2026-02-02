//
//  SessionPlaylist.swift
//  Faith Journal
//
//  Group related sessions into playlists/series
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class SessionPlaylist {
    var id: UUID = UUID()
    var name: String = ""
    var description: String = ""
    var createdBy: String = "" // userId
    var createdAt: Date = Date()
    var sessionIds: [UUID] = []
    
    init(name: String, description: String = "", createdBy: String) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.createdBy = createdBy
        self.createdAt = Date()
        self.sessionIds = []
    }
}
