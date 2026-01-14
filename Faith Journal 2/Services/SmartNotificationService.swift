//
//  SmartNotificationService.swift
//  Faith Journal
//
//  Intelligent notification system for daily engagement
//

import Foundation
import UserNotifications
import SwiftData

@available(iOS 17.0, *)
@MainActor
class SmartNotificationService: ObservableObject {
    static let shared = SmartNotificationService()
    
    @Published var isEnabled = true
    @Published var journalRemindersEnabled = true
    @Published var prayerRemindersEnabled = true
    @Published var readingPlanRemindersEnabled = true
    @Published var moodCheckInRemindersEnabled = true
    
    @Published var preferredJournalTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var preferredPrayerTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var preferredReadingTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    
    private let userDefaults = UserDefaults.standard
    private var usagePatterns: [Date] = [] // Track when users open app/journal
    
    // Notification identifiers
    private enum NotificationID {
        static let journalReminder = "journal_reminder"
        static let prayerReminder = "prayer_reminder"
        static let readingPlanReminder = "reading_plan_reminder"
        static let moodCheckIn = "mood_checkin"
        static let gentleNudge = "gentle_nudge"
        static let answeredPrayer = "answered_prayer_check"
        static let streakReminder = "streak_reminder"
    }
    
    private init() {
        loadPreferences()
    }
    
    // MARK: - Preferences
    
    private func loadPreferences() {
        isEnabled = userDefaults.bool(forKey: "smartNotificationsEnabled", defaultValue: true)
        journalRemindersEnabled = userDefaults.bool(forKey: "journalRemindersEnabled", defaultValue: true)
        prayerRemindersEnabled = userDefaults.bool(forKey: "prayerRemindersEnabled", defaultValue: true)
        readingPlanRemindersEnabled = userDefaults.bool(forKey: "readingPlanRemindersEnabled", defaultValue: true)
        moodCheckInRemindersEnabled = userDefaults.bool(forKey: "moodCheckInRemindersEnabled", defaultValue: true)
        
        if let journalTime = userDefaults.object(forKey: "preferredJournalTime") as? Date {
            preferredJournalTime = journalTime
        }
        if let prayerTime = userDefaults.object(forKey: "preferredPrayerTime") as? Date {
            preferredPrayerTime = prayerTime
        }
        if let readingTime = userDefaults.object(forKey: "preferredReadingTime") as? Date {
            preferredReadingTime = readingTime
        }
    }
    
    func savePreferences() {
        userDefaults.set(isEnabled, forKey: "smartNotificationsEnabled")
        userDefaults.set(journalRemindersEnabled, forKey: "journalRemindersEnabled")
        userDefaults.set(prayerRemindersEnabled, forKey: "prayerRemindersEnabled")
        userDefaults.set(readingPlanRemindersEnabled, forKey: "readingPlanRemindersEnabled")
        userDefaults.set(moodCheckInRemindersEnabled, forKey: "moodCheckInRemindersEnabled")
        
        userDefaults.set(preferredJournalTime, forKey: "preferredJournalTime")
        userDefaults.set(preferredPrayerTime, forKey: "preferredPrayerTime")
        userDefaults.set(preferredReadingTime, forKey: "preferredReadingTime")
    }
    
    // MARK: - Usage Pattern Tracking
    
    func trackAppUsage() {
        usagePatterns.append(Date())
        // Keep only last 30 days
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        usagePatterns.removeAll { $0 < thirtyDaysAgo }
        
        // Update preferred times based on usage
        updatePreferredTimesFromUsage()
    }
    
    private func updatePreferredTimesFromUsage() {
        guard usagePatterns.count >= 7 else { return } // Need at least a week of data
        
        // Find most common journaling hours (evening times 18-22)
        let journalHours = usagePatterns
            .filter { Calendar.current.component(.hour, from: $0) >= 18 }
            .map { Calendar.current.component(.hour, from: $0) }
        
        if let mostCommonHour = journalHours.mostFrequent() {
            preferredJournalTime = Calendar.current.date(bySettingHour: mostCommonHour, minute: 0, second: 0, of: Date()) ?? preferredJournalTime
        }
    }
    
