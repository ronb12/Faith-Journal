//
//  CloudKitPublicSyncService.swift
//  Faith Journal
//
//  Syncs LiveSession, LiveSessionParticipant, and ChatMessage to CloudKit Public Database
//  Enables sharing between different Apple ID users
//

import Foundation
import CloudKit
import SwiftData
import Combine

@MainActor
@available(iOS 17.0, *)
class CloudKitPublicSyncService: ObservableObject {

    static let shared: CloudKitPublicSyncService = {
        // Always disable CloudKit in simulator to prevent crashes
        // CKContainer.default() crashes in simulator, not throws
        #if targetEnvironment(simulator)
        return CloudKitPublicSyncService(disableCloudKit: true)
        #else
        return CloudKitPublicSyncService()
        #endif
    }()
    
    private let container: CKContainer?
    private var publicDatabase: CKDatabase? {
        container?.publicCloudDatabase
    }
    private var cloudKitDisabled: Bool
    
    private init(disableCloudKit: Bool = false) {
        self.cloudKitDisabled = disableCloudKit
        
        if disableCloudKit {
            container = nil
            print("ℹ️ CloudKitPublicSyncService: CloudKit is disabled")
            return
        }
        
        // Use default container which matches bundle identifier
        // Or specify: CKContainer(identifier: "iCloud.com.ronellbradley.FaithJournal")
        // Note: CKContainer.default() can crash in simulator, so we disable CloudKit there
        container = CKContainer.default()
        print("ℹ️ CloudKitPublicSyncService: Initialized CloudKit container")
    }
    
    // MARK: - LiveSession Sync
    
    func syncSessionToPublic(_ session: LiveSession) async throws {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot sync - CloudKit is disabled")
            return
        }
        
        let record = CKRecord(recordType: "LiveSession", recordID: CKRecord.ID(recordName: session.id.uuidString))
        
        record["title"] = session.title
        record["details"] = session.details
        record["hostId"] = session.hostId
        record["startTime"] = session.startTime
        record["endTime"] = session.endTime
        record["isActive"] = session.isActive
        record["maxParticipants"] = session.maxParticipants
        record["currentParticipants"] = session.currentParticipants
        record["category"] = session.category
        record["tags"] = session.tags
        record["isPrivate"] = session.isPrivate
        record["createdAt"] = session.createdAt
        
