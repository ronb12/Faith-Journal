//
//  UserChannel.swift
//  Faith Journal
//
//  Model for user channels (like YouTube channels)
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class UserChannel {
    var id: UUID = UUID()
    var ownerId: String = "" // Firebase Auth UID
    var channelName: String = ""
    var channelDescription: String = ""
    var channelAvatarURL: String?
    var channelBannerURL: String?
    var category: String = "" // e.g., "Pastor", "Teacher", "Study Group"
    var tags: [String] = []
    var subscriberCount: Int = 0
    var sessionCount: Int = 0
    var isVerified: Bool = false // Verified/badged channels
    var isPublic: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(
        ownerId: String,
        channelName: String,
        channelDescription: String = "",
        category: String = "",
        tags: [String] = []
    ) {
        self.id = UUID()
        self.ownerId = ownerId
        self.channelName = channelName
        self.channelDescription = channelDescription
        self.category = category
        self.tags = tags
        self.subscriberCount = 0
        self.sessionCount = 0
        self.isVerified = false
        self.isPublic = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
