//
//  JournalPrompt.swift
//  Faith Journal
//
//  Guided journal prompts model
//

import Foundation
import SwiftData

@Model
final class JournalPrompt {
    var id: UUID = UUID()
    var promptText: String = ""
    var category: PromptCategory = JournalPrompt.PromptCategory.general
    var isCustom: Bool = false
    var createdAt: Date = Date()
    var lastUsed: Date?
    var timesUsed: Int = 0
    var isFavorite: Bool = false
    
    enum PromptCategory: String, CaseIterable, Codable {
        case gratitude = "Gratitude"
        case prayer = "Prayer"
        case scripture = "Scripture"
        case growth = "Growth"
        case challenges = "Challenges"
        case reflection = "Reflection"
        case relationships = "Relationships"
        case service = "Service"
        case morning = "Morning"
        case evening = "Evening"
        case general = "General"
    }
    
    init(promptText: String, category: PromptCategory, isCustom: Bool = false) {
        self.id = UUID()
        self.promptText = promptText
        self.category = category
        self.isCustom = isCustom
        self.createdAt = Date()
        self.timesUsed = 0
        self.isFavorite = false
    }
}

