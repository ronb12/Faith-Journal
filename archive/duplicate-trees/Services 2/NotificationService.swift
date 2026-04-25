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
    @Published var badgeCount: Int = 0
    
    private override init() {
        super.init()
        print("🚀 [LAUNCH] NotificationService.init started")
        // CRITICAL: Defer potentially unsafe operations to avoid crashes during app startup
        // Don't access UNUserNotificationCenter or UIApplication during init on real devices
        // These will be initialized when first accessed
        UNUserNotificationCenter.current().delegate = self
        // Don't call clearBadge() during init - it accesses UIApplication which might not be ready
        // Badge will be cleared later in .task modifier
        print("🚀 [LAUNCH] NotificationService.init completed (deferred operations)")
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
    
    // MARK: - Badge Management
    
    /// Clear the app badge
    func clearBadge() {
        // Set badge to 0 using the new iOS 17+ API
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("Error clearing badge: \(error.localizedDescription)")
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        badgeCount = 0
        
        // Remove all delivered notifications to prevent badge from reappearing
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        // Also update any pending notifications to not set badge
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // For any pending notifications that have badge set, we'll update them
            // This is handled by not setting badge in recurring notifications
        }
    }
    
    /// Update badge count based on unread notifications
    /// Only counts one-time notifications (not recurring informational ones)
    func updateBadgeCount() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            DispatchQueue.main.async {
                // Only count one-time notifications (invitations, messages)
                // Filter out recurring informational notifications
                let oneTimeNotifications = notifications.filter { notification in
                    let userInfo = notification.request.content.userInfo
                    let notificationType = userInfo["type"] as? String
                    return notificationType != "daily_prompt" && 
                           notificationType != "devotional" && 
                           notificationType != "bible_verse" &&
                           notificationType != "daily_reminder"
                }
                
                let unreadCount = oneTimeNotifications.count
                self.badgeCount = unreadCount
                
                // Update badge using the new iOS 17+ API
                if #available(iOS 17.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(unreadCount) { error in
                        if let error = error {
                            print("Error updating badge: \(error.localizedDescription)")
                        }
                    }
                } else {
                    UIApplication.shared.applicationIconBadgeNumber = unreadCount
                }
            }
        }
    }
    
    /// Get the next badge number (increments current count)
    private func getNextBadgeNumber() -> NSNumber {
        badgeCount += 1
        return NSNumber(value: badgeCount)
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
        // Use dynamic badge count instead of hardcoded 1
        content.badge = getNextBadgeNumber()
        
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
        // For recurring daily notifications, don't set badge (they're informational)
        // Badge will be managed by one-time notifications like invitations and messages
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
        // Don't set badge for recurring reminders
        content.userInfo = ["type": "daily_reminder"]
        
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
    
    // MARK: - Devotional & Bible Verse Notifications
    
    func scheduleDevotionalNotification(
        title: String,
        scripture: String,
        content: String,
        time: Date
    ) {
        guard isAuthorized else { return }
        
        // Remove existing devotional notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-devotional"])
        
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = title
        notificationContent.subtitle = scripture
        notificationContent.body = content
        notificationContent.sound = .default
        // For recurring daily notifications, don't set badge (they're informational)
        notificationContent.userInfo = ["type": "devotional"]
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "daily-devotional", content: notificationContent, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling devotional notification: \(error)")
            } else {
                print("Devotional notification scheduled for \(dateComponents.hour ?? 9):\(dateComponents.minute ?? 0)")
            }
        }
    }
    
    func scheduleBibleVerseNotification(
        reference: String,
        text: String,
        translation: String,
        time: Date
    ) {
        guard isAuthorized else { return }
        
        // Remove existing verse of the day notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-bible-verse"])
        
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "📖 Verse of the Day"
        notificationContent.subtitle = "\(reference) (\(translation))"
        notificationContent.body = text
        notificationContent.sound = .default
        // For recurring daily notifications, don't set badge (they're informational)
        notificationContent.userInfo = ["type": "bible_verse"]
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "daily-bible-verse", content: notificationContent, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling Bible verse notification: \(error)")
            } else {
                print("Bible verse notification scheduled for \(dateComponents.hour ?? 9):\(dateComponents.minute ?? 0)")
            }
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground, but don't set badge
        // Badge will only be set for one-time notifications (invitations, messages)
        // Recurring notifications (daily prompts, devotionals) won't set badge
        let userInfo = notification.request.content.userInfo
        let isRecurring = userInfo["type"] as? String == "daily_prompt" || 
                          userInfo["type"] as? String == "devotional" || 
                          userInfo["type"] as? String == "bible_verse" ||
                          userInfo["type"] as? String == "daily_reminder"
        
        if isRecurring {
            // Don't show badge for recurring informational notifications
            completionHandler([.banner, .sound])
        } else {
            // Show badge for one-time notifications
            completionHandler([.banner, .sound, .badge])
        }
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let identifier = response.notification.request.identifier
        
        Task { @MainActor in
            // Clear badge when user taps on notification
            self.clearBadge()
            
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












