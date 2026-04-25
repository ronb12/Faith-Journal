//
//  MoodGoal.swift
//  Faith Journal
//
//  Mood goals model
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class MoodGoal {
    var id: UUID = UUID()
    var title: String = ""
    var goalDescription: String = ""
    var targetMood: Int = 7 // Target average mood (1-10)
    var targetDate: Date?
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedDate: Date?
    var progress: Double = 0.0 // 0.0 to 1.0
    
    init(title: String, description: String, targetMood: Int = 7, targetDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.goalDescription = description
        self.targetMood = max(1, min(10, targetMood))
        self.targetDate = targetDate
        self.isCompleted = false
        self.createdAt = Date()
        self.progress = 0.0
    }
}

@available(iOS 17.0, *)
@Model
final class MoodAchievement {
    var id: UUID = UUID()
    var title: String = ""
    var goalDescription: String = ""
    var icon: String = "🏆"
    var unlockedDate: Date?
    var isUnlocked: Bool = false
    var category: AchievementCategory = MoodAchievement.AchievementCategory.consistency
    
    enum AchievementCategory: String, CaseIterable, Codable {
        case consistency = "Consistency"
        case streak = "Streak"
        case improvement = "Improvement"
        case milestone = "Milestone"
        case special = "Special"
    }
    
    init(title: String, description: String, icon: String = "🏆", category: AchievementCategory = .consistency) {
        self.id = UUID()
        self.title = title
        self.goalDescription = description
        self.icon = icon
        self.category = category
        self.isUnlocked = false
    }
}
