//
//  StatisticAchievement.swift
//  Faith Journal
//
//  Statistics achievement model
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class StatisticAchievement {
    var id: UUID = UUID()
    var title: String = ""
    var achievementDescription: String = ""
    var icon: String = "🏆"
    var category: AchievementCategory = StatisticAchievement.AchievementCategory.milestone
    var unlockedDate: Date?
    var isUnlocked: Bool = false
    var threshold: Int = 0
    var currentProgress: Int = 0
    
    enum AchievementCategory: String, CaseIterable, Codable {
        case milestone = "Milestone"
        case streak = "Streak"
        case consistency = "Consistency"
        case growth = "Growth"
        case special = "Special"
    }
    
    init(title: String, description: String, icon: String = "🏆", category: AchievementCategory = .milestone, threshold: Int = 0) {
        self.id = UUID()
        self.title = title
        self.achievementDescription = description
        self.icon = icon
        self.category = category
        self.threshold = threshold
        self.isUnlocked = false
        self.currentProgress = 0
    }
}

