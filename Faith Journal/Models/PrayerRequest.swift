import Foundation
import SwiftData

@Model
final class PrayerRequest {
    var title: String
    var details: String
    var date: Date
    var category: String
    var isPrivate: Bool
    var isAnswered: Bool
    var answerDate: Date?
    var answerDetails: String?
    var prayerPartners: [String]
    var reminderDate: Date?
    
    init(
        title: String,
        details: String,
        date: Date = Date(),
        category: String,
        isPrivate: Bool = false,
        isAnswered: Bool = false,
        answerDate: Date? = nil,
        answerDetails: String? = nil,
        prayerPartners: [String] = [],
        reminderDate: Date? = nil
    ) {
        self.title = title
        self.details = details
        self.date = date
        self.category = category
        self.isPrivate = isPrivate
        self.isAnswered = isAnswered
        self.answerDate = answerDate
        self.answerDetails = answerDetails
        self.prayerPartners = prayerPartners
        self.reminderDate = reminderDate
    }
} 