//
//  Faith_JournalApp.swift
//  Faith Journal
//
//  Created by Ronell Bradley on 6/29/25.
//

import SwiftUI
import SwiftData

@main
struct Faith_JournalApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            JournalEntry.self,
            PrayerRequest.self,
            UserProfile.self,
            MoodEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
