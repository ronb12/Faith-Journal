//
//  StreamSchedulingService.swift
//  Faith Journal
//
//  Scheduling service for live streams
//

import Foundation
import SwiftData
import EventKit

@MainActor
@available(iOS 17.0, *)
class StreamSchedulingService: ObservableObject {
    static let shared = StreamSchedulingService()
    
    @Published var scheduledStreams: [ScheduledStream] = []
    @Published var upcomingStreams: [ScheduledStream] = []
    
    private let eventStore = EKEventStore()
    
    struct ScheduledStream: Identifiable {
        let id = UUID()
        let sessionId: UUID
        let title: String
        let description: String
        let scheduledTime: Date
        let duration: TimeInterval
        let category: String
        var reminderMinutes: [Int] = [60, 15, 5] // Default reminders
        var isReminderSet: Bool = false
    }
    
    private init() {}
    
    func scheduleStream(
        sessionId: UUID,
        title: String,
        description: String,
        scheduledTime: Date,
        duration: TimeInterval = 3600,
        category: String = "Worship"
    ) -> ScheduledStream {
        let stream = ScheduledStream(
            sessionId: sessionId,
            title: title,
            description: description,
            scheduledTime: scheduledTime,
            duration: duration,
            category: category
        )
        
        scheduledStreams.append(stream)
        updateUpcomingStreams()
        return stream
    }
    
    func setReminder(for stream: ScheduledStream) async throws {
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            throw SchedulingError.calendarPermissionDenied
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "Live Stream: \(stream.title)"
        event.notes = stream.description
        event.startDate = stream.scheduledTime
        event.endDate = stream.scheduledTime.addingTimeInterval(stream.duration)
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add alarms for reminders
        for minutes in stream.reminderMinutes {
            let alarm = EKAlarm(relativeOffset: -Double(minutes * 60))
            event.addAlarm(alarm)
        }
        
        try eventStore.save(event, span: .thisEvent)
        
        var updatedStream = stream
        updatedStream.isReminderSet = true
        if let index = scheduledStreams.firstIndex(where: { $0.id == stream.id }) {
            scheduledStreams[index] = updatedStream
        }
    }
    
    func cancelScheduledStream(_ stream: ScheduledStream) {
        scheduledStreams.removeAll { $0.id == stream.id }
        updateUpcomingStreams()
    }
    
    func getCountdown(for stream: ScheduledStream) -> TimeInterval {
        return max(0, stream.scheduledTime.timeIntervalSinceNow)
    }
    
    private func updateUpcomingStreams() {
        let now = Date()
        upcomingStreams = scheduledStreams
            .filter { $0.scheduledTime > now }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    func getNextStream() -> ScheduledStream? {
        return upcomingStreams.first
    }
}

enum SchedulingError: LocalizedError {
    case calendarPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .calendarPermissionDenied:
            return "Calendar permission is required to set reminders"
        }
    }
}

