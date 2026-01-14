//
//  MoodGoalsService.swift
//  Faith Journal
//
//  Mood goals and achievements service
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@MainActor
class MoodGoalsService: ObservableObject {
    static let shared = MoodGoalsService()
    
    private init() {}
    
    func checkAchievements(entries: [MoodEntry], achievements: [MoodAchievement]) -> [MoodAchievement] {
        var unlocked: [MoodAchievement] = []
        let analytics = MoodAnalyticsService.shared
        
        for achievement in achievements where !achievement.isUnlocked {
            if shouldUnlockAchievement(achievement, entries: entries, analytics: analytics) {
                achievement.isUnlocked = true
                achievement.unlockedDate = Date()
                unlocked.append(achievement)
            }
        }
        
        return unlocked
    }
    
    private func shouldUnlockAchievement(_ achievement: MoodAchievement, entries: [MoodEntry], analytics: MoodAnalyticsService) -> Bool {
        guard !entries.isEmpty else { return false }
        
        switch achievement.title {
        case "First Check-in":
            return entries.count >= 1
        case "Week Warrior":
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return entries.filter { $0.date >= weekAgo }.count >= 7
        case "Month Master":
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
            return entries.filter { $0.date >= monthAgo }.count >= 30
        case "Streak Starter":
            let streaks = analytics.getMoodStreaks(entries: entries)
            return streaks.currentStreak >= 3
        case "Streak Champion":
            let streaks = analytics.getMoodStreaks(entries: entries)
            return streaks.currentStreak >= 7
        case "Mood Master":
            let streaks = analytics.getMoodStreaks(entries: entries)
            return streaks.currentStreak >= 30
        case "Positive Vibes":
            let avgMood = analytics.getAverageMood(entries: entries, timeframe: .month)
            return avgMood >= 7.5
        case "Consistent Tracker":
            return entries.count >= 100
        default:
            return false
        }
    }
    
    func updateGoalProgress(goal: MoodGoal, entries: [MoodEntry]) {
        guard let targetDate = goal.targetDate else {
            // No target date, calculate based on all entries
            let avgMood = MoodAnalyticsService.shared.getAverageMood(entries: entries, timeframe: .all)
            goal.progress = min(1.0, Double(avgMood) / Double(goal.targetMood))
            return
        }
        
        let relevantEntries = entries.filter { $0.date <= targetDate }
        let avgMood = MoodAnalyticsService.shared.getAverageMood(entries: relevantEntries, timeframe: .all)
        goal.progress = min(1.0, Double(avgMood) / Double(goal.targetMood))
        
        if goal.progress >= 1.0 && !goal.isCompleted {
            goal.isCompleted = true
            goal.completedDate = Date()
        }
    }
    
    func getDefaultAchievements() -> [MoodAchievement] {
        return [
            MoodAchievement(title: "First Check-in", description: "Track your first mood", icon: "🎯", category: .milestone),
            MoodAchievement(title: "Week Warrior", description: "Track your mood for 7 days straight", icon: "📅", category: .consistency),
            MoodAchievement(title: "Month Master", description: "Track your mood for 30 days", icon: "📆", category: .consistency),
            MoodAchievement(title: "Streak Starter", description: "Maintain a 3-day mood streak", icon: "🔥", category: .streak),
            MoodAchievement(title: "Streak Champion", description: "Maintain a 7-day mood streak", icon: "⭐", category: .streak),
            MoodAchievement(title: "Mood Master", description: "Maintain a 30-day mood streak", icon: "👑", category: .streak),
            MoodAchievement(title: "Positive Vibes", description: "Average mood of 7.5+ for a month", icon: "✨", category: .improvement),
            MoodAchievement(title: "Consistent Tracker", description: "Track 100 mood entries", icon: "💯", category: .milestone)
        ]
    }
}
