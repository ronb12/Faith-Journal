//
//  Faith_JournalApp.swift
//  Faith Journal
//
//  Created by Ronell Bradley on 6/29/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct Faith_JournalApp: App {
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var promptManager = PromptManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            JournalEntry.self,
            PrayerRequest.self,
            UserProfile.self,
            MoodEntry.self,
            BibleVerseOfTheDay.self,
            LiveSession.self,
            LiveSessionParticipant.self,
            Subscription.self,
            ChatMessage.self,
            SessionInvitation.self,
            BookmarkedVerse.self,
            ReadingPlan.self,
            JournalPrompt.self,
            BibleStudyTopic.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // In production, log the error and use in-memory storage as fallback
            print("❌ CRITICAL: Could not create ModelContainer: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // Try to create an in-memory container as fallback
            let fallbackConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            
            do {
                print("⚠️ Attempting fallback to in-memory storage...")
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                // Last resort: fatal error (but with better logging)
                let errorMessage = """
                Failed to initialize data storage.
                This may be due to:
                1. CloudKit configuration issues
                2. Schema migration problems
                3. Insufficient device storage
                
                Error: \(error.localizedDescription)
                """
                print("❌ FATAL: \(errorMessage)")
                fatalError(errorMessage)
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(notificationService)
                .environmentObject(promptManager)
                .onAppear {
                    setupNotifications()
                    // Initialize prompt manager to load daily prompt
                    _ = PromptManager.shared
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupNotifications() {
        Task {
            _ = await notificationService.requestAuthorization()
            // Schedule daily prompt notification at 9 AM
            var dateComponents = DateComponents()
            dateComponents.hour = 9
            dateComponents.minute = 0
            if let scheduledDate = Calendar.current.date(from: dateComponents) {
                notificationService.scheduleDailyPromptNotification(time: scheduledDate)
            }
        }
    }
}
