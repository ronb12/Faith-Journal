//
//  StreamModerationService.swift
//  Faith Journal
//
//  Moderation service for live stream chat and interactions
//

import Foundation
import SwiftData

@MainActor
@available(iOS 17.0, *)
class StreamModerationService: ObservableObject {
    static let shared = StreamModerationService()
    
    @Published var blockedUsers: Set<String> = []
    @Published var mutedUsers: Set<String> = []
    @Published var filteredKeywords: [String] = []
    @Published var reportedMessages: [ReportedMessage] = []
    
    struct ReportedMessage: Identifiable {
        let id = UUID()
        let messageId: UUID
        let userId: String
        let userName: String
        let message: String
        let reason: String
        let reportedAt: Date
        var status: ReportStatus = .pending
    }
    
    enum ReportStatus {
        case pending
        case reviewed
        case actionTaken
        case dismissed
    }
    
    private init() {
        // Load default filtered keywords
        filteredKeywords = [
            "spam", "advertisement", "promo", "buy now",
            "inappropriate", "offensive"
        ]
    }
    
    func blockUser(_ userId: String) {
        blockedUsers.insert(userId)
        mutedUsers.insert(userId) // Also mute when blocking
    }
    
    func unblockUser(_ userId: String) {
        blockedUsers.remove(userId)
    }
    
    func muteUser(_ userId: String) {
        mutedUsers.insert(userId)
    }
    
    func unmuteUser(_ userId: String) {
        mutedUsers.remove(userId)
    }
    
    func addFilteredKeyword(_ keyword: String) {
        let lowercased = keyword.lowercased()
        if !filteredKeywords.contains(lowercased) {
            filteredKeywords.append(lowercased)
        }
    }
    
    func removeFilteredKeyword(_ keyword: String) {
        filteredKeywords.removeAll { $0 == keyword.lowercased() }
    }
    
    func shouldFilterMessage(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return filteredKeywords.contains { lowercased.contains($0) }
    }
    
    func reportMessage(messageId: UUID, userId: String, userName: String, message: String, reason: String) {
        let report = ReportedMessage(
            messageId: messageId,
            userId: userId,
            userName: userName,
            message: message,
            reason: reason,
            reportedAt: Date()
        )
        reportedMessages.append(report)
    }
    
    func isUserBlocked(_ userId: String) -> Bool {
        return blockedUsers.contains(userId)
    }
    
    func isUserMuted(_ userId: String) -> Bool {
        return mutedUsers.contains(userId)
    }
}

