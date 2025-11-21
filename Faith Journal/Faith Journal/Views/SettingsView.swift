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
    @AppStorage("reminderTimeInterval") private var reminderTimeInterval: Double = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = false
    
    // State for DatePicker (synced with AppStorage)
    @State private var reminderTime: Date = Date()
    
    // Computed property to sync Date with AppStorage
    private func updateReminderTime() {
        reminderTime = Date(timeIntervalSince1970: reminderTimeInterval)
    }
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
                            if let avatarURL = profile.avatarPhotoURL,
                               let imageData = try? Data(contentsOf: avatarURL),
                               let avatarImage = UIImage(data: imageData) {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            } else {
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
                            }
                            
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
                                reminderTimeInterval = newTime.timeIntervalSince1970
                                if reminderEnabled {
                                    scheduleDailyReminder(at: newTime)
                                }
                            }
                    }
                }
                .onAppear {
                    // Sync DatePicker with stored value (iOS 17.0 compatible)
                    reminderTime = Date(timeIntervalSince1970: reminderTimeInterval)
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
                    }
                }
                
                Section(header: Text("App Info")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Contact Support")
                        Spacer()
                        Link("Email", destination: URL(string: "mailto:support@faithjournal.app")!)
                    }
                    HStack {
                        Text("About")
                        Spacer()
                        Text("Faith Journal helps you grow in faith, one day at a time.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationViewStyle(.stack) // Force full-width layout on iPad
            .fullScreenCover(isPresented: $showAuthLock) {
                BiometricLockView(isAuthenticated: $isAuthenticated)
            }
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView(profile: userProfile)
            }
            .sheet(isPresented: $showingTermsOfService) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .onAppear {
                ensureUserProfileExists()
            }
        }
    }
    
    private func ensureUserProfileExists() {
        if userProfiles.isEmpty {
            // Create default profile if none exists
            let defaultName = UIDevice.current.name
            let profile = UserProfile(name: defaultName)
            modelContext.insert(profile)
            try? modelContext.save()
        }
    }
    
    // REMINDERS
    func scheduleDailyReminder(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Faith Journal"
            content.body = "Don't forget to reflect and journal today!"
            content.sound = .default
            let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
            center.add(request)
        }
    }
    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
    }
    
    // BIOMETRIC
    struct BiometricLockView: View {
        @Binding var isAuthenticated: Bool
        @Environment(\.dismiss) var dismiss
        @State private var errorMessage: String?
        var body: some View {
            VStack(spacing: 24) {
                Text("Unlock Faith Journal")
                    .font(.title)
                    .fontWeight(.bold)
                Button("Unlock with Face ID / Touch ID") {
                    authenticate()
                }
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            .onAppear(perform: authenticate)
        }
        func authenticate() {
            let context = LAContext()
            var error: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Faith Journal") { success, authError in
                    DispatchQueue.main.async {
                        if success {
                            isAuthenticated = true
                            dismiss()
                        } else {
                            errorMessage = "Authentication failed. Try again."
                        }
                    }
                }
            } else {
                errorMessage = "Biometric authentication not available."
            }
        }
    }
    
    // EXPORT DATA
    func exportAllData() -> String {
        // This function should be called with modelContext to access actual data
        // For now, return a template that can be enhanced
        let exportInfo = """
        Faith Journal Export
        Generated: \(Date().formatted())
        
        Note: Full data export requires modelContext access.
        This is a simplified export template.
        """
        return exportInfo
    }
    
    func exportData(context: ModelContext) -> String {
        do {
            var exportContent = "Faith Journal Data Export\n"
            exportContent += "Generated: \(Date().formatted())\n\n"
            
            // Export Journal Entries
            let entryDescriptor = FetchDescriptor<JournalEntry>()
            let entries = try context.fetch(entryDescriptor)
            exportContent += "=== JOURNAL ENTRIES (\(entries.count)) ===\n"
            for entry in entries {
                exportContent += """
                
                Title: \(entry.title)
                Date: \(entry.date.formatted())
                Content: \(entry.content.prefix(200))
                Tags: \(entry.tags.joined(separator: ", "))
                Mood: \(entry.mood ?? "N/A")
                Private: \(entry.isPrivate ? "Yes" : "No")
                ---
                """
            }
            
            // Export Prayer Requests
            let prayerDescriptor = FetchDescriptor<PrayerRequest>()
            let prayers = try context.fetch(prayerDescriptor)
            exportContent += "\n\n=== PRAYER REQUESTS (\(prayers.count)) ===\n"
            for prayer in prayers {
                exportContent += """
                
                Title: \(prayer.title)
                Status: \(prayer.status.rawValue)
                Date: \(prayer.date.formatted())
                Answered: \(prayer.isAnswered ? "Yes" : "No")
                Details: \(prayer.details.prefix(200))
                Tags: \(prayer.tags.joined(separator: ", "))
                ---
                """
            }
            
            // Export Mood Entries
            let moodDescriptor = FetchDescriptor<MoodEntry>()
            let moods = try context.fetch(moodDescriptor)
            exportContent += "\n\n=== MOOD ENTRIES (\(moods.count)) ===\n"
            for mood in moods {
                exportContent += """
                
                Mood: \(mood.mood)
                Intensity: \(mood.intensity)/10
                Date: \(mood.date.formatted())
                Notes: \(mood.notes ?? "None")
                ---
                """
            }
            
            return exportContent
        } catch {
            return "Error exporting data: \(error.localizedDescription)"
        }
    }
    
    // RESET DATA
    func resetAllData() {
        // Clear UserDefaults
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        // Delete all SwiftData models
        do {
            // Delete all Journal Entries
            let journalDescriptor = FetchDescriptor<JournalEntry>()
            let journalEntries = try modelContext.fetch(journalDescriptor)
            for entry in journalEntries {
                modelContext.delete(entry)
            }
            
            // Delete all Prayer Requests
            let prayerDescriptor = FetchDescriptor<PrayerRequest>()
            let prayers = try modelContext.fetch(prayerDescriptor)
            for prayer in prayers {
                modelContext.delete(prayer)
            }
            
            // Delete all Mood Entries
            let moodDescriptor = FetchDescriptor<MoodEntry>()
            let moods = try modelContext.fetch(moodDescriptor)
            for mood in moods {
                modelContext.delete(mood)
            }
            
            // Delete all User Profiles
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(profileDescriptor)
            for profile in profiles {
                modelContext.delete(profile)
            }
            
            // Delete all Bible Verse of the Day entries
            let verseDescriptor = FetchDescriptor<BibleVerseOfTheDay>()
            let verses = try modelContext.fetch(verseDescriptor)
            for verse in verses {
                modelContext.delete(verse)
            }
            
            // Delete all Reading Plans
            let planDescriptor = FetchDescriptor<ReadingPlan>()
            let plans = try modelContext.fetch(planDescriptor)
            for plan in plans {
                modelContext.delete(plan)
            }
            
            // Delete all Bookmarked Verses
            let bookmarkDescriptor = FetchDescriptor<BookmarkedVerse>()
            let bookmarks = try modelContext.fetch(bookmarkDescriptor)
            for bookmark in bookmarks {
                modelContext.delete(bookmark)
            }
            
            // Save changes
            try modelContext.save()
        } catch {
            print("Error resetting SwiftData: \(error.localizedDescription)")
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 