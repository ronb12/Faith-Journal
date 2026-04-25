//
//  StatisticsService.swift
//  Faith Journal
//
//  Comprehensive statistics and analytics service
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@MainActor
class StatisticsService: ObservableObject {
    static let shared = StatisticsService()
    
    private init() {}
    
    // MARK: - Journal Statistics
    
    func getTotalWords(entries: [JournalEntry]) -> Int {
        entries.reduce(0) { $0 + $1.content.split(separator: " ").count }
    }
    
    func getAverageEntryLength(entries: [JournalEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        return getTotalWords(entries: entries) / entries.count
    }
    
    func getLongestEntry(entries: [JournalEntry]) -> JournalEntry? {
        entries.max(by: { $0.content.count < $1.content.count })
    }
    
    func getShortestEntry(entries: [JournalEntry]) -> JournalEntry? {
        entries.filter { !$0.content.isEmpty }.min(by: { $0.content.count < $1.content.count })
    }
    
    func getEntriesByDayOfWeek(entries: [JournalEntry]) -> [String: Int] {
        let calendar = Calendar.current
        var dayCounts: [String: Int] = [:]
        
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.date)
            let dayName = calendar.weekdaySymbols[weekday - 1]
            dayCounts[dayName, default: 0] += 1
        }
        
        return dayCounts
    }
    
    func getMostActiveDay(entries: [JournalEntry]) -> String {
        let dayCounts = getEntriesByDayOfWeek(entries: entries)
        return dayCounts.max(by: { $0.value < $1.value })?.key ?? "N/A"
    }
    
    func getEntriesByHour(entries: [JournalEntry]) -> [Int: Int] {
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]
        
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.date)
            hourCounts[hour, default: 0] += 1
        }
        
        return hourCounts
    }
    
    func getBestJournalingTime(entries: [JournalEntry]) -> String {
        let hourCounts = getEntriesByHour(entries: entries)
        guard let bestHour = hourCounts.max(by: { $0.value < $1.value })?.key else {
            return "N/A"
        }
        
        switch bestHour {
        case 5..<12: return "Morning (\(bestHour):00)"
        case 12..<17: return "Afternoon (\(bestHour):00)"
        case 17..<21: return "Evening (\(bestHour):00)"
        default: return "Night (\(bestHour):00)"
        }
    }
    
    func getConsistencyScore(entries: [JournalEntry], timeframe: Timeframe) -> Double {
        let filtered = filterByTimeframe(entries: entries, timeframe: timeframe)
        guard !filtered.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let days = getDaysInTimeframe(timeframe)
        let entryDates = Set(filtered.map { calendar.startOfDay(for: $0.date) })
        
        return Double(entryDates.count) / Double(days) * 100.0
    }
    
    // MARK: - Prayer Statistics
    
    func getAverageAnswerTime(prayers: [PrayerRequest]) -> TimeInterval? {
        let answered = prayers.filter { $0.isAnswered && $0.answerDate != nil }
        guard !answered.isEmpty else { return nil }
        
        let totalTime = answered.reduce(0.0) { total, prayer in
            if let answerDate = prayer.answerDate {
                return total + answerDate.timeIntervalSince(prayer.date)
            }
            return total
        }
        
        return totalTime / Double(answered.count)
    }
    
    func getPrayerAnswerRate(prayers: [PrayerRequest], timeframe: Timeframe) -> Double {
        let filtered = filterPrayersByTimeframe(prayers: prayers, timeframe: timeframe)
        guard !filtered.isEmpty else { return 0 }
        return Double(filtered.filter { $0.isAnswered }.count) / Double(filtered.count) * 100.0
    }
    
    func getMostPrayedTopics(prayers: [PrayerRequest]) -> [(String, Int)] {
        var topicCounts: [String: Int] = [:]
        
        for prayer in prayers {
            for tag in prayer.tags {
                topicCounts[tag, default: 0] += 1
            }
        }
        
        return Array(topicCounts.sorted(by: { $0.value > $1.value }).prefix(5))
    }
    
    // MARK: - Mood Statistics
    
    func getMoodTrend(entries: [MoodEntry], timeframe: Timeframe) -> [Date: Double] {
        let filtered = filterMoodsByTimeframe(entries: entries, timeframe: timeframe)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { entry in
            calendar.startOfDay(for: entry.date)
        }
        
        return grouped.mapValues { entries in
            Double(entries.reduce(0) { $0 + $1.intensity }) / Double(entries.count)
        }
    }
    
    func getMoodConsistency(entries: [MoodEntry], timeframe: Timeframe) -> Double {
        let filtered = filterMoodsByTimeframe(entries: entries, timeframe: timeframe)
        guard filtered.count > 1 else { return 0 }
        
        let intensities = filtered.map { Double($0.intensity) }
        let mean = intensities.reduce(0, +) / Double(intensities.count)
        let variance = intensities.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intensities.count)
        let stdDev = sqrt(variance)
        
        // Convert to 0-100 score (lower stdDev = higher consistency)
        return max(0, 100 - (stdDev * 10))
    }
    
    // MARK: - Reading Plans Statistics
    
    func getReadingPlansStats(plans: [ReadingPlan]) -> ReadingPlansStats {
        let completed = plans.filter { $0.isCompleted }.count
        let active = plans.filter { !$0.isCompleted && !$0.isPaused }.count
        let totalReadings = plans.reduce(0) { $0 + $1.completedReadingsCount }
        let totalTime = plans.reduce(0.0) { $0 + $1.totalReadingTime }
        let longestStreak = plans.map { $0.longestStreak }.max() ?? 0
        
        return ReadingPlansStats(
            total: plans.count,
            completed: completed,
            active: active,
            totalReadings: totalReadings,
            totalTime: totalTime,
            longestStreak: longestStreak
        )
    }
    
    // MARK: - Bible Statistics
    
    func getBibleStats(bookmarks: [BookmarkedVerse], highlights: [BibleHighlight], notes: [BibleNote]) -> BibleStats {
        let favoriteBooks = getFavoriteBooks(bookmarks: bookmarks, highlights: highlights)
        
        return BibleStats(
            bookmarks: bookmarks.count,
            highlights: highlights.count,
            notes: notes.count,
            favoriteBooks: favoriteBooks
        )
    }
    
    private func getFavoriteBooks(bookmarks: [BookmarkedVerse], highlights: [BibleHighlight]) -> [String: Int] {
        var bookCounts: [String: Int] = [:]
        
        for bookmark in bookmarks {
            if let book = extractBook(from: bookmark.verseReference) {
                bookCounts[book, default: 0] += 1
            }
        }
        
        for highlight in highlights {
            if let book = extractBook(from: highlight.verseReference) {
                bookCounts[book, default: 0] += 1
            }
        }
        
        return bookCounts.sorted { $0.value > $1.value }
            .reduce(into: [String: Int]()) { $0[$1.key] = $1.value }
    }
    
    private func extractBook(from reference: String) -> String? {
        return reference.components(separatedBy: " ").first
    }
    
    // MARK: - Engagement Scores
    
    func getOverallEngagementScore(
        entries: [JournalEntry],
        prayers: [PrayerRequest],
        moods: [MoodEntry],
        plans: [ReadingPlan]
    ) -> EngagementScore {
        let journalScore = getJournalingEngagement(entries: entries)
        let prayerScore = getPrayerEngagement(prayers: prayers)
        let moodScore = getMoodEngagement(entries: moods)
        let readingScore = getReadingEngagement(plans: plans)
        
        let overall = (journalScore + prayerScore + moodScore + readingScore) / 4.0
        
        return EngagementScore(
            overall: overall,
            journaling: journalScore,
            prayer: prayerScore,
            mood: moodScore,
            reading: readingScore
        )
    }
    
    private func getJournalingEngagement(entries: [JournalEntry]) -> Double {
        guard !entries.isEmpty else { return 0 }
        let recentEntries = entries.filter { $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: Date())! }
        let consistency = Double(recentEntries.count) / 30.0 * 100.0
        return min(100, consistency)
    }
    
    private func getPrayerEngagement(prayers: [PrayerRequest]) -> Double {
        guard !prayers.isEmpty else { return 0 }
        let recentPrayers = prayers.filter { $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: Date())! }
        let consistency = Double(recentPrayers.count) / 30.0 * 100.0
        return min(100, consistency)
    }
    
    private func getMoodEngagement(entries: [MoodEntry]) -> Double {
        guard !entries.isEmpty else { return 0 }
        let recentMoods = entries.filter { $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: Date())! }
        let consistency = Double(recentMoods.count) / 30.0 * 100.0
        return min(100, consistency)
    }
    
    private func getReadingEngagement(plans: [ReadingPlan]) -> Double {
        guard !plans.isEmpty else { return 0 }
        let activePlans = plans.filter { !$0.isCompleted && !$0.isPaused }
        guard !activePlans.isEmpty else { return 0 }
        
        let avgProgress = activePlans.reduce(0.0) { $0 + $1.progress } / Double(activePlans.count)
        return avgProgress * 100.0
    }
    
    // MARK: - Insights Generation
    
    func generateInsights(
        entries: [JournalEntry],
        prayers: [PrayerRequest],
        moods: [MoodEntry],
        plans: [ReadingPlan]
    ) -> [StatisticInsight] {
        var insights: [StatisticInsight] = []
        
        // Journal insights
        if entries.count >= 10 {
            let mostActiveDay = getMostActiveDay(entries: entries)
            insights.append(StatisticInsight(
                type: .pattern,
                title: "Journaling Pattern",
                message: "You journal most on \(mostActiveDay)s",
                icon: "calendar",
                priority: .low
            ))
        }
        
        if entries.count >= 50 {
            let consistency = getConsistencyScore(entries: entries, timeframe: .month)
            if consistency >= 70 {
                insights.append(StatisticInsight(
                    type: .achievement,
                    title: "Great Consistency!",
                    message: "You've journaled \(Int(consistency))% of days this month",
                    icon: "star.fill",
                    priority: .medium
                ))
            }
        }
        
        // Prayer insights
        if !prayers.isEmpty {
            let answerRate = getPrayerAnswerRate(prayers: prayers, timeframe: .all)
            if answerRate >= 50 {
                insights.append(StatisticInsight(
                    type: .positive,
                    title: "Prayers Answered",
                    message: "\(Int(answerRate))% of your prayers have been answered!",
                    icon: "hands.sparkles.fill",
                    priority: .high
                ))
            }
        }
        
        // Streak insights
        let streak = calculateStreak(entries: entries)
        if streak >= 7 {
            insights.append(StatisticInsight(
                type: .achievement,
                title: "Amazing Streak!",
                message: "You've journaled for \(streak) consecutive days!",
                icon: "flame.fill",
                priority: .high
            ))
        }
        
        return insights
    }
    
    private func calculateStreak(entries: [JournalEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        var streak = 0
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())
        
        let entryDates = Set(entries.map { calendar.startOfDay(for: $0.date) })
        
        while entryDates.contains(currentDate) {
            streak += 1
            if let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                currentDate = calendar.startOfDay(for: previousDate)
            } else {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Period Comparison
    
    func comparePeriods<T>(
        current: [T],
        previous: [T],
        dateExtractor: (T) -> Date
    ) -> PeriodComparison {
        let currentCount = current.count
        let previousCount = previous.count
        
        let change = currentCount - previousCount
        let percentChange = previousCount > 0 ? Double(change) / Double(previousCount) * 100.0 : 0
        
        return PeriodComparison(
            current: currentCount,
            previous: previousCount,
            change: change,
            percentChange: percentChange,
            trend: change > 0 ? .up : change < 0 ? .down : .stable
        )
    }
    
    // MARK: - Helper Methods
    
    enum Timeframe {
        case week, month, year, all, custom(start: Date, end: Date)
    }
    
    private func filterByTimeframe<T>(items: [T], timeframe: Timeframe, dateExtractor: (T) -> Date) -> [T] {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeframe {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return items.filter { dateExtractor($0) >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return items.filter { dateExtractor($0) >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return items.filter { dateExtractor($0) >= yearAgo }
        case .all:
            return items
        case .custom(let start, let end):
            return items.filter { dateExtractor($0) >= start && dateExtractor($0) <= end }
        }
    }
    
    func filterByTimeframe(entries: [JournalEntry], timeframe: Timeframe) -> [JournalEntry] {
        filterByTimeframe(items: entries, timeframe: timeframe) { $0.date }
    }
    
    func filterPrayersByTimeframe(prayers: [PrayerRequest], timeframe: Timeframe) -> [PrayerRequest] {
        filterByTimeframe(items: prayers, timeframe: timeframe) { $0.date }
    }
    
    func filterMoodsByTimeframe(entries: [MoodEntry], timeframe: Timeframe) -> [MoodEntry] {
        filterByTimeframe(items: entries, timeframe: timeframe) { $0.date }
    }
    
    private func getDaysInTimeframe(_ timeframe: Timeframe) -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeframe {
        case .week: return 7
        case .month:
            if let days = calendar.range(of: .day, in: .month, for: now)?.count {
                return days
            }
            return 30
        case .year: return 365
        case .all: return 365
        case .custom(let start, let end):
            return calendar.dateComponents([.day], from: start, to: end).day ?? 0
        }
    }
}

// MARK: - Data Structures

struct ReadingPlansStats {
    let total: Int
    let completed: Int
    let active: Int
    let totalReadings: Int
    let totalTime: TimeInterval
    let longestStreak: Int
    
    var formattedTotalTime: String {
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct BibleStats {
    let bookmarks: Int
    let highlights: Int
    let notes: Int
    let favoriteBooks: [String: Int]
}

struct EngagementScore {
    let overall: Double
    let journaling: Double
    let prayer: Double
    let mood: Double
    let reading: Double
}

struct StatisticInsight {
    let type: InsightType
    let title: String
    let message: String
    let icon: String
    let priority: Priority
    
    enum InsightType {
        case achievement, pattern, positive, warning, recommendation
    }
    
    enum Priority {
        case high, medium, low
    }
}

struct PeriodComparison {
    let current: Int
    let previous: Int
    let change: Int
    let percentChange: Double
    let trend: Trend
    
    enum Trend {
        case up, down, stable
    }
}

