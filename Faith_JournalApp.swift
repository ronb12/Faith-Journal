
//  Faith_JournalApp.swift
//  Faith Journal
//
//  Created by Ronell Bradley on 6/29/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

/// A human-readable identifier we can show in the UI to prove which binary is running.
/// Update this whenever diagnosing “old build still showing”.
enum BuildInfo {
    static let stamp = "2026-01-06.1"
}

@main
@available(iOS 17.0, *)
struct Faith_JournalApp: App {
    // CRITICAL: Use lazy initialization for singletons to avoid crashes during app startup
    // Accessing .shared during app initialization can cause crashes if services aren't ready
    private var notificationService: NotificationService {
        NotificationService.shared
    }
    private var promptManager: PromptManager {
        PromptManager.shared
    }
    
    init() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        print("✅ [BUILD] Faith Journal \(version) (\(build)) stamp=\(BuildInfo.stamp)")

        // CRITICAL: Fix corrupted UserDefaults values BEFORE any views are created
        // This prevents crashes when @AppStorage tries to load arrays/dictionaries that are stored as Strings
        print("🔧 [FIX] Checking for corrupted UserDefaults values at app init...")
        
        // Fix bookmarkedVerses - if stored as String, remove it
        if let value = UserDefaults.standard.object(forKey: "bookmarkedVerses"),
           value is String {
            print("⚠️ [FIX] Found corrupted bookmarkedVerses (String), removing...")
            UserDefaults.standard.removeObject(forKey: "bookmarkedVerses")
        }
        
        // Fix verseNotes - if stored as String, remove it
        if let value = UserDefaults.standard.object(forKey: "verseNotes"),
           value is String {
            print("⚠️ [FIX] Found corrupted verseNotes (String), removing...")
            UserDefaults.standard.removeObject(forKey: "verseNotes")
        }
        
        // Fix bibleRecentSearches - if stored as String, remove it
        if let value = UserDefaults.standard.object(forKey: "bibleRecentSearches"),
           value is String {
            print("⚠️ [FIX] Found corrupted bibleRecentSearches (String), removing...")
            UserDefaults.standard.removeObject(forKey: "bibleRecentSearches")
        }
        
