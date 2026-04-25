//
//  MoodReminderService.swift
//  Faith Journal
//
//  Mood check-in reminders service
//

import Foundation
import UserNotifications

@available(iOS 17.0, *)
class MoodReminderService: ObservableObject {
    static let shared = MoodReminderService()
    
    private init() {}
    
    func requestNotificationPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Error requesting notification authorization: \(error.localizedDescription)")
            return false
        }
    }
    
    func scheduleDailyReminder(time: Date, isEnabled: Bool) {
        if !isEnabled {
            cancelReminder()
            return
        }
        
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted == true {
                cancelReminder() // Remove existing reminders
                
                let content = UNMutableNotificationContent()
                content.title = "📝 Time for Your Mood Check-in"
                content.body = "How are you feeling today? Take a moment to track your mood."
                content.sound = .default
                content.userInfo = ["type": "moodReminder"]
                
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: time)
                var dateComponents = DateComponents()
                dateComponents.hour = components.hour
                dateComponents.minute = components.minute
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(identifier: "moodDailyReminder", content: content, trigger: trigger)
                
                do {
                    try await center.add(request)
                    print("✅ Scheduled daily mood reminder at \(time)")
                } catch {
                    print("❌ Error scheduling reminder: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func scheduleWeeklyReview(isEnabled: Bool) {
        if !isEnabled {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["moodWeeklyReview"])
            return
        }
        
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted == true {
                let content = UNMutableNotificationContent()
                content.title = "📊 Weekly Mood Review"
                content.body = "Check out your mood patterns and insights for this week!"
                content.sound = .default
                content.userInfo = ["type": "moodWeeklyReview"]
                
                var dateComponents = DateComponents()
                dateComponents.weekday = 1 // Sunday
                dateComponents.hour = 9
                dateComponents.minute = 0
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(identifier: "moodWeeklyReview", content: content, trigger: trigger)
                
                do {
                    try await center.add(request)
                    print("✅ Scheduled weekly mood review")
                } catch {
                    print("❌ Error scheduling weekly review: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["moodDailyReminder"])
    }
    
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["moodDailyReminder", "moodWeeklyReview"])
    }
}
