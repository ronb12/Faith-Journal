import SwiftUI
import SwiftData

@main
struct Faith_JournalApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(
                for: JournalEntry.self, PrayerRequest.self, Devotional.self, 
                BibleVerseOfTheDay.self, UserProfile.self, MoodEntry.self,
                LiveSession.self, LiveSessionParticipant.self, Subscription.self,
                ChatMessage.self
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
} 