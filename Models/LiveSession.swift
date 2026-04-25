import Foundation
import SwiftData

struct StreamSegment: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var scriptureReference: String = ""
    var durationMinutes: Int = 0
}

enum StreamMode: String, CaseIterable {
    case broadcast = "broadcast"
    case conference = "conference"
    case multiParticipant = "multiParticipant"
}

@available(iOS 17.0, *)
@Model
final class LiveSession {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var hostId: String = ""
    var hostName: String = ""
    var hostBio: String = ""
    var startTime: Date = Date()
    var scheduledStartTime: Date? // For scheduled sessions
    var endTime: Date?
    var isActive: Bool = true
    var maxParticipants: Int = 10
    var currentParticipants: Int = 0
    var currentBroadcasters: Int = 0 // Number of active broadcasters
    var viewerCount: Int = 0 // For broadcast mode
    var peakViewerCount: Int = 0
    var category: String = ""
    /// Stored as JSON array string to avoid Core Data "could not materialize Objective-C class Array" for [String].
    private var tagsJSON: String = "[]"
    /// Backed by tagsJSON for SwiftData/Core Data compatibility.
    var tags: [String] {
        get {
            guard let data = tagsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            tagsJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }
    }
    var isPrivate: Bool = false
    var isFavorite: Bool = false
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var agenda: String = "" // Session outline/agenda
    /// Stored as JSON array string to avoid Core Data "could not materialize Objective-C class Array" for [String].
    private var relatedResourcesJSON: String = "[]"
    /// Bible verses, prayer topics, etc. Backed by relatedResourcesJSON for SwiftData/Core Data compatibility.
    var relatedResources: [String] {
        get {
            guard let data = relatedResourcesJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            relatedResourcesJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }
    }
    var recordingURL: String? // URL to session recording
    var transcriptURL: String? // URL to transcript
    var summary: String = "" // Post-session summary
    var connectionQuality: String = "Good" // Good, Fair, Poor
    var isLocked: Bool = false // Lock session from new joins
    var isRecording: Bool = false
    var thumbnailURL: String? // Preview image
    var messageCount: Int = 0 // Total messages in chat
    var reactionCount: Int = 0 // Total reactions received
    // Stream mode: "broadcast", "conference", or "multiParticipant"
    var streamMode: String = StreamMode.conference.rawValue

    var typedStreamMode: StreamMode {
        get { StreamMode(rawValue: streamMode) ?? .conference }
        set { streamMode = newValue.rawValue }
    }

    // Session controls / scheduling enhancements
    var durationLimitMinutes: Int = 30

    // Recurring session fields
    var isRecurring: Bool = false
    var recurrencePattern: String = "" // "weekly", "monthly"
    var recurrenceEndDate: Date? // Optional end date for recurring sessions
    var parentSessionId: UUID? // Link to parent template
    var calendarEventId: String? // Calendar integration identifier

    // Waiting room fields
    var hasWaitingRoom: Bool = false
    var waitingRoomEnabled: Bool = false
    var allowParticipantsBeforeStart: Bool = true

    // Segment agenda (Feature 6)
    var segmentsData: Data?

    // Amen moment timestamps since session start (Feature 3)
    var amenMomentsData: Data?

    // Friend notification list (Feature 5) — stores friend userIds to notify on schedule
    private var notifyFriendIdsJSON: String = "[]"
    var notifyFriendIds: [String] {
        get {
            guard let data = notifyFriendIdsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return decoded
        }
        set {
            notifyFriendIdsJSON = (try? JSONEncoder().encode(newValue)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }
    }

    init(title: String, description: String, hostId: String, category: String, maxParticipants: Int = 10, tags: [String] = []) {
        self.id = UUID()
        self.title = title
        self.details = description
        self.hostId = hostId
        self.hostName = ""
        self.hostBio = ""
        self.startTime = Date()
        self.scheduledStartTime = nil
        self.isActive = true
        self.maxParticipants = maxParticipants
        self.currentParticipants = 1
        self.currentBroadcasters = 1 // Host is a broadcaster by default
        self.viewerCount = 0
        self.peakViewerCount = 0
        self.category = category
        self.tagsJSON = (try? JSONEncoder().encode(tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.isPrivate = false
        self.isFavorite = false
        self.createdAt = Date()
        self.agenda = ""
        self.relatedResources = []
        self.connectionQuality = "Good"
        self.isLocked = false
        self.isRecording = false
        self.streamMode = StreamMode.conference.rawValue
        self.durationLimitMinutes = 30
        self.isRecurring = false
        self.recurrencePattern = ""
        self.recurrenceEndDate = nil
        self.parentSessionId = nil
        self.calendarEventId = nil
        self.hasWaitingRoom = false
        self.waitingRoomEnabled = false
        self.allowParticipantsBeforeStart = true
        self.segmentsData = nil
        self.amenMomentsData = nil
        self.notifyFriendIdsJSON = "[]"
    }
    
    // Computed properties
    var duration: TimeInterval {
        guard let end = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return end.timeIntervalSince(startTime)
    }

    var durationLimitDescription: String {
        if durationLimitMinutes > 0 {
            return "\(durationLimitMinutes)m limit"
        }
        return "No limit"
    }
    
    var formattedDuration: String {
        let duration = self.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var isScheduled: Bool {
        guard let scheduled = scheduledStartTime else { return false }
        return scheduled > Date() && !isActive
    }
    
    var timeUntilStart: TimeInterval? {
        guard let scheduled = scheduledStartTime else { return nil }
        return scheduled.timeIntervalSince(Date())
    }
} 