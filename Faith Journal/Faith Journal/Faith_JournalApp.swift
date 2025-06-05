//
//  Faith_JournalApp.swift
//  Faith Journal
//
//  Created by Ronell Bradley on 6/4/25.
//

import SwiftUI
import SwiftData

@main
struct Faith_JournalApp: App {
    let container: ModelContainer
    @State private var errorMessage: String?
    @State private var showingError = false
    
    init() {
        do {
            let schema = Schema([
                JournalEntry.self,
                PrayerRequest.self,
                Devotional.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            container = try ModelContainer(
                schema: schema,
                migrationPlan: nil,
                configurations: [modelConfiguration]
            )
        } catch {
            errorMessage = error.localizedDescription
            fatalError("Could not initialize SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert("Database Error", isPresented: $showingError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "An unknown error occurred.")
                }
        }
        .modelContainer(container)
        .onChange(of: errorMessage) { _, newError in
            showingError = newError != nil
        }
    }
}
