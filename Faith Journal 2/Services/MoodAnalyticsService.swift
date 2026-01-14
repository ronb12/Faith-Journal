//
//  MoodAnalyticsService.swift
//  Faith Journal
//
//  Advanced mood analytics and insights service
//

import Foundation
import SwiftData
import CoreLocation

@available(iOS 17.0, *)
@MainActor
class MoodAnalyticsService: ObservableObject {
    static let shared = MoodAnalyticsService()
    
    private init() {}
    
    // MARK: - Basic Statistics
    
    func getAverageMood(entries: [MoodEntry], timeframe: Timeframe) -> Double {
        let filtered = filterByTimeframe(entries: entries, timeframe: timeframe)
        guard !filtered.isEmpty else { return 0 }
        let sum = filtered.reduce(0) { $0 + Double($1.intensity) }
        return sum / Double(filtered.count)
    }
    
    func getMoodDistribution(entries: [MoodEntry], timeframe: Timeframe) -> [String: Int] {
        let filtered = filterByTimeframe(entries: entries, timeframe: timeframe)
        var distribution: [String: Int] = [:]
        for entry in filtered {
            distribution[entry.mood, default: 0] += 1
        }
        return distribution
    }
    
    // MARK: - Pattern Analysis
    
    func getBestWorstDays(entries: [MoodEntry]) -> (best: String, worst: String) {
        let calendar = Calendar.current
        var dayAverages: [String: [Int]] = [:]
        
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.date)
            let dayName = calendar.weekdaySymbols[weekday - 1]
            dayAverages[dayName, default: []].append(entry.intensity)
        }
        
        let dayMeans = dayAverages.mapValues { values in
            Double(values.reduce(0, +)) / Double(values.count)
        }
        
        let best = dayMeans.max(by: { $0.value < $1.value })?.key ?? "N/A"
        let worst = dayMeans.min(by: { $0.value < $1.value })?.key ?? "N/A"
        
        return (best: best, worst: worst)
    }
    
    func getBestWorstTimes(entries: [MoodEntry]) -> (best: String, worst: String) {
        var timeAverages: [String: [Int]] = [:]
        
        for entry in entries {
            timeAverages[entry.timeOfDay, default: []].append(entry.intensity)
        }
        
        let timeMeans = timeAverages.mapValues { values in
            Double(values.reduce(0, +)) / Double(values.count)
        }
        
        let best = timeMeans.max(by: { $0.value < $1.value })?.key ?? "N/A"
        let worst = timeMeans.min(by: { $0.value < $1.value })?.key ?? "N/A"
        
        return (best: best, worst: worst)
    }
    
    func getMoodStreaks(entries: [MoodEntry]) -> (positiveStreak: Int, negativeStreak: Int, currentStreak: Int) {
        let sorted = entries.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        
        var positiveStreak = 0
        var negativeStreak = 0
        var currentStreak = 0
        var lastDate: Date?
        var lastWasPositive = false
        
        for entry in sorted.reversed() {
            let isPositive = entry.intensity >= 7
            let dayStart = calendar.startOfDay(for: entry.date)
            
            if let last = lastDate {
                let lastDayStart = calendar.startOfDay(for: last)
                if calendar.isDate(dayStart, inSameDayAs: lastDayStart) {
                    continue // Same day, skip
                }
                
                if calendar.isDate(dayStart, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: lastDayStart)!) {
                    // Consecutive day
                    if isPositive == lastWasPositive {
                        currentStreak += 1
                    } else {
                        if lastWasPositive {
                            positiveStreak = max(positiveStreak, currentStreak)
                        } else {
                            negativeStreak = max(negativeStreak, currentStreak)
                        }
                        currentStreak = 1
                    }
                } else {
                    // Not consecutive
                    if lastWasPositive {
                        positiveStreak = max(positiveStreak, currentStreak)
                    } else {
                        negativeStreak = max(negativeStreak, currentStreak)
                    }
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = dayStart
            lastWasPositive = isPositive
        }
        
        if lastWasPositive {
            positiveStreak = max(positiveStreak, currentStreak)
        } else {
            negativeStreak = max(negativeStreak, currentStreak)
        }
        
        return (positiveStreak: positiveStreak, negativeStreak: negativeStreak, currentStreak: currentStreak)
    }
    
    func getMoodVolatility(entries: [MoodEntry], timeframe: Timeframe) -> Double {
        let filtered = filterByTimeframe(entries: entries, timeframe: timeframe)
        guard filtered.count > 1 else { return 0 }
        
        let intensities = filtered.map { Double($0.intensity) }
        let mean = intensities.reduce(0, +) / Double(intensities.count)
        let variance = intensities.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intensities.count)
        return sqrt(variance) // Standard deviation
    }
    
    // MARK: - Correlation Analysis
    
    func getActivityCorrelation(entries: [MoodEntry]) -> [String: Double] {
        var activityMoods: [String: [Int]] = [:]
        
        for entry in entries {
            for activity in entry.activities {
                activityMoods[activity, default: []].append(entry.intensity)
            }
        }
        
        return activityMoods.mapValues { moods in
            Double(moods.reduce(0, +)) / Double(moods.count)
        }
    }
    
    func getWeatherCorrelation(entries: [MoodEntry]) -> [String: Double] {
        var weatherMoods: [String: [Int]] = [:]
        
        for entry in entries where entry.weather != nil {
            weatherMoods[entry.weather!, default: []].append(entry.intensity)
        }
        
        return weatherMoods.mapValues { moods in
            Double(moods.reduce(0, +)) / Double(moods.count)
        }
    }
    
    // MARK: - Insights Generation
    
    func generateInsights(entries: [MoodEntry], journalEntries: [JournalEntry], prayerRequests: [PrayerRequest]) -> [MoodInsight] {
        var insights: [MoodInsight] = []
        
        guard !entries.isEmpty else {
            insights.append(MoodInsight(
                type: .encouragement,
                title: "Start Tracking",
                message: "Begin tracking your mood to discover patterns and insights!",
                priority: .low
            ))
            return insights
        }
        
        let recentEntries = entries.filter { $0.date >= Calendar.current.date(byAdding: .day, value: -7, to: Date())! }
        let avgMood = getAverageMood(entries: recentEntries, timeframe: .week)
        
        // Low mood insight
        if avgMood < 5 {
            insights.append(MoodInsight(
                type: .warning,
                title: "Lower Mood Pattern",
                message: "Your mood has been lower this week. Consider spending time in prayer and reflection.",
                priority: .high,
                suggestedActions: ["Prayer", "Bible Reading", "Journaling"]
            ))
        }
        
        // Activity correlation
        let activityCorr = getActivityCorrelation(entries: entries)
        if let bestActivity = activityCorr.max(by: { $0.value < $1.value }) {
            if bestActivity.value >= 7 {
                insights.append(MoodInsight(
                    type: .positive,
                    title: "Positive Activity",
                    message: "\(bestActivity.key) seems to boost your mood! Consider doing it more often.",
                    priority: .medium,
                    suggestedActions: [bestActivity.key]
                ))
            }
        }
        
        // Streak insights
        let streaks = getMoodStreaks(entries: entries)
        if streaks.currentStreak >= 3 {
            insights.append(MoodInsight(
                type: .achievement,
                title: "Great Streak!",
                message: "You've had \(streaks.currentStreak) consecutive days of \(streaks.currentStreak >= 7 ? "positive" : "consistent") mood!",
                priority: .low
            ))
        }
        
        // Pattern insights
        let (bestDay, worstDay) = getBestWorstDays(entries: entries)
        if bestDay != worstDay && bestDay != "N/A" {
            insights.append(MoodInsight(
                type: .pattern,
                title: "Day Pattern",
                message: "\(bestDay)s tend to be your best days, while \(worstDay)s are more challenging.",
                priority: .low
            ))
        }
        
        return insights
    }
    
    // MARK: - Helper Methods
    
    enum Timeframe {
        case week, month, year, all
    }
    
    private func filterByTimeframe(entries: [MoodEntry], timeframe: Timeframe) -> [MoodEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeframe {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return entries.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return entries.filter { $0.date >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return entries.filter { $0.date >= yearAgo }
        case .all:
            return entries
        }
    }
}

struct MoodInsight {
    let type: InsightType
    let title: String
    let message: String
    let priority: Priority
    var suggestedActions: [String] = []
    var scriptureReference: String?
    
    enum InsightType {
        case positive, warning, pattern, achievement, encouragement
    }
    
    enum Priority {
        case high, medium, low
    }
}
