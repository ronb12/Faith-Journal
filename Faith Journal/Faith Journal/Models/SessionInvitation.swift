//
//  SessionInvitation.swift
//  Faith Journal
//
//  Session invitation model for multi-user support
//

import Foundation
import SwiftData

@Model
final class SessionInvitation {
    var id: UUID = UUID()
    var sessionId: UUID = UUID()
    var sessionTitle: String = ""
    var hostId: String = ""
    var hostName: String = ""
    var invitedUserId: String?
    var invitedUserName: String?
    var invitedEmail: String?
    var inviteCode: String = ""
    var status: InvitationStatus = SessionInvitation.InvitationStatus.pending
    var createdAt: Date = Date()
    var respondedAt: Date?
    var expiresAt: Date?
    
    enum InvitationStatus: String, CaseIterable, Codable {
        case pending = "Pending"
        case accepted = "Accepted"
        case declined = "Declined"
        case expired = "Expired"
    }
    
    init(
        sessionId: UUID,
        sessionTitle: String,
        hostId: String,
        hostName: String,
        invitedUserId: String? = nil,
        invitedUserName: String? = nil,
        invitedEmail: String? = nil,
        inviteCode: String = String(UUID().uuidString.prefix(8).uppercased()),
        expiresAt: Date? = nil
    ) {
        self.id = UUID()
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.hostId = hostId
        self.hostName = hostName
        self.invitedUserId = invitedUserId
        self.invitedUserName = invitedUserName
        self.invitedEmail = invitedEmail
        let code = inviteCode.isEmpty ? String(UUID().uuidString.prefix(8).uppercased()) : inviteCode
        self.inviteCode = code
        self.status = .pending
        self.createdAt = Date()
        self.expiresAt = expiresAt ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())
    }
    
    var isExpired: Bool {
        if let expiresAt = expiresAt {
            return Date() > expiresAt
        }
        return false
    }
    
    var isValid: Bool {
        status == .pending && !isExpired
    }
}

