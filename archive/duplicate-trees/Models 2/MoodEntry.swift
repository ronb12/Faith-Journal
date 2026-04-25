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
    var tags: [String] = []
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
    var activities: [String] = [] // Activities done (prayer, reading, meditation, etc.)
    var energyLevel: Int = 5 // 1-10
    var sleepQuality: Int? // 1-10, optional
    var linkedJournalEntryId: UUID? // Link to JournalEntry
    var linkedPrayerRequestIds: [UUID] = [] // Link to PrayerRequests
    var linkedReadingPlanId: UUID? // Link to ReadingPlan
    var triggers: [String] = [] // What triggered this mood
    var photoURL: URL? // Optional photo
    var voiceNoteURL: URL? // Optional voice note
    
    init(mood: String, intensity: Int, notes: String? = nil, tags: [String] = [], moodCategory: String = "Neutral", emoji: String = "😊", activities: [String] = [], energyLevel: Int = 5) {
        self.id = UUID()
        self.mood = mood
        self.intensity = max(1, min(10, intensity))
        self.notes = notes
        self.date = Date()
        self.tags = tags
        self.createdAt = Date()
        self.moodCategory = moodCategory
        self.emoji = emoji
        self.activities = activities
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