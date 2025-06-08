import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: String
    var name: String
    var email: String
    var preferences: UserPreferences
    var readingPlan: ReadingPlan?
    var streak: Int
    var lastActive: Date
    var achievements: [Achievement]
    var prayerStats: PrayerStats
    var bibleStats: BibleStats
    var journalStats: JournalStats
    
    init(
        id: String = UUID().uuidString,
        name: String,
        email: String,
        preferences: UserPreferences = UserPreferences(),
        readingPlan: ReadingPlan? = nil,
        streak: Int = 0,
        lastActive: Date = Date(),
        achievements: [Achievement] = [],
        prayerStats: PrayerStats = PrayerStats(),
        bibleStats: BibleStats = BibleStats(),
        journalStats: JournalStats = JournalStats()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.preferences = preferences
        self.readingPlan = readingPlan
        self.streak = streak
        self.lastActive = lastActive
        self.achievements = achievements
        self.prayerStats = prayerStats
        self.bibleStats = bibleStats
        self.journalStats = journalStats
    }
}

struct UserPreferences: Codable {
    var theme: String = "system"
    var notifications: Bool = true
    var defaultTranslation: String = "NIV"
    var defaultPrivacy: Bool = false
    var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
}

struct ReadingPlan: Codable {
    var name: String
    var startDate: Date
    var endDate: Date
    var progress: Double
    var currentDay: Int
}

struct Achievement: Codable {
    var id: String
    var title: String
    var description: String
    var dateEarned: Date
    var icon: String
}

struct PrayerStats: Codable {
    var totalPrayers: Int = 0
    var answeredPrayers: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var categories: [String: Int] = [:]
}

struct BibleStats: Codable {
    var versesMemorized: Int = 0
    var readingStreak: Int = 0
    var chaptersRead: Int = 0
    var translations: [String: Int] = [:]
}

struct JournalStats: Codable {
    var totalEntries: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var moodDistribution: [String: Int] = [:]
} 