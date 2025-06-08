import Foundation
import SwiftData

@Model
final class PrayerRequest: Identifiable {
    var title: String
    var details: String
    var dateCreated: Date
    var dateAnswered: Date?
    var status: PrayerStatus
    var category: String?
    var reminderDate: Date?
    var isPrivate: Bool
    var tags: [String]
    
    enum PrayerStatus: String, Codable, CaseIterable {
        case active = "Active"
        case answered = "Answered"
        case inProgress = "In Progress"
        case archived = "Archived"
    }
    
    init(
        title: String,
        details: String,
        dateCreated: Date = Date(),
        dateAnswered: Date? = nil,
        status: PrayerStatus = .active,
        category: String? = nil,
        reminderDate: Date? = nil,
        isPrivate: Bool = false,
        tags: [String] = []
    ) {
        self.title = title
        self.details = details
        self.dateCreated = dateCreated
        self.dateAnswered = dateAnswered
        self.status = status
        self.category = category
        self.reminderDate = reminderDate
        self.isPrivate = isPrivate
        self.tags = tags
    }
} 