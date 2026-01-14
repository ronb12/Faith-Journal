//
//  ReadingPlanStatisticsService.swift
//  Faith Journal
//
//  Manages reading plan statistics and analytics
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
class ReadingPlanStatisticsService {
    static let shared = ReadingPlanStatisticsService()
    
    private init() {}
    
    func getOverallStatistics(plans: [ReadingPlan]) -> ReadingPlanStatistics {
        let totalPlans = plans.count
        let completedPlans = plans.filter { $0.isCompleted }.count
        let activePlans = plans.filter { !$0.isCompleted && !$0.isPaused }.count
        let totalReadings = plans.reduce(0) { $0 + $1.completedReadingsCount }
        let totalTime = plans.reduce(0) { $0 + $1.totalReadingTime }
        let longestStreak = plans.map { $0.longestStreak }.max() ?? 0
        let currentStreak = plans.map { $0.streakCount }.max() ?? 0
        
        return ReadingPlanStatistics(
            totalPlans: totalPlans,
            completedPlans: completedPlans,
            activePlans: activePlans,
            totalReadings: totalReadings,
            totalReadingTime: totalTime,
            longestStreak: longestStreak,
            currentStreak: currentStreak,
            averageCompletionRate: totalPlans > 0 ? Double(completedPlans) / Double(totalPlans) : 0
        )
    }
    
    func getWeeklyProgress(plan: ReadingPlan) -> [Date: Bool] {
        let calendar = Calendar.current
        var weeklyProgress: [Date: Bool] = [:]
        
        let today = Date()
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayStart = calendar.startOfDay(for: date)
                // Check if any reading was completed on this day
                let completed = plan.readings.contains { reading in
                    if let completedDate = reading.completedDate {
                        return calendar.isDate(completedDate, inSameDayAs: dayStart)
                    }
                    return false
                }
                weeklyProgress[dayStart] = completed
            }
        }
        
        return weeklyProgress
    }
    
    func getMonthlyProgress(plan: ReadingPlan) -> [Date: Bool] {
        let calendar = Calendar.current
        var monthlyProgress: [Date: Bool] = [:]
        
        let today = Date()
        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayStart = calendar.startOfDay(for: date)
                let completed = plan.readings.contains { reading in
                    if let completedDate = reading.completedDate {
                        return calendar.isDate(completedDate, inSameDayAs: dayStart)
                    }
                    return false
                }
                monthlyProgress[dayStart] = completed
            }
        }
        
        return monthlyProgress
    }
    
    func getFavoriteBooks(plans: [ReadingPlan]) -> [String: Int] {
        var bookCounts: [String: Int] = [:]
        
        for plan in plans {
            for reading in plan.readings where reading.isCompleted {
                // Extract book name from reference (e.g., "John 3:16" -> "John")
                let book = reading.reference.components(separatedBy: " ").first ?? ""
                bookCounts[book, default: 0] += 1
            }
        }
        
        return bookCounts.sorted { $0.value > $1.value }
            .reduce(into: [String: Int]()) { $0[$1.key] = $1.value }
    }
    
    func getReadingPatterns(plan: ReadingPlan) -> ReadingPatterns {
        let calendar = Calendar.current
        var timeOfDayCounts: [String: Int] = ["Morning": 0, "Afternoon": 0, "Evening": 0, "Night": 0]
        var dayOfWeekCounts: [String: Int] = [:]
        
        for reading in plan.readings where reading.isCompleted {
            guard let completedDate = reading.completedDate else { continue }
            let hour = calendar.component(.hour, from: completedDate)
            let weekday = calendar.component(.weekday, from: completedDate)
            
            // Time of day
            switch hour {
            case 5..<12: timeOfDayCounts["Morning", default: 0] += 1
            case 12..<17: timeOfDayCounts["Afternoon", default: 0] += 1
            case 17..<21: timeOfDayCounts["Evening", default: 0] += 1
            default: timeOfDayCounts["Night", default: 0] += 1
            }
            
            // Day of week
            let weekdayName = calendar.weekdaySymbols[weekday - 1]
            dayOfWeekCounts[weekdayName, default: 0] += 1
        }
        
        return ReadingPatterns(
            preferredTimeOfDay: timeOfDayCounts.max(by: { $0.value < $1.value })?.key ?? "Morning",
            preferredDayOfWeek: dayOfWeekCounts.max(by: { $0.value < $1.value })?.key ?? "Sunday",
            timeOfDayDistribution: timeOfDayCounts,
            dayOfWeekDistribution: dayOfWeekCounts
        )
    }
}

struct ReadingPlanStatistics {
    let totalPlans: Int
    let completedPlans: Int
    let activePlans: Int
    let totalReadings: Int
    let totalReadingTime: TimeInterval
    let longestStreak: Int
    let currentStreak: Int
    let averageCompletionRate: Double
    
    var formattedTotalTime: String {
        let hours = Int(totalReadingTime) / 3600
        let minutes = (Int(totalReadingTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct ReadingPatterns {
    let preferredTimeOfDay: String
    let preferredDayOfWeek: String
    let timeOfDayDistribution: [String: Int]
    let dayOfWeekDistribution: [String: Int]
}

