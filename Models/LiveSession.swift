import Foundation
import SwiftData

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
    var viewerCount: Int = 0 // For broadcast mode
    var peakViewerCount: Int = 0
    var category: String = ""
    var tags: [String] = []
    var isPrivate: Bool = false
    var isFavorite: Bool = false
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var agenda: String = "" // Session outline/agenda
    var relatedResources: [String] = [] // Bible verses, prayer topics, etc.
    var recordingURL: String? // URL to session recording
    var transcriptURL: String? // URL to transcript
    var summary: String = "" // Post-session summary
    var connectionQuality: String = "Good" // Good, Fair, Poor
    var isLocked: Bool = false // Lock session from new joins
    var isRecording: Bool = false
    var thumbnailURL: String? // Preview image
    var messageCount: Int = 0 // Total messages in chat
    var reactionCount: Int = 0 // Total reactions received
    
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
        self.viewerCount = 0
        self.peakViewerCount = 0
        self.category = category
        self.tags = tags
        self.isPrivate = false
        self.isFavorite = false
        self.createdAt = Date()
        self.agenda = ""
        self.relatedResources = []
        self.connectionQuality = "Good"
        self.isLocked = false
        self.isRecording = false
    }
    
    // Computed properties
    var duration: TimeInterval {
        guard let end = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return end.timeIntervalSince(startTime)
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