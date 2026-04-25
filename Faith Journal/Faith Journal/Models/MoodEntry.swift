import Foundation
import SwiftData
import CoreLocation

@available(iOS 17.0, *)
@Model
final class MoodEntry {
    var id: UUID = UUID()
    var mood: String = ""
    var intensity: Int = 5
    var notes: String?
    var date: Date = Date()
    private var tagsJSON: String = "[]"
    var tags: [String] {
        get {
            guard let data = tagsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set { tagsJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]" }
    }
    var createdAt: Date = Date()
    
    // Enhanced properties
    var moodCategory: String = "Neutral" // Positive, Neutral, Challenging
    var emoji: String = "😊" // Emoji representation
    var location: String? // Location name
    var latitude: Double?
    var longitude: Double?
    var weather: String? // Weather condition
    var temperature: Double? // Temperature in Fahrenheit
    var timeOfDay: String = "" // Morning, Afternoon, Evening, Night
    private var activitiesJSON: String = "[]"
    var activities: [String] {
        get {
            guard let data = activitiesJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set { activitiesJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]" }
    }
    var energyLevel: Int = 5 // 1-10
    var sleepQuality: Int? // 1-10, optional
    var linkedJournalEntryId: UUID? // Link to JournalEntry
    private var linkedPrayerRequestIdsJSON: String = "[]"
    var linkedPrayerRequestIds: [UUID] {
        get {
            guard let data = linkedPrayerRequestIdsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([UUID].self, from: data) else { return [] }
            return decoded
        }
        set { linkedPrayerRequestIdsJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]" }
    }
    var linkedReadingPlanId: UUID? // Link to ReadingPlan
    private var triggersJSON: String = "[]"
    var triggers: [String] {
        get {
            guard let data = triggersJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set { triggersJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]" }
    }
    var photoURL: URL? // Optional photo
    var voiceNoteURL: URL? // Optional voice note
    
    init(mood: String, intensity: Int, notes: String? = nil, tags: [String] = [], moodCategory: String = "Neutral", emoji: String = "😊", activities: [String] = [], energyLevel: Int = 5) {
        self.id = UUID()
        self.mood = mood
        self.intensity = max(1, min(10, intensity))
        self.notes = notes
        self.date = Date()
        self.tagsJSON = (try? JSONEncoder().encode(tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.createdAt = Date()
        self.moodCategory = moodCategory
        self.emoji = emoji
        self.activitiesJSON = (try? JSONEncoder().encode(activities)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.energyLevel = max(1, min(10, energyLevel))
        
        // Set time of day
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: self.timeOfDay = "Morning"
        case 12..<17: self.timeOfDay = "Afternoon"
        case 17..<21: self.timeOfDay = "Evening"
        default: self.timeOfDay = "Night"
        }
    }
} 