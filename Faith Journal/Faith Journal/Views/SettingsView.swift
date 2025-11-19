import SwiftUI
import SwiftData
import Foundation
import UserNotifications
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    @Query var userProfiles: [UserProfile]
    @AppStorage("selectedTheme") private var selectedTheme: String = "System"
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = false
    @AppStorage("reminderTime") private var reminderTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = false
    @State private var showResetAlert = false
    @State private var showExportSheet = false
    @State private var exportData: String = ""
    @State private var showAuthLock = false
    @State private var isAuthenticated = false
    @State private var showingProfileEdit = false
    @State private var showingTermsOfService = false
    @State private var showingPrivacyPolicy = false
    
    var userProfile: UserProfile? {
        userProfiles.first
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile")) {
                    HStack {
                        if let profile = userProfile, !profile.name.isEmpty {
                            // Profile Avatar
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [themeManager.colors.primary, themeManager.colors.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(profile.name.prefix(1).uppercased()))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(.headline)
                                
                                if let email = profile.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No Profile Set")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Tap to set up your profile")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingProfileEdit = true
                    }
                    
                    if userProfile == nil {
                        Button(action: {
                            showingProfileEdit = true
                        }) {
                            Text("Set Up Profile")
                                .foregroundColor(themeManager.colors.primary)
                        }
                    } else {
                        Button(action: {
                            showingProfileEdit = true
                        }) {
                            Text("Edit Profile")
                                .foregroundColor(themeManager.colors.primary)
                        }
                    }
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $themeManager.currentTheme) {
                        ForEach(ThemeManager.Theme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Reminders")) {
                    Toggle("Daily Reminder", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, enabled in
                            if enabled {
                                scheduleDailyReminder(at: reminderTime)
                            } else {
                                cancelDailyReminder()
                            }
                        }
                    if reminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _, newTime in
                                if reminderEnabled {
                                    scheduleDailyReminder(at: newTime)
                                }
                            }
                    }
                }
                
                Section(header: Text("Privacy & Security")) {
                    Toggle("Enable Biometric Lock", isOn: $biometricEnabled)
                        .onChange(of: biometricEnabled) { _, enabled in
                            if enabled {
                                showAuthLock = true
                            }
                        }
                }
                
                Section(header: Text("Data")) {
                    Button("Export Data") {
                        exportData = exportData(context: modelContext)
                        showExportSheet = true
                    }
                    .sheet(isPresented: $showExportSheet) {
                        ActivityView(activityItems: [exportData])
                    }
                    Button("Reset App Data", role: .destructive) {
                        showResetAlert = true
                    }
                    .alert("Reset All Data?", isPresented: $showResetAlert) {
                        Button("Delete Everything", role: .destructive) {
                            resetAllData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all your journal entries, prayers, and settings. This cannot be undone.")
                    }
                }
                
                Section(header: Text("Legal")) {
                    Button(action: {
                        showingTermsOfService = true
                    }) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        showingPrivacyPolicy = true
                    }) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
     