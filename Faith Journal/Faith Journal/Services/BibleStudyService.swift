//
//  BibleStudyService.swift
//  Faith Journal
//
//  Manages Bible study topics library - 365 topics (one for each day of the year)
//

import Foundation
import SwiftUI

@MainActor
class BibleStudyService: ObservableObject {
    static let shared = BibleStudyService()
    
    @Published var dailyTopic: BibleStudyTopic?
    @Published var favoriteTopics: [BibleStudyTopic] = []
    
    private let topicLibrary: [BibleStudyTopic]
    private let calendar = Calendar.current
    private let bibleService = BibleService.shared
    
    // Stored topics (from SwiftData) - user's saved progress
    private var storedTopics: [BibleStudyTopic] = []
    
    private init() {
        // Initialize with 365 topics across categories
        topicLibrary = BibleStudyService.createTopicLibrary()
        loadDailyTopic()
        loadFavorites()
    }
    
    // Set stored topics from SwiftData
    func setStoredTopics(_ topics: [BibleStudyTopic]) {
        storedTopics = topics
        loadFavorites()
    }
    
    // Get all topics (merged with stored data)
    func getAllTopics() -> [BibleStudyTopic] {
        // Merge with stored topics to preserve user progress
        let merged = topicLibrary.map { topic -> BibleStudyTopic in
            // Check if this topic has stored data
            if let stored = storedTopics.first(where: { $0.id == topic.id || $0.title == topic.title }) {
                // Merge stored data (favorites, completion, answers, notes)
                topic.isFavorite = stored.isFavorite
                topic.isCompleted = stored.isCompleted
                topic.completedDate = stored.completedDate
                topic.lastViewedDate = stored.lastViewedDate
                topic.questionAnswers = stored.questionAnswers
                topic.discussionAnswers = stored.discussionAnswers
                topic.notes = stored.notes
            }
            return topic
        }
        return merged
    }
    
    // Get today's topic based on day of year (1-365)
    func getDailyTopic() -> BibleStudyTopic {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return getTopicForDay(dayOfYear)
    }
    
    // Get topic by day of year (1-365)
    func getTopicForDay(_ day: Int) -> BibleStudyTopic {
        let index = (day - 1) % topicLibrary.count
        return topicLibrary[index]
    }
    
    // Get topics by category
    func getTopics(for category: BibleStudyTopic.TopicCategory) -> [BibleStudyTopic] {
        return getAllTopics().filter { $0.category == category }
    }
    
    // Enhanced search - includes verses, questions, and application points
    func searchTopics(query: String) -> [BibleStudyTopic] {
        let lowerQuery = query.lowercased()
        return getAllTopics().filter { topic in
            // Search in title, description, category
            topic.title.lowercased().contains(lowerQuery) ||
            topic.topicDescription.lowercased().contains(lowerQuery) ||
            topic.category.rawValue.lowercased().contains(lowerQuery) ||
            // Search in verses
            topic.keyVerses.contains { $0.lowercased().contains(lowerQuery) } ||
            topic.verseTexts.contains { $0.lowercased().contains(lowerQuery) } ||
            // Search in questions
            topic.studyQuestions.contains { $0.lowercased().contains(lowerQuery) } ||
            // Search in application points
            topic.applicationPoints.contains { $0.lowercased().contains(lowerQuery) }
        }
    }
    
    // Get favorite topics
    func getFavoriteTopics() -> [BibleStudyTopic] {
        return getAllTopics().filter { $0.isFavorite }
    }
    
    // Get recently viewed topics
    func getRecentTopics(limit: Int = 10) -> [BibleStudyTopic] {
        return getAllTopics()
            .filter { $0.lastViewedDate != nil }
            .sorted { ($0.lastViewedDate ?? Date.distantPast) > ($1.lastViewedDate ?? Date.distantPast) }
            .prefix(limit)
            .map { $0 }
    }
    
    // Get completed topics
    func getCompletedTopics() -> [BibleStudyTopic] {
        return getAllTopics().filter { $0.isCompleted }
    }
    
    // Get progress statistics
    func getProgressStats() -> (total: Int, completed: Int, favorites: Int, percentComplete: Double) {
        let all = getAllTopics()
        let completed = all.filter { $0.isCompleted }.count
        let favorites = all.filter { $0.isFavorite }.count
        let percent = all.isEmpty ? 0.0 : Double(completed) / Double(all.count) * 100.0
        return (total: all.count, completed: completed, favorites: favorites, percentComplete: percent)
    }
    
    // Get related topics
    func getRelatedTopics(for topic: BibleStudyTopic, limit: Int = 5) -> [BibleStudyTopic] {
        let all = getAllTopics()
        // Find topics with same category or related topic titles
        var related = all.filter { $0.category == topic.category && $0.id != topic.id }
        
        // Also check if topic has related topic titles defined
        if !topic.relatedTopics.isEmpty {
            for relatedTitle in topic.relatedTopics {
                if let found = all.first(where: { $0.title == relatedTitle && $0.id != topic.id }) {
                    if !related.contains(where: { $0.id == found.id }) {
                        related.append(found)
                    }
                }
            }
        }
        
        return Array(related.prefix(limit))
    }
    
    // Get topics for live session (filtered for Bible Study)
    func getTopicsForLiveSession() -> [BibleStudyTopic] {
        return topicLibrary
    }
    
    // Load daily topic (store and update daily)
    func loadDailyTopic() {
        let lastTopicDate = UserDefaults.standard.object(forKey: "lastDailyTopicDate") as? Date
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastTopicDate,
           calendar.startOfDay(for: lastDate) == today {
            // Same day, use stored topic
            if let storedTopicData = UserDefaults.standard.data(forKey: "dailyTopic"),
               let topic = try? JSONDecoder().decode(StoredTopic.self, from: storedTopicData) {
                dailyTopic = createTopicFromStored(topic)
            }
        } else {
            // New day, generate new topic based on day of year
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
            dailyTopic = getTopicForDay(dayOfYear)
            saveDailyTopic()
        }
    }
    
