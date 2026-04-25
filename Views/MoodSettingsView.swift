//
//  MoodSettingsView.swift
//  Faith Journal
//
//  Mood settings and reminders view
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@available(iOS 17.0, macOS 14.0, *)
struct MoodSettingsView: View {
    @AppStorage("moodReminderEnabled") private var reminderEnabled = false
    @AppStorage("moodReminderTime") private var reminderTimeData: Data = Data()
    @AppStorage("moodWeeklyReviewEnabled") private var weeklyReviewEnabled = false
    
    @State private var reminderTime = Date()
    // Use regular property for singleton, not @StateObject
    private let reminderService = MoodReminderService.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Reminders")) {
                    Toggle("Daily Mood Check-in", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { oldValue, newValue in
                            if newValue {
                                Task {
                                    let granted = await reminderService.requestNotificationPermission()
                                    if granted {
                                        reminderService.scheduleDailyReminder(time: reminderTime, isEnabled: true)
                                    }
                                }
                            } else {
                                reminderService.cancelReminder()
                            }
                        }
                    
                    if reminderEnabled {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { oldValue, newValue in
                                reminderService.scheduleDailyReminder(time: newValue, isEnabled: reminderEnabled)
                            }
                    }
                    
                    Toggle("Weekly Review", isOn: $weeklyReviewEnabled)
                        .onChange(of: weeklyReviewEnabled) { oldValue, newValue in
                            reminderService.scheduleWeeklyReview(isEnabled: newValue)
                        }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // Show Privacy Policy view
                        if let url = URL(string: "https://faith-journal.web.app/privacy") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #elseif os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    }) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    
                    Button(action: {
                        // Show Terms of Service view
                        if let url = URL(string: "https://faith-journal.web.app/terms") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #elseif os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    }) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("Mood Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                if let decoded = try? JSONDecoder().decode(Date.self, from: reminderTimeData) {
                    reminderTime = decoded
                } else {
                    reminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                }
            }
            .onChange(of: reminderTime) { oldValue, newValue in
                if let encoded = try? JSONEncoder().encode(newValue) {
                    reminderTimeData = encoded
                }
            }
        }
    }
}
