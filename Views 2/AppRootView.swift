//
//  AppRootView.swift
//  Faith Journal
//
//  Root view that handles app flow: Landing -> Login -> Onboarding -> Main App
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasLoggedIn") private var hasLoggedIn = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @State private var showOnboarding = false
    @StateObject private var appNavigation = AppNavigation()
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @State private var pendingInviteCode: String? = nil
    @State private var showingJoinByCode = false
    
    // For testing: Set to true to bypass login and show ContentView directly
    private let bypassLoginForTesting = false
    
    // Firebase sync service - use @ObservedObject for shared singleton
    @ObservedObject private var firebaseSync = FirebaseSyncService.shared
    
    var selectedColorScheme: ColorScheme? {
        guard let mode = AppearanceMode(rawValue: appearanceMode) else { return nil }
        return mode.colorScheme
    }
    
    var body: some View {
        ZStack {
            // Base background to prevent any black from showing - extends under all safe areas
            Color.purple.opacity(0.8)
                .ignoresSafeArea(.all, edges: [.top, .bottom, .leading, .trailing])
            
            #if targetEnvironment(simulator)
            // In simulator, allow demo mode to bypass login
            if bypassLoginForTesting || (hasLoggedIn && hasCompletedOnboarding) {
                ContentView()
                    .environmentObject(appNavigation)
            } else if hasLoggedIn && !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else {
                LandingView(hasLoggedIn: $hasLoggedIn)
            }
            #else
            // On real devices, always require proper authentication
            // Check if user has properly authenticated (not just demo mode)
            if bypassLoginForTesting {
                ContentView()
                    .environmentObject(appNavigation)
            } else if hasLoggedIn && hasCompletedOnboarding {
                // User has logged in - show main app
                ContentView()
                    .environmentObject(appNavigation)
            } else if hasLoggedIn && !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else {
                // Show login screen - always allow login on real devices
                LandingView(hasLoggedIn: $hasLoggedIn)
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(selectedColorScheme)
        .ignoresSafeArea(.all, edges: [.top, .bottom, .leading, .trailing])
        .onAppear {
            print("🚀 [LAUNCH] AppRootView.onAppear started")
            showOnboarding = !hasCompletedOnboarding
            print("🚀 [LAUNCH] Onboarding state: \(hasCompletedOnboarding)")
            // Clear badge when app opens - do this safely on main actor
            Task { @MainActor in
                NotificationService.shared.clearBadge()
                print("🚀 [LAUNCH] AppRootView badge cleared")
                
                // Fix corrupted UserDefaults values that might cause crashes
                // Check for bookmarkedVerses - if it's a String, remove it
                if let value = UserDefaults.standard.object(forKey: "bookmarkedVerses"),
                   value is String {
                    print("⚠️ [FIX] Found corrupted bookmarkedVerses (String), removing...")
                    UserDefaults.standard.removeObject(forKey: "bookmarkedVerses")
                }
                
                // Check for verseNotes - if it's a String, remove it
                if let value = UserDefaults.standard.object(forKey: "verseNotes"),
                   value is String {
                    print("⚠️ [FIX] Found corrupted verseNotes (String), removing...")
                    UserDefaults.standard.removeObject(forKey: "verseNotes")
                }
                
                // Check for bibleRecentSearches - if it's a String, remove it
                if let value = UserDefaults.standard.object(forKey: "bibleRecentSearches"),
                   value is String {
                    print("⚠️ [FIX] Found corrupted bibleRecentSearches (String), removing...")
                    UserDefaults.standard.removeObject(forKey: "bibleRecentSearches")
                }
                
                // Load user profile from Firebase (if authenticated)
                #if canImport(FirebaseAuth)
                if FirebaseInitializer.shared.isConfigured {
                    ProfileManager.shared.loadProfile()
                    print("✅ [PROFILE] Profile loaded from Firebase on app launch")
                }
                #endif
                
                // Configure Firebase sync service
                if FirebaseInitializer.shared.isConfigured {
                    firebaseSync.configure(modelContext: modelContext)
                    print("✅ [FIREBASE] Sync service configured")
                    
                    // If user is already logged in, sync all existing data to Firebase
                    // This ensures any local entries created before sign-in are uploaded
                    if hasLoggedIn {
                        print("🔄 [FIREBASE] User is already logged in, syncing existing data...")
                        Task {
                            await firebaseSync.syncAllData()
                            print("✅ [FIREBASE] Existing data sync initiated")
                        }
                    }
                }
                
                // Check for pending username/email from email/password sign-up
                if let pendingUsername = UserDefaults.standard.string(forKey: "pendingUsername"),
                   let pendingEmail = UserDefaults.standard.string(forKey: "pendingEmail") {
                    // Create or update UserProfile with email sign-up info
                    let descriptor = FetchDescriptor<UserProfile>()
                    if let existingProfile = try? modelContext.fetch(descriptor).first {
                        existingProfile.name = pendingUsername
                        existingProfile.email = pendingEmail
                        existingProfile.updatedAt = Date()
                    } else {
                        let newProfile = UserProfile(name: pendingUsername, email: pendingEmail)
                        modelContext.insert(newProfile)
                    }
                    try? modelContext.save()
                    UserDefaults.standard.removeObject(forKey: "pendingUsername")
                    UserDefaults.standard.removeObject(forKey: "pendingEmail")
                    print("✅ [USER PROFILE] Created/updated profile for email sign-up: \(pendingUsername)")
                }
                
                // Check for pending invite code from URL when app appears
                if let pendingCode = UserDefaults.standard.string(forKey: "pendingInviteCode") {
                    // Only show if user is logged in and completed onboarding
                    if hasLoggedIn && hasCompletedOnboarding {
                        pendingInviteCode = pendingCode
                        showingJoinByCode = true
                        UserDefaults.standard.removeObject(forKey: "pendingInviteCode")
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Restart Firebase listener when app becomes active to catch changes from other devices
            // This ensures cross-device sync works even if the app was in background
            Task { @MainActor in
                if FirebaseInitializer.shared.isConfigured {
                    // Ensure modelContext is set
                    FirebaseSyncService.shared.configure(modelContext: modelContext)
                    FirebaseSyncService.shared.restartListening()
                    print("🔄 [FIREBASE] Restarted listener on app becoming active")
                    
                    // If user is authenticated, sync all existing data to ensure nothing is missed
                    if hasLoggedIn {
                        print("🔄 [FIREBASE] User is authenticated, syncing all existing data...")
                        await FirebaseSyncService.shared.syncAllData()
                    }
                }
            }
        }
        .onOpenURL { url in
            handleInvitationURL(url)
        }
        .sheet(isPresented: $showingJoinByCode) {
            if let code = pendingInviteCode {
                JoinByCodeView(initialCode: code)
            }
        }
    }
    
    private func handleInvitationURL(_ url: URL) {
        print("🔗 [DEEP LINK] Received URL: \(url.absoluteString)")
        print("🔗 [DEEP LINK] Scheme: \(url.scheme ?? "nil")")
        print("🔗 [DEEP LINK] Host: \(url.host ?? "nil")")
        print("🔗 [DEEP LINK] Path: \(url.path)")
        print("🔗 [DEEP LINK] PathComponents: \(url.pathComponents)")
        
        var extractedCode: String? = nil
        
        // Handle faithjournal://invite/CODE format
        if url.scheme == "faithjournal" {
            if url.host == "invite" {
                // Extract the code from the path (format: /CODE or CODE)
                let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
                extractedCode = pathComponents.first ?? pathComponents.joined()
                print("🔗 [DEEP LINK] Extracted invite code from scheme: \(extractedCode ?? "nil")")
            } else if url.host == nil || url.host?.isEmpty == true {
                // Handle faithjournal://CODE format (no host, just code)
                let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
                extractedCode = pathComponents.first ?? pathComponents.joined()
                if extractedCode?.isEmpty == true {
                    // Try extracting from the full path
                    let path = url.absoluteString.replacingOccurrences(of: "faithjournal://", with: "")
                    extractedCode = path.isEmpty ? nil : path
                }
                print("🔗 [DEEP LINK] Extracted invite code (no host): \(extractedCode ?? "nil")")
            }
        }
        // Also handle https://faithjournal.app/invite/CODE format (for universal links)
        else if url.scheme == "https" && url.host == "faithjournal.app" {
            let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            if pathComponents.first == "invite", let code = pathComponents.dropFirst().first {
                extractedCode = code
                print("🔗 [DEEP LINK] Extracted invite code from https link: \(code)")
            }
        }
        
        // Process the extracted code
        if let code = extractedCode, !code.isEmpty {
            let cleanCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            print("🔗 [DEEP LINK] Processing code: \(cleanCode)")
            
            // If user is logged in and completed onboarding, show join screen
            if hasLoggedIn && hasCompletedOnboarding {
                pendingInviteCode = cleanCode
                showingJoinByCode = true
                print("🔗 [DEEP LINK] Showing join screen with code: \(cleanCode)")
            } else {
                // Store code for later when user completes login/onboarding
                UserDefaults.standard.set(cleanCode, forKey: "pendingInviteCode")
                print("🔗 [DEEP LINK] Stored code for after login: \(cleanCode)")
            }
        } else {
            print("⚠️ [DEEP LINK] Could not extract invite code from URL: \(url.absoluteString)")
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    AppRootView()
}
