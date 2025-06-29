import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var bibleVerseManager = BibleVerseOfTheDayManager.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            JournalView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Journal")
                }
            
            PrayerView()
                .tabItem {
                    Image(systemName: "hands.sparkles.fill")
                    Text("Prayer")
                }
            
            DevotionalsView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Devotionals")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(themeManager.colors.primary)
        .background(themeManager.colors.background)
        .onAppear {
            setupInitialData()
        }
    }
    
    private func setupInitialData() {
        // Load today's Bible verse
        bibleVerseManager.loadTodaysVerse(context: modelContext)
        
        // Add sample data if needed
        addSampleDataIfNeeded()
    }
    
    private func addSampleDataIfNeeded() {
        // Check if we have any devotionals
        let devotionalDescriptor = FetchDescriptor<Devotional>()
        let bibleVerseDescriptor = FetchDescriptor<BibleVerseOfTheDay>()
        
        do {
            let devotionals = try modelContext.fetch(devotionalDescriptor)
            let verses = try modelContext.fetch(bibleVerseDescriptor)
            
            if devotionals.isEmpty {
                DataManager.shared.addSampleDevotionals(context: modelContext)
            }
            
            if verses.isEmpty {
                DataManager.shared.addSampleBibleVerses(context: modelContext)
                bibleVerseManager.loadTodaysVerse(context: modelContext)
            }
        } catch {
            print("Error checking sample data: \(error)")
        }
    }
} 