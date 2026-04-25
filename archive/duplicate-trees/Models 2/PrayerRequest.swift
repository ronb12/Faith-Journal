import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class PrayerRequest {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var date: Date = Date()
    var status: PrayerStatus = PrayerRequest.PrayerStatus.active
    var isAnswered: Bool = false
    var answerDate: Date?
    var answerNotes: String?
    var isPrivate: Bool = false
    var tags: [String] = []
    var prayerPartners: [String] = []
    var enableReminder: Bool = false
    var reminderTime: Date = Date()
    var reminderFrequency: String = "Daily" // "Daily", "Weekly", "Custom"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    enum PrayerStatus: String, CaseIterable, Codable {
        case active = "Active"
        case answered = "Answered"
        case archived = "Archived"
    }
    
    init(title: String, details: String, tags: [String] = [], isPrivate: Bool = false) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.date = Date()
        self.status = .active
        self.isAnswered = false
        self.isPrivate = isPrivate
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 