    // MARK: - Intelligent Notification Scheduling
    
    func scheduleAllNotifications(modelContext: ModelContext) async {
        guard isEnabled else {
            await cancelAllNotifications()
            return
        }
        
        // Check authorization first
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        guard settings.authorizationStatus == .authorized else {
            print("⚠️ Notifications not authorized")
            return
        }
        
        await scheduleJournalReminders(modelContext: modelContext)
        await schedulePrayerReminders(modelContext: modelContext)
        await scheduleReadingPlanReminders(modelContext: modelContext)
        await scheduleMoodCheckInReminders()
        await scheduleContextualReminders(modelContext: modelContext)
    }
    
    // MARK: - Journal Reminders
    
    private func scheduleJournalReminders(modelContext: ModelContext) async {
        guard journalRemindersEnabled else { return }
        
        // Check if user has journaled today
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { entry in
                entry.date >= today
            }
        )
        
        if let entries = try? modelContext.fetch(descriptor), entries.isEmpty {
            // User hasn't journaled today - schedule reminder
            let daysSinceLastEntry = await daysSinceLastJournalEntry(modelContext: modelContext)
            
            let content = UNMutableNotificationContent()
            content.sound = .default
            
            if daysSinceLastEntry >= 3 {
                content.title = "Continue Your Journey"
                content.body = "It's been \(daysSinceLastEntry) days since you last journaled. Take a moment to reflect on your faith journey."
            } else if daysSinceLastEntry >= 1 {
                content.title = "Time to Journal"
                content.body = "Capture today's thoughts and reflections in your journal."
            } else {
                content.title = "Daily Journal Reminder"
                content.body = "Don't forget to journal today! Reflect on God's blessings."
            }
            
            content.userInfo = ["type": "journal_reminder"]
            
            // Schedule for preferred time
            let components = Calendar.current.dateComponents([.hour, .minute], from: preferredJournalTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: NotificationID.journalReminder,
                content: content,
                trigger: trigger
            )
            
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func daysSinceLastJournalEntry(modelContext: ModelContext) async -> Int {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\JournalEntry.date, order: .reverse)]
        )
        
        guard let entries = try? modelContext.fetch(descriptor),
              let lastEntry = entries.first else {
            return 999 // Never journaled
        }
        
        let days = Calendar.current.dateComponents([.day], from: lastEntry.date, to: Date()).day ?? 0
        return days
    }
    
    // MARK: - Prayer Reminders
    
    private func schedulePrayerReminders(modelContext: ModelContext) async {
        guard prayerRemindersEnabled else { return }
        
        // Check for unanswered prayers
        let descriptor = FetchDescriptor<PrayerRequest>(
            predicate: #Predicate<PrayerRequest> { request in
                request.status == PrayerRequest.PrayerStatus.active
            }
        )
        
        let requests = try? modelContext.fetch(descriptor)
        if let requests = requests, !requests.isEmpty {
            let oldPrayers = requests.filter { request in
                let daysOld = Calendar.current.dateComponents([.day], from: request.createdAt, to: Date()).day ?? 0
                return daysOld >= 7
            }
            
            if !oldPrayers.isEmpty {
                let content = UNMutableNotificationContent()
                content.title = "Check Your Prayer Requests"
                content.body = "You have \(oldPrayers.count) prayer\(oldPrayers.count > 1 ? "s" : "") that you've been praying for. Consider checking if any have been answered."
                content.sound = .default
                content.userInfo = ["type": "prayer_reminder"]
                
                // Schedule for morning prayer time
                let components = Calendar.current.dateComponents([.hour, .minute], from: preferredPrayerTime)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                
                let request = UNNotificationRequest(
                    identifier: NotificationID.prayerReminder,
                    content: content,
                    trigger: trigger
                )
                
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    // MARK: - Reading Plan Reminders
    
    private func scheduleReadingPlanReminders(modelContext: ModelContext) async {
        guard readingPlanRemindersEnabled else { return }
        
        // Check for active reading plans
        let descriptor = FetchDescriptor<ReadingPlan>(
            predicate: #Predicate<ReadingPlan> { plan in
                !plan.isCompleted && !plan.isPaused
            }
        )
        
        let plans = try? modelContext.fetch(descriptor)
        if let plans = plans, !plans.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = "Daily Bible Reading"
            content.body = "Time for your daily Bible reading! Continue your reading plan."
            content.sound = .default
            content.userInfo = ["type": "reading_plan_reminder"]
            
            let components = Calendar.current.dateComponents([.hour, .minute], from: preferredReadingTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: NotificationID.readingPlanReminder,
                content: content,
                trigger: trigger
            )
            
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    
    // MARK: - Mood Check-In Reminders
    
    private func scheduleMoodCheckInReminders() async {
        guard moodCheckInRemindersEnabled else { return }
        
        // Schedule daily mood check-in at end of day
        var content = UNMutableNotificationContent()
        content.title = "Mood Check-In"
        content.body = "How are you feeling today? Track your mood to see patterns in your spiritual journey."
        content.sound = .default
        content.userInfo = ["type": "mood_checkin"]
        
        // Schedule for 9 PM
        var components = DateComponents()
        components.hour = 21
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: NotificationID.moodCheckIn,
            content: content,
            trigger: trigger
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Contextual Reminders
    
    private func scheduleContextualReminders(modelContext: ModelContext) async {
        // Gentle nudges for inactive users
        let daysSinceLastActivity = await daysSinceLastActivity(modelContext: modelContext)
        
        if daysSinceLastActivity >= 3 {
            let content = UNMutableNotificationContent()
            content.title = "We Miss You!"
            content.body = "It's been a while. Your faith journey is waiting for you."
            content.sound = .default
            content.userInfo = ["type": "gentle_nudge"]
            
            // Schedule for tomorrow at 10 AM
            if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
               let scheduledTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledTime)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let request = UNNotificationRequest(
                    identifier: NotificationID.gentleNudge,
                    content: content,
                    trigger: trigger
                )
                
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    private func daysSinceLastActivity(modelContext: ModelContext) async -> Int {
        // Check journal, prayer, and reading activity
        let today = Calendar.current.startOfDay(for: Date())
        
        let journalDescriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate<JournalEntry> { $0.date >= today }
        )
        
        let journalEntries = try? modelContext.fetch(journalDescriptor)
        let hasRecentJournal = journalEntries?.isEmpty == false
        
        if hasRecentJournal == true {
            return 0
        }
        
        // Find most recent activity
        let allJournalDescriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\JournalEntry.date, order: .reverse)]
        )
        
        if let entries = try? modelContext.fetch(allJournalDescriptor),
           let lastEntry = entries.first {
            return Calendar.current.dateComponents([.day], from: lastEntry.date, to: Date()).day ?? 0
        }
        
        return 999
    }
    
    // MARK: - Cancel Notifications
    
    func cancelAllNotifications() async {
        let identifiers = [
            NotificationID.journalReminder,
            NotificationID.prayerReminder,
            NotificationID.readingPlanReminder,
            NotificationID.moodCheckIn,
            NotificationID.gentleNudge,
            NotificationID.answeredPrayer,
            NotificationID.streakReminder
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Request Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("❌ Error requesting notification authorization: \(error)")
            return false
        }
    }
}

// MARK: - Helper Extensions

extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}

extension Array where Element == Int {
    func mostFrequent() -> Element? {
        let counts = Dictionary(grouping: self, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
