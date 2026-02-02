//
//  SessionNotificationService.swift
//  Faith Journal
//
//  Handles push notifications for live session events
//

import Foundation
import UserNotifications
import EventKit

@available(iOS 17.0, *)
@MainActor
class SessionNotificationService: ObservableObject {
    static let shared = SessionNotificationService()
    
    private let eventStore = EKEventStore()
    
    private init() {}
    
    // MARK: - Notification Permissions
    
    func requestNotificationPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func requestCalendarPermission() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            print("Error requesting calendar permission: \(error)")
            return false
        }
    }
    
    // MARK: - Session Notifications
    
    func scheduleSessionStartingSoon(session: LiveSession, minutesBefore: Int = 5) async {
        guard let scheduledTime = session.scheduledStartTime else { return }
        
        let notificationTime = scheduledTime.addingTimeInterval(-Double(minutesBefore * 60))
        guard notificationTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Session Starting Soon"
        content.body = "\(session.title) starts in \(minutesBefore) minutes"
        content.sound = .default
        content.userInfo = ["sessionId": session.id.uuidString, "type": "sessionStarting"]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: notificationTime.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "session-\(session.id.uuidString)-starting",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    func scheduleSessionStarted(session: LiveSession) async {
        let content = UNMutableNotificationContent()
        content.title = "Session Started"
        content.body = "\(session.title) is now live"
        content.sound = .default
        content.userInfo = ["sessionId": session.id.uuidString, "type": "sessionStarted"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session-\(session.id.uuidString)-started",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    func scheduleParticipantJoined(session: LiveSession, participantName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "New Participant"
        content.body = "\(participantName) joined \(session.title)"
        content.sound = .default
        content.userInfo = ["sessionId": session.id.uuidString, "type": "participantJoined"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session-\(session.id.uuidString)-participant-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    func scheduleNewMessage(session: LiveSession, senderName: String, message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "New Message in \(session.title)"
        content.body = "\(senderName): \(message)"
        content.sound = .default
        content.userInfo = ["sessionId": session.id.uuidString, "type": "newMessage"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session-\(session.id.uuidString)-message-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    func scheduleNewSessionNotification(session: LiveSession, channelOwnerName: String) async {
        let content = UNMutableNotificationContent()
        content.title = "New Session from \(channelOwnerName)"
        content.body = "\(session.title) - \(session.category)"
        content.sound = .default
        content.userInfo = ["sessionId": session.id.uuidString, "type": "newSession", "channelOwnerId": session.hostId]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session-\(session.id.uuidString)-new-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    func scheduleSessionEnded(session: LiveSession) async {
        let content = UNMutableNotificationContent()
        content.title = "Session Ended"
        content.body = "\(session.title) has ended. Recording available soon."
        content.sound = .default
        content.userInfo = ["sessionId": session.id.uuidString, "type": "sessionEnded"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session-\(session.id.uuidString)-ended",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    // MARK: - Calendar Integration
    
    func checkCalendarAuthorizationStatus() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }
    
    func addSessionToCalendar(session: LiveSession) async throws {
        // Check current authorization status first
        let currentStatus = checkCalendarAuthorizationStatus()
        
        // If not determined, request permission
        if currentStatus == .notDetermined {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                guard granted else {
                    throw NotificationError.calendarPermissionDenied
                }
            } catch {
                throw NotificationError.calendarPermissionDenied
            }
        }
        // If denied or restricted, throw error
        else if currentStatus == .denied || currentStatus == .restricted {
            throw NotificationError.calendarPermissionDenied
        }
        // If full access or write-only access already granted, we're good
        else if currentStatus == .fullAccess || currentStatus == .writeOnly {
            // Already have access, continue
        }
        // For any other status, request full access
        else {
            do {
                let hasFullAccess = try await eventStore.requestFullAccessToEvents()
                guard hasFullAccess else {
                    throw NotificationError.calendarPermissionDenied
                }
            } catch {
                throw NotificationError.calendarPermissionDenied
            }
        }
        
        // Ensure we have a calendar to use
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            throw NotificationError.calendarSaveFailed
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = session.title
        event.notes = session.details
        event.startDate = session.scheduledStartTime ?? session.startTime
        event.endDate = session.endTime ?? event.startDate.addingTimeInterval(3600) // Default 1 hour
        event.calendar = defaultCalendar
        
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Calendar save error: \(error.localizedDescription)")
            throw NotificationError.calendarSaveFailed
        }
    }
    
    func removeSessionFromCalendar(session: LiveSession) async {
        // Implementation to find and remove calendar event
    }
}

enum NotificationError: LocalizedError {
    case calendarPermissionDenied
    case calendarSaveFailed
    
    var errorDescription: String? {
        switch self {
        case .calendarPermissionDenied:
            return "Calendar access is required to add events. Please enable calendar access in Settings > Faith Journal."
        case .calendarSaveFailed:
            return "Failed to save event to calendar. Please try again or check your calendar settings."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .calendarPermissionDenied:
            return "Open Settings app and grant calendar access to Faith Journal."
        case .calendarSaveFailed:
            return "Make sure you have a default calendar set up in your Calendar app."
        }
    }
}

