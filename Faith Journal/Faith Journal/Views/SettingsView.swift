import SwiftUI
import SwiftData
import Foundation
import UserNotifications
import LocalAuthentication

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@available(iOS 17.0, *)
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var profileManager = ProfileManager.shared
    @Query var userProfiles: [UserProfile]
    private var userProfile: UserProfile? { userProfiles.first }
    @AppStorage("selectedTheme") private var selectedTheme: String = "System"
    // Default notification times (users can change these in settings)
    // Bible Verse: 7am, Journal Reminder: 8am, Devotional: 9am
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = true
    @AppStorage("reminderTimeInterval") private var reminderTimeInterval: Double = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = false
    @AppStorage("selectedBibleVersion") private var selectedBibleVersion: String = BibleVersion.niv.rawValue
    @AppStorage("devotionalNotificationsEnabled") private var devotionalNotificationsEnabled: Bool = true
    @AppStorage("devotionalTimeInterval") private var devotionalTimeInterval: Double = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    @AppStorage("bibleVerseNotificationsEnabled") private var bibleVerseNotificationsEnabled: Bool = true
    @AppStorage("bibleVerseTimeInterval") private var bibleVerseTimeInterval: Double = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    @AppStorage("useBibleAPI") private var useBibleAPI: Bool = false
    
    // Removed: API key is managed by the app, not user
    
    // State for DatePicker (synced with AppStorage)
    @State private var reminderTime: Date = Date()
    @State private var devotionalTime: Date = Date()
    @State private var bibleVerseTime: Date = Date()
    
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
    @State private var showingBibleStudy = false
    @State private var showingBibleView = false
    @State private var showingLiveSessions = false
    @State private var showingMoodAnalytics = false
    @State private var showingReadingPlans = false
    @State private var showingStatistics = false
    @State private var showingGlobalSearch = false
    @State private var syncStatusText: String = "Checking..."
    @State private var syncStatusIconColor: Color = .secondary
    @State private var showingContactSupport = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("hasLoggedIn") private var hasLoggedIn = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasPreviouslyLoggedIn") private var hasPreviouslyLoggedIn = false
    @State private var showLogoutAlert = false
    // CloudKitSyncService removed - using Firebase for sync
    
    @ViewBuilder
    private func profileAvatarView(profile: UserProfile) -> some View {
        if let avatarURLString = profile.avatarPhotoURL,
           let avatarURL = URL(string: avatarURLString),
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
                .overlay(profileInitialText(profile: profile))
        }
    }
    
    private func profileInitialText(profile: UserProfile) -> Text {
        let initial = String(profile.name.prefix(1).uppercased())
        return Text(initial)
            .font(.headline)
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
    }
    
    private func profileInitialCircle(profile: UserProfile) -> some View {
        Circle()
            .fill(profileGradient)
            .frame(width: 40, height: 40)
            .overlay(profileInitialText(profile: profile))
    }
    
    private var profileGradient: LinearGradient {
        LinearGradient(
            colors: [themeManager.colors.primary, themeManager.colors.secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    @ViewBuilder
    private func profileInfoView(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.name)
                .font(.headline)
            
            if let email = profile.email {
                Text(email)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
    
    @ViewBuilder
    private func profileInfoViewFirebase() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profileManager.userName)
                .font(.headline)
            
            // Email from Firebase Auth if available
            #if canImport(FirebaseAuth)
            if let email = Auth.auth().currentUser?.email {
                Text(email)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            #endif
        }
    }
    
    @ViewBuilder
    private func profileAvatarViewFirebase() -> some View {
        // Try to load profile image from Firebase
        if let urlString = profileManager.profileImageURL,
           let url = URL(string: urlString),
           let imageData = try? Data(contentsOf: url),
           let avatarImage = UIImage(data: imageData) {
            Image(uiImage: avatarImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
        } else {
            // Fallback to initial circle
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
                    Text(String(profileManager.userName.prefix(1).uppercased()))
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                )
        }
    }
    
    private func noProfileView() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No Profile Set")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Tap to set up your profile")
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private func profileActionButton() -> some View {
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
    
    @ViewBuilder
    private var settingsForm: some View {
        Form {
            profileSection
            appearanceSection
            colorThemeSection
            bibleSettingsSection
            notificationSections
            dataSection
            accountSection
            appInfoSection
            legalSection
        }
        .scrollContentBackground(.hidden)
    }
    
    @ViewBuilder
    private var profileSection: some View {
        Section(header: Text("Profile")) {
                        HStack {
                            // Use ProfileManager (Firebase) for name, fallback to local UserProfile
                            if !profileManager.userName.isEmpty {
                                // Profile Avatar - use Firebase profile image if available
                                profileAvatarViewFirebase()
                                
                                // Profile Info - use Firebase name
                                profileInfoViewFirebase()
                            } else if let profile = userProfile, !profile.name.isEmpty {
                                // Fallback to local UserProfile if Firebase doesn't have name
                                profileAvatarView(profile: profile)
                                profileInfoView(profile: profile)
                            } else {
                                noProfileView()
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.primary)
                                .font(.caption)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingProfileEdit = true
                        }
                        
                        profileActionButton()
        }
    }
    
    @ViewBuilder
    private var appearanceSection: some View {
        Section(header: Text("Appearance"), footer: Text("Choose light or dark mode for the app interface.")) {
            Picker("Appearance", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    @ViewBuilder
    private var colorThemeSection: some View {
        Section(header: Text("Color Theme"), footer: Text("Personalize your app with different color themes.")) {
            // Show current theme selection
            currentThemeDisplay
            
            // Color Theme Picker
            colorThemePicker
        }
    }
    
    @ViewBuilder
    private var currentThemeDisplay: some View {
        HStack {
            Text("Current Theme")
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(themeManager.colors.primary)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(themeManager.colors.secondary)
                    .frame(width: 12, height: 12)
            }
            Text(themeManager.currentTheme.rawValue)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var colorThemePicker: some View {
        Picker("Color Theme", selection: Binding(
            get: { themeManager.currentTheme },
            set: { themeManager.currentTheme = $0 }
        )) {
            ForEach(ThemeManager.Theme.allCases, id: \.self) { theme in
                themePickerRow(theme: theme)
                    .tag(theme)
            }
        }
        .pickerStyle(.menu)
    }
    
    @ViewBuilder
    private func themePickerRow(theme: ThemeManager.Theme) -> some View {
        let themeColors = colorsForTheme(theme)
        HStack(spacing: 12) {
            // Color preview (primary and secondary only, accent color is in Assets)
            HStack(spacing: 4) {
                Circle()
                    .fill(themeColors.primary)
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(themeColors.secondary)
                    .frame(width: 16, height: 16)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    .padding(-2)
            )
            Text(theme.rawValue)
                .font(.body)
            Spacer()
            if themeManager.currentTheme == theme {
                Image(systemName: "checkmark")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
    }
    
    // Helper function to get colors for a specific theme
    private func colorsForTheme(_ theme: ThemeManager.Theme) -> ThemeColors {
        switch theme {
        case .default:
            return ThemeColors(
                primary: Color(red: 0.4, green: 0.2, blue: 0.8),
                secondary: Color(red: 0.9, green: 0.6, blue: 0.2),
                accent: Color(red: 0.2, green: 0.8, blue: 0.6),
                background: Color(red: 0.98, green: 0.96, blue: 1.0),
                cardBackground: Color.white,
                text: Color(red: 0.1, green: 0.1, blue: 0.2),
                textSecondary: Color(red: 0.4, green: 0.4, blue: 0.5)
            )
        case .sunset:
            return ThemeColors(
                primary: Color(red: 0.9, green: 0.3, blue: 0.3),
                secondary: Color(red: 1.0, green: 0.7, blue: 0.3),
                accent: Color(red: 0.8, green: 0.4, blue: 0.6),
                background: Color(red: 1.0, green: 0.95, blue: 0.9),
                cardBackground: Color.white,
                text: Color(red: 0.3, green: 0.2, blue: 0.2),
                textSecondary: Color(red: 0.6, green: 0.4, blue: 0.4)
            )
        case .ocean:
            return ThemeColors(
                primary: Color(red: 0.2, green: 0.6, blue: 0.9),
                secondary: Color(red: 0.4, green: 0.8, blue: 1.0),
                accent: Color(red: 0.1, green: 0.8, blue: 0.7),
                background: Color(red: 0.95, green: 0.98, blue: 1.0),
                cardBackground: Color.white,
                text: Color(red: 0.1, green: 0.2, blue: 0.4),
                textSecondary: Color(red: 0.4, green: 0.5, blue: 0.6)
            )
        case .forest:
            return ThemeColors(
                primary: Color(red: 0.2, green: 0.7, blue: 0.3),
                secondary: Color(red: 0.6, green: 0.8, blue: 0.4),
                accent: Color(red: 0.8, green: 0.6, blue: 0.2),
                background: Color(red: 0.96, green: 0.98, blue: 0.95),
                cardBackground: Color.white,
                text: Color(red: 0.1, green: 0.3, blue: 0.1),
                textSecondary: Color(red: 0.4, green: 0.5, blue: 0.4)
            )
        case .lavender:
            return ThemeColors(
                primary: Color(red: 0.6, green: 0.4, blue: 0.9),
                secondary: Color(red: 0.8, green: 0.6, blue: 1.0),
                accent: Color(red: 0.9, green: 0.4, blue: 0.8),
                background: Color(red: 0.98, green: 0.96, blue: 1.0),
                cardBackground: Color.white,
                text: Color(red: 0.3, green: 0.2, blue: 0.4),
                textSecondary: Color(red: 0.5, green: 0.4, blue: 0.6)
            )
        case .golden:
            return ThemeColors(
                primary: Color(red: 0.9, green: 0.7, blue: 0.2),
                secondary: Color(red: 1.0, green: 0.8, blue: 0.4),
                accent: Color(red: 0.8, green: 0.5, blue: 0.2),
                background: Color(red: 1.0, green: 0.98, blue: 0.95),
                cardBackground: Color.white,
                text: Color(red: 0.4, green: 0.3, blue: 0.1),
                textSecondary: Color(red: 0.6, green: 0.5, blue: 0.3)
            )
        case .midnight:
            return ThemeColors(
                primary: Color(red: 0.3, green: 0.2, blue: 0.8),
                secondary: Color(red: 0.6, green: 0.4, blue: 1.0),
                accent: Color(red: 0.2, green: 0.8, blue: 0.9),
                background: Color(red: 0.05, green: 0.05, blue: 0.1),
                cardBackground: Color(red: 0.1, green: 0.1, blue: 0.15),
                text: Color.white,
                textSecondary: Color(red: 0.7, green: 0.7, blue: 0.8)
            )
        case .spring:
            return ThemeColors(
                primary: Color(red: 0.8, green: 0.4, blue: 0.6),
                secondary: Color(red: 0.6, green: 0.8, blue: 0.4),
                accent: Color(red: 0.4, green: 0.6, blue: 0.8),
                background: Color(red: 0.98, green: 0.95, blue: 0.98),
                cardBackground: Color.white,
                text: Color(red: 0.3, green: 0.2, blue: 0.3),
                textSecondary: Color(red: 0.5, green: 0.4, blue: 0.5)
            )
        case .pink:
            return ThemeColors(
                primary: Color(red: 1.0, green: 0.4, blue: 0.7),
                secondary: Color(red: 1.0, green: 0.6, blue: 0.8),
                accent: Color(red: 0.9, green: 0.3, blue: 0.6),
                background: Color(red: 1.0, green: 0.98, blue: 0.99),
                cardBackground: Color.white,
                text: Color(red: 0.3, green: 0.1, blue: 0.2),
                textSecondary: Color(red: 0.6, green: 0.4, blue: 0.5)
            )
    }
    }
    
    @ViewBuilder
    private var bibleSettingsSection: some View {
        Section(header: Text("Bible Settings"), footer: Text(useBibleAPI ? "Using Bible API for multiple translations. Requires internet connection." : "Using offline verses (NIV only). Enable API for other translations.")) {
                        Picker("Bible Version", selection: $selectedBibleVersion) {
                            ForEach(BibleVersion.allCases, id: \.rawValue) { version in
                                VStack(alignment: .leading) {
                                    Text(version.rawValue)
                                        .font(.headline)
                                    Text(version.fullName)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                .tag(version.rawValue)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedBibleVersion) { _, newVersion in
                            if let version = BibleVersion(rawValue: newVersion) {
                                // Update version first
                                BibleVerseOfTheDayManager.shared.updateVersion(version)
                                
                                // Automatically enable API mode if user selects a non-NIV version
                                // since local verses are only available in NIV
                                if version != .niv {
                                    // Update the toggle binding to reflect API mode is enabled
                                    // This will also trigger toggleAPIUsage via the onChange handler
                                    useBibleAPI = true
                                }
                            }
                        }
                        
                        Toggle("Use Bible API", isOn: $useBibleAPI)
                            .onChange(of: useBibleAPI) { _, enabled in
                                BibleVerseOfTheDayManager.shared.toggleAPIUsage(enabled)
                            }
                        
                        // Removed: API key entry and info UI
        }
    }
    
    @ViewBuilder
    private var notificationSections: some View {
        Section(header: Text("Daily Devotional"), footer: Text("Receive full devotional content as a notification")) {
                        Toggle("Daily Devotional Notification", isOn: $devotionalNotificationsEnabled)
                            .onChange(of: devotionalNotificationsEnabled) { _, enabled in
                                if enabled {
                                    scheduleDevotionalNotification(at: devotionalTime)
                                } else {
                                    cancelDevotionalNotification()
                                }
                            }
                        if devotionalNotificationsEnabled {
                            DatePicker("Time", selection: $devotionalTime, displayedComponents: .hourAndMinute)
                                .onChange(of: devotionalTime) { _, newTime in
                                    scheduleDevotionalNotification(at: newTime)
                                }
                        }
                    }
                    
                    Section(header: Text("Daily Bible Verse"), footer: Text("Receive a daily Bible verse as a notification")) {
                        Toggle("Bible Verse Notification", isOn: $bibleVerseNotificationsEnabled)
                            .onChange(of: bibleVerseNotificationsEnabled) { _, enabled in
                                if enabled {
                                    scheduleBibleVerseNotification(at: bibleVerseTime)
                                } else {
                                    cancelBibleVerseNotification()
                                }
                            }
                        if bibleVerseNotificationsEnabled {
                            DatePicker("Time", selection: $bibleVerseTime, displayedComponents: .hourAndMinute)
                                .onChange(of: bibleVerseTime) { _, newTime in
                                    scheduleBibleVerseNotification(at: newTime)
                                }
                        }
                    }
                    
                    Section(header: Text("Reminders")) {
                        Toggle("Daily Journal Reminder", isOn: $reminderEnabled)
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
                                    scheduleDailyReminder(at: newTime)
                                }
                        }
        }
    }
    
    @ViewBuilder
    private var dataSection: some View {
        Section(header: Text("Data"), footer: Text("Your data automatically syncs across all your devices when signed in with Apple. Changes sync in real-time via Firebase.")) {
                        // Backup & Restore
                        if #available(iOS 17.0, *) {
                            NavigationLink {
                                BackupRestoreView()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .foregroundColor(themeManager.colors.primary)
                                    Text("Backup & Restore")
                                }
                            }
                        }
                        
                        // CloudKit Sync Section - Simple and user-friendly
                        if #available(iOS 17.0, *) {
                            // Simple sync status indicator
                            HStack {
                                Label("Sync Status", systemImage: "cloud.fill")
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: syncStatusText == "Synced" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(syncStatusIconColor)
                                        .font(.caption)
                                    Text(syncStatusText)
                                        .font(.caption)
                                        .foregroundColor(syncStatusIconColor)
                                }
                            }
                            .task {
                                // Using Firebase for sync - check sync status
                                await MainActor.run {
                                    updateSyncStatus()
                                }
                            }
                            .onChange(of: FirebaseSyncService.shared.isSyncing) { _, _ in
                                updateSyncStatus()
                            }
                            
                            // Manual sync button
                            Button(action: {
                                Task {
                                    await performManualSync()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Sync Now")
                                }
                            }
                            .disabled(FirebaseSyncService.shared.isSyncing)
                            
                            Divider()
                        }
                        
                        Button(action: {
                            exportData = exportData(context: modelContext)
                            showExportSheet = true
                        }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: {
                            showResetAlert = true
                        }) {
                            Label("Reset All Data", systemImage: "trash")
                        }
        }
    }
    
    @ViewBuilder
    private var accountSection: some View {
        Section(header: Text("Account")) {
                        Button(role: .destructive, action: {
                            showLogoutAlert = true
                        }) {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
        }
    }
    
    @ViewBuilder
    private var appInfoSection: some View {
        Section(header: Text("App Information")) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundColor(.primary)
                        }

                        HStack {
                            Text("Build")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
                                .foregroundColor(.primary)
                        }

                        HStack {
                            Text("Built by")
                            Spacer()
                            Text("Ronell Bradley")
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                            Text("Faith Journal is a comprehensive spiritual companion app designed to help you deepen your faith journey. Track your daily reflections, manage prayer requests, explore Bible verses and devotionals, analyze your mood patterns, and connect with others through live sessions. Built with love to support your spiritual growth and daily walk with God.")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 4)
                        
                        Button(action: {
                            showingContactSupport = true
                        }) {
                            Label("Contact Support", systemImage: "envelope.fill")
                        }
        }
    }
    
    @ViewBuilder
    private var legalSection: some View {
        Section(header: Text("Legal")) {
                        Button(action: {
                            showingTermsOfService = true
                        }) {
                            Label("Terms of Service", systemImage: "doc.text")
                        }
                        
                        Button(action: {
                            showingPrivacyPolicy = true
                        }) {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                        }
        }
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            NavigationStack {
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea(.all, edges: .all)
                    
                    settingsForm
                }
                .navigationTitle("Settings")
                .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    // Configure navigation bar to extend behind status bar
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor.systemGroupedBackground
                    appearance.shadowColor = .clear
                    UINavigationBar.appearance().standardAppearance = appearance
                    UINavigationBar.appearance().scrollEdgeAppearance = appearance
                }
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
                .sheet(isPresented: $showingContactSupport) {
                    ContactSupportView()
                }
                .sheet(isPresented: $showExportSheet) {
                    ShareSheet(activityItems: [exportData])
                }
                .alert("Reset All Data", isPresented: $showResetAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        resetAllData()
                    }
                } message: {
                    Text("This will permanently delete all your journal entries, prayers, moods, and other data. This action cannot be undone.")
                }
                .alert("Log Out", isPresented: $showLogoutAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Log Out", role: .destructive) {
                        logout()
                    }
                } message: {
                    Text("Are you sure you want to log out? You will be returned to the login screen.")
                }
                .onAppear {
                    ensureUserProfileExists()
                    // Load profile from Firebase
                    Task {
                        await profileManager.loadProfile()
                    }
                    updateReminderTime()
                    reminderTime = Date(timeIntervalSince1970: reminderTimeInterval)
                    devotionalTime = Date(timeIntervalSince1970: devotionalTimeInterval)
                    bibleVerseTime = Date(timeIntervalSince1970: bibleVerseTimeInterval)
                    
                    // Schedule default notifications if they're enabled
                    // This ensures notifications are set up even if user hasn't visited settings yet
                    Task {
                        // Request notification permission first
                        let authorized = await NotificationService.shared.requestAuthorization()
                        if authorized {
                            // Schedule notifications with default times if enabled
                            if reminderEnabled {
                                scheduleDailyReminder(at: reminderTime)
                            }
                            if devotionalNotificationsEnabled {
                                scheduleDevotionalNotification(at: devotionalTime)
                            }
                            if bibleVerseNotificationsEnabled {
                                scheduleBibleVerseNotification(at: bibleVerseTime)
                            }
                        }
                    }
                }
                .onChange(of: profileManager.userName) { oldValue, newValue in
                    // Reload profile when name changes
                    if !newValue.isEmpty {
                        print("🔄 [SettingsView] Profile name updated: \(newValue)")
                    }
                }
                .onChange(of: profileManager.profileImageURL) { oldValue, newValue in
                    // Reload when profile image changes
                    print("🔄 [SettingsView] Profile image URL updated")
                }
            }
        } else {
            Text("Faith Journal requires iOS 17.0 or later")
        }
    }
    
    // Helper function to format last sync time
    private func lastSyncTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Helper to get color for sync status
    private var syncStatusColor: Color {
        if FirebaseSyncService.shared.isSyncing {
            return .blue
        } else {
            return .green
        }
    }
    
    // Update sync status display
    private func updateSyncStatus() {
        if FirebaseSyncService.shared.isSyncing {
            syncStatusText = "Syncing..."
            syncStatusIconColor = .blue
        } else if let lastSync = FirebaseSyncService.shared.lastSyncDate {
            syncStatusText = "Synced \(lastSyncTimeString(from: lastSync))"
            syncStatusIconColor = .green
        } else if FirebaseSyncService.shared.syncError != nil {
            syncStatusText = "Error"
            syncStatusIconColor = .red
        } else {
            syncStatusText = "Ready"
            syncStatusIconColor = .green
        }
    }
    
    // Perform manual sync
    private func performManualSync() async {
        syncStatusText = "Syncing..."
        syncStatusIconColor = .blue
        
        // Restart listener to catch any missed updates
        FirebaseSyncService.shared.restartListening()
        
        // Sync all data
        await FirebaseSyncService.shared.syncAllData()
        
        // Update status
        await MainActor.run {
            updateSyncStatus()
        }
    }
    
    // Get Firebase user ID for debugging
    private func getFirebaseUserId() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
    
    private func ensureUserProfileExists() {
        if userProfiles.isEmpty {
            // Create default profile if none exists
            let defaultName = UIDevice.current.name
            let profile = UserProfile(name: defaultName)
            modelContext.insert(profile)
            
            do {
                try modelContext.save()
            } catch {
                print("❌ Error creating default profile: \(error.localizedDescription)")
                ErrorHandler.shared.handle(.saveFailed)
            }
        }
    }
    
    // LOGOUT
    private func logout() {
        print("🚪 [LOGOUT] Logging out user...")
        
        // Reset login state completely to show login screen
        hasLoggedIn = false
        hasPreviouslyLoggedIn = false
        // Keep onboarding state - user doesn't need to go through it again
        
        print("✅ [LOGOUT] User logged out successfully")
        print("✅ [LOGOUT] Login state reset - app will navigate to login screen")
        print("ℹ️ [LOGOUT] hasLoggedIn: false, hasCompletedOnboarding: \(hasCompletedOnboarding)")
        
        // The @AppStorage change should automatically trigger AppRootView to re-evaluate
        // and show LandingView since hasLoggedIn is now false
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

func scheduleDevotionalNotification(at date: Date) {
    Task {
        // Request authorization if needed
        let authorized = await NotificationService.shared.requestAuthorization()
        guard authorized else { return }
        
        // Get today's devotional from DevotionalManager
        let devotional = DevotionalManager.shared.devotionals.first
        
        if let devotional = devotional {
            NotificationService.shared.scheduleDevotionalNotification(
                title: devotional.title,
                scripture: devotional.scripture,
                content: devotional.content,
                time: date
            )
        }
    }
}

func cancelDevotionalNotification() {
    NotificationService.shared.cancelNotification(identifier: "daily-devotional")
}

func scheduleBibleVerseNotification(at date: Date) {
    Task {
        // Request authorization if needed
        let authorized = await NotificationService.shared.requestAuthorization()
        guard authorized else { return }
        
        // Get today's verse from BibleVerseOfTheDayManager
        let verse = BibleVerseOfTheDayManager.shared.currentVerse
        
        if let verse = verse {
            NotificationService.shared.scheduleBibleVerseNotification(
                reference: verse.reference,
                text: verse.text,
                translation: verse.translation,
                time: date
            )
        }
    }
}

func cancelBibleVerseNotification() {
    NotificationService.shared.cancelNotification(identifier: "daily-bible-verse")
}

// Biometric lock view extracted from SettingsView to avoid accidental
// top-level property declarations inside the SettingsView file.
struct BiometricLockView: View {
    @Binding var isAuthenticated: Bool
    @Environment(\.dismiss) var dismiss
    @State private var errorMessage: String?

    var body: some View {
        if #available(iOS 17.0, *) {
            VStack(spacing: 24) {
                Text("Unlock Faith Journal")
                    .font(.title)
                    .font(.body.weight(.bold))
                Button("Unlock with Face ID / Touch ID") {
                    authenticate()
                }
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            .onAppear(perform: authenticate)
        } else {
            Text("Biometric lock is only available on iOS 17+")
        }
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

@available(iOS 17.0, *)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}