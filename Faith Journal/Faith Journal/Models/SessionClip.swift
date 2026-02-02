//
//  SessionClip.swift
//  Faith Journal
//
//  Shareable session highlights/clips
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class SessionClip {
    var id: UUID = UUID()
    var sessionId: UUID
    var title: String = ""
    var clipDescription: String = "" // Note: renamed from 'description' to avoid conflict with @Model macro
    var clipURL: String = "" // URL to video clip
    var thumbnailURL: String? // Preview thumbnail
    var startTime: TimeInterval = 0 // Start time in recording (seconds)
    var endTime: TimeInterval = 0 // End time in recording (seconds)
    var duration: TimeInterval { endTime - startTime }
    var createdBy: String = "" // userId
    var createdAt: Date = Date()
    var shareCount: Int = 0
    var viewCount: Int = 0
    
    init(sessionId: UUID, title: String, startTime: TimeInterval, endTime: TimeInterval, createdBy: String, description: String = "") {
        self.id = UUID()
        self.sessionId = sessionId
        self.title = title
        self.clipDescription = description
        self.startTime = startTime
        self.endTime = endTime
        self.createdBy = createdBy
        self.createdAt = Date()
        self.shareCount = 0
        self.viewCount = 0
        self.clipURL = ""
    }
}
