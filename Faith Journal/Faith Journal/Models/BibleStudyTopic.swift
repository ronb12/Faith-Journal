//
//  BibleStudyTopic.swift
//  Faith Journal
//
//  Bible study topics model
//

import Foundation
import SwiftData

@Model
final class BibleStudyTopic {
    var id: UUID = UUID()
    var title: String = ""
    var topicDescription: String = "" // Renamed from 'description' to avoid conflict with NSObject.description
    var category: TopicCategory = BibleStudyTopic.TopicCategory.general
    var keyVerses: [String] = [] // Verse references like "John 3:16"
    var verseTexts: [String] = [] // Full verse texts
    var studyQuestions: [String] = []
    var questionAnswers: [String] = [] // Answers to study questions (indexed to match studyQuestions)
    var discussionPrompts: [String] = []
    var discussionAnswers: [String] = [] // Answers to discussion prompts (indexed to match discussionPrompts)
    var applicationPoints: [String] = []
    var relatedTopics: [String] = []
    var createdAt: Date = Date()
    var isCompleted: Bool = false
    var completedDate: Date?
    var isFavorite: Bool = false
    var lastViewedDate: Date?
    var notes: String = ""
    
    enum TopicCategory: String, CaseIterable, Codable {
        case faith = "Faith"
        case prayer = "Prayer"
        case love = "Love"
        case forgiveness = "Forgiveness"
        case hope = "Hope"
        case service = "Service"
        case worship = "Worship"
        case obedience = "Obedience"
        case trust = "Trust"
        case grace = "Grace"
        case peace = "Peace"
        case joy = "Joy"
        case wisdom = "Wisdom"
        case courage = "Courage"
        case patience = "Patience"
        case gratitude = "Gratitude"
        case salvation = "Salvation"
        case character = "Character"
        case relationships = "Relationships"
        case trials = "Trials"
        case general = "General"
    }
    
    init(
        title: String,
        description: String,
        category: TopicCategory,
        keyVerses: [String] = [],
        verseTexts: [String] = [],
        studyQuestions: [String] = [],
        discussionPrompts: [String] = [],
        applicationPoints: [String] = [],
        relatedTopics: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.topicDescription = description
        self.category = category
        self.keyVerses = keyVerses
        self.verseTexts = verseTexts
        self.studyQuestions = studyQuestions
        self.discussionPrompts = discussionPrompts
        self.applicationPoints = applicationPoints
        self.relatedTopics = relatedTopics
        self.createdAt = Date()
        self.isCompleted = false
    }
}