    private func saveDailyTopic() {
        guard let topic = dailyTopic else { return }
        
        let stored = StoredTopic(
            title: topic.title,
            description: topic.topicDescription,
            category: topic.category,
            keyVerses: topic.keyVerses,
            verseTexts: topic.verseTexts,
            studyQuestions: topic.studyQuestions,
            discussionPrompts: topic.discussionPrompts,
            applicationPoints: topic.applicationPoints
        )
        
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: "dailyTopic")
            UserDefaults.standard.set(Date(), forKey: "lastDailyTopicDate")
        }
    }
    
    private func createTopicFromStored(_ stored: StoredTopic) -> BibleStudyTopic {
        return BibleStudyTopic(
            title: stored.title,
            description: stored.description,
            category: stored.category,
            keyVerses: stored.keyVerses,
            verseTexts: stored.verseTexts,
            studyQuestions: stored.studyQuestions,
            discussionPrompts: stored.discussionPrompts,
            applicationPoints: stored.applicationPoints
        )
    }
    
    func loadFavorites() {
        favoriteTopics = getAllTopics().filter { $0.isFavorite }
    }
    
    func toggleFavorite(_ topic: BibleStudyTopic) {
        topic.isFavorite.toggle()
        loadFavorites()
    }
    
    func markAsViewed(_ topic: BibleStudyTopic) {
        topic.lastViewedDate = Date()
    }
    
    func toggleCompletion(_ topic: BibleStudyTopic) {
        topic.isCompleted.toggle()
        if topic.isCompleted {
            topic.completedDate = Date()
        } else {
            topic.completedDate = nil
        }
    }
    
    func updateQuestionAnswer(_ topic: BibleStudyTopic, questionIndex: Int, answer: String) {
        // Ensure questionAnswers array is properly sized
        while topic.questionAnswers.count < topic.studyQuestions.count {
            topic.questionAnswers.append("")
        }
        if questionIndex >= 0 && questionIndex < topic.studyQuestions.count {
            topic.questionAnswers[questionIndex] = answer
        }
    }
    
    func getQuestionAnswer(_ topic: BibleStudyTopic, questionIndex: Int) -> String {
        if questionIndex >= 0 && questionIndex < topic.questionAnswers.count {
            return topic.questionAnswers[questionIndex]
        }
        return ""
    }
    
    func updateDiscussionAnswer(_ topic: BibleStudyTopic, promptIndex: Int, answer: String) {
        // Ensure discussionAnswers array is properly sized
        while topic.discussionAnswers.count < topic.discussionPrompts.count {
            topic.discussionAnswers.append("")
        }
        if promptIndex >= 0 && promptIndex < topic.discussionPrompts.count {
            topic.discussionAnswers[promptIndex] = answer
        }
    }
    
    func getDiscussionAnswer(_ topic: BibleStudyTopic, promptIndex: Int) -> String {
        if promptIndex >= 0 && promptIndex < topic.discussionAnswers.count {
            return topic.discussionAnswers[promptIndex]
        }
        return ""
    }
    
    // Create topic library with 365 topics (one for each day of the year)
    private static func createTopicLibrary() -> [BibleStudyTopic] {
        var topics: [BibleStudyTopic] = []
        
        // Helper function to get verse text from local database
        func getVerseText(_ reference: String) -> String {
            let verse = BibleService.shared.getLocalVerse(reference: reference)
            return verse?.text ?? ""
        }
        
        // === FAITH TOPICS (35 topics) ===
        topics.append(contentsOf: [
            BibleStudyTopic(
                title: "What is Faith?",
                description: "Understanding the definition and nature of biblical faith.",
                category: .faith,
                keyVerses: ["Hebrews 11:1", "Ephesians 2:8-9", "Romans 10:17"],
                verseTexts: [getVerseText("Hebrews 11:1"), getVerseText("Ephesians 2:8-9"), getVerseText("Romans 10:17")],
                studyQuestions: ["How does the Bible define faith?", "How is faith different from belief?", "How does faith come to us?"],
                discussionPrompts: ["Share a time when you had to step out in faith.", "How does faith change how you live?", "What obstacles to faith have you faced?"],
                applicationPoints: ["Faith is trust in God's promises.", "Faith is a gift from God, not earned.", "Faith grows through hearing God's Word."]
            ),
            BibleStudyTopic(
                title: "Faith in Action",
                description: "How faith produces works and practical outcomes in our lives.",
                category: .faith,
                keyVerses: ["James 2:14-26", "Hebrews 11:6", "Matthew 17:20"],
                verseTexts: [getVerseText("James 2:14-26"), getVerseText("Hebrews 11:6"), getVerseText("Matthew 17:20")],
                studyQuestions: ["How does faith express itself through actions?", "What does 'faith without works is dead' mean?", "How can you demonstrate your faith today?"],
                discussionPrompts: ["How has your faith led you to action?", "What works has God prepared for you?", "How do faith and works work together?"],
                applicationPoints: ["True faith produces good works.", "Faith without action is incomplete.", "Our actions demonstrate our faith."]
            ),
            BibleStudyTopic(
                title: "Growing in Faith",
                description: "How to develop and strengthen your faith in God.",
                category: .faith,
                keyVerses: ["Romans 10:17", "2 Thessalonians 1:3", "Luke 17:5"],
                verseTexts: [getVerseText("Romans 10:17"), getVerseText("2 Thessalonians 1:3"), getVerseText("Luke 17:5")],
                studyQuestions: ["How does faith grow?", "What spiritual disciplines strengthen faith?", "How can you pray for increased faith?"],
                discussionPrompts: ["What has helped your faith grow?", "How has your faith changed over time?", "What do you need faith for right now?"],
                applicationPoints: ["Faith grows through hearing God's Word.", "Prayer and study strengthen faith.", "Faith increases through testing and trials."]
            ),
            BibleStudyTopic(
                title: "Faith in Trials",
                description: "Trusting God when circumstances are difficult.",
                category: .faith,
                keyVerses: ["1 Peter 1:6-7", "James 1:2-4", "Romans 5:3-5"],
                verseTexts: [getVerseText("1 Peter 1:6-7"), getVerseText("James 1:2-4"), getVerseText("Romans 5:3-5")],
                studyQuestions: ["How do trials test and strengthen faith?", "Why does God allow suffering?", "How can we maintain faith during hard times?"],
                discussionPrompts: ["Share how a trial strengthened your faith.", "How do you trust God in uncertainty?", "What trial requires faith right now?"],
                applicationPoints: ["Trials test and refine our faith.", "Suffering produces perseverance and character.", "God uses trials to grow us."]
            ),
            BibleStudyTopic(
                title: "Faith and Doubt",
                description: "Understanding the relationship between faith and doubt.",
                category: .faith,
                keyVerses: ["Mark 9:24", "Matthew 28:17", "John 20:24-29"],
                verseTexts: [getVerseText("Mark 9:24"), getVerseText("Matthew 28:17"), getVerseText("John 20:24-29")],
                studyQuestions: ["Is it okay to have doubts?", "How do biblical characters handle doubt?", "How can we move from doubt to faith?"],
                discussionPrompts: ["When have you experienced doubt?", "How has God helped you through doubt?", "What questions about faith do you have?"],
                applicationPoints: ["Doubt can coexist with faith.", "Bring your doubts to God honestly.", "Faith grows as we seek answers."]
            )
        ])
        
        // Generate comprehensive 365 topics programmatically
        // Using topic templates and variations to cover all categories
        
        // Define topics per category to total 365
        let topicCategories: [(category: BibleStudyTopic.TopicCategory, count: Int)] = [
            (.faith, 35),
            (.prayer, 40),
            (.love, 40),
            (.forgiveness, 25),
            (.hope, 25),
            (.service, 25),
            (.worship, 25),
            (.obedience, 25),
            (.trust, 20),
            (.grace, 20),
            (.peace, 20),
            (.joy, 20),
            (.wisdom, 20),
            (.courage, 20),
            (.patience, 20),
            (.gratitude, 20),
            (.salvation, 15),
            (.character, 15),
            (.relationships, 15),
            (.trials, 15),
            (.general, 15)
        ]
        
        // Generate topics for each category
        for (category, count) in topicCategories {
            let templates = getTopicTemplatesForCategory(category)
            
            for i in 0..<count {
                // Use templates with variations based on index
                let templateIndex = i % templates.count
                let template = templates[templateIndex]
                
                // Create variation by adding index if multiple iterations
                let variation = i >= templates.count ? " (Part \(i / templates.count + 2))" : ""
                let title = template.title + variation
                
                let topic = BibleStudyTopic(
                    title: title,
                    description: template.description,
                    category: category,
                    keyVerses: template.keyVerses,
                    verseTexts: template.verseTexts,
                    studyQuestions: template.studyQuestions,
                    discussionPrompts: template.discussionPrompts,
                    applicationPoints: template.applicationPoints
                )
                topics.append(topic)
            }
        }
        
        return Array(topics.prefix(365))
    }
    
    
    // Helper to get verse text from BibleService
    private static func getVerseText(_ reference: String) -> String {
        return BibleService.shared.getLocalVerse(reference: reference)?.text ?? ""
    }
    
    // Helper function to generate comprehensive topic templates for each category
    private static func getTopicTemplatesForCategory(_ category: BibleStudyTopic.TopicCategory) -> [TopicTemplate] {
        let baseTemplates = getBaseTopicTemplatesForCategory(category)
        var templates: [TopicTemplate] = []
        
        // Create multiple variations for each base template
        for (_, base) in baseTemplates.enumerated() {
            // Create 5-7 variations of each base template
            for variation in 0..<min(7, 365 / (baseTemplates.count * 5) + 1) {
                let titleVariations = generateTitleVariations(base.title, variation: variation)
                let questionVariations = generateQuestionVariations(base.studyQuestions, variation: variation)
                let promptVariations = generatePromptVariations(base.discussionPrompts, variation: variation)
                
                templates.append(TopicTemplate(
                    title: titleVariations,
                    description: base.description,
                    keyVerses: base.keyVerses,
                    verseTexts: base.verseTexts,
                    studyQuestions: questionVariations,
                    discussionPrompts: promptVariations,
                    applicationPoints: base.applicationPoints
                ))
            }
        }
        
        return templates.isEmpty ? [getDefaultTemplate(category)] : templates
    }
    
    // Generate variations for titles, questions, and prompts
    private static func generateTitleVariations(_ base: String, variation: Int) -> String {
        if variation == 0 { return base }
        let suffixes = ["- Part 2", "- Continued", "- Advanced", "- Deep Dive", "- Application", "- Personal Reflection", "- Group Discussion"]
        return base + (suffixes[variation % suffixes.count])
    }
    
    private static func generateQuestionVariations(_ base: [String], variation: Int) -> [String] {
        var questions = base
        if variation > 0 {
            questions.append("How does this apply to your life today?")
            questions.append("What specific action can you take based on this?")
        }
        return questions
    }
    
    private static func generatePromptVariations(_ base: [String], variation: Int) -> [String] {
        var prompts = base
        if variation > 0 {
            prompts.append("How can you apply this in your relationships?")
            prompts.append("What does this mean for your daily walk with God?")
        }
        return prompts
    }
    
    // Base templates for each category - comprehensive foundational topics
    private static func getBaseTopicTemplatesForCategory(_ category: BibleStudyTopic.TopicCategory) -> [TopicTemplate] {
        switch category {
        case .faith:
            return getFaithBaseTemplates()
        case .prayer:
            return getPrayerBaseTemplates()
        case .love:
            return getLoveBaseTemplates()
        case .forgiveness:
            return getForgivenessBaseTemplates()
        case .hope:
            return getHopeBaseTemplates()
        case .service:
            return getServiceBaseTemplates()
        case .worship:
            return getWorshipBaseTemplates()
        case .obedience:
            return getObedienceBaseTemplates()
        case .trust:
            return getTrustBaseTemplates()
        case .grace:
            return getGraceBaseTemplates()
        case .peace:
            return getPeaceBaseTemplates()
        case .joy:
            return getJoyBaseTemplates()
        case .wisdom:
            return getWisdomBaseTemplates()
        case .courage:
            return getCourageBaseTemplates()
        case .patience:
            return getPatienceBaseTemplates()
        case .gratitude:
            return getGratitudeBaseTemplates()
        case .salvation:
            return getSalvationBaseTemplates()
        case .character:
            return getCharacterBaseTemplates()
        case .relationships:
            return getRelationshipsBaseTemplates()
        case .trials:
            return getTrialsBaseTemplates()
        case .general:
            return getGeneralBaseTemplates()
        }
    }
    
    // Default template generator for categories without specific templates
    private static func getDefaultTemplate(_ category: BibleStudyTopic.TopicCategory) -> TopicTemplate {
        return TopicTemplate(
            title: "Understanding \(category.rawValue)",
            description: "A study on \(category.rawValue.lowercased()) from a biblical perspective.",
            keyVerses: ["John 3:16", "Romans 8:28", "Philippians 4:13"],
            verseTexts: [getVerseText("John 3:16"), getVerseText("Romans 8:28"), getVerseText("Philippians 4:13")],
            studyQuestions: ["What does the Bible say about \(category.rawValue.lowercased())?", "How can you apply this to your life?", "What examples do you see in Scripture?"],
            discussionPrompts: ["How does \(category.rawValue.lowercased()) impact your faith?", "Share an experience related to \(category.rawValue.lowercased())."],
            applicationPoints: ["Apply biblical principles of \(category.rawValue.lowercased()) daily.", "Seek God's guidance in this area."]
        )
    }
    
    // Faith base templates
    private static func getFaithBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "What is Faith?",
                description: "Understanding the definition and nature of biblical faith.",
                keyVerses: ["Hebrews 11:1", "Ephesians 2:8-9", "Romans 10:17"],
                verseTexts: [getVerseText("Hebrews 11:1"), getVerseText("Ephesians 2:8-9"), getVerseText("Romans 10:17")],
                studyQuestions: ["How does the Bible define faith?", "How is faith different from belief?", "How does faith come to us?"],
                discussionPrompts: ["Share a time when you had to step out in faith.", "How does faith change how you live?"],
                applicationPoints: ["Faith is trust in God's promises.", "Faith is a gift from God.", "Faith grows through God's Word."]
            ),
            TopicTemplate(
                title: "Faith in Action",
                description: "How faith produces works and practical outcomes.",
                keyVerses: ["James 2:14-26", "Hebrews 11:6", "Matthew 17:20"],
                verseTexts: [getVerseText("James 2:14-26"), getVerseText("Hebrews 11:6"), getVerseText("Matthew 17:20")],
                studyQuestions: ["How does faith express itself through actions?", "What does 'faith without works is dead' mean?"],
                discussionPrompts: ["How has your faith led you to action?", "What works has God prepared for you?"],
                applicationPoints: ["True faith produces good works.", "Our actions demonstrate our faith."]
            ),
            TopicTemplate(
                title: "Growing in Faith",
                description: "How to develop and strengthen your faith in God.",
                keyVerses: ["Romans 10:17", "2 Thessalonians 1:3", "Luke 17:5"],
                verseTexts: [getVerseText("Romans 10:17"), getVerseText("2 Thessalonians 1:3"), getVerseText("Luke 17:5")],
                studyQuestions: ["How does faith grow?", "What spiritual disciplines strengthen faith?"],
                discussionPrompts: ["What has helped your faith grow?", "How has your faith changed over time?"],
                applicationPoints: ["Faith grows through hearing God's Word.", "Prayer strengthens faith."]
            ),
            TopicTemplate(
                title: "Faith in Trials",
                description: "Trusting God when circumstances are difficult.",
                keyVerses: ["1 Peter 1:6-7", "James 1:2-4", "Romans 5:3-5"],
                verseTexts: [getVerseText("1 Peter 1:6-7"), getVerseText("James 1:2-4"), getVerseText("Romans 5:3-5")],
                studyQuestions: ["How do trials test and strengthen faith?", "Why does God allow suffering?"],
                discussionPrompts: ["Share how a trial strengthened your faith.", "How do you trust God in uncertainty?"],
                applicationPoints: ["Trials test and refine our faith.", "Suffering produces perseverance."]
            ),
            TopicTemplate(
                title: "Faith and Doubt",
                description: "Understanding the relationship between faith and doubt.",
                keyVerses: ["Mark 9:24", "Matthew 28:17", "John 20:24-29"],
                verseTexts: [getVerseText("Mark 9:24"), getVerseText("Matthew 28:17"), getVerseText("John 20:24-29")],
                studyQuestions: ["Is it okay to have doubts?", "How do biblical characters handle doubt?"],
                discussionPrompts: ["When have you experienced doubt?", "How has God helped you through doubt?"],
                applicationPoints: ["Doubt can coexist with faith.", "Bring your doubts to God honestly."]
            )
        ]
    }
    
    // Prayer base templates
    private static func getPrayerBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "The Power of Prayer",
                description: "Understanding prayer as communication with God.",
                keyVerses: ["Philippians 4:6-7", "Matthew 21:22", "James 5:16"],
                verseTexts: [getVerseText("Philippians 4:6-7"), getVerseText("Matthew 21:22"), getVerseText("James 5:16")],
                studyQuestions: ["What is prayer?", "Why should we pray?", "How does prayer change things?"],
                discussionPrompts: ["How has prayer impacted your life?", "Share an answered prayer."],
                applicationPoints: ["Prayer is talking with God.", "Prayer changes us and situations."]
            ),
            TopicTemplate(
                title: "How to Pray",
                description: "Learning biblical models and methods of prayer.",
                keyVerses: ["Matthew 6:9-13", "Luke 11:1-4", "1 Thessalonians 5:17"],
                verseTexts: [getVerseText("Matthew 6:9-13"), getVerseText("Luke 11:1-4"), getVerseText("1 Thessalonians 5:17")],
                studyQuestions: ["What is the Lord's Prayer?", "How often should we pray?", "What should we pray about?"],
                discussionPrompts: ["What's your prayer routine?", "How can we pray without ceasing?"],
                applicationPoints: ["Follow Jesus' model of prayer.", "Pray continuously throughout the day."]
            ),
            TopicTemplate(
                title: "Prayer for Others",
                description: "Intercessory prayer and praying for others.",
                keyVerses: ["1 Timothy 2:1", "Ephesians 6:18", "James 5:16"],
                verseTexts: [getVerseText("1 Timothy 2:1"), getVerseText("Ephesians 6:18"), getVerseText("James 5:16")],
                studyQuestions: ["Why pray for others?", "Who should we pray for?", "How does intercessory prayer work?"],
                discussionPrompts: ["Who can you pray for today?", "How has praying for others changed you?"],
                applicationPoints: ["Prayer is a ministry to others.", "God uses our prayers to help others."]
            ),
            TopicTemplate(
                title: "Answered Prayer",
                description: "Understanding God's response to our prayers.",
                keyVerses: ["Matthew 7:7-8", "1 John 5:14-15", "John 15:7"],
                verseTexts: [getVerseText("Matthew 7:7-8"), getVerseText("1 John 5:14-15"), getVerseText("John 15:7")],
                studyQuestions: ["How does God answer prayer?", "Why are some prayers not answered as we expect?", "How do we handle unanswered prayer?"],
                discussionPrompts: ["Share a time God answered prayer.", "How do you trust God's timing?"],
                applicationPoints: ["God answers in His way and time.", "Trust God's wisdom in answers."]
            ),
            TopicTemplate(
                title: "Prayer and Fasting",
                description: "Combining prayer with fasting for deeper spiritual focus.",
                keyVerses: ["Matthew 6:16-18", "Acts 13:2-3", "Isaiah 58:6-8"],
                verseTexts: [getVerseText("Matthew 6:16-18"), getVerseText("Acts 13:2-3"), getVerseText("Isaiah 58:6-8")],
                studyQuestions: ["What is fasting?", "Why fast with prayer?", "How do we fast properly?"],
                discussionPrompts: ["Have you tried fasting?", "What spiritual benefit have you seen?"],
                applicationPoints: ["Fasting deepens prayer focus.", "Fasting is for God's glory, not ours."]
            )
        ]
    }
    
    // Love base templates
    private static func getLoveBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "God's Love for Us",
                description: "Understanding the depth and nature of God's love.",
                keyVerses: ["John 3:16", "Romans 8:38-39", "1 John 4:9-10"],
                verseTexts: [getVerseText("John 3:16"), getVerseText("Romans 8:38-39"), getVerseText("1 John 4:9-10")],
                studyQuestions: ["How does God show His love?", "What does 'God is love' mean?", "How does God's love change us?"],
                discussionPrompts: ["How have you experienced God's love?", "What makes God's love unique?"],
                applicationPoints: ["God's love is unconditional.", "We are loved beyond measure."]
            ),
            TopicTemplate(
                title: "Loving God",
                description: "How to love God with all our heart, soul, and mind.",
                keyVerses: ["Matthew 22:37-38", "Deuteronomy 6:5", "1 John 4:19"],
                verseTexts: [getVerseText("Matthew 22:37-38"), getVerseText("Deuteronomy 6:5"), getVerseText("1 John 4:19")],
                studyQuestions: ["How do we love God?", "What does it mean to love God completely?", "How is love for God demonstrated?"],
                discussionPrompts: ["How do you express love for God?", "What hinders your love for God?"],
                applicationPoints: ["Love God with all your being.", "Our love response to His love."]
            ),
            TopicTemplate(
                title: "Loving Others",
                description: "Biblical love for neighbors, enemies, and everyone.",
                keyVerses: ["Matthew 22:39", "John 13:34-35", "1 Corinthians 13:4-7"],
                verseTexts: [getVerseText("Matthew 22:39"), getVerseText("John 13:34-35"), getVerseText("1 Corinthians 13:4-7")],
                studyQuestions: ["Who should we love?", "How do we love our enemies?", "What is biblical love?"],
                discussionPrompts: ["Who is hardest for you to love?", "How can you love others better?"],
                applicationPoints: ["Love others as yourself.", "Love is an action, not just feeling."]
            ),
            TopicTemplate(
                title: "The Love Chapter",
                description: "Exploring 1 Corinthians 13 - the definition of love.",
                keyVerses: ["1 Corinthians 13:1-13"],
                verseTexts: [getVerseText("1 Corinthians 13:1-13")],
                studyQuestions: ["What are the characteristics of love?", "Why is love the greatest?", "How is love patient and kind?"],
                discussionPrompts: ["Which love characteristic do you need most?", "How does this challenge you?"],
                applicationPoints: ["Love is patient, kind, and enduring.", "Love never fails."]
            ),
            TopicTemplate(
                title: "Love in Action",
                description: "Practical ways to show love to others daily.",
                keyVerses: ["1 John 3:18", "Galatians 5:13-14", "1 Peter 4:8"],
                verseTexts: [getVerseText("1 John 3:18"), getVerseText("Galatians 5:13-14"), getVerseText("1 Peter 4:8")],
                studyQuestions: ["How do we love with actions?", "What practical ways can we show love?", "How does serving show love?"],
                discussionPrompts: ["How have you shown love recently?", "Who needs your love today?"],
                applicationPoints: ["Love in deed and truth.", "Serve others as an act of love."]
            )
        ]
    }
    
    // Forgiveness base templates
    private static func getForgivenessBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "God's Forgiveness",
                description: "Understanding God's forgiveness of our sins.",
                keyVerses: ["1 John 1:9", "Ephesians 1:7", "Psalm 103:12"],
                verseTexts: [getVerseText("1 John 1:9"), getVerseText("Ephesians 1:7"), getVerseText("Psalm 103:12")],
                studyQuestions: ["How does God forgive us?", "What does it mean to be forgiven?", "How do we receive forgiveness?"],
                discussionPrompts: ["How has God's forgiveness changed you?", "What does it mean to be a forgiven sinner?"],
                applicationPoints: ["God forgives when we confess.", "Forgiveness is available to all."]
            ),
            TopicTemplate(
                title: "Forgiving Others",
                description: "Learning to extend forgiveness to those who hurt us.",
                keyVerses: ["Matthew 6:14-15", "Ephesians 4:32", "Colossians 3:13"],
                verseTexts: [getVerseText("Matthew 6:14-15"), getVerseText("Ephesians 4:32"), getVerseText("Colossians 3:13")],
                studyQuestions: ["Why must we forgive others?", "How do we forgive when it's hard?", "What if they don't apologize?"],
                discussionPrompts: ["Who do you need to forgive?", "How has forgiving someone freed you?"],
                applicationPoints: ["Forgive as God forgave us.", "Forgiveness is for our freedom."]
            ),
            TopicTemplate(
                title: "Forgiving Yourself",
                description: "Accepting God's forgiveness and letting go of guilt.",
                keyVerses: ["Romans 8:1", "Philippians 3:13-14", "Isaiah 43:25"],
                verseTexts: [getVerseText("Romans 8:1"), getVerseText("Philippians 3:13-14"), getVerseText("Isaiah 43:25")],
                studyQuestions: ["Why is self-forgiveness important?", "How do we move past guilt?", "What does God say about our past?"],
                discussionPrompts: ["What guilt are you carrying?", "How can you accept God's forgiveness?"],
                applicationPoints: ["There is no condemnation in Christ.", "Let go and move forward."]
            ),
            TopicTemplate(
                title: "Seeking Forgiveness",
                description: "How to ask for forgiveness when we've wronged others.",
                keyVerses: ["Matthew 5:23-24", "James 5:16", "Proverbs 28:13"],
                verseTexts: [getVerseText("Matthew 5:23-24"), getVerseText("James 5:16"), getVerseText("Proverbs 28:13")],
                studyQuestions: ["When should we seek forgiveness?", "How do we ask properly?", "What if they don't forgive us?"],
                discussionPrompts: ["Who do you need to ask forgiveness from?", "How can you make amends?"],
                applicationPoints: ["Seek forgiveness promptly.", "Make restitution when possible."]
            ),
            TopicTemplate(
                title: "The Power of Forgiveness",
                description: "How forgiveness brings freedom and healing.",
                keyVerses: ["Luke 23:34", "Acts 7:60", "2 Corinthians 2:10"],
                verseTexts: [getVerseText("Luke 23:34"), getVerseText("Acts 7:60"), getVerseText("2 Corinthians 2:10")],
                studyQuestions: ["How does forgiveness set us free?", "What happens when we don't forgive?", "How does Jesus model forgiveness?"],
                discussionPrompts: ["How has forgiveness brought you freedom?", "What bitterness do you need to release?"],
                applicationPoints: ["Forgiveness breaks chains.", "Jesus showed ultimate forgiveness."]
            )
        ]
    }
    
    // Hope base templates
    private static func getHopeBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Hope in God",
                description: "Finding hope in God's promises and character.",
                keyVerses: ["Romans 15:13", "Hebrews 6:19", "Psalm 42:11"],
                verseTexts: [getVerseText("Romans 15:13"), getVerseText("Hebrews 6:19"), getVerseText("Psalm 42:11")],
                studyQuestions: ["What is biblical hope?", "Where do we place our hope?", "How is hope different from wishful thinking?"],
                discussionPrompts: ["What gives you hope?", "How does God's character give hope?"],
                applicationPoints: ["Hope is in God alone.", "Hope is confident expectation."]
            ),
            TopicTemplate(
                title: "Hope in Trials",
                description: "Maintaining hope during difficult circumstances.",
                keyVerses: ["Romans 5:3-5", "Hebrews 12:1-2", "Lamentations 3:21-23"],
                verseTexts: [getVerseText("Romans 5:3-5"), getVerseText("Hebrews 12:1-2"), getVerseText("Lamentations 3:21-23")],
                studyQuestions: ["How do we have hope in suffering?", "What does hope produce?", "How does hope help us persevere?"],
                discussionPrompts: ["How do you maintain hope in trials?", "What promise gives you hope?"],
                applicationPoints: ["Hope comes through trials.", "God's mercies are new every morning."]
            ),
            TopicTemplate(
                title: "Eternal Hope",
                description: "Hope beyond this life - our future in Christ.",
                keyVerses: ["Titus 2:13", "1 Peter 1:3-4", "1 Thessalonians 4:13-14"],
                verseTexts: [getVerseText("Titus 2:13"), getVerseText("1 Peter 1:3-4"), getVerseText("1 Thessalonians 4:13-14")],
                studyQuestions: ["What is our eternal hope?", "How does eternity change our perspective?", "What awaits believers?"],
                discussionPrompts: ["How does eternal hope impact your life?", "What are you looking forward to?"],
                applicationPoints: ["Our hope is in heaven.", "This world is temporary."]
            ),
            TopicTemplate(
                title: "Hope for Others",
                description: "Sharing hope with those who are hopeless.",
                keyVerses: ["1 Peter 3:15", "Colossians 1:27", "Romans 10:14-15"],
                verseTexts: [getVerseText("1 Peter 3:15"), getVerseText("Colossians 1:27"), getVerseText("Romans 10:14-15")],
                studyQuestions: ["How do we share hope?", "Who needs hope?", "What message of hope do we have?"],
                discussionPrompts: ["Who can you give hope to?", "How has someone shared hope with you?"],
                applicationPoints: ["We are hope bearers.", "Share the reason for your hope."]
            ),
            TopicTemplate(
                title: "Hope in God's Promises",
                description: "Trusting in God's faithful promises.",
                keyVerses: ["2 Corinthians 1:20", "Hebrews 10:23", "Numbers 23:19"],
                verseTexts: [getVerseText("2 Corinthians 1:20"), getVerseText("Hebrews 10:23"), getVerseText("Numbers 23:19")],
                studyQuestions: ["What promises has God made?", "How do we hold onto promises?", "Why can we trust God's promises?"],
                discussionPrompts: ["Which promise means most to you?", "How do you wait on God's promises?"],
                applicationPoints: ["God keeps His promises.", "All God's promises are yes in Christ."]
            )
        ]
    }
    
    // Service base templates
    private static func getServiceBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Serving God",
                description: "What it means to serve the Lord wholeheartedly.",
                keyVerses: ["Joshua 24:15", "Romans 12:1", "Colossians 3:23-24"],
                verseTexts: [getVerseText("Joshua 24:15"), getVerseText("Romans 12:1"), getVerseText("Colossians 3:23-24")],
                studyQuestions: ["How do we serve God?", "What does wholehearted service look like?", "Why should we serve?"],
                discussionPrompts: ["How are you serving God?", "What hinders your service?"],
                applicationPoints: ["Serve God with all your heart.", "Service is worship."]
            ),
            TopicTemplate(
                title: "Serving Others",
                description: "Following Jesus' example of servanthood.",
                keyVerses: ["Mark 10:45", "John 13:14-15", "Galatians 5:13"],
                verseTexts: [getVerseText("Mark 10:45"), getVerseText("John 13:14-15"), getVerseText("Galatians 5:13")],
                studyQuestions: ["How did Jesus serve?", "Who should we serve?", "What does humble service look like?"],
                discussionPrompts: ["How can you serve others today?", "What gift can you use to serve?"],
                applicationPoints: ["Serve others as Jesus served.", "Service requires humility."]
            ),
            TopicTemplate(
                title: "Using Your Gifts to Serve",
                description: "Discovering and using spiritual gifts to serve.",
                keyVerses: ["1 Peter 4:10", "Romans 12:6-8", "1 Corinthians 12:4-7"],
                verseTexts: [getVerseText("1 Peter 4:10"), getVerseText("Romans 12:6-8"), getVerseText("1 Corinthians 12:4-7")],
                studyQuestions: ["What are spiritual gifts?", "How do we discover our gifts?", "How do gifts serve the body?"],
                discussionPrompts: ["What gifts has God given you?", "How can you use them to serve?"],
                applicationPoints: ["Everyone has gifts to use.", "Use gifts to build others up."]
            ),
            TopicTemplate(
                title: "Serving in the Church",
                description: "How to serve in your local faith community.",
                keyVerses: ["Ephesians 4:11-13", "1 Corinthians 12:12-27", "Hebrews 10:24-25"],
                verseTexts: [getVerseText("Ephesians 4:11-13"), getVerseText("1 Corinthians 12:12-27"), getVerseText("Hebrews 10:24-25")],
                studyQuestions: ["Why serve in the church?", "What needs exist in your church?", "How do we serve without burnout?"],
                discussionPrompts: ["How are you serving your church?", "What ministry can you join?"],
                applicationPoints: ["Church needs everyone to serve.", "Find where God calls you."]
            ),
            TopicTemplate(
                title: "Serving the Needy",
                description: "Caring for the poor, widows, orphans, and marginalized.",
                keyVerses: ["James 1:27", "Matthew 25:35-40", "Proverbs 14:31"],
                verseTexts: [getVerseText("James 1:27"), getVerseText("Matthew 25:35-40"), getVerseText("Proverbs 14:31")],
                studyQuestions: ["Who are the needy?", "Why should we care?", "How can we help practically?"],
                discussionPrompts: ["Who in your community needs help?", "What need breaks your heart?"],
                applicationPoints: ["True religion cares for the needy.", "Serving others is serving Jesus."]
            )
        ]
    }
    
    // Worship base templates
    private static func getWorshipBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "What is Worship?",
                description: "Understanding true biblical worship.",
                keyVerses: ["John 4:23-24", "Romans 12:1", "Psalm 95:6"],
                verseTexts: [getVerseText("John 4:23-24"), getVerseText("Romans 12:1"), getVerseText("Psalm 95:6")],
                studyQuestions: ["How does the Bible define worship?", "What does it mean to worship in spirit and truth?", "Is worship just singing?"],
                discussionPrompts: ["What does worship mean to you?", "How do you worship daily?"],
                applicationPoints: ["Worship is a lifestyle.", "Worship God in spirit and truth."]
            ),
            TopicTemplate(
                title: "Worship Through Music",
                description: "Using music and singing to worship God.",
                keyVerses: ["Psalm 100:1-2", "Ephesians 5:19", "Colossians 3:16"],
                verseTexts: [getVerseText("Psalm 100:1-2"), getVerseText("Ephesians 5:19"), getVerseText("Colossians 3:16")],
                studyQuestions: ["Why do we sing to God?", "How does music help us worship?", "What makes worship music meaningful?"],
                discussionPrompts: ["What songs help you worship?", "How does music connect you to God?"],
                applicationPoints: ["Music is a gift to God.", "Sing praises with thankfulness."]
            ),
            TopicTemplate(
                title: "Daily Worship",
                description: "Making worship part of everyday life.",
                keyVerses: ["1 Corinthians 10:31", "Colossians 3:17", "Psalm 34:1"],
                verseTexts: [getVerseText("1 Corinthians 10:31"), getVerseText("Colossians 3:17"), getVerseText("Psalm 34:1")],
                studyQuestions: ["How do we worship daily?", "Can work be worship?", "What does continual praise look like?"],
                discussionPrompts: ["How can you worship in ordinary moments?", "What activities become worship?"],
                applicationPoints: ["Everything can be worship.", "Do all to God's glory."]
            ),
            TopicTemplate(
                title: "Corporate Worship",
                description: "Worshipping together as the body of Christ.",
                keyVerses: ["Hebrews 10:24-25", "Psalm 34:3", "Acts 2:42-47"],
                verseTexts: [getVerseText("Hebrews 10:24-25"), getVerseText("Psalm 34:3"), getVerseText("Acts 2:42-47")],
                studyQuestions: ["Why worship together?", "How does corporate worship differ?", "What happens when we worship together?"],
                discussionPrompts: ["How has corporate worship impacted you?", "Why is community worship important?"],
                applicationPoints: ["Worship together regularly.", "Encourage one another in worship."]
            ),
            TopicTemplate(
                title: "Worship and Gratitude",
                description: "Connecting worship with thanksgiving.",
                keyVerses: ["Psalm 100:4", "1 Thessalonians 5:18", "Hebrews 13:15"],
                verseTexts: [getVerseText("Psalm 100:4"), getVerseText("1 Thessalonians 5:18"), getVerseText("Hebrews 13:15")],
                studyQuestions: ["How are worship and gratitude connected?", "Why be grateful in all circumstances?", "How does thankfulness change worship?"],
                discussionPrompts: ["What are you grateful for today?", "How does gratitude lead to worship?"],
                applicationPoints: ["Enter with thanksgiving.", "Gratitude is a form of worship."]
            )
        ]
    }
    
    // Obedience base templates
    private static func getObedienceBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "The Importance of Obedience",
                description: "Why obedience to God matters.",
                keyVerses: ["1 Samuel 15:22", "John 14:15", "Deuteronomy 28:1-2"],
                verseTexts: [getVerseText("1 Samuel 15:22"), getVerseText("John 14:15"), getVerseText("Deuteronomy 28:1-2")],
                studyQuestions: ["Why is obedience important?", "How does obedience show love?", "What are the benefits of obedience?"],
                discussionPrompts: ["When is obedience difficult?", "How has obedience blessed you?"],
                applicationPoints: ["Obedience is better than sacrifice.", "Obedience shows our love for God."]
            ),
            TopicTemplate(
                title: "Obedience in Small Things",
                description: "Faithfulness in little leads to faithfulness in much.",
                keyVerses: ["Luke 16:10", "Matthew 25:21", "Proverbs 3:27"],
                verseTexts: [getVerseText("Luke 16:10"), getVerseText("Matthew 25:21"), getVerseText("Proverbs 3:27")],
                studyQuestions: ["Why do small things matter?", "How does faithfulness in little things prepare us?", "What small act of obedience can you do?"],
                discussionPrompts: ["What small thing is God asking you to do?", "How do you stay faithful in routine?"],
                applicationPoints: ["Be faithful in small things.", "Faithfulness leads to more responsibility."]
            ),
            TopicTemplate(
                title: "Cost of Obedience",
                description: "Understanding that obedience sometimes comes at a price.",
                keyVerses: ["Luke 9:23", "Acts 5:29", "Matthew 16:24-25"],
                verseTexts: [getVerseText("Luke 9:23"), getVerseText("Acts 5:29"), getVerseText("Matthew 16:24-25")],
                studyQuestions: ["When does obedience cost us?", "Why obey when it's difficult?", "What did obedience cost Jesus?"],
                discussionPrompts: ["When has obedience been costly for you?", "How do you obey despite the cost?"],
                applicationPoints: ["Obedience may require sacrifice.", "The reward outweighs the cost."]
            ),
            TopicTemplate(
                title: "Delayed Obedience",
                description: "The danger of putting off what God asks us to do.",
                keyVerses: ["Hebrews 3:15", "James 4:17", "Luke 9:59-62"],
                verseTexts: [getVerseText("Hebrews 3:15"), getVerseText("James 4:17"), getVerseText("Luke 9:59-62")],
                studyQuestions: ["Why do we delay obedience?", "What are the consequences of delay?", "How do we overcome procrastination?"],
                discussionPrompts: ["What have you been putting off?", "What keeps you from obeying immediately?"],
                applicationPoints: ["Obedey promptly.", "Today is the day of salvation."]
            ),
            TopicTemplate(
                title: "Joy in Obedience",
                description: "Finding joy when we follow God's commands.",
                keyVerses: ["John 15:10-11", "Psalm 119:35", "1 John 5:3"],
                verseTexts: [getVerseText("John 15:10-11"), getVerseText("Psalm 119:35"), getVerseText("1 John 5:3")],
                studyQuestions: ["How does obedience bring joy?", "Why are God's commands not burdensome?", "What joy comes from following God?"],
                discussionPrompts: ["When have you found joy in obeying?", "How does obedience connect to joy?"],
                applicationPoints: ["God's commands lead to joy.", "Complete joy comes through obedience."]
            )
        ]
    }
    
    // Trust base templates
    private static func getTrustBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Trusting God Completely",
                description: "What it means to trust God with our whole lives.",
                keyVerses: ["Proverbs 3:5-6", "Psalm 37:5", "Isaiah 26:3-4"],
                verseTexts: [getVerseText("Proverbs 3:5-6"), getVerseText("Psalm 37:5"), getVerseText("Isaiah 26:3-4")],
                studyQuestions: ["What does it mean to trust God?", "How do we trust with all our heart?", "What does it mean to lean not on understanding?"],
                discussionPrompts: ["What area needs more trust?", "How do you build trust in God?"],
                applicationPoints: ["Trust God completely.", "Don't rely on your understanding."]
            ),
            TopicTemplate(
                title: "Trust in Difficult Times",
                description: "Maintaining trust when circumstances are hard.",
                keyVerses: ["Psalm 56:3", "Nahum 1:7", "Psalm 9:10"],
                verseTexts: [getVerseText("Psalm 56:3"), getVerseText("Nahum 1:7"), getVerseText("Psalm 9:10")],
                studyQuestions: ["How do we trust when it's hard?", "Why trust God in suffering?", "What helps us maintain trust?"],
                discussionPrompts: ["When has trusting been difficult?", "How do you trust despite circumstances?"],
                applicationPoints: ["Trust God especially in trials.", "God is a refuge in trouble."]
            ),
            TopicTemplate(
                title: "Trusting God's Plan",
                description: "Believing God has a good plan even when we can't see it.",
                keyVerses: ["Jeremiah 29:11", "Romans 8:28", "Isaiah 55:8-9"],
                verseTexts: [getVerseText("Jeremiah 29:11"), getVerseText("Romans 8:28"), getVerseText("Isaiah 55:8-9")],
                studyQuestions: ["Does God have a plan?", "How do we trust when plans change?", "How do God's ways differ from ours?"],
                discussionPrompts: ["How has God's plan surprised you?", "What plan are you trusting God with?"],
                applicationPoints: ["God's plans are good.", "Trust His timing and ways."]
            ),
            TopicTemplate(
                title: "Trust vs. Fear",
                description: "Choosing to trust instead of being controlled by fear.",
                keyVerses: ["Isaiah 41:10", "Psalm 56:3-4", "2 Timothy 1:7"],
                verseTexts: [getVerseText("Isaiah 41:10"), getVerseText("Psalm 56:3-4"), getVerseText("2 Timothy 1:7")],
                studyQuestions: ["How do fear and trust conflict?", "What are you afraid of?", "How does trust overcome fear?"],
                discussionPrompts: ["What fear do you need to release?", "How can you choose trust over fear?"],
                applicationPoints: ["Trust drives out fear.", "Don't be afraid - God is with you."]
            ),
            TopicTemplate(
                title: "Building Trust",
                description: "How trust in God develops and grows over time.",
                keyVerses: ["Psalm 28:7", "Psalm 31:14", "Isaiah 12:2"],
                verseTexts: [getVerseText("Psalm 28:7"), getVerseText("Psalm 31:14"), getVerseText("Isaiah 12:2")],
                studyQuestions: ["How does trust grow?", "What experiences build trust?", "How do we strengthen our trust?"],
                discussionPrompts: ["How has your trust in God grown?", "What has helped you trust more?"],
                applicationPoints: ["Trust grows through experience.", "Remember God's faithfulness."]
            )
        ]
    }
    
    // Grace base templates
    private static func getGraceBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "What is Grace?",
                description: "Understanding God's unmerited favor and kindness.",
                keyVerses: ["Ephesians 2:8-9", "Romans 3:24", "2 Corinthians 12:9"],
                verseTexts: [getVerseText("Ephesians 2:8-9"), getVerseText("Romans 3:24"), getVerseText("2 Corinthians 12:9")],
                studyQuestions: ["How does the Bible define grace?", "Why is grace unmerited?", "How do we receive grace?"],
                discussionPrompts: ["How have you experienced grace?", "What does grace mean to you?"],
                applicationPoints: ["Grace is unearned favor.", "We are saved by grace alone."]
            ),
            TopicTemplate(
                title: "Amazing Grace",
                description: "Celebrating the incredible gift of God's grace.",
                keyVerses: ["John 1:16", "Romans 5:20-21", "Titus 2:11-12"],
                verseTexts: [getVerseText("John 1:16"), getVerseText("Romans 5:20-21"), getVerseText("Titus 2:11-12")],
                studyQuestions: ["Why is grace amazing?", "How much grace does God give?", "What does grace teach us?"],
                discussionPrompts: ["What makes grace so powerful?", "How has grace transformed your life?"],
                applicationPoints: ["Grace abounds more than sin.", "Grace teaches us to say no to sin."]
            ),
            TopicTemplate(
                title: "Extending Grace",
                description: "Showing grace and mercy to others.",
                keyVerses: ["Ephesians 4:32", "Matthew 18:21-22", "Colossians 3:13"],
                verseTexts: [getVerseText("Ephesians 4:32"), getVerseText("Matthew 18:21-22"), getVerseText("Colossians 3:13")],
                studyQuestions: ["How do we show grace to others?", "Why extend grace when others don't deserve it?", "How much should we forgive?"],
                discussionPrompts: ["Who needs your grace?", "How can you show grace today?"],
                applicationPoints: ["Forgive as God forgave you.", "Extend grace freely."]
            ),
            TopicTemplate(
                title: "Living in Grace",
                description: "How grace transforms our daily lives.",
                keyVerses: ["Romans 6:14", "Galatians 2:21", "Hebrews 4:16"],
                verseTexts: [getVerseText("Romans 6:14"), getVerseText("Galatians 2:21"), getVerseText("Hebrews 4:16")],
                studyQuestions: ["How does grace change how we live?", "Can grace be abused?", "How do we approach God's throne?"],
                discussionPrompts: ["How does grace impact your daily choices?", "How do you live under grace?"],
                applicationPoints: ["We're under grace, not law.", "Approach God with confidence."]
            ),
            TopicTemplate(
                title: "Sufficient Grace",
                description: "God's grace is enough for every need.",
                keyVerses: ["2 Corinthians 12:9", "James 4:6", "1 Peter 5:10"],
                verseTexts: [getVerseText("2 Corinthians 12:9"), getVerseText("James 4:6"), getVerseText("1 Peter 5:10")],
                studyQuestions: ["Is God's grace sufficient?", "When do we need grace most?", "How does grace help in weakness?"],
                discussionPrompts: ["When has God's grace been sufficient?", "What weakness needs grace?"],
                applicationPoints: ["Grace is enough.", "Power is made perfect in weakness."]
            )
        ]
    }
    
    // Peace base templates
    private static func getPeaceBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "God's Peace",
                description: "Understanding the peace that comes from God.",
                keyVerses: ["John 14:27", "Philippians 4:7", "Isaiah 26:3"],
                verseTexts: [getVerseText("John 14:27"), getVerseText("Philippians 4:7"), getVerseText("Isaiah 26:3")],
                studyQuestions: ["What is God's peace?", "How is God's peace different?", "How do we receive peace?"],
                discussionPrompts: ["When have you experienced God's peace?", "What situation needs peace?"],
                applicationPoints: ["God's peace transcends understanding.", "Peace comes from trusting God."]
            ),
            TopicTemplate(
                title: "Peace with God",
                description: "Being reconciled to God through Christ.",
                keyVerses: ["Romans 5:1", "Colossians 1:20", "Ephesians 2:14-16"],
                verseTexts: [getVerseText("Romans 5:1"), getVerseText("Colossians 1:20"), getVerseText("Ephesians 2:14-16")],
                studyQuestions: ["What does it mean to have peace with God?", "How did Jesus bring peace?", "Why do we need reconciliation?"],
                discussionPrompts: ["How has peace with God changed you?", "What does reconciliation mean?"],
                applicationPoints: ["We have peace through Christ.", "Jesus reconciles us to God."]
            ),
            TopicTemplate(
                title: "Peace with Others",
                description: "Pursuing peace in our relationships.",
                keyVerses: ["Romans 12:18", "Hebrews 12:14", "Matthew 5:9"],
                verseTexts: [getVerseText("Romans 12:18"), getVerseText("Hebrews 12:14"), getVerseText("Matthew 5:9")],
                studyQuestions: ["How do we make peace?", "When is peace impossible?", "What does it mean to be a peacemaker?"],
                discussionPrompts: ["What relationship needs peace?", "How can you be a peacemaker?"],
                applicationPoints: ["Pursue peace with everyone.", "Blessed are the peacemakers."]
            ),
            TopicTemplate(
                title: "Inner Peace",
                description: "Finding peace within through Christ.",
                keyVerses: ["Philippians 4:6-7", "Colossians 3:15", "Psalm 4:8"],
                verseTexts: [getVerseText("Philippians 4:6-7"), getVerseText("Colossians 3:15"), getVerseText("Psalm 4:8")],
                studyQuestions: ["How do we find inner peace?", "What disrupts our peace?", "How does prayer bring peace?"],
                discussionPrompts: ["What threatens your inner peace?", "How do you maintain peace?"],
                applicationPoints: ["Prayer brings peace.", "Let peace rule your heart."]
            ),
            TopicTemplate(
                title: "Peace in Storms",
                description: "Maintaining peace when life is chaotic.",
                keyVerses: ["Mark 4:39", "Psalm 107:29", "Isaiah 54:10"],
                verseTexts: [getVerseText("Mark 4:39"), getVerseText("Psalm 107:29"), getVerseText("Isaiah 54:10")],
                studyQuestions: ["How do we have peace in chaos?", "What did Jesus do in storms?", "How can God calm our storms?"],
                discussionPrompts: ["What storm are you facing?", "How do you find peace in chaos?"],
                applicationPoints: ["Jesus calms storms.", "Peace doesn't depend on circumstances."]
            )
        ]
    }
    
    // Joy base templates
    private static func getJoyBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Joy in the Lord",
                description: "Finding joy that comes from God alone.",
                keyVerses: ["Nehemiah 8:10", "Psalm 16:11", "Philippians 4:4"],
                verseTexts: [getVerseText("Nehemiah 8:10"), getVerseText("Psalm 16:11"), getVerseText("Philippians 4:4")],
                studyQuestions: ["What is joy?", "How is joy different from happiness?", "Where does joy come from?"],
                discussionPrompts: ["What brings you joy?", "How do you find joy in God?"],
                applicationPoints: ["Joy comes from God.", "Rejoice always in the Lord."]
            ),
            TopicTemplate(
                title: "Joy in Trials",
                description: "Experiencing joy even in difficult circumstances.",
                keyVerses: ["James 1:2", "1 Peter 1:6", "Romans 5:3"],
                verseTexts: [getVerseText("James 1:2"), getVerseText("1 Peter 1:6"), getVerseText("Romans 5:3")],
                studyQuestions: ["How can we have joy in trials?", "Why consider trials pure joy?", "How does joy help us persevere?"],
                discussionPrompts: ["When have you found joy in difficulty?", "How do trials lead to joy?"],
                applicationPoints: ["Consider trials as joy.", "Joy comes through perseverance."]
            ),
            TopicTemplate(
                title: "Joy of Salvation",
                description: "Celebrating the joy that comes from being saved.",
                keyVerses: ["Psalm 51:12", "Luke 15:10", "Acts 8:8"],
                verseTexts: [getVerseText("Psalm 51:12"), getVerseText("Luke 15:10"), getVerseText("Acts 8:8")],
                studyQuestions: ["What brings joy to heaven?", "Why does salvation bring joy?", "How do we maintain joy in salvation?"],
                discussionPrompts: ["What joy do you have in being saved?", "How do you celebrate salvation?"],
                applicationPoints: ["Salvation is cause for joy.", "Heaven rejoices over repentance."]
            ),
            TopicTemplate(
                title: "Sharing Joy",
                description: "Spreading joy to others around us.",
                keyVerses: ["Romans 15:13", "2 Corinthians 1:24", "1 Thessalonians 2:19-20"],
                verseTexts: [getVerseText("Romans 15:13"), getVerseText("2 Corinthians 1:24"), getVerseText("1 Thessalonians 2:19-20")],
                studyQuestions: ["How do we share joy?", "Why share our joy?", "Who needs joy in your life?"],
                discussionPrompts: ["How can you spread joy today?", "Who has shared joy with you?"],
                applicationPoints: ["Share joy with others.", "Joy is meant to be shared."]
            ),
            TopicTemplate(
                title: "Complete Joy",
                description: "Experiencing the fullness of joy in Christ.",
                keyVerses: ["John 15:11", "John 16:24", "1 John 1:4"],
                verseTexts: [getVerseText("John 15:11"), getVerseText("John 16:24"), getVerseText("1 John 1:4")],
                studyQuestions: ["What is complete joy?", "How do we find it?", "What completes our joy?"],
                discussionPrompts: ["When have you experienced complete joy?", "What brings you full joy?"],
                applicationPoints: ["Complete joy comes from Christ.", "Joy is made complete in obedience."]
            )
        ]
    }
    
    // Wisdom base templates
    private static func getWisdomBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Seeking Wisdom",
                description: "The importance of asking God for wisdom.",
                keyVerses: ["James 1:5", "Proverbs 2:6", "Proverbs 4:7"],
                verseTexts: [getVerseText("James 1:5"), getVerseText("Proverbs 2:6"), getVerseText("Proverbs 4:7")],
                studyQuestions: ["Where does wisdom come from?", "Why ask God for wisdom?", "How do we gain wisdom?"],
                discussionPrompts: ["What do you need wisdom for?", "How has God given you wisdom?"],
                applicationPoints: ["Ask God for wisdom.", "Wisdom is the principal thing."]
            ),
            TopicTemplate(
                title: "Wisdom vs. Knowledge",
                description: "Understanding the difference between wisdom and knowledge.",
                keyVerses: ["Proverbs 9:10", "Ecclesiastes 7:12", "1 Corinthians 1:25"],
                verseTexts: [getVerseText("Proverbs 9:10"), getVerseText("Ecclesiastes 7:12"), getVerseText("1 Corinthians 1:25")],
                studyQuestions: ["What's the difference between wisdom and knowledge?", "Why is wisdom valuable?", "How do we apply knowledge wisely?"],
                discussionPrompts: ["When have you had knowledge but lacked wisdom?", "How do you seek wisdom over just information?"],
                applicationPoints: ["Fear of God is wisdom.", "Wisdom comes from God."]
            ),
            TopicTemplate(
                title: "Wisdom in Decision Making",
                description: "Using God's wisdom to make life choices.",
                keyVerses: ["Proverbs 3:5-6", "Proverbs 16:9", "James 3:17"],
                verseTexts: [getVerseText("Proverbs 3:5-6"), getVerseText("Proverbs 16:9"), getVerseText("James 3:17")],
                studyQuestions: ["How do we make wise decisions?", "What role does God play in decisions?", "How do we know God's will?"],
                discussionPrompts: ["What decision needs wisdom?", "How do you seek God's guidance?"],
                applicationPoints: ["Acknowledge God in decisions.", "God will direct your paths."]
            ),
            TopicTemplate(
                title: "The Wisdom of God",
                description: "Appreciating God's infinite wisdom.",
                keyVerses: ["Romans 11:33", "Isaiah 55:8-9", "1 Corinthians 1:30"],
                verseTexts: [getVerseText("Romans 11:33"), getVerseText("Isaiah 55:8-9"), getVerseText("1 Corinthians 1:30")],
                studyQuestions: ["How is God's wisdom different?", "Why are God's ways higher?", "How does God's wisdom amaze you?"],
                discussionPrompts: ["When have you seen God's wisdom?", "How do you trust God's wisdom?"],
                applicationPoints: ["God's wisdom is unsearchable.", "Trust God's perfect wisdom."]
            ),
            TopicTemplate(
                title: "Walking in Wisdom",
                description: "Living wisely according to God's ways.",
                keyVerses: ["Ephesians 5:15-17", "Colossians 4:5", "Proverbs 13:20"],
                verseTexts: [getVerseText("Ephesians 5:15-17"), getVerseText("Colossians 4:5"), getVerseText("Proverbs 13:20")],
                studyQuestions: ["What does it mean to walk wisely?", "How do we make the most of time?", "Who should we walk with?"],
                discussionPrompts: ["How are you walking in wisdom?", "What unwise patterns need changing?"],
                applicationPoints: ["Walk as the wise.", "Make the most of every opportunity."]
            )
        ]
    }
    
    // Courage base templates
    private static func getCourageBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Be Strong and Courageous",
                description: "God's command to have courage.",
                keyVerses: ["Joshua 1:9", "Deuteronomy 31:6", "1 Corinthians 16:13"],
                verseTexts: [getVerseText("Joshua 1:9"), getVerseText("Deuteronomy 31:6"), getVerseText("1 Corinthians 16:13")],
                studyQuestions: ["Why does God command courage?", "Where does courage come from?", "How do we be strong and courageous?"],
                discussionPrompts: ["When do you need courage?", "How does God's presence give courage?"],
                applicationPoints: ["God is with us - be courageous.", "Strength comes from the Lord."]
            ),
            TopicTemplate(
                title: "Courage to Stand",
                description: "Standing firm in faith when facing opposition.",
                keyVerses: ["Ephesians 6:10-11", "1 Corinthians 15:58", "Galatians 5:1"],
                verseTexts: [getVerseText("Ephesians 6:10-11"), getVerseText("1 Corinthians 15:58"), getVerseText("Galatians 5:1")],
                studyQuestions: ["When do we need to stand firm?", "How do we stand against opposition?", "What helps us stand?"],
                discussionPrompts: ["When have you had to stand firm?", "What makes standing difficult?"],
                applicationPoints: ["Stand firm in faith.", "Don't be moved."]
            ),
            TopicTemplate(
                title: "Courage to Share",
                description: "Having boldness to share the gospel.",
                keyVerses: ["Acts 4:13", "2 Timothy 1:7-8", "Romans 1:16"],
                verseTexts: [getVerseText("Acts 4:13"), getVerseText("2 Timothy 1:7-8"), getVerseText("Romans 1:16")],
                studyQuestions: ["Why do we need courage to share?", "What fears keep us silent?", "How do we overcome fear of rejection?"],
                discussionPrompts: ["Who can you share with?", "What makes sharing difficult?"],
                applicationPoints: ["Don't be ashamed of the gospel.", "Spirit gives us boldness."]
            ),
            TopicTemplate(
                title: "Courage in Weakness",
                description: "Finding courage through God's strength in our weakness.",
                keyVerses: ["2 Corinthians 12:9-10", "Isaiah 40:29-31", "Philippians 4:13"],
                verseTexts: [getVerseText("2 Corinthians 12:9-10"), getVerseText("Isaiah 40:29-31"), getVerseText("Philippians 4:13")],
                studyQuestions: ["How do we have courage when weak?", "How does God's power work in weakness?", "What does 'when I am weak, I am strong' mean?"],
                discussionPrompts: ["When has weakness led to strength?", "How do you rely on God's power?"],
                applicationPoints: ["Weakness is opportunity for God's power.", "We can do all through Christ."]
            ),
            TopicTemplate(
                title: "Courageous Faith",
                description: "Stepping out in faith requires courage.",
                keyVerses: ["Hebrews 11", "Matthew 14:29", "Ruth 1:16-17"],
                verseTexts: [getVerseText("Hebrews 11"), getVerseText("Matthew 14:29"), getVerseText("Ruth 1:16-17")],
                studyQuestions: ["How does faith require courage?", "Who are examples of courageous faith?", "What step of faith needs courage?"],
                discussionPrompts: ["What step of faith scares you?", "How does courage help faith?"],
                applicationPoints: ["Faith often requires courage.", "Step out in faith despite fear."]
            )
        ]
    }
    
    // Patience base templates
    private static func getPatienceBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "The Fruit of Patience",
                description: "Understanding patience as a fruit of the Spirit.",
                keyVerses: ["Galatians 5:22-23", "Colossians 3:12", "Ephesians 4:2"],
                verseTexts: [getVerseText("Galatians 5:22-23"), getVerseText("Colossians 3:12"), getVerseText("Ephesians 4:2")],
                studyQuestions: ["What is patience?", "How is patience a fruit of the Spirit?", "How do we develop patience?"],
                discussionPrompts: ["When is patience hardest?", "How has God been patient with you?"],
                applicationPoints: ["Patience is a fruit of Spirit.", "Be patient with others."]
            ),
            TopicTemplate(
                title: "Waiting on God",
                description: "Practicing patience as we wait for God's timing.",
                keyVerses: ["Psalm 27:14", "Isaiah 40:31", "Lamentations 3:25"],
                verseTexts: [getVerseText("Psalm 27:14"), getVerseText("Isaiah 40:31"), getVerseText("Lamentations 3:25")],
                studyQuestions: ["Why wait on God?", "How do we wait patiently?", "What are we waiting for?"],
                discussionPrompts: ["What are you waiting for from God?", "How do you wait without giving up?"],
                applicationPoints: ["Wait on the Lord.", "God's timing is perfect."]
            ),
            TopicTemplate(
                title: "Patience with Others",
                description: "Showing patience and forbearance toward people.",
                keyVerses: ["1 Corinthians 13:4", "Proverbs 15:18", "Ephesians 4:2"],
                verseTexts: [getVerseText("1 Corinthians 13:4"), getVerseText("Proverbs 15:18"), getVerseText("Ephesians 4:2")],
                studyQuestions: ["How do we be patient with others?", "Who requires your patience?", "How does love relate to patience?"],
                discussionPrompts: ["Who tests your patience?", "How can you show more patience?"],
                applicationPoints: ["Love is patient.", "Be patient with everyone."]
            ),
            TopicTemplate(
                title: "God's Patience",
                description: "Understanding how patient God is with us.",
                keyVerses: ["2 Peter 3:9", "Romans 2:4", "Numbers 14:18"],
                verseTexts: [getVerseText("2 Peter 3:9"), getVerseText("Romans 2:4"), getVerseText("Numbers 14:18")],
                studyQuestions: ["How patient is God?", "Why is God patient?", "What does God's patience teach us?"],
                discussionPrompts: ["How has God been patient with you?", "What does God's patience mean to you?"],
                applicationPoints: ["God is slow to anger.", "Patience leads to repentance."]
            ),
            TopicTemplate(
                title: "Patience in Trials",
                description: "Enduring hardship with patience and perseverance.",
                keyVerses: ["James 5:7-8", "Romans 5:3-4", "Hebrews 10:36"],
                verseTexts: [getVerseText("James 5:7-8"), getVerseText("Romans 5:3-4"), getVerseText("Hebrews 10:36")],
                studyQuestions: ["How do we be patient in suffering?", "Why is patience needed in trials?", "How does patience produce character?"],
                discussionPrompts: ["What trial requires patience?", "How do you endure with patience?"],
                applicationPoints: ["Patience produces character.", "Endure with patience."]
            )
        ]
    }
    
    // Gratitude base templates
    private static func getGratitudeBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Heart of Gratitude",
                description: "Developing a grateful heart in all circumstances.",
                keyVerses: ["1 Thessalonians 5:18", "Colossians 3:15-17", "Psalm 100:4"],
                verseTexts: [getVerseText("1 Thessalonians 5:18"), getVerseText("Colossians 3:15-17"), getVerseText("Psalm 100:4")],
                studyQuestions: ["Why be grateful in all circumstances?", "How do we develop gratitude?", "What are you grateful for?"],
                discussionPrompts: ["What are you thankful for today?", "How does gratitude change your perspective?"],
                applicationPoints: ["Give thanks in all circumstances.", "Gratitude is a choice."]
            ),
            TopicTemplate(
                title: "Gratitude for Salvation",
                description: "Thanking God for the gift of salvation.",
                keyVerses: ["2 Corinthians 9:15", "1 Corinthians 15:57", "Ephesians 2:8-9"],
                verseTexts: [getVerseText("2 Corinthians 9:15"), getVerseText("1 Corinthians 15:57"), getVerseText("Ephesians 2:8-9")],
                studyQuestions: ["What does salvation mean to you?", "Why is salvation the greatest gift?", "How do we express gratitude for salvation?"],
                discussionPrompts: ["How grateful are you for salvation?", "How does this impact your daily life?"],
                applicationPoints: ["Salvation is an indescribable gift.", "Thank God for His gift."]
            ),
            TopicTemplate(
                title: "Gratitude in Hard Times",
                description: "Finding things to be grateful for even in difficulty.",
                keyVerses: ["Psalm 34:1", "Habakkuk 3:17-18", "1 Peter 1:6-7"],
                verseTexts: [getVerseText("Psalm 34:1"), getVerseText("Habakkuk 3:17-18"), getVerseText("1 Peter 1:6-7")],
                studyQuestions: ["How do we give thanks in trials?", "What can we be grateful for in hard times?", "Why praise God in difficulty?"],
                discussionPrompts: ["What can you thank God for in trials?", "How has gratitude helped in difficulty?"],
                applicationPoints: ["Gratitude changes perspective.", "Praise God even in storms."]
            ),
            TopicTemplate(
                title: "Expressing Gratitude",
                description: "Practical ways to show and express thankfulness.",
                keyVerses: ["Psalm 107:1", "Psalm 136:1", "Colossians 2:7"],
                verseTexts: [getVerseText("Psalm 107:1"), getVerseText("Psalm 136:1"), getVerseText("Colossians 2:7")],
                studyQuestions: ["How do we express gratitude?", "Who should we thank?", "What are ways to show thankfulness?"],
                discussionPrompts: ["How do you express gratitude?", "Who needs your thanks?"],
                applicationPoints: ["Give thanks to the Lord.", "Express gratitude regularly."]
            ),
            TopicTemplate(
                title: "Gratitude's Impact",
                description: "How gratitude transforms our hearts and lives.",
                keyVerses: ["Psalm 92:1", "Philippians 4:6", "Hebrews 12:28"],
                verseTexts: [getVerseText("Psalm 92:1"), getVerseText("Philippians 4:6"), getVerseText("Hebrews 12:28")],
                studyQuestions: ["How does gratitude change us?", "What happens when we're grateful?", "How does thankfulness affect our relationship with God?"],
                discussionPrompts: ["How has gratitude changed you?", "What transformation have you seen?"],
                applicationPoints: ["Gratitude transforms hearts.", "Thankfulness opens our hearts to God."]
            )
        ]
    }
    
    // Salvation base templates
    private static func getSalvationBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "What is Salvation?",
                description: "Understanding what it means to be saved.",
                keyVerses: ["Romans 10:9-10", "Acts 16:31", "Ephesians 2:8-9"],
                verseTexts: [getVerseText("Romans 10:9-10"), getVerseText("Acts 16:31"), getVerseText("Ephesians 2:8-9")],
                studyQuestions: ["What does it mean to be saved?", "How are we saved?", "Why do we need salvation?"],
                discussionPrompts: ["What does salvation mean to you?", "When did you receive salvation?"],
                applicationPoints: ["Salvation comes through faith.", "Believe and be saved."]
            ),
            TopicTemplate(
                title: "The Gift of Salvation",
                description: "Salvation as God's free gift to us.",
                keyVerses: ["Romans 6:23", "Ephesians 2:8", "Titus 3:5"],
                verseTexts: [getVerseText("Romans 6:23"), getVerseText("Ephesians 2:8"), getVerseText("Titus 3:5")],
                studyQuestions: ["Why is salvation called a gift?", "What did salvation cost God?", "How do we receive this gift?"],
                discussionPrompts: ["How have you received this gift?", "Why is it free to us?"],
                applicationPoints: ["Salvation is a gift.", "We can't earn it."]
            ),
            TopicTemplate(
                title: "Assurance of Salvation",
                description: "Knowing with confidence that you are saved.",
                keyVerses: ["1 John 5:13", "John 10:27-28", "Romans 8:16"],
                verseTexts: [getVerseText("1 John 5:13"), getVerseText("John 10:27-28"), getVerseText("Romans 8:16")],
                studyQuestions: ["How do we know we're saved?", "Can we lose salvation?", "What gives us assurance?"],
                discussionPrompts: ["Do you have assurance?", "What gives you confidence?"],
                applicationPoints: ["You can know you're saved.", "Nothing can separate us from God's love."]
            ),
            TopicTemplate(
                title: "Sharing Salvation",
                description: "Telling others about the good news of salvation.",
                keyVerses: ["Romans 10:14-15", "Mark 16:15", "Acts 1:8"],
                verseTexts: [getVerseText("Romans 10:14-15"), getVerseText("Mark 16:15"), getVerseText("Acts 1:8")],
                studyQuestions: ["Why share salvation?", "How do we share the gospel?", "Who needs to hear?"],
                discussionPrompts: ["Who can you share with?", "What's your salvation story?"],
                applicationPoints: ["Everyone needs to hear.", "Share the good news."]
            ),
            TopicTemplate(
                title: "Walking in Salvation",
                description: "Living out your salvation daily.",
                keyVerses: ["Philippians 2:12-13", "Ephesians 4:1", "1 Peter 2:2"],
                verseTexts: [getVerseText("Philippians 2:12-13"), getVerseText("Ephesians 4:1"), getVerseText("1 Peter 2:2")],
                studyQuestions: ["How do we work out our salvation?", "What does it mean to walk worthy?", "How do we grow in salvation?"],
                discussionPrompts: ["How are you working out salvation?", "What growth do you see?"],
                applicationPoints: ["Work out salvation with fear.", "Grow in your salvation."]
            )
        ]
    }
    
    // Character base templates
    private static func getCharacterBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Building Character",
                description: "Developing godly character qualities.",
                keyVerses: ["Romans 5:3-4", "2 Peter 1:5-8", "Galatians 5:22-23"],
                verseTexts: [getVerseText("Romans 5:3-4"), getVerseText("2 Peter 1:5-8"), getVerseText("Galatians 5:22-23")],
                studyQuestions: ["What is character?", "How is character built?", "What character qualities matter most?"],
                discussionPrompts: ["What character quality do you need?", "How has God built your character?"],
                applicationPoints: ["Trials build character.", "Add to your faith."]
            ),
            TopicTemplate(
                title: "Integrity",
                description: "Living with honesty and moral uprightness.",
                keyVerses: ["Proverbs 10:9", "Psalm 25:21", "Titus 2:7-8"],
                verseTexts: [getVerseText("Proverbs 10:9"), getVerseText("Psalm 25:21"), getVerseText("Titus 2:7-8")],
                studyQuestions: ["What is integrity?", "Why does integrity matter?", "How do we maintain integrity?"],
                discussionPrompts: ["When has integrity been tested?", "How do you live with integrity?"],
                applicationPoints: ["Walk in integrity.", "Integrity protects us."]
            ),
            TopicTemplate(
                title: "Humility",
                description: "Developing a humble heart before God and others.",
                keyVerses: ["Philippians 2:3-4", "James 4:10", "1 Peter 5:5-6"],
                verseTexts: [getVerseText("Philippians 2:3-4"), getVerseText("James 4:10"), getVerseText("1 Peter 5:5-6")],
                studyQuestions: ["What is humility?", "How did Jesus model humility?", "Why is humility important?"],
                discussionPrompts: ["When is humility difficult?", "How do you practice humility?"],
                applicationPoints: ["Humility before God.", "God exalts the humble."]
            ),
            TopicTemplate(
                title: "Honesty",
                description: "Speaking and living truthfully.",
                keyVerses: ["Ephesians 4:25", "Proverbs 12:22", "Colossians 3:9"],
                verseTexts: [getVerseText("Ephesians 4:25"), getVerseText("Proverbs 12:22"), getVerseText("Colossians 3:9")],
                studyQuestions: ["Why is honesty important?", "When is honesty difficult?", "How do we speak truth in love?"],
                discussionPrompts: ["When has honesty been hard?", "How do you maintain honesty?"],
                applicationPoints: ["Speak truthfully.", "God detests lying."]
            ),
            TopicTemplate(
                title: "Perseverance",
                description: "Enduring and continuing in faith despite obstacles.",
                keyVerses: ["Hebrews 12:1-2", "James 1:12", "Galatians 6:9"],
                verseTexts: [getVerseText("Hebrews 12:1-2"), getVerseText("James 1:12"), getVerseText("Galatians 6:9")],
                studyQuestions: ["What is perseverance?", "How do we develop it?", "Why keep going when it's hard?"],
                discussionPrompts: ["When have you needed to persevere?", "What helps you keep going?"],
                applicationPoints: ["Run with perseverance.", "Don't give up."]
            )
        ]
    }
    
    // Relationships base templates
    private static func getRelationshipsBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Biblical Relationships",
                description: "Building relationships according to God's design.",
                keyVerses: ["1 Corinthians 15:33", "Proverbs 13:20", "Ecclesiastes 4:9-10"],
                verseTexts: [getVerseText("1 Corinthians 15:33"), getVerseText("Proverbs 13:20"), getVerseText("Ecclesiastes 4:9-10")],
                studyQuestions: ["What makes relationships biblical?", "How should relationships work?", "Who should we build relationships with?"],
                discussionPrompts: ["What relationships matter most?", "How do you build godly relationships?"],
                applicationPoints: ["Choose relationships wisely.", "Two are better than one."]
            ),
            TopicTemplate(
                title: "Love in Relationships",
                description: "Applying biblical love to relationships.",
                keyVerses: ["1 Corinthians 13:4-7", "1 Peter 4:8", "Ephesians 5:25"],
                verseTexts: [getVerseText("1 Corinthians 13:4-7"), getVerseText("1 Peter 4:8"), getVerseText("Ephesians 5:25")],
                studyQuestions: ["How do we love in relationships?", "What does 1 Corinthians 13 teach?", "How does love cover wrongs?"],
                discussionPrompts: ["How do you show love in relationships?", "What love characteristic do you need?"],
                applicationPoints: ["Love is patient and kind.", "Love covers a multitude of sins."]
            ),
            TopicTemplate(
                title: "Forgiving in Relationships",
                description: "The role of forgiveness in healthy relationships.",
                keyVerses: ["Colossians 3:13", "Matthew 18:21-22", "Ephesians 4:32"],
                verseTexts: [getVerseText("Colossians 3:13"), getVerseText("Matthew 18:21-22"), getVerseText("Ephesians 4:32")],
                studyQuestions: ["Why forgive in relationships?", "How often should we forgive?", "What if they keep hurting us?"],
                discussionPrompts: ["Who do you need to forgive?", "How has forgiveness healed relationships?"],
                applicationPoints: ["Forgive as God forgave.", "Forgiveness is essential."]
            ),
            TopicTemplate(
                title: "Communication in Relationships",
                description: "Speaking truthfully and lovingly in relationships.",
                keyVerses: ["Ephesians 4:15", "Proverbs 15:1", "James 1:19"],
                verseTexts: [getVerseText("Ephesians 4:15"), getVerseText("Proverbs 15:1"), getVerseText("James 1:19")],
                studyQuestions: ["How should we communicate?", "What does speaking truth in love mean?", "Why listen before speaking?"],
                discussionPrompts: ["How can you communicate better?", "What communication habit needs work?"],
                applicationPoints: ["Speak truth in love.", "Be quick to listen."]
            ),
            TopicTemplate(
                title: "Encouraging Others",
                description: "Building up and encouraging people in relationships.",
                keyVerses: ["1 Thessalonians 5:11", "Hebrews 10:24-25", "Ephesians 4:29"],
                verseTexts: [getVerseText("1 Thessalonians 5:11"), getVerseText("Hebrews 10:24-25"), getVerseText("Ephesians 4:29")],
                studyQuestions: ["Why encourage others?", "How do we build people up?", "What words are encouraging?"],
                discussionPrompts: ["Who needs encouragement?", "How can you encourage someone today?"],
                applicationPoints: ["Build others up.", "Use words that edify."]
            )
        ]
    }
    
    // Trials base templates
    private static func getTrialsBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Purpose in Trials",
                description: "Understanding God's purpose in allowing trials.",
                keyVerses: ["James 1:2-4", "Romans 5:3-5", "1 Peter 1:6-7"],
                verseTexts: [getVerseText("James 1:2-4"), getVerseText("Romans 5:3-5"), getVerseText("1 Peter 1:6-7")],
                studyQuestions: ["Why does God allow trials?", "What purpose do trials serve?", "How do trials produce character?"],
                discussionPrompts: ["What trial are you facing?", "What purpose might God have?"],
                applicationPoints: ["Trials produce perseverance.", "God uses trials for good."]
            ),
            TopicTemplate(
                title: "God's Presence in Trials",
                description: "Experiencing God's nearness during difficult times.",
                keyVerses: ["Psalm 46:1", "Isaiah 43:2", "Deuteronomy 31:6"],
                verseTexts: [getVerseText("Psalm 46:1"), getVerseText("Isaiah 43:2"), getVerseText("Deuteronomy 31:6")],
                studyQuestions: ["Is God with us in trials?", "How do we sense God's presence?", "Why does God allow suffering?"],
                discussionPrompts: ["When have you felt God's presence in trials?", "How does knowing God is with you help?"],
                applicationPoints: ["God is our refuge.", "He never leaves us."]
            ),
            TopicTemplate(
                title: "Overcoming Trials",
                description: "How to overcome and grow through difficulties.",
                keyVerses: ["1 Corinthians 10:13", "John 16:33", "Romans 8:37"],
                verseTexts: [getVerseText("1 Corinthians 10:13"), getVerseText("John 16:33"), getVerseText("Romans 8:37")],
                studyQuestions: ["How do we overcome?", "Will God provide a way out?", "How are we more than conquerors?"],
                discussionPrompts: ["What trial needs overcoming?", "How do you overcome with God's help?"],
                applicationPoints: ["God provides a way out.", "We can overcome through Christ."]
            ),
            TopicTemplate(
                title: "Learning from Trials",
                description: "What trials teach us about God and ourselves.",
                keyVerses: ["Hebrews 12:11", "Psalm 119:71", "Job 23:10"],
                verseTexts: [getVerseText("Hebrews 12:11"), getVerseText("Psalm 119:71"), getVerseText("Job 23:10")],
                studyQuestions: ["What can we learn from trials?", "How do trials teach us?", "What has God shown you through trials?"],
                discussionPrompts: ["What have you learned from trials?", "How have trials taught you?"],
                applicationPoints: ["Discipline yields fruit.", "Trials teach us."]
            ),
            TopicTemplate(
                title: "Hope in Trials",
                description: "Maintaining hope when going through difficult times.",
                keyVerses: ["Romans 5:3-5", "Lamentations 3:21-23", "Psalm 34:19"],
                verseTexts: [getVerseText("Romans 5:3-5"), getVerseText("Lamentations 3:21-23"), getVerseText("Psalm 34:19")],
                studyQuestions: ["How do we have hope in trials?", "What promises sustain us?", "How does hope help us endure?"],
                discussionPrompts: ["What gives you hope in trials?", "How do you maintain hope?"],
                applicationPoints: ["Hope doesn't disappoint.", "God's mercies are new every morning."]
            )
        ]
    }
    
    // General base templates
    private static func getGeneralBaseTemplates() -> [TopicTemplate] {
        return [
            TopicTemplate(
                title: "Walking with God",
                description: "What it means to have a daily walk with God.",
                keyVerses: ["Genesis 5:24", "Micah 6:8", "Amos 3:3"],
                verseTexts: [getVerseText("Genesis 5:24"), getVerseText("Micah 6:8"), getVerseText("Amos 3:3")],
                studyQuestions: ["What does walking with God mean?", "How do we walk daily with God?", "What does God require?"],
                discussionPrompts: ["How is your walk with God?", "What helps you walk closely?"],
                applicationPoints: ["Walk humbly with God.", "Live justly, love mercy."]
            ),
            TopicTemplate(
                title: "Abiding in Christ",
                description: "Remaining connected to Jesus as the source of life.",
                keyVerses: ["John 15:4-5", "1 John 2:6", "John 15:7"],
                verseTexts: [getVerseText("John 15:4-5"), getVerseText("1 John 2:6"), getVerseText("John 15:7")],
                studyQuestions: ["What does abiding mean?", "How do we abide in Christ?", "What happens when we abide?"],
                discussionPrompts: ["How do you abide in Christ?", "What does this look like daily?"],
                applicationPoints: ["Abide in Christ.", "Apart from Him we can do nothing."]
            ),
            TopicTemplate(
                title: "Being Transformed",
                description: "How God transforms us into Christ's image.",
                keyVerses: ["Romans 12:2", "2 Corinthians 3:18", "Ephesians 4:22-24"],
                verseTexts: [getVerseText("Romans 12:2"), getVerseText("2 Corinthians 3:18"), getVerseText("Ephesians 4:22-24")],
                studyQuestions: ["How are we transformed?", "What does transformation look like?", "How long does it take?"],
                discussionPrompts: ["How have you been transformed?", "What transformation do you need?"],
                applicationPoints: ["Be transformed by renewing your mind.", "We're being changed."]
            ),
            TopicTemplate(
                title: "Following Jesus",
                description: "What it means to be a disciple and follow Christ.",
                keyVerses: ["Matthew 16:24", "Luke 9:23", "John 12:26"],
                verseTexts: [getVerseText("Matthew 16:24"), getVerseText("Luke 9:23"), getVerseText("John 12:26")],
                studyQuestions: ["What does following Jesus require?", "How do we deny ourselves?", "What does it mean to take up our cross?"],
                discussionPrompts: ["What does following Jesus look like for you?", "What makes following hard?"],
                applicationPoints: ["Deny yourself and follow.", "Whoever serves me must follow."]
            ),
            TopicTemplate(
                title: "Living for God",
                description: "Making God the center and purpose of our lives.",
                keyVerses: ["1 Corinthians 10:31", "Colossians 3:17", "Romans 14:8"],
                verseTexts: [getVerseText("1 Corinthians 10:31"), getVerseText("Colossians 3:17"), getVerseText("Romans 14:8")],
                studyQuestions: ["How do we live for God?", "What does it mean to glorify God?", "How do we make God the center?"],
                discussionPrompts: ["How are you living for God?", "What needs to change?"],
                applicationPoints: ["Do everything for God's glory.", "Live for the Lord."]
            )
        ]
    }
    
    struct StoredTopic: Codable {
        let title: String
        let description: String
        let category: BibleStudyTopic.TopicCategory
        let keyVerses: [String]
        let verseTexts: [String]
        let studyQuestions: [String]
        let discussionPrompts: [String]
        let applicationPoints: [String]
        // Note: answers are stored in SwiftData, not in UserDefaults
    }
    
    struct TopicTemplate {
        let title: String
        let description: String
        let keyVerses: [String]
        let verseTexts: [String]
        let studyQuestions: [String]
        let discussionPrompts: [String]
        let applicationPoints: [String]
    }
}
