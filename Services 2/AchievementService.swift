//
//  AchievementService.swift
//  Faith Journal
//
//  Achievements and milestones service
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@MainActor
class AchievementService: ObservableObject {
    static let shared = AchievementService()
    
    private init() {}
    
    func checkAchievements(
        entries: [JournalEntry],
        prayers: [PrayerRequest],
        moods: [MoodEntry],
        plans: [ReadingPlan],
        bookmarks: [BookmarkedVerse],
        highlights: [BibleHighlight],
        notes: [BibleNote],
        achievements: [StatisticAchievement]
    ) -> [StatisticAchievement] {
        var unlocked: [StatisticAchievement] = []
        
        for achievement in achievements where !achievement.isUnlocked {
            if shouldUnlockAchievement(
                achievement,
                entries: entries,
                prayers: prayers,
                moods: moods,
                plans: plans,
                bookmarks: bookmarks,
                highlights: highlights,
                notes: notes
            ) {
                achievement.isUnlocked = true
                achievement.unlockedDate = Date()
                unlocked.append(achievement)
            }
        }
        
        return unlocked
    }
    
    private func shouldUnlockAchievement(
        _ achievement: StatisticAchievement,
        entries: [JournalEntry],
        prayers: [PrayerRequest],
        moods: [MoodEntry],
        plans: [ReadingPlan],
        bookmarks: [BookmarkedVerse],
        highlights: [BibleHighlight],
        notes: [BibleNote]
    ) -> Bool {
        switch achievement.title {
        case "First Entry":
            return entries.count >= 1
        case "10 Entries":
            return entries.count >= 10
        case "50 Entries":
            return entries.count >= 50
        case "100 Entries":
            return entries.count >= 100
        case "500 Entries":
            return entries.count >= 500
        case "1000 Entries":
            return entries.count >= 1000
        case "7 Day Streak":
            return calculateStreak(entries: entries) >= 7
        case "30 Day Streak":
            return calculateStreak(entries: entries) >= 30
        case "100 Day Streak":
            return calculateStreak(entries: entries) >= 100
        case "First Prayer":
            return prayers.count >= 1
        case "10 Prayers":
            return prayers.count >= 10
        case "50 Prayers":
            return prayers.count >= 50
        case "First Answered Prayer":
            return prayers.filter { $0.isAnswered }.count >= 1
        case "10 Answered Prayers":
            return prayers.filter { $0.isAnswered }.count >= 10
        case "First Mood Check-in":
            return moods.count >= 1
        case "100 Mood Check-ins":
            return moods.count >= 100
        case "First Reading Plan":
            return plans.count >= 1
        case "Completed Reading Plan":
            return plans.filter { $0.isCompleted }.count >= 1
        case "First Bookmark":
            return bookmarks.count >= 1
        case "10 Bookmarks":
            return bookmarks.count >= 10
        case "First Highlight":
            return highlights.count >= 1
        case "10 Highlights":
            return highlights.count >= 10
        case "First Note":
            return notes.count >= 1
        case "10 Notes":
            return notes.count >= 10
        default:
            return false
        }
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
    
    func getDefaultAchievements() -> [StatisticAchievement] {
        return [
            StatisticAchievement(title: "First Entry", description: "Create your first journal entry", icon: "📝", category: .milestone, threshold: 1),
            StatisticAchievement(title: "10 Entries", description: "Write 10 journal entries", icon: "📖", category: .milestone, threshold: 10),
            StatisticAchievement(title: "50 Entries", description: "Write 50 journal entries", icon: "📚", category: .milestone, threshold: 50),
            StatisticAchievement(title: "100 Entries", description: "Write 100 journal entries", icon: "🎉", category: .milestone, threshold: 100),
            StatisticAchievement(title: "500 Entries", description: "Write 500 journal entries", icon: "🌟", category: .milestone, threshold: 500),
            StatisticAchievement(title: "1000 Entries", description: "Write 1000 journal entries", icon: "👑", category: .milestone, threshold: 1000),
            StatisticAchievement(title: "7 Day Streak", description: "Journal for 7 consecutive days", icon: "🔥", category: .streak, threshold: 7),
            StatisticAchievement(title: "30 Day Streak", description: "Journal for 30 consecutive days", icon: "⭐", category: .streak, threshold: 30),
            StatisticAchievement(title: "100 Day Streak", description: "Journal for 100 consecutive days", icon: "💎", category: .streak, threshold: 100),
            StatisticAchievement(title: "First Prayer", description: "Create your first prayer request", icon: "🙏", category: .milestone, threshold: 1),
            StatisticAchievement(title: "10 Prayers", description: "Create 10 prayer requests", icon: "💒", category: .milestone, threshold: 10),
            StatisticAchievement(title: "50 Prayers", description: "Create 50 prayer requests", icon: "⛪", category: .milestone, threshold: 50),
            StatisticAchievement(title: "First Answered Prayer", description: "Mark your first prayer as answered", icon: "✨", category: .milestone, threshold: 1),
            StatisticAchievement(title: "10 Answered Prayers", description: "Have 10 prayers answered", icon: "🎊", category: .milestone, threshold: 10),
            StatisticAchievement(title: "First Mood Check-in", description: "Track your first mood", icon: "😊", category: .milestone, threshold: 1),
            StatisticAchievement(title: "100 Mood Check-ins", description: "Track your mood 100 times", icon: "📊", category: .milestone, threshold: 100),
            StatisticAchievement(title: "First Reading Plan", description: "Start your first reading plan", icon: "📖", category: .milestone, threshold: 1),
            StatisticAchievement(title: "Completed Reading Plan", description: "Complete a reading plan", icon: "✅", category: .milestone, threshold: 1),
            StatisticAchievement(title: "First Bookmark", description: "Bookmark your first verse", icon: "🔖", category: .milestone, threshold: 1),
            StatisticAchievement(title: "10 Bookmarks", description: "Bookmark 10 verses", icon: "📑", category: .milestone, threshold: 10),
            StatisticAchievement(title: "First Highlight", description: "Highlight your first verse", icon: "🖍️", category: .milestone, threshold: 1),
            StatisticAchievement(title: "10 Highlights", description: "Highlight 10 verses", icon: "🖊️", category: .milestone, threshold: 10),
            StatisticAchievement(title: "First Note", description: "Create your first Bible note", icon: "📝", category: .milestone, threshold: 1),
            StatisticAchievement(title: "10 Notes", description: "Create 10 Bible notes", icon: "📋", category: .milestone, threshold: 10)
        ]
    }
}

