//
//  ReadingPlan.swift
//  Faith Journal
//
//  Bible reading plans model
//

import Foundation
import SwiftData

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
    
    init(title: String, description: String, duration: Int = 30, startDate: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.planDescription = description
        self.duration = duration
        self.startDate = startDate
        self.currentDay = 1
        self.isCompleted = false
        self.createdAt = Date()
        self.readingsData = nil
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
    
    init(day: Int, reference: String, description: String) {
        self.day = day
        self.reference = reference
        self.readingDescription = description
        self.isCompleted = false
        self.completedDate = nil
    }
}

extension ReadingPlan {
    var progress: Double {
        guard duration > 0 else { return 0 }
        return Double(currentDay - 1) / Double(duration)
    }
    
    var daysRemaining: Int {
        max(0, duration - currentDay + 1)
    }
    
    func getTodayReading() -> DailyReading? {
        readings.first { $0.day == currentDay }
    }
    
    func markReadingComplete(_ day: Int) {
        if let index = readings.firstIndex(where: { $0.day == day }) {
            readings[index].isCompleted = true
            readings[index].completedDate = Date()
            
            if day == currentDay && currentDay < duration {
                currentDay += 1
            }
            
            if currentDay > duration {
                isCompleted = true
                endDate = Date()
            }
        }
    }
}
