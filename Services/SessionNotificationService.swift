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
    
    func addSessionToCalendar(session: LiveSession) async throws {
        let status: Bool
        do {
            status = try await eventStore.requestFullAccessToEvents()
        } catch {
            throw NotificationError.calendarPermissionDenied
        }
        guard status else {
            throw NotificationError.calendarPermissionDenied
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = session.title
        event.notes = session.details
        event.startDate = session.scheduledStartTime ?? session.startTime
        event.endDate = session.endTime ?? event.startDate.addingTimeInterval(3600) // Default 1 hour
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
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
            return "Calendar permission denied"
        case .calendarSaveFailed:
            return "Failed to save to calendar"
        }
    }
}

