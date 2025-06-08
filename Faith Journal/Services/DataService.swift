import Foundation
import SwiftData

@Observable
class DataService {
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Journal Entries
    
    func saveJournalEntry(_ entry: JournalEntry) {
        modelContext.insert(entry)
        try? modelContext.save()
    }
    
    func fetchJournalEntries() -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Prayer Requests
    
    func savePrayerRequest(_ request: PrayerRequest) {
        modelContext.insert(request)
        try? modelContext.save()
    }
    
    func fetchPrayerRequests() -> [PrayerRequest] {
        let descriptor = FetchDescriptor<PrayerRequest>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Bible Verses
    
    func saveBibleVerse(_ verse: BibleVerse) {
        modelContext.insert(verse)
        try? modelContext.save()
    }
    
    func fetchBibleVerses() -> [BibleVerse] {
        let descriptor = FetchDescriptor<BibleVerse>(sortBy: [SortDescriptor(\.reference)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - User Profile
    
    func saveUserProfile(_ profile: UserProfile) {
        modelContext.insert(profile)
        try? modelContext.save()
    }
    
    func fetchUserProfile() -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try? modelContext.fetch(descriptor).first
    }
    
    // MARK: - Utility Methods
    
    func delete<T>(_ item: T) where T: PersistentModel {
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    func update<T>(_ item: T) where T: PersistentModel {
        try? modelContext.save()
    }
} 