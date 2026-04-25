//
//  ReadingPlan.swift
//  Faith Journal
//
//  Bible reading plans model
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class ReadingPlan {
    var id: UUID = UUID()
    var title: String = ""
    var planDescription: String = ""
    var duration: Int = 30 // days
    var startDate: Date = Date()
    var endDate: Date?
    var currentDay: Int = 1
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var readingsData: Data? // Store DailyReading array as JSON data
    
    // New features
    var reminderEnabled: Bool = false
    var reminderTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    var catchUpModeEnabled: Bool = true
    var isPaused: Bool = false
    var pauseDate: Date?
    var streakCount: Int = 0
    var longestStreak: Int = 0
    var totalReadingTime: TimeInterval = 0 // in seconds
    var lastReadingDate: Date?
    var category: String = "General"
    var difficulty: String = "Beginner" // Beginner, Intermediate, Advanced
    var isCustom: Bool = false
    var sharedWithFriends: Bool = false
    var notesData: Data? // Store notes as JSON
    
    init(title: String, description: String, duration: Int = 30, startDate: Date = Date(), category: String = "General", difficulty: String = "Beginner", isCustom: Bool = false) {
        self.id = UUID()
        self.title = title
        self.planDescription = description
        self.duration = duration
        self.startDate = startDate
        self.currentDay = 1
        self.isCompleted = false
        self.createdAt = Date()
        self.readingsData = nil
        self.reminderEnabled = false
        self.reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        self.catchUpModeEnabled = true
        self.isPaused = false
        self.streakCount = 0
        self.longestStreak = 0
        self.totalReadingTime = 0
        self.category = category
        self.difficulty = difficulty
        self.isCustom = isCustom
        self.sharedWithFriends = false
    }
    
    var readings: [DailyReading] {
        get {
            guard let data = readingsData,
                  let decoded = try? JSONDecoder().decode([DailyReading].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            readingsData = try? JSONEncoder().encode(newValue)
        }
    }
}

struct DailyReading: Codable, Identifiable {
    var id: Int { day } // Use day as unique identifier
    let day: Int
    let reference: String
    let readingDescription: String
    var isCompleted: Bool = false
    var completedDate: Date?
    var readingTime: TimeInterval = 0 // in seconds
    var notes: String = ""
    var highlights: [String] = [] // Verse references that were highlighted
    var reflection: String = ""
    var studyQuestions: [String] = []
    var crossReferences: [String] = []
    
    init(day: Int, reference: String, description: String, studyQuestions: [String] = [], crossReferences: [String] = []) {
        self.day = day
        self.reference = reference
        self.readingDescription = description
        self.isCompleted = false
        self.completedDate = nil
        self.readingTime = 0
        self.notes = ""
        self.highlights = []
        self.reflection = ""
        self.studyQuestions = studyQuestions
        self.crossReferences = crossReferences
    }
}

@available(iOS 17.0, *)
extension ReadingPlan {
    var progress: Double {
        guard duration > 0 else { return 0 }
        let completedCount = readings.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(duration)
    }
    
    var daysRemaining: Int {
        if catchUpModeEnabled {
            let completedCount = readings.filter { $0.isCompleted }.count
            return max(0, duration - completedCount)
        } else {
            return max(0, duration - currentDay + 1)
        }
    }
    
    var completedReadingsCount: Int {
        readings.filter { $0.isCompleted }.count
    }
    
    var missedDays: Int {
        guard !isPaused else { return 0 }
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(0, daysSinceStart - completedReadingsCount)
    }
    
    var averageReadingTime: TimeInterval {
        let completedReadings = readings.filter { $0.isCompleted && $0.readingTime > 0 }
        guard !completedReadings.isEmpty else { return 0 }
        let totalTime = completedReadings.reduce(0) { $0 + $1.readingTime }
        return totalTime / Double(completedReadings.count)
    }
    
    var notes: [ReadingNote] {
        get {
            guard let data = notesData,
                  let decoded = try? JSONDecoder().decode([ReadingNote].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            notesData = try? JSONEncoder().encode(newValue)
        }
    }
    
    func getTodayReading() -> DailyReading? {
        if catchUpModeEnabled {
            // Find first uncompleted reading
            return readings.first { !$0.isCompleted }
        } else {
            return readings.first { $0.day == currentDay }
        }
    }
    
    func getReadingForDay(_ day: Int) -> DailyReading? {
        readings.first { $0.day == day }
    }
    
    func markReadingComplete(_ day: Int, readingTime: TimeInterval = 0) {
        guard let index = readings.firstIndex(where: { $0.day == day }) else { return }
        
        readings[index].isCompleted = true
        readings[index].completedDate = Date()
        readings[index].readingTime = readingTime
        
        // Update streak
        updateStreak()
        
        // Update total reading time
        totalReadingTime += readingTime
        lastReadingDate = Date()
        
        // Update current day if not in catch-up mode
        if !catchUpModeEnabled {
            if day == currentDay && currentDay < duration {
                currentDay += 1
            }
        }
        
        // Check if plan is completed
        if completedReadingsCount >= duration {
            isCompleted = true
            endDate = Date()
        }
    }
    
    func updateStreak() {
        let calendar = Calendar.current
        guard let lastDate = lastReadingDate else {
            streakCount = 1
            longestStreak = max(longestStreak, streakCount)
            return
        }
        
        if let daysSince = calendar.dateComponents([.day], from: lastDate, to: Date()).day {
            if daysSince == 1 {
                // Consecutive day
                streakCount += 1
            } else if daysSince > 1 {
                // Streak broken
                longestStreak = max(longestStreak, streakCount)
                streakCount = 1
            }
            // daysSince == 0 means same day, don't change streak
        }
        
        longestStreak = max(longestStreak, streakCount)
    }
    
    func pause() {
        isPaused = true
        pauseDate = Date()
    }
    
    func resume() {
        isPaused = false
        pauseDate = nil
    }
    
    func getCalendarData() -> [Date: Bool] {
        var calendarData: [Date: Bool] = [:]
        let calendar = Calendar.current
        
        for reading in readings {
            if let completedDate = reading.completedDate {
                let dayStart = calendar.startOfDay(for: completedDate)
                calendarData[dayStart] = true
            }
        }
        
        return calendarData
    }
}

struct ReadingNote: Codable, Identifiable {
    var id: UUID = UUID()
    var day: Int
    var note: String
    var createdAt: Date = Date()
    
    init(day: Int, note: String) {
        self.id = UUID()
        self.day = day
        self.note = note
        self.createdAt = Date()
    }
}
