//
//  NotificationService.swift
//  Faith Journal
//
//  Push notifications setup for invitations and messages
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var notificationSettings: UNAuthorizationStatus = .notDetermined
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationSettings = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationSettings = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleNotification(
        title: String,
        body: String,
        identifier: String,
        timeInterval: TimeInterval = 0,
        repeats: Bool = false
    ) {
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let trigger: UNNotificationTrigger
        if timeInterval > 0 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        }
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func scheduleSessionInvitationNotification(
        sessionTitle: String,
        hostName: String,
        inviteCode: String
    ) {
        scheduleNotification(
            title: "Bible Study Invitation",
            body: "\(hostName) invited you to join '\(sessionTitle)'. Invite code: \(inviteCode)",
            identifier: "session-invitation-\(inviteCode)"
        )
    }
    
    func scheduleDailyPromptNotification(time: Date = Date()) {
        guard isAuthorized else { return }
        
        // Remove existing daily prompt notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-journal-prompt"])
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Journal Prompt"
        content.body = "Ready to reflect? Check out today's journal prompt!"
        content.sound = .default
        content.badge = 1
        content.userInfo = ["type": "daily_prompt"]
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-journal-prompt", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily prompt notification: \(error)")
            } else {
                print("Daily prompt notification scheduled for \(dateComponents.hour ?? 9):\(dateComponents.minute ?? 0)")
            }
        }
    }
    
    func scheduleMessageNotification(
        senderName: String,
        message: String,
        sessionTitle: String
    ) {
        scheduleNotification(
            title: "New message from \(senderName)",
            body: "\(sessionTitle): \(message.prefix(50))...",
            identifier: "message-\(UUID().uuidString)"
        )
    }
    
    func scheduleDailyReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Faith Journal Reminder"
        content.body = "Don't forget to spend time with God today!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily reminder: \(error)")
            }
        }
    }
    
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let identifier = response.notification.request.identifier
        
        Task { @MainActor in
            if identifier.contains("session-invitation") {
                // Navigate to invitations
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToInvitations"), object: nil)
            } else if identifier.contains("message") {
                // Navigate to live sessions
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToLiveSessions"), object: nil)
            }
        }
        
        completionHandler()
    }
}
