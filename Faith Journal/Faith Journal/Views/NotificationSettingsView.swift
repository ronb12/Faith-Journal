//
//  NotificationSettingsView.swift
//  Faith Journal
//
//  Settings view for smart notifications
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct NotificationSettingsView: View {
    @StateObject private var notificationService = SmartNotificationService.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingAuthorizationAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Enable/Disable Section
                Section {
                    Toggle("Enable Notifications", isOn: $notificationService.isEnabled)
                        .onChange(of: notificationService.isEnabled) { oldValue, newValue in
                            if newValue {
                                Task {
                                    let authorized = await notificationService.requestAuthorization()
                                    if !authorized {
                                        showingAuthorizationAlert = true
                                        notificationService.isEnabled = false
                                    } else {
                                        notificationService.savePreferences()
                                        await notificationService.scheduleAllNotifications(modelContext: modelContext)
                                    }
                                }
                            } else {
                                notificationService.savePreferences()
                                Task {
                                    await notificationService.cancelAllNotifications()
                                }
                            }
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get reminders to journal, pray, and read your Bible daily")
                }
                
                if notificationService.isEnabled {
                    // Notification Types Section
                    Section("Notification Types") {
                        Toggle("Journal Reminders", isOn: $notificationService.journalRemindersEnabled)
                            .onChange(of: notificationService.journalRemindersEnabled) { _, _ in
                                notificationService.savePreferences()
                                Task {
                                    await notificationService.scheduleAllNotifications(modelContext: modelContext)
                                }
                            }
                        
                        Toggle("Prayer Reminders", isOn: $notificationService.prayerRemindersEnabled)
                            .onChange(of: notificationService.prayerRemindersEnabled) { _, _ in
                                notificationService.savePreferences()
                                Task {
                                    await notificationService.scheduleAllNotifications(modelContext: modelContext)
                                }
                            }
                        
                        Toggle("Reading Plan Reminders", isOn: $notificationService.readingPlanRemindersEnabled)
                            .onChange(of: notificationService.readingPlanRemindersEnabled) { _, _ in
                                notificationService.savePreferences()
                                Task {
                                    await notificationService.scheduleAllNotifications(modelContext: modelContext)
                                }
                            }
                        
                        Toggle("Mood Check-In Reminders", isOn: $notificationService.moodCheckInRemindersEnabled)
                            .onChange(of: notificationService.moodCheckInRemindersEnabled) { _, _ in
                                notificationService.savePreferences()
                                Task {
                                    await notificationService.scheduleAllNotifications(modelContext: modelContext)
                                }
                            }
                    }
                    
                    // Preferred Times Section
                    Section(header: Text("Preferred Times")) {
                        DatePicker("Journal Time", selection: $notificationService.preferredJournalTime, displayedComponents: .hourAndMinute)
                            .onChange(of: notificationService.preferredJournalTime) { _, _ in
                                notificationService.savePreferences()
                                Task {
                                    await notificationService.scheduleAllNotifications(modelContext: modelContext)
                                }
                            }
                        
                        DatePicker("Prayer Time", selection: $notificationService.preferredPrayerTime, displayedComponents: .hourAndMinute)
                            .onChange(of: notificationService.preferredPrayerTime) { _, _ in
                                notificationService.savePreferences()
                                Task {
                                    await notificationService.scheduleAllNotifications(modelContext: modelContext)
                                }
                            }
                        
                        DatePicker("Reading Time", selection: $notificationService.preferredReadingTime, displayedComponents: .hourAndMinute)
                            .onChange(of: notificationService.preferredReadingTime) { _, _ in
                                notificationService.savePreferences()
                                Task {
                                    await notificationService.scheduleAllNotifications(modelContext: modelContext)
                                }
                            }
                    } footer: {
                        Text("Notifications will adapt to your usage patterns over time")
                    }
                    
                    // Test Notification Section
                    Section {
                        Button {
                            sendTestNotification()
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge")
                                Text("Send Test Notification")
                            }
                        }
                    } footer: {
                        Text("Send a test notification to verify your settings")
                    }
                }
                
                // Help Section
                Section("About Smart Notifications") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Smart Notifications learn from your usage patterns to send reminders at the best times for you.")
                            .font(.caption)
                        
                        Text("Features:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Adaptive scheduling based on when you use the app")
                            Text("• Contextual reminders (e.g., haven't journaled in 3 days)")
                            Text("• Gentle nudges, not nagging")
                            Text("• Respects your preferences")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Notifications Not Enabled", isPresented: $showingAuthorizationAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable notifications in Settings to receive reminders.")
            }
        }
    }
    
    private func sendTestNotification() {
        Task {
            let content = UNMutableNotificationContent()
            content.title = "Test Notification"
            content.body = "Your notification settings are working correctly!"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
            
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
