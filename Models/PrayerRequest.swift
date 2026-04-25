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
    private var tagsJSON: String = "[]"
    var tags: [String] {
        get {
            guard let data = tagsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set { tagsJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]" }
    }
    private var prayerPartnersJSON: String = "[]"
    var prayerPartners: [String] {
        get {
            guard let data = prayerPartnersJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set { prayerPartnersJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]" }
    }
    var enableReminder: Bool = false
    var reminderTime: Date = Date()
    var reminderFrequency: String = "Daily" // "Daily", "Weekly", "Custom"
    private var checkInDatesJSON: String = "[]"
    var checkInDates: [Date] {
        get {
            guard let data = checkInDatesJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Date].self, from: data) else { return [] }
            return decoded
        }
        set { checkInDatesJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]" }
    }
    var isFasting: Bool = false
    var fastingStartDate: Date?
    var fastingEndDate: Date?
    var isSharedWithFriends: Bool = false
    private var intercessorIdsJSON: String = "[]"
    var intercessorIds: [String] {
        get {
            guard let data = intercessorIdsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set { intercessorIdsJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]" }
    }
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
        self.tagsJSON = (try? JSONEncoder().encode(tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 