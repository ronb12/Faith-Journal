//
//  ReadingPlanReminderService.swift
//  Faith Journal
//
//  Handles daily reminders for reading plans
//

import Foundation
import UserNotifications
import SwiftData

@available(iOS 17.0, *)
class ReadingPlanReminderService {
    static let shared = ReadingPlanReminderService()
    
    private init() {}
    
    func requestNotificationPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("❌ Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func scheduleReminder(for plan: ReadingPlan) {
        guard plan.reminderEnabled, !plan.isCompleted, !plan.isPaused else {
            cancelReminder(for: plan)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "📖 Time for Your Daily Reading"
        content.body = "Don't forget to read \(plan.title) - Day \(plan.currentDay)"
        content.sound = .default
        content.badge = 1
        content.userInfo = ["planId": plan.id.uuidString, "type": "readingPlan"]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: plan.reminderTime)
        
        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "readingPlan_\(plan.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling reminder: \(error)")
            } else {
                print("✅ Reminder scheduled for plan: \(plan.title)")
            }
        }
    }
    
    func cancelReminder(for plan: ReadingPlan) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["readingPlan_\(plan.id.uuidString)"]
        )
    }
    
    func updateReminder(for plan: ReadingPlan) {
        cancelReminder(for: plan)
        scheduleReminder(for: plan)
    }
    
    func scheduleCatchUpReminder(for plan: ReadingPlan) {
        guard plan.catchUpModeEnabled, plan.missedDays > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📚 Catch Up on Your Reading"
        content.body = "You have \(plan.missedDays) day(s) to catch up on \(plan.title)"
        content.sound = .default
        content.userInfo = ["planId": plan.id.uuidString, "type": "catchUp"]
        
        // Schedule for 2 hours after regular reminder
        let calendar = Calendar.current
        if let reminderDate = calendar.date(bySettingHour: calendar.component(.hour, from: plan.reminderTime),
                                           minute: calendar.component(.minute, from: plan.reminderTime),
                                           second: 0,
                                           of: Date()),
           let catchUpDate = calendar.date(byAdding: .hour, value: 2, to: reminderDate) {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: catchUpDate.timeIntervalSinceNow, repeats: false)
            let request = UNNotificationRequest(
                identifier: "catchUp_\(plan.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
}

