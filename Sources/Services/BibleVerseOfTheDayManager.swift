import Foundation
import SwiftData
import SwiftUI

@MainActor
class BibleVerseOfTheDayManager: ObservableObject {
    @Published var currentVerse: BibleVerseOfTheDay?
    @Published var isLoading = false
    
    static let shared = BibleVerseOfTheDayManager()
    
    private init() {}
    
    func loadTodaysVerse(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let descriptor = FetchDescriptor<BibleVerseOfTheDay>(
            predicate: #Predicate<BibleVerseOfTheDay> { verse in
                verse.date >= today && verse.date < tomorrow
            },
            sortBy: [SortDescriptor(\BibleVerseOfTheDay.date, order: .reverse)]
        )
        
        do {
            let verses = try context.fetch(descriptor)
            if let verse = verses.first {
                currentVerse = verse
            } else {
                // If no verse for today, get a random one
                loadRandomVerse(context: context)
            }
        } catch {
            print("Error loading today's verse: \(error)")
            loadRandomVerse(context: context)
        }
    }
    
    func loadRandomVerse(context: ModelContext) {
        let descriptor = FetchDescriptor<BibleVerseOfTheDay>()
        
        do {
            let verses = try context.fetch(descriptor)
            if let randomVerse = verses.randomElement() {
                currentVerse = randomVerse
            }
        } catch {
            print("Error loading random verse: \(error)")
        }
    }
    
    func addNewVerse(_ verse: BibleVerseOfTheDay, context: ModelContext) {
        context.insert(verse)
        try? context.save()
        currentVerse = verse
    }
    
    func toggleFavorite(context: ModelContext) {
        guard let verse = currentVerse else { return }
        verse.isFavorite.toggle()
        try? context.save()
    }
} 