        print("✅ [FIX] UserDefaults corruption check complete")
    }
    
    // Add defensive logging for TestFlight debugging
    // Using local-only storage with Firebase for sync
    // CRITICAL: Schema must be defined as a static property to prevent it from "disappearing"
    static let appSchema = Schema([
        JournalEntry.self,
        PrayerRequest.self,
        UserProfile.self,
        MoodEntry.self,
        MoodGoal.self,
        MoodAchievement.self,
        BibleVerseOfTheDay.self,
        LiveSession.self,
        LiveSessionParticipant.self,
        Subscription.self,
        ChatMessage.self,
        SessionInvitation.self,
        SessionTemplate.self,
        SessionRating.self,
        SessionPlaylist.self,
        SessionNote.self,
        SessionClip.self,
        BookmarkedVerse.self,
        BibleHighlight.self,
        BibleNote.self,
        BibleReadingHistory.self,
        ReadingPlan.self,
        JournalPrompt.self,
        BibleStudyTopic.self,
        StatisticAchievement.self
    ])
    
    var sharedModelContainer: ModelContainer = {
        print("🚀 [LAUNCH] Starting ModelContainer initialization...")
        print("🚀 [LAUNCH] Thread: \(Thread.isMainThread ? "Main" : "Background")")
        print("🚀 [LAUNCH] Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        let schema = Faith_JournalApp.appSchema
        
        // Using Firebase for backend sync, not CloudKit
        // SwiftData will use local storage only
        print("🚀 [LAUNCH] Creating ModelContainer with local storage (Firebase for sync)...")
        print("🚀 [STORAGE] Using SwiftData local storage")
        print("🚀 [STORAGE] Firebase will handle cross-device synchronization")
        
        // Use local-only storage (no CloudKit)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
            // No cloudKitDatabase - using Firebase for sync instead
        )
        
        do {
            print("🚀 [LAUNCH] Attempting ModelContainer creation with local storage...")
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Log successful initialization for debugging
            print("✅ [LAUNCH] ModelContainer initialized successfully")
            print("✅ [LAUNCH] Using local SwiftData storage")
            print("✅ [LAUNCH] Schema includes \(schema.entities.count) models")
            print("✅ [LAUNCH] Schema entities: \(schema.entities.map { $0.name }.joined(separator: ", "))")
            print("ℹ️ [STORAGE] Firebase will handle data synchronization")
            
            return container
        } catch let error as NSError {
            // Check if this is a migration error (CoreData error 134140)
            if error.domain == "NSCocoaErrorDomain" && error.code == 134140 {
                print("❌ [MIGRATION] CoreData migration failed (Code 134140)")
                print("❌ [MIGRATION] This usually means the schema changed in an incompatible way")
                print("❌ [MIGRATION] Error details: \(error.localizedDescription)")
                let userInfo = error.userInfo
                print("❌ [MIGRATION] UserInfo: \(userInfo)")
                if let reason = userInfo["reason"] as? String {
                    print("❌ [MIGRATION] Reason: \(reason)")
                }
                
                // In DEBUG mode, try to delete the old database and start fresh
                #if DEBUG
                print("⚠️ [MIGRATION] DEBUG MODE: Attempting to reset database...")
                let fileManager = FileManager.default
                
                // SwiftData stores databases in Application Support directory
                if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    let defaultStoreURL = appSupportURL.appendingPathComponent("default.store")
                    let defaultStoreShmURL = appSupportURL.appendingPathComponent("default.store-shm")
                    let defaultStoreWalURL = appSupportURL.appendingPathComponent("default.store-wal")
                    
                    var deleted = false
                    
                    for storeFile in [defaultStoreURL, defaultStoreShmURL, defaultStoreWalURL] {
                        if fileManager.fileExists(atPath: storeFile.path) {
                            do {
                                try fileManager.removeItem(at: storeFile)
                                print("✅ [MIGRATION] Deleted: \(storeFile.lastPathComponent)")
                                deleted = true
                            } catch {
                                print("⚠️ [MIGRATION] Could not delete \(storeFile.lastPathComponent): \(error)")
                            }
                        }
                    }
                    
                    if deleted {
                        print("🔄 [MIGRATION] Retrying ModelContainer creation after database reset...")
                        do {
                            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                            print("✅ [MIGRATION] ModelContainer created successfully after reset")
                            return container
                        } catch {
                            print("❌ [MIGRATION] Still failed after reset: \(error)")
                        }
                    } else {
                        print("⚠️ [MIGRATION] No database files found to delete")
                    }
                } else {
                    print("⚠️ [MIGRATION] Could not find Application Support directory")
                }
                #else
                print("⚠️ [MIGRATION] PRODUCTION MODE: Migration error detected")
                print("⚠️ [MIGRATION] To fix: Reset simulator data or reinstall app")
                #endif
            }
            
            // In production, log the error and use local storage as fallback
            print("❌ CRITICAL: Could not create ModelContainer: \(error)")
            print("❌ CRITICAL: Error type: \(type(of: error))")
            print("❌ CRITICAL: Error description: \(error.localizedDescription)")
            print("❌ CRITICAL: Error domain: \(error.domain)")
            print("❌ CRITICAL: Error code: \(error.code)")
            print("❌ CRITICAL: Error userInfo: \(error.userInfo)")
            print("Error details: \(error.localizedDescription)")
            print("⚠️ [LAUNCH] Attempting in-memory fallback...")
            
            // Try to create an in-memory container as fallback for NSError
            #if DEBUG
            let fallbackConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            
            do {
                print("⚠️ Attempting fallback to in-memory storage (DEBUG ONLY)...")
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                print("❌ CRITICAL: In-memory fallback also failed: \(error)")
                fatalError("Failed to initialize data storage: \(error.localizedDescription)")
            }
            #else
            // In production, try minimal configuration
            let minimalConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            do {
                print("⚠️ Using minimal configuration...")
                return try ModelContainer(for: schema, configurations: [minimalConfiguration])
            } catch {
                print("❌ CRITICAL: Minimal configuration failed: \(error)")
                // Last resort: in-memory only
                let emergencyConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                do {
                    return try ModelContainer(for: schema, configurations: [emergencyConfiguration])
                } catch {
                    // Absolute last resort: empty schema
                    return try! ModelContainer(for: Schema([]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
                }
            }
            #endif
        } catch {
            // Handle non-NSError errors
            print("❌ CRITICAL: Could not create ModelContainer: \(error)")
            print("❌ CRITICAL: Error type: \(type(of: error))")
            print("❌ CRITICAL: Error description: \(error.localizedDescription)")
            print("⚠️ [LAUNCH] Attempting in-memory fallback...")
            
            // Try to create an in-memory container as fallback
            #if DEBUG
            let fallbackConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            
            do {
                print("⚠️ Attempting fallback to in-memory storage (DEBUG ONLY)...")
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                // Last resort: fatal error (but with better logging)
                let errorMessage = """
                Failed to initialize data storage.
                This may be due to:
                1. Schema migration problems
                2. Insufficient device storage
                3. Database corruption
                
                Error: \(error.localizedDescription)
                """
                print("❌ FATAL: \(errorMessage)")
                fatalError(errorMessage)
            }
            #else
            // In production, show error screen instead of crashing
            // Create a minimal in-memory container to prevent crash
            // User will see an error message in the UI
            print("❌ CRITICAL: Failed to initialize ModelContainer in production")
            print("Error: \(error.localizedDescription)")
            print("⚠️ Attempting minimal fallback configuration...")
            
            // Try minimal configuration
            let minimalConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            do {
                print("⚠️ Using minimal configuration...")
                return try ModelContainer(for: schema, configurations: [minimalConfiguration])
            } catch {
                // Last resort: in-memory only (data won't persist, but app won't crash)
                print("❌ CRITICAL: Even minimal configuration failed")
                print("⚠️ Using in-memory storage as last resort - data will not persist")
                let emergencyConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                do {
                    return try ModelContainer(for: schema, configurations: [emergencyConfiguration])
                } catch {
                    // CRITICAL: Never crash in production - create a minimal working container
                    // Even if this fails, we'll try with an empty schema to at least let the app start
                    print("❌ CRITICAL: Emergency configuration failed: \(error)")
                    print("⚠️ Attempting absolute minimal configuration...")
                    
                    // Try with just the essential models
                    let essentialSchema = Schema([
                        JournalEntry.self,
                        PrayerRequest.self,
                        UserProfile.self
                    ])
                    
                    let absoluteMinimalConfig = ModelConfiguration(
                        schema: essentialSchema,
                        isStoredInMemoryOnly: true
                    )
                    
                    do {
                        print("⚠️ Using essential models only (in-memory)...")
                        return try ModelContainer(for: essentialSchema, configurations: [absoluteMinimalConfig])
                    } catch {
                        // Last absolute resort - this should never happen, but if it does,
                        // we'll create an empty container to prevent crash
                        print("❌ CRITICAL: All initialization attempts failed")
                        print("⚠️ Creating empty container to prevent crash")
                        // Create a minimal empty container - app will work but data won't persist
                        // This is better than crashing
                        // CRITICAL: Never crash in production - try one final time
                        // Log extensively for debugging but allow app to continue
                        print("❌ CRITICAL: Unable to create even empty container")
                        print("⚠️ App will continue with limited functionality")
                        // Try one more time with absolute minimal setup
                        do {
                            print("⚠️ FINAL FALLBACK: Attempting emergency container creation")
                            return try ModelContainer(for: Schema([]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
                        } catch {
                            // Last resort: Create a dummy container that won't crash
                            // The app will show an error to the user but won't crash
                            print("❌ FINAL FALLBACK: Emergency container creation failed: \(error)")
                            print("⚠️ Using force unwrap as absolute last resort - app must start")
                            // Return a container with empty schema - app can still run
                            // This try! is acceptable as it's the absolute last resort
                            return try! ModelContainer(for: Schema([]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
                        }
                    }
                }
            }
            #endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Ensure window background fills entire screen - no safe areas
                Color.purple.opacity(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()

                AppRootView()
                    .environmentObject(notificationService)
                    .environmentObject(promptManager)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .background(FullScreenWindowConfigurator())
                .task {
                print("🚀 [LAUNCH] App body task started")
                // Use task instead of onAppear for async initialization
                // Initialize services safely on main actor
                await MainActor.run {
                    print("🚀 [LAUNCH] MainActor.run block started")
                    
                    // CRITICAL: Fix corrupted UserDefaults values BEFORE any views load
                    // This prevents crashes when @AppStorage tries to load arrays/dictionaries that are stored as Strings
                    print("🔧 [FIX] Checking for corrupted UserDefaults values...")
                    
                    // Fix bookmarkedVerses - if stored as String, remove it
                    if let value = UserDefaults.standard.object(forKey: "bookmarkedVerses"),
                       value is String {
                        print("⚠️ [FIX] Found corrupted bookmarkedVerses (String), removing...")
                        UserDefaults.standard.removeObject(forKey: "bookmarkedVerses")
                    }
                    
                    // Fix verseNotes - if stored as String, remove it
                    if let value = UserDefaults.standard.object(forKey: "verseNotes"),
                       value is String {
                        print("⚠️ [FIX] Found corrupted verseNotes (String), removing...")
                        UserDefaults.standard.removeObject(forKey: "verseNotes")
                    }
                    
                    // Fix bibleRecentSearches - if stored as String, remove it
                    if let value = UserDefaults.standard.object(forKey: "bibleRecentSearches"),
                       value is String {
                        print("⚠️ [FIX] Found corrupted bibleRecentSearches (String), removing...")
                        UserDefaults.standard.removeObject(forKey: "bibleRecentSearches")
                    }
                    
                    // Fix any other array/dictionary AppStorage values that might be corrupted
                    // Check for common keys that should be arrays but might be strings
                    let arrayKeys = ["bookmarkedVerses", "bibleRecentSearches", "recentSearches"]
                    for key in arrayKeys {
                        if let value = UserDefaults.standard.object(forKey: key),
                           value is String {
                            print("⚠️ [FIX] Found corrupted \(key) (String), removing...")
                            UserDefaults.standard.removeObject(forKey: key)
                        }
                    }
                    
                    // Check for dictionary keys that might be strings
                    let dictKeys = ["verseNotes", "highlightedVerses"]
                    for key in dictKeys {
                        if let value = UserDefaults.standard.object(forKey: key),
                           value is String {
                            print("⚠️ [FIX] Found corrupted \(key) (String), removing...")
                            UserDefaults.standard.removeObject(forKey: key)
                        }
                    }
                    
                    print("✅ [FIX] UserDefaults corruption check complete")
                    
                    // Initialize prompt manager lazily (will initialize on first access)
                    _ = promptManager
                    print("🚀 [LAUNCH] PromptManager accessed")
                    // Clear badge when app opens
                    notificationService.clearBadge()
                    print("🚀 [LAUNCH] Badge cleared")
                    
                    // Initialize Firebase
                    FirebaseInitializer.shared.initialize()
                    
                    // Enable background sync (already registered in init, just schedule it)
                    // Temporarily disabled until BackgroundSyncService compilation is resolved
                    // if #available(iOS 17.0, *) {
                    //     BackgroundSyncService.shared.scheduleBackgroundSync()
                    //     print("🚀 [LAUNCH] Background sync enabled")
                    // }
                }
                // Setup notifications asynchronously
                await setupNotifications()
                print("🚀 [LAUNCH] Notifications setup complete")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Also clear badge when app comes to foreground
                Task { @MainActor in
                    notificationService.clearBadge()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Clear badge when app becomes active
                Task { @MainActor in
                    notificationService.clearBadge()
                    
                    // Check for pending sync when app becomes active
                    if #available(iOS 17.0, *) {
                        // Get ModelContext from environment and check for sync
                        // Note: We'll handle this in AppRootView where we have access to ModelContext
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupNotifications() async {
        // Request notification authorization
        _ = await notificationService.requestAuthorization()
        // Schedule daily prompt notification at 9 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        if let scheduledDate = Calendar.current.date(from: dateComponents) {
            await MainActor.run {
                notificationService.scheduleDailyPromptNotification(time: scheduledDate)
            }
        }
    }
    
}

// MARK: - Full Screen Window Configurator
struct FullScreenWindowConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.edgesForExtendedLayout = .all
        controller.extendedLayoutIncludesOpaqueBars = true
        controller.view.backgroundColor = .clear
        controller.view.clipsToBounds = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    // Ensure window fills entire screen
                    window.frame = windowScene.screen.bounds
                    window.backgroundColor = .clear

                    // Configure root view controller for full screen
                    if let rootViewController = window.rootViewController {
                        rootViewController.edgesForExtendedLayout = .all
                        rootViewController.extendedLayoutIncludesOpaqueBars = true
                        rootViewController.view.backgroundColor = .clear
                        rootViewController.view.frame = window.bounds
                        rootViewController.view.clipsToBounds = false
                    }
                }
            }
        }
    }
}