        try await database.save(record)
    }
    
    func fetchPublicSessions() async throws -> [LiveSession] {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot fetch - CloudKit is disabled")
            return []
        }
        
        let query = CKQuery(recordType: "LiveSession", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        
        let (matchResults, _) = try await database.records(matching: query)
        
        var sessions: [LiveSession] = []
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let session = sessionFromRecord(record) {
                    sessions.append(session)
                }
            case .failure(let error):
                print("Error fetching session: \(error)")
            }
        }
        
        return sessions
    }
    
    func deleteSession(_ sessionId: UUID) async throws {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot delete - CloudKit is disabled")
            return
        }
        
        let recordID = CKRecord.ID(recordName: sessionId.uuidString)
        try await database.deleteRecord(withID: recordID)
        print("✅ Session deleted from CloudKit: \(sessionId)")
    }
    
    private func sessionFromRecord(_ record: CKRecord) -> LiveSession? {
        guard let title = record["title"] as? String,
              let details = record["details"] as? String,
              let hostId = record["hostId"] as? String,
              let category = record["category"] as? String,
              let startTime = record["startTime"] as? Date,
              let maxParticipants = record["maxParticipants"] as? Int else {
            return nil
        }
        
        // Session ID from CloudKit record (not used, sessions get new IDs)
        guard UUID(uuidString: record.recordID.recordName) != nil else {
            return nil
        }
        
        let isActive = record["isActive"] as? Bool ?? true
        let currentParticipants = record["currentParticipants"] as? Int ?? 1
        let tags = record["tags"] as? [String] ?? []
        let isPrivate = record["isPrivate"] as? Bool ?? false
        let _ = record["createdAt"] as? Date ?? startTime
        let endTime = record["endTime"] as? Date
        
        let session = LiveSession(
            title: title,
            description: details,
            hostId: hostId,
            category: category,
            maxParticipants: maxParticipants,
            tags: tags
        )
        // Override ID to match CloudKit record
        // Note: This requires LiveSession.id to be mutable or we need to modify init
        // For now, sessions will get new IDs but sync will match by hostId + title
        session.isActive = isActive
        session.currentParticipants = currentParticipants
        session.isPrivate = isPrivate
        session.endTime = endTime
        
        return session
    }
    
    // MARK: - LiveSessionParticipant Sync
    
    func syncParticipantToPublic(_ participant: LiveSessionParticipant) async throws {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot sync participant - CloudKit is disabled")
            return
        }
        
        let record = CKRecord(recordType: "LiveSessionParticipant", recordID: CKRecord.ID(recordName: participant.id.uuidString))
        
        record["sessionId"] = participant.sessionId.uuidString
        record["userId"] = participant.userId
        record["userName"] = participant.userName
        record["joinedAt"] = participant.joinedAt
        record["leftAt"] = participant.leftAt
        record["isHost"] = participant.isHost
        record["isActive"] = participant.isActive
        
        try await database.save(record)
    }
    
    // MARK: - ChatMessage Sync
    
    func syncMessageToPublic(_ message: ChatMessage) async throws {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot sync message - CloudKit is disabled")
            return
        }
        
        let record = CKRecord(recordType: "ChatMessage", recordID: CKRecord.ID(recordName: message.id.uuidString))
        
        record["sessionId"] = message.sessionId.uuidString
        record["userId"] = message.userId
        record["userName"] = message.userName
        record["message"] = message.message
        record["timestamp"] = message.timestamp
        record["messageType"] = message.messageType.rawValue
        
        try await database.save(record)
    }
    
    func fetchPublicMessages(for sessionId: UUID) async throws -> [ChatMessage] {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot fetch messages - CloudKit is disabled")
            return []
        }
        
        let predicate = NSPredicate(format: "sessionId == %@", sessionId.uuidString)
        let query = CKQuery(recordType: "ChatMessage", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        let (matchResults, _) = try await database.records(matching: query)
        
        var messages: [ChatMessage] = []
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let message = messageFromRecord(record) {
                    messages.append(message)
                }
            case .failure(let error):
                print("Error fetching message: \(error)")
            }
        }
        
        return messages
    }
    
    private func messageFromRecord(_ record: CKRecord) -> ChatMessage? {
        guard let sessionIdString = record["sessionId"] as? String,
              let sessionId = UUID(uuidString: sessionIdString),
              let userId = record["userId"] as? String,
              let userName = record["userName"] as? String,
              let message = record["message"] as? String,
              let _ = record["timestamp"] as? Date,
              let messageTypeString = record["messageType"] as? String,
              let messageType = ChatMessage.MessageType(rawValue: messageTypeString) else {
            return nil
        }
        
        let _ = UUID(uuidString: record.recordID.recordName) ?? UUID()
        
        let chatMessage = ChatMessage(
            sessionId: sessionId,
            userId: userId,
            userName: userName,
            message: message,
            messageType: messageType
        )
        
        return chatMessage
    }
    
    // MARK: - SessionInvitation Sync
    
    func syncInvitationToPublic(_ invitation: SessionInvitation) async throws {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot sync invitation - CloudKit is disabled")
            return
        }
        
        let record = CKRecord(recordType: "SessionInvitation", recordID: CKRecord.ID(recordName: invitation.id.uuidString))
        
        record["sessionId"] = invitation.sessionId.uuidString
        record["sessionTitle"] = invitation.sessionTitle
        record["hostId"] = invitation.hostId
        record["hostName"] = invitation.hostName
        record["invitedUserId"] = invitation.invitedUserId
        record["invitedUserName"] = invitation.invitedUserName
        record["invitedEmail"] = invitation.invitedEmail
        record["inviteCode"] = invitation.inviteCode
        record["status"] = invitation.status.rawValue
        record["createdAt"] = invitation.createdAt
        record["respondedAt"] = invitation.respondedAt
        record["expiresAt"] = invitation.expiresAt
        
        try await database.save(record)
    }
    
    func fetchPublicInvitations(for userId: String) async throws -> [SessionInvitation] {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot fetch invitations - CloudKit is disabled")
            return []
        }
        
        let predicate = NSPredicate(format: "invitedUserId == %@ OR invitedEmail != nil", userId)
        let query = CKQuery(recordType: "SessionInvitation", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let (matchResults, _) = try await database.records(matching: query)
        
        var invitations: [SessionInvitation] = []
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let invitation = invitationFromRecord(record) {
                    invitations.append(invitation)
                }
            case .failure(let error):
                print("Error fetching invitation: \(error)")
            }
        }
        
        return invitations
    }
    
    private func invitationFromRecord(_ record: CKRecord) -> SessionInvitation? {
        guard let sessionIdString = record["sessionId"] as? String,
              let sessionId = UUID(uuidString: sessionIdString),
              let sessionTitle = record["sessionTitle"] as? String,
              let hostId = record["hostId"] as? String,
              let hostName = record["hostName"] as? String,
              let inviteCode = record["inviteCode"] as? String,
              let statusString = record["status"] as? String,
              let status = SessionInvitation.InvitationStatus(rawValue: statusString),
              let _ = record["createdAt"] as? Date else {
            return nil
        }
        
        let invitedUserId = record["invitedUserId"] as? String
        let invitedUserName = record["invitedUserName"] as? String
        let invitedEmail = record["invitedEmail"] as? String
        let respondedAt = record["respondedAt"] as? Date
        let expiresAt = record["expiresAt"] as? Date
        
        let invitation = SessionInvitation(
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            hostId: hostId,
            hostName: hostName,
            invitedUserId: invitedUserId,
            invitedUserName: invitedUserName,
            invitedEmail: invitedEmail,
            inviteCode: inviteCode,
            expiresAt: expiresAt
        )
        
        invitation.status = status
        invitation.respondedAt = respondedAt
        
        return invitation
    }
    
    // MARK: - Subscription for Real-Time Updates
    
    func subscribeToSessions() async throws {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot subscribe - CloudKit is disabled")
            return
        }
        
        let subscription = CKQuerySubscription(
            recordType: "LiveSession",
            predicate: NSPredicate(value: true),
            subscriptionID: "live-sessions-updates",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification
        
        try await database.save(subscription)
    }
    
    func subscribeToMessages(for sessionId: UUID) async throws {
        guard !cloudKitDisabled, let database = publicDatabase else {
            print("⚠️ CloudKitPublicSyncService: Cannot subscribe - CloudKit is disabled")
            return
        }
        
        let predicate = NSPredicate(format: "sessionId == %@", sessionId.uuidString)
        let subscription = CKQuerySubscription(
            recordType: "ChatMessage",
            predicate: predicate,
            subscriptionID: "chat-messages-\(sessionId.uuidString)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification
        
        try await database.save(subscription)
    }
}

