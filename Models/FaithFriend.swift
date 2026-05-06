//
//  FaithFriend.swift
//  Faith Journal
//
//  Represents a friendship or friend request between users.
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class FaithFriend {
    var id: UUID = UUID()
    /// Current user's ID (Firebase UID)
    var userId: String = ""
    /// Friend's user ID (Firebase UID)
    var friendUserId: String = ""
    /// Friend's display name (cached)
    var friendDisplayName: String = ""
    /// Friend's avatar URL (optional, cached)
    var friendAvatarURL: String?
    /// Status: pending, accepted, declined
    var status: String = "pending"
    /// Who initiated the request (Firebase UID)
    var requestedBy: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(userId: String, friendUserId: String, friendDisplayName: String, friendAvatarURL: String? = nil, status: String = "pending", requestedBy: String) {
        self.userId = userId
        self.friendUserId = friendUserId
        self.friendDisplayName = friendDisplayName
        self.friendAvatarURL = friendAvatarURL
        self.status = status
        self.requestedBy = requestedBy
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isAccepted: Bool { status == "accepted" }
    var isPending: Bool { status == "pending" }
    var isDeclined: Bool { status == "declined" }
}
