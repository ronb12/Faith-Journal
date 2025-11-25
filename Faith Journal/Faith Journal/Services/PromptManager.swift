//
//  PromptManager.swift
//  Faith Journal
//
//  Manages journal prompts library - 365 prompts (one for each day of the year)
//

import Foundation
import SwiftUI

@MainActor
class PromptManager: ObservableObject {
    static let shared = PromptManager()
    
    @Published var dailyPrompt: JournalPrompt?
    @Published var favoritePrompts: [JournalPrompt] = []
    
    private let promptLibrary: [JournalPrompt]
    private let calendar = Calendar.current
    
    private init() {
        // Initialize with 365 prompts across categories
        promptLibrary = PromptManager.createPromptLibrary()
        loadDailyPrompt()
        loadFavorites()
    }
    
    // Get today's prompt based on day of year (1-365) for consistency
    func getDailyPrompt() -> JournalPrompt {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return getPromptForDay(dayOfYear)
    }
    
    // Get random prompt from specific categories
    func getRandomPrompt(from categories: [JournalPrompt.PromptCategory] = []) -> JournalPrompt {
        let filteredPrompts = categories.isEmpty ? 
            promptLibrary : 
            promptLibrary.filter { categories.contains($0.category) }
        
        return filteredPrompts.randomElement() ?? promptLibrary.randomElement() ?? JournalPrompt(
            promptText: "What's on your heart today?",
            category: .general
        )
    }
    
    // Get prompts by category
    func getPrompts(for category: JournalPrompt.PromptCategory) -> [JournalPrompt] {
        return promptLibrary.filter { $0.category == category }
    }
    
    // Get all categories with prompt counts
    func getCategoryStats() -> [(category: JournalPrompt.PromptCategory, count: Int)] {
        return JournalPrompt.PromptCategory.allCases.map { category in
            (category: category, count: promptLibrary.filter { $0.category == category }.count)
        }
    }
    
    // Get prompt by day of year (1-365)
    func getPromptForDay(_ day: Int) -> JournalPrompt {
        let index = (day - 1) % promptLibrary.count
        return promptLibrary[index]
    }
    
    // Load daily prompt (store and update daily)
    func loadDailyPrompt() {
        let lastPromptDate = UserDefaults.standard.object(forKey: "lastDailyPromptDate") as? Date
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastPromptDate,
           calendar.startOfDay(for: lastDate) == today {
            // Same day, use stored prompt
            if let storedPromptData = UserDefaults.standard.data(forKey: "dailyPrompt"),
               let prompt = try? JSONDecoder().decode(StoredPrompt.self, from: storedPromptData) {
                dailyPrompt = JournalPrompt(
                    promptText: prompt.promptText,
                    category: prompt.category
                )
            }
        } else {
            // New day, generate new prompt based on day of year
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
            dailyPrompt = getPromptForDay(dayOfYear)
            saveDailyPrompt()
        }
    }
    
    private func saveDailyPrompt() {
        guard let prompt = dailyPrompt else { return }
        
        let stored = StoredPrompt(
            promptText: prompt.promptText,
            category: prompt.category
        )
        
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: "dailyPrompt")
            UserDefaults.standard.set(Date(), forKey: "lastDailyPromptDate")
        }
    }
    
    func loadFavorites() {
        // Load favorite prompts from UserDefaults or SwiftData
        // For now, use a simple approach
        favoritePrompts = promptLibrary.filter { $0.isFavorite }
    }
    
    func toggleFavorite(_ prompt: JournalPrompt) {
        prompt.isFavorite.toggle()
        loadFavorites()
    }
    
    // Create prompt library with 365 prompts (one for each day of the year)
    private static func createPromptLibrary() -> [JournalPrompt] {
        var prompts: [JournalPrompt] = []
        
        // === GRATITUDE PROMPTS (40 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "What are three things you're grateful for today?", category: .gratitude),
            JournalPrompt(promptText: "How has God blessed you this week?", category: .gratitude),
            JournalPrompt(promptText: "Who are you thankful for and why?", category: .gratitude),
            JournalPrompt(promptText: "What simple pleasure brought you joy today?", category: .gratitude),
            JournalPrompt(promptText: "How has gratitude changed your perspective recently?", category: .gratitude),
            JournalPrompt(promptText: "What unexpected blessing did you receive today?", category: .gratitude),
            JournalPrompt(promptText: "Who in your life makes you feel grateful?", category: .gratitude),
            JournalPrompt(promptText: "What answered prayer can you thank God for?", category: .gratitude),
            JournalPrompt(promptText: "What physical ability are you grateful to have?", category: .gratitude),
            JournalPrompt(promptText: "What memory are you grateful for?", category: .gratitude),
            JournalPrompt(promptText: "What talent or skill has God given you?", category: .gratitude),
            JournalPrompt(promptText: "What place are you grateful exists in your life?", category: .gratitude),
            JournalPrompt(promptText: "How has God provided for your needs recently?", category: .gratitude),
            JournalPrompt(promptText: "What challenge taught you to be grateful?", category: .gratitude),
            JournalPrompt(promptText: "What season of life are you grateful for?", category: .gratitude),
            JournalPrompt(promptText: "What material possession are you most thankful for?", category: .gratitude),
            JournalPrompt(promptText: "What lesson are you grateful you learned?", category: .gratitude),
            JournalPrompt(promptText: "How does expressing gratitude change your day?", category: .gratitude),
            JournalPrompt(promptText: "What person showed you kindness recently?", category: .gratitude),
            JournalPrompt(promptText: "What sound, smell, or taste brought you joy today?", category: .gratitude),
            JournalPrompt(promptText: "What opportunity are you grateful came your way?", category: .gratitude),
            JournalPrompt(promptText: "What aspect of nature are you thankful for?", category: .gratitude),
            JournalPrompt(promptText: "What moment from today will you remember gratefully?", category: .gratitude),
            JournalPrompt(promptText: "What quality in others are you grateful to witness?", category: .gratitude),
            JournalPrompt(promptText: "How has gratitude helped you through hard times?", category: .gratitude),
            JournalPrompt(promptText: "What dream or goal are you grateful to pursue?", category: .gratitude),
            JournalPrompt(promptText: "What freedom are you grateful to have?", category: .gratitude),
            JournalPrompt(promptText: "What tradition or custom are you thankful for?", category: .gratitude),
            JournalPrompt(promptText: "What small thing made a big difference today?", category: .gratitude),
            JournalPrompt(promptText: "How has gratitude strengthened your faith?", category: .gratitude),
            JournalPrompt(promptText: "What part of your identity are you grateful for?", category: .gratitude),
            JournalPrompt(promptText: "What milestone are you grateful to have reached?", category: .gratitude),
            JournalPrompt(promptText: "What song or music brought you joy today?", category: .gratitude),
            JournalPrompt(promptText: "What book or story impacted you positively?", category: .gratitude),
            JournalPrompt(promptText: "What technology are you grateful exists?", category: .gratitude),
            JournalPrompt(promptText: "What change are you grateful happened in your life?", category: .gratitude),
            JournalPrompt(promptText: "What prayer request can you thank God for answering?", category: .gratitude),
            JournalPrompt(promptText: "What relationship are you most grateful for?", category: .gratitude),
            JournalPrompt(promptText: "What comfort did God provide you today?", category: .gratitude),
            JournalPrompt(promptText: "How does being grateful help you see God's goodness?", category: .gratitude)
        ])
        
        // === PRAYER PROMPTS (40 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "What's on your heart that you want to pray about?", category: .prayer),
            JournalPrompt(promptText: "How has prayer strengthened your relationship with God?", category: .prayer),
            JournalPrompt(promptText: "What prayer request do you want to bring before God?", category: .prayer),
            JournalPrompt(promptText: "Describe a time when you felt God answered your prayer.", category: .prayer),
            JournalPrompt(promptText: "How can you pray for someone else today?", category: .prayer),
            JournalPrompt(promptText: "What burden do you need to lay before God in prayer?", category: .prayer),
            JournalPrompt(promptText: "How does prayer bring you peace in difficult times?", category: .prayer),
            JournalPrompt(promptText: "What prayer habit would you like to develop?", category: .prayer),
            JournalPrompt(promptText: "Who needs your prayers today and why?", category: .prayer),
            JournalPrompt(promptText: "How has God responded to your prayers recently?", category: .prayer),
            JournalPrompt(promptText: "What do you want to thank God for in prayer?", category: .prayer),
            JournalPrompt(promptText: "How can prayer transform your perspective on a current situation?", category: .prayer),
            JournalPrompt(promptText: "What unanswered prayer are you still trusting God with?", category: .prayer),
            JournalPrompt(promptText: "How does praying for others change your heart?", category: .prayer),
            JournalPrompt(promptText: "What biblical prayer do you want to make your own?", category: .prayer),
            JournalPrompt(promptText: "How can you make prayer a more regular part of your day?", category: .prayer),
            JournalPrompt(promptText: "What prayer do you need to pray but haven't yet?", category: .prayer),
            JournalPrompt(promptText: "How has God's timing in answering prayers taught you patience?", category: .prayer),
            JournalPrompt(promptText: "What area of your life needs more prayer?", category: .prayer),
            JournalPrompt(promptText: "How does listening in prayer change what you pray?", category: .prayer),
            JournalPrompt(promptText: "What prayer of praise do you want to offer God today?", category: .prayer),
            JournalPrompt(promptText: "How can you pray for your community or church?", category: .prayer),
            JournalPrompt(promptText: "What prayer request from someone else are you carrying?", category: .prayer),
            JournalPrompt(promptText: "How does praying Scripture deepen your faith?", category: .prayer),
            JournalPrompt(promptText: "What prayer can you pray for your family today?", category: .prayer),
            JournalPrompt(promptText: "How has God answered prayers differently than you expected?", category: .prayer),
            JournalPrompt(promptText: "What prayer of confession do you need to make?", category: .prayer),
            JournalPrompt(promptText: "How can you pray for someone who has hurt you?", category: .prayer),
            JournalPrompt(promptText: "What prayer request do you need to keep trusting God with?", category: .prayer),
            JournalPrompt(promptText: "How does prayer help you surrender control to God?", category: .prayer),
            JournalPrompt(promptText: "What prayer can you pray for your work or studies?", category: .prayer),
            JournalPrompt(promptText: "How has prayer helped you make difficult decisions?", category: .prayer),
            JournalPrompt(promptText: "What prayer of worship do you want to express today?", category: .prayer),
            JournalPrompt(promptText: "How can you pray for your future goals and dreams?", category: .prayer),
            JournalPrompt(promptText: "What prayer habit from someone inspires you?", category: .prayer),
            JournalPrompt(promptText: "How does praying with others strengthen your faith?", category: .prayer),
            JournalPrompt(promptText: "What unanswered prayer taught you about God's will?", category: .prayer),
            JournalPrompt(promptText: "How can you pray for people who don't know Jesus?", category: .prayer),
            JournalPrompt(promptText: "What prayer do you want to pray but feel too weak to pray?", category: .prayer),
            JournalPrompt(promptText: "How does prayer remind you of God's presence?", category: .prayer)
        ])
        
        // === SCRIPTURE PROMPTS (40 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "What verse encouraged you today and why?", category: .scripture),
            JournalPrompt(promptText: "Which Bible passage has been meaningful to you this week?", category: .scripture),
            JournalPrompt(promptText: "How does Scripture guide your daily decisions?", category: .scripture),
            JournalPrompt(promptText: "What biblical truth do you need to remember today?", category: .scripture),
            JournalPrompt(promptText: "How can you apply God's Word to your current situation?", category: .scripture),
            JournalPrompt(promptText: "What Bible story relates to what you're going through?", category: .scripture),
            JournalPrompt(promptText: "How has a verse changed your perspective recently?", category: .scripture),
            JournalPrompt(promptText: "What Scripture promise are you holding onto?", category: .scripture),
            JournalPrompt(promptText: "Which biblical character's faith inspires you and why?", category: .scripture),
            JournalPrompt(promptText: "How can you memorize Scripture to help in difficult times?", category: .scripture),
            JournalPrompt(promptText: "What passage challenged you to grow in your faith?", category: .scripture),
            JournalPrompt(promptText: "How does reading the Bible daily impact your life?", category: .scripture),
            JournalPrompt(promptText: "What verse about love, hope, or peace speaks to you?", category: .scripture),
            JournalPrompt(promptText: "How has God's Word corrected or guided you recently?", category: .scripture),
            JournalPrompt(promptText: "What Scripture can you share to encourage someone else?", category: .scripture),
            JournalPrompt(promptText: "How does the Bible help you understand who God is?", category: .scripture),
            JournalPrompt(promptText: "What verse about prayer changed how you pray?", category: .scripture),
            JournalPrompt(promptText: "Which parable of Jesus applies to your life right now?", category: .scripture),
            JournalPrompt(promptText: "How has a verse comforted you in times of trouble?", category: .scripture),
            JournalPrompt(promptText: "What biblical command challenges you to grow?", category: .scripture),
            JournalPrompt(promptText: "How does Scripture help you resist temptation?", category: .scripture),
            JournalPrompt(promptText: "What verse about God's character brings you hope?", category: .scripture),
            JournalPrompt(promptText: "How has the Bible helped you forgive someone?", category: .scripture),
            JournalPrompt(promptText: "What Scripture verse do you want to live out today?", category: .scripture),
            JournalPrompt(promptText: "How does reading God's Word deepen your relationship with Him?", category: .scripture),
            JournalPrompt(promptText: "What verse about perseverance encourages you?", category: .scripture),
            JournalPrompt(promptText: "How has Scripture helped you understand suffering?", category: .scripture),
            JournalPrompt(promptText: "What Bible passage about grace impacts your daily life?", category: .scripture),
            JournalPrompt(promptText: "How does God's Word guide your relationships?", category: .scripture),
            JournalPrompt(promptText: "What verse about serving others challenges you?", category: .scripture),
            JournalPrompt(promptText: "How has Scripture helped you find your purpose?", category: .scripture),
            JournalPrompt(promptText: "What biblical truth about God's love do you need to remember?", category: .scripture),
            JournalPrompt(promptText: "How does the Bible help you deal with worry or anxiety?", category: .scripture),
            JournalPrompt(promptText: "What verse about God's faithfulness strengthens your faith?", category: .scripture),
            JournalPrompt(promptText: "How has Scripture helped you make wise decisions?", category: .scripture),
            JournalPrompt(promptText: "What Bible passage about gratitude changes your perspective?", category: .scripture),
            JournalPrompt(promptText: "How does God's Word help you love others better?", category: .scripture),
            JournalPrompt(promptText: "What verse about courage helps you face challenges?", category: .scripture),
            JournalPrompt(promptText: "How has Scripture revealed God's plan for your life?", category: .scripture),
            JournalPrompt(promptText: "What biblical teaching do you want to understand deeper?", category: .scripture)
        ])
        
        // === GROWTH PROMPTS (40 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "How have you grown in your faith recently?", category: .growth),
            JournalPrompt(promptText: "What spiritual discipline would you like to develop?", category: .growth),
            JournalPrompt(promptText: "How is God transforming your character?", category: .growth),
            JournalPrompt(promptText: "What area of your life needs God's guidance?", category: .growth),
            JournalPrompt(promptText: "What lesson is God teaching you through current circumstances?", category: .growth),
            JournalPrompt(promptText: "How has your understanding of God deepened this year?", category: .growth),
            JournalPrompt(promptText: "What sin or struggle are you working to overcome?", category: .growth),
            JournalPrompt(promptText: "How have you become more like Christ recently?", category: .growth),
            JournalPrompt(promptText: "What spiritual fruit is God developing in you?", category: .growth),
            JournalPrompt(promptText: "How has your prayer life grown or changed?", category: .growth),
            JournalPrompt(promptText: "What Bible study or devotional helped you grow?", category: .growth),
            JournalPrompt(promptText: "How is God stretching you out of your comfort zone?", category: .growth),
            JournalPrompt(promptText: "What area of spiritual maturity do you want to focus on?", category: .growth),
            JournalPrompt(promptText: "How has God used trials to help you grow?", category: .growth),
            JournalPrompt(promptText: "What mentor or teacher has helped you grow spiritually?", category: .growth),
            JournalPrompt(promptText: "How has serving others helped you mature in faith?", category: .growth),
            JournalPrompt(promptText: "What spiritual goal do you want to achieve this year?", category: .growth),
            JournalPrompt(promptText: "How has your relationship with God evolved?", category: .growth),
            JournalPrompt(promptText: "What bad habit is God helping you break?", category: .growth),
            JournalPrompt(promptText: "How has God's grace transformed your life?", category: .growth),
            JournalPrompt(promptText: "What area of your faith needs more attention?", category: .growth),
            JournalPrompt(promptText: "How have you grown in patience, love, or kindness?", category: .growth),
            JournalPrompt(promptText: "What spiritual practice has become more meaningful?", category: .growth),
            JournalPrompt(promptText: "How has God used community to help you grow?", category: .growth),
            JournalPrompt(promptText: "What weakness is God turning into strength?", category: .growth),
            JournalPrompt(promptText: "How has your understanding of grace deepened?", category: .growth),
            JournalPrompt(promptText: "What area of theology do you want to learn more about?", category: .growth),
            JournalPrompt(promptText: "How has worship changed your perspective on life?", category: .growth),
            JournalPrompt(promptText: "What discipline do you need to practice more consistently?", category: .growth),
            JournalPrompt(promptText: "How is God preparing you for something greater?", category: .growth),
            JournalPrompt(promptText: "What character trait is God developing in you?", category: .growth),
            JournalPrompt(promptText: "How has your faith become more practical in daily life?", category: .growth),
            JournalPrompt(promptText: "What breakthrough have you experienced in your walk with God?", category: .growth),
            JournalPrompt(promptText: "How has God changed your priorities?", category: .growth),
            JournalPrompt(promptText: "What area of obedience is God calling you to?", category: .growth),
            JournalPrompt(promptText: "How have you grown in trusting God's timing?", category: .growth),
            JournalPrompt(promptText: "What spiritual insight have you gained recently?", category: .growth),
            JournalPrompt(promptText: "How is God shaping your identity in Christ?", category: .growth),
            JournalPrompt(promptText: "What area of your life reflects spiritual growth?", category: .growth),
            JournalPrompt(promptText: "How has God expanded your capacity to love?", category: .growth)
        ])
        
        // === CHALLENGES PROMPTS (35 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "What challenge are you facing and how can faith help?", category: .challenges),
            JournalPrompt(promptText: "How do you find strength in God during difficult times?", category: .challenges),
            JournalPrompt(promptText: "What fear do you need to surrender to God?", category: .challenges),
            JournalPrompt(promptText: "How has God helped you overcome a past struggle?", category: .challenges),
            JournalPrompt(promptText: "What worry can you give to God today?", category: .challenges),
            JournalPrompt(promptText: "How has God proven faithful in past difficulties?", category: .challenges),
            JournalPrompt(promptText: "What trial are you currently walking through?", category: .challenges),
            JournalPrompt(promptText: "How does your faith help you face uncertainty?", category: .challenges),
            JournalPrompt(promptText: "What obstacle seems impossible but God can overcome?", category: .challenges),
            JournalPrompt(promptText: "How has God used a challenge to draw you closer to Him?", category: .challenges),
            JournalPrompt(promptText: "What situation are you struggling to trust God with?", category: .challenges),
            JournalPrompt(promptText: "How do you maintain hope when circumstances are hard?", category: .challenges),
            JournalPrompt(promptText: "What burden do you need to lay down at Jesus' feet?", category: .challenges),
            JournalPrompt(promptText: "How has God provided for you in a time of need?", category: .challenges),
            JournalPrompt(promptText: "What disappointment are you processing with God?", category: .challenges),
            JournalPrompt(promptText: "How does God's presence comfort you in suffering?", category: .challenges),
            JournalPrompt(promptText: "What challenge taught you to depend more on God?", category: .challenges),
            JournalPrompt(promptText: "How has God turned a trial into a testimony?", category: .challenges),
            JournalPrompt(promptText: "What situation requires more faith than you feel you have?", category: .challenges),
            JournalPrompt(promptText: "How has God shown His power in your weakness?", category: .challenges),
            JournalPrompt(promptText: "What fear is keeping you from experiencing God's best?", category: .challenges),
            JournalPrompt(promptText: "How do you find peace when anxiety overwhelms you?", category: .challenges),
            JournalPrompt(promptText: "What unanswered question are you trusting God with?", category: .challenges),
            JournalPrompt(promptText: "How has God used pain to produce purpose in your life?", category: .challenges),
            JournalPrompt(promptText: "What challenge revealed God's faithfulness to you?", category: .challenges),
            JournalPrompt(promptText: "How do you hold onto hope when life is difficult?", category: .challenges),
            JournalPrompt(promptText: "What struggle are you asking God to help you overcome?", category: .challenges),
            JournalPrompt(promptText: "How has God met you in your darkest moments?", category: .challenges),
            JournalPrompt(promptText: "What trial is teaching you to persevere?", category: .challenges),
            JournalPrompt(promptText: "How does knowing God is with you change how you face challenges?", category: .challenges),
            JournalPrompt(promptText: "What difficulty are you learning to see from God's perspective?", category: .challenges),
            JournalPrompt(promptText: "How has God strengthened you in a time of weakness?", category: .challenges),
            JournalPrompt(promptText: "What challenge is growing your character?", category: .challenges),
            JournalPrompt(promptText: "How do you find joy even in difficult circumstances?", category: .challenges),
            JournalPrompt(promptText: "What struggle taught you that God's grace is sufficient?", category: .challenges)
        ])
        
        // === REFLECTION PROMPTS (35 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "What did God teach you today?", category: .reflection),
            JournalPrompt(promptText: "How did you see God's faithfulness today?", category: .reflection),
            JournalPrompt(promptText: "What does peace mean to you?", category: .reflection),
            JournalPrompt(promptText: "How has your perspective on life changed recently?", category: .reflection),
            JournalPrompt(promptText: "What moment today reminded you of God's presence?", category: .reflection),
            JournalPrompt(promptText: "How did you experience God's love today?", category: .reflection),
            JournalPrompt(promptText: "What decision do you need to make and how can God guide you?", category: .reflection),
            JournalPrompt(promptText: "How has this week changed you?", category: .reflection),
            JournalPrompt(promptText: "What does joy look like in your life?", category: .reflection),
            JournalPrompt(promptText: "How do you see God working in your circumstances?", category: .reflection),
            JournalPrompt(promptText: "What truth about yourself did God reveal to you?", category: .reflection),
            JournalPrompt(promptText: "How has your understanding of grace deepened?", category: .reflection),
            JournalPrompt(promptText: "What question about faith are you reflecting on?", category: .reflection),
            JournalPrompt(promptText: "How does silence and stillness help you hear from God?", category: .reflection),
            JournalPrompt(promptText: "What area of your life needs honest reflection?", category: .reflection),
            JournalPrompt(promptText: "How has God challenged your assumptions recently?", category: .reflection),
            JournalPrompt(promptText: "What does it mean to you to be made in God's image?", category: .reflection),
            JournalPrompt(promptText: "How do you see God's beauty in the world around you?", category: .reflection),
            JournalPrompt(promptText: "What relationship needs reflection and prayer?", category: .reflection),
            JournalPrompt(promptText: "How has God's timing in your life been perfect?", category: .reflection),
            JournalPrompt(promptText: "What does surrender look like in your walk with God?", category: .reflection),
            JournalPrompt(promptText: "How do you balance faith and doubt?", category: .reflection),
            JournalPrompt(promptText: "What does it mean to you to trust God completely?", category: .reflection),
            JournalPrompt(promptText: "How has God's presence felt different at various times in your life?", category: .reflection),
            JournalPrompt(promptText: "What does authentic faith look like to you?", category: .reflection),
            JournalPrompt(promptText: "How do you process difficult emotions with God?", category: .reflection),
            JournalPrompt(promptText: "What does it mean to abide in Christ?", category: .reflection),
            JournalPrompt(promptText: "How has your understanding of prayer evolved?", category: .reflection),
            JournalPrompt(promptText: "What does worship mean beyond just singing?", category: .reflection),
            JournalPrompt(promptText: "How do you see God's sovereignty in everyday life?", category: .reflection),
            JournalPrompt(promptText: "What does it mean to seek first God's kingdom?", category: .reflection),
            JournalPrompt(promptText: "How has God's love changed how you view yourself?", category: .reflection),
            JournalPrompt(promptText: "What does it mean to you to be a disciple of Christ?", category: .reflection),
            JournalPrompt(promptText: "How do you balance being in the world but not of it?", category: .reflection),
            JournalPrompt(promptText: "What does rest in God look like for you?", category: .reflection)
        ])
        
        // === RELATIONSHIPS PROMPTS (30 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "How can you love others better this week?", category: .relationships),
            JournalPrompt(promptText: "What relationship needs God's healing touch?", category: .relationships),
            JournalPrompt(promptText: "How has God used others to bless you?", category: .relationships),
            JournalPrompt(promptText: "Who needs your encouragement today?", category: .relationships),
            JournalPrompt(promptText: "How can you show Christ's love to someone this week?", category: .relationships),
            JournalPrompt(promptText: "What relationship is God calling you to invest in?", category: .relationships),
            JournalPrompt(promptText: "How can you forgive someone who hurt you?", category: .relationships),
            JournalPrompt(promptText: "Who in your life reflects God's love well?", category: .relationships),
            JournalPrompt(promptText: "What relationship needs more prayer and grace?", category: .relationships),
            JournalPrompt(promptText: "How can you be a better friend, family member, or partner?", category: .relationships),
            JournalPrompt(promptText: "Who needs your support and how can you provide it?", category: .relationships),
            JournalPrompt(promptText: "How has someone been Jesus to you recently?", category: .relationships),
            JournalPrompt(promptText: "What difficult conversation do you need to have with love?", category: .relationships),
            JournalPrompt(promptText: "How can you love someone who is hard to love?", category: .relationships),
            JournalPrompt(promptText: "What relationship needs boundaries or better communication?", category: .relationships),
            JournalPrompt(promptText: "How has God placed people in your life for a purpose?", category: .relationships),
            JournalPrompt(promptText: "Who can you thank for their impact on your faith?", category: .relationships),
            JournalPrompt(promptText: "How can you serve someone in your life this week?", category: .relationships),
            JournalPrompt(promptText: "What relationship requires more patience from you?", category: .relationships),
            JournalPrompt(promptText: "How does loving others reflect your love for God?", category: .relationships),
            JournalPrompt(promptText: "Who needs to hear that God loves them?", category: .relationships),
            JournalPrompt(promptText: "How can you be a light in your relationships?", category: .relationships),
            JournalPrompt(promptText: "What relationship taught you about God's love?", category: .relationships),
            JournalPrompt(promptText: "How can you mend a broken relationship?", category: .relationships),
            JournalPrompt(promptText: "Who needs your forgiveness and how can you extend it?", category: .relationships),
            JournalPrompt(promptText: "How has community strengthened your faith?", category: .relationships),
            JournalPrompt(promptText: "What relationship needs more intentional time?", category: .relationships),
            JournalPrompt(promptText: "How can you encourage someone who is struggling?", category: .relationships),
            JournalPrompt(promptText: "What relationship brings you closer to God?", category: .relationships),
            JournalPrompt(promptText: "How can you be more present and loving in your relationships?", category: .relationships)
        ])
        
        // === SERVICE PROMPTS (30 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "How can you serve someone today?", category: .service),
            JournalPrompt(promptText: "What act of kindness did you receive or give?", category: .service),
            JournalPrompt(promptText: "How can you use your gifts to bless others?", category: .service),
            JournalPrompt(promptText: "What need in your community breaks your heart?", category: .service),
            JournalPrompt(promptText: "How is God calling you to serve others?", category: .service),
            JournalPrompt(promptText: "What talent can you use to serve God and others?", category: .service),
            JournalPrompt(promptText: "How can you be the hands and feet of Jesus today?", category: .service),
            JournalPrompt(promptText: "What injustice can you help address?", category: .service),
            JournalPrompt(promptText: "How has serving others changed your perspective?", category: .service),
            JournalPrompt(promptText: "What need can you meet for someone in your community?", category: .service),
            JournalPrompt(promptText: "How can you serve even in small ways today?", category: .service),
            JournalPrompt(promptText: "What ministry or organization can you support?", category: .service),
            JournalPrompt(promptText: "How does serving others reflect Christ's love?", category: .service),
            JournalPrompt(promptText: "What gift has God given you that can bless others?", category: .service),
            JournalPrompt(promptText: "How can you use your time to serve someone?", category: .service),
            JournalPrompt(promptText: "What act of service changed someone's day?", category: .service),
            JournalPrompt(promptText: "How has serving brought you joy?", category: .service),
            JournalPrompt(promptText: "What need can you address in your neighborhood?", category: .service),
            JournalPrompt(promptText: "How can you serve your church or faith community?", category: .service),
            JournalPrompt(promptText: "What skill can you use to help someone?", category: .service),
            JournalPrompt(promptText: "How does serving with humility reflect Jesus?", category: .service),
            JournalPrompt(promptText: "What opportunity to serve are you grateful for?", category: .service),
            JournalPrompt(promptText: "How can you serve someone who can't repay you?", category: .service),
            JournalPrompt(promptText: "What act of service taught you about God's love?", category: .service),
            JournalPrompt(promptText: "How can you be generous with your resources today?", category: .service),
            JournalPrompt(promptText: "What need can you help meet in your family?", category: .service),
            JournalPrompt(promptText: "How has serving others strengthened your faith?", category: .service),
            JournalPrompt(promptText: "What way to serve aligns with your passions?", category: .service),
            JournalPrompt(promptText: "How can you make serving a regular part of your life?", category: .service),
            JournalPrompt(promptText: "What act of service do you want to remember?", category: .service)
        ])
        
        // === MORNING PROMPTS (35 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "What are you praying for as you start this day?", category: .morning),
            JournalPrompt(promptText: "How can you honor God with your actions today?", category: .morning),
            JournalPrompt(promptText: "What scripture can guide you through today?", category: .morning),
            JournalPrompt(promptText: "What intention are you setting for today?", category: .morning),
            JournalPrompt(promptText: "How can you be a light to others today?", category: .morning),
            JournalPrompt(promptText: "What do you need God's strength for today?", category: .morning),
            JournalPrompt(promptText: "How can you show God's love today?", category: .morning),
            JournalPrompt(promptText: "What attitude do you want to have today?", category: .morning),
            JournalPrompt(promptText: "How can you start your day with gratitude?", category: .morning),
            JournalPrompt(promptText: "What goal do you have for today that aligns with God's will?", category: .morning),
            JournalPrompt(promptText: "How can you be present and mindful today?", category: .morning),
            JournalPrompt(promptText: "What opportunity do you want to seize today?", category: .morning),
            JournalPrompt(promptText: "How can you make today count for God's kingdom?", category: .morning),
            JournalPrompt(promptText: "What do you want to surrender to God this morning?", category: .morning),
            JournalPrompt(promptText: "How can you be kind and patient today?", category: .morning),
            JournalPrompt(promptText: "What challenge will you face with God's help today?", category: .morning),
            JournalPrompt(promptText: "How can you serve someone today?", category: .morning),
            JournalPrompt(promptText: "What do you want to learn or grow in today?", category: .morning),
            JournalPrompt(promptText: "How can you trust God with today's unknowns?", category: .morning),
            JournalPrompt(promptText: "What promise from God do you want to hold onto today?", category: .morning),
            JournalPrompt(promptText: "How can you be more like Jesus today?", category: .morning),
            JournalPrompt(promptText: "What conversation do you need God's wisdom for today?", category: .morning),
            JournalPrompt(promptText: "How can you spread joy and encouragement today?", category: .morning),
            JournalPrompt(promptText: "What do you need to let go of to have peace today?", category: .morning),
            JournalPrompt(promptText: "How can you practice gratitude throughout today?", category: .morning),
            JournalPrompt(promptText: "What boundary do you need to set for today?", category: .morning),
            JournalPrompt(promptText: "How can you rest in God's provision today?", category: .morning),
            JournalPrompt(promptText: "What decision needs God's guidance today?", category: .morning),
            JournalPrompt(promptText: "How can you be generous with your time, resources, or love today?", category: .morning),
            JournalPrompt(promptText: "What do you want God to do in your heart today?", category: .morning),
            JournalPrompt(promptText: "How can you listen for God's voice today?", category: .morning),
            JournalPrompt(promptText: "What do you want to accomplish with God's help today?", category: .morning),
            JournalPrompt(promptText: "How can you bless someone unexpectedly today?", category: .morning),
            JournalPrompt(promptText: "What do you need to pray about before starting your day?", category: .morning),
            JournalPrompt(promptText: "How can you make today meaningful and purposeful?", category: .morning)
        ])
        
        // === EVENING PROMPTS (35 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "What are you grateful for from today?", category: .evening),
            JournalPrompt(promptText: "How did God show up in your day?", category: .evening),
            JournalPrompt(promptText: "What would you like to surrender to God tonight?", category: .evening),
            JournalPrompt(promptText: "How can you rest in God's peace tonight?", category: .evening),
            JournalPrompt(promptText: "What did you learn about yourself or God today?", category: .evening),
            JournalPrompt(promptText: "What prayer do you want to carry into tomorrow?", category: .evening),
            JournalPrompt(promptText: "How did you see God's faithfulness today?", category: .evening),
            JournalPrompt(promptText: "What moment from today will you remember?", category: .evening),
            JournalPrompt(promptText: "How did you grow or change today?", category: .evening),
            JournalPrompt(promptText: "What challenge did you face and how did God help?", category: .evening),
            JournalPrompt(promptText: "What do you need to let go of before tomorrow?", category: .evening),
            JournalPrompt(promptText: "How can you reflect on God's goodness from today?", category: .evening),
            JournalPrompt(promptText: "What conversation or interaction impacted you today?", category: .evening),
            JournalPrompt(promptText: "How did you experience God's love today?", category: .evening),
            JournalPrompt(promptText: "What mistake or failure can you learn from?", category: .evening),
            JournalPrompt(promptText: "How did you serve or bless someone today?", category: .evening),
            JournalPrompt(promptText: "What answered prayer can you thank God for?", category: .evening),
            JournalPrompt(promptText: "How did you see God's provision today?", category: .evening),
            JournalPrompt(promptText: "What worry can you release to God tonight?", category: .evening),
            JournalPrompt(promptText: "How can you prepare your heart for tomorrow?", category: .evening),
            JournalPrompt(promptText: "What blessing did you receive or give today?", category: .evening),
            JournalPrompt(promptText: "How did God teach you something today?", category: .evening),
            JournalPrompt(promptText: "What struggle are you trusting God with tonight?", category: .evening),
            JournalPrompt(promptText: "How did you practice faith today?", category: .evening),
            JournalPrompt(promptText: "What do you want to thank God for from today?", category: .evening),
            JournalPrompt(promptText: "How did you grow closer to God today?", category: .evening),
            JournalPrompt(promptText: "What moment brought you peace today?", category: .evening),
            JournalPrompt(promptText: "How can you rest knowing God is in control?", category: .evening),
            JournalPrompt(promptText: "What decision do you need God's wisdom for tomorrow?", category: .evening),
            JournalPrompt(promptText: "How did you show or receive kindness today?", category: .evening),
            JournalPrompt(promptText: "What do you want God to work on in your heart tonight?", category: .evening),
            JournalPrompt(promptText: "How can you end today in gratitude and peace?", category: .evening),
            JournalPrompt(promptText: "What answered prayer or blessing surprised you today?", category: .evening),
            JournalPrompt(promptText: "How did you experience God's grace today?", category: .evening),
            JournalPrompt(promptText: "What do you want to carry forward from today into tomorrow?", category: .evening)
        ])
        
        // === GENERAL PROMPTS (25 prompts) ===
        prompts.append(contentsOf: [
            JournalPrompt(promptText: "What's on your heart today?", category: .general),
            JournalPrompt(promptText: "How is your relationship with God today?", category: .general),
            JournalPrompt(promptText: "What brings you closer to God?", category: .general),
            JournalPrompt(promptText: "What does your faith journey look like right now?", category: .general),
            JournalPrompt(promptText: "How do you feel God's presence in your life?", category: .general),
            JournalPrompt(promptText: "What question about faith are you wrestling with?", category: .general),
            JournalPrompt(promptText: "How has God been speaking to you recently?", category: .general),
            JournalPrompt(promptText: "What does living out your faith mean to you?", category: .general),
            JournalPrompt(promptText: "How do you balance faith and daily life?", category: .general),
            JournalPrompt(promptText: "What does being a Christian mean to you?", category: .general),
            JournalPrompt(promptText: "How has your faith shaped your identity?", category: .general),
            JournalPrompt(promptText: "What does following Jesus look like in your life?", category: .general),
            JournalPrompt(promptText: "How do you see God at work in the world?", category: .general),
            JournalPrompt(promptText: "What does it mean to you to have a personal relationship with God?", category: .general),
            JournalPrompt(promptText: "How does your faith give you purpose?", category: .general),
            JournalPrompt(promptText: "What does it mean to trust God with your whole life?", category: .general),
            JournalPrompt(promptText: "How has your faith helped you through life's ups and downs?", category: .general),
            JournalPrompt(promptText: "What does it mean to you to be made new in Christ?", category: .general),
            JournalPrompt(promptText: "How do you experience God's love in your daily life?", category: .general),
            JournalPrompt(promptText: "What does it mean to live by faith and not by sight?", category: .general),
            JournalPrompt(promptText: "How does your faith impact how you treat others?", category: .general),
            JournalPrompt(promptText: "What does it mean to you to be part of God's family?", category: .general),
            JournalPrompt(promptText: "How has God's grace transformed your understanding of yourself?", category: .general),
            JournalPrompt(promptText: "What does walking with God daily mean to you?", category: .general),
            JournalPrompt(promptText: "How do you want to grow in your relationship with God?", category: .general)
        ])
        
        // Ensure we have exactly 365 prompts
        while prompts.count < 365 {
            // If somehow we're short, duplicate from general category
            let generalPrompts = prompts.filter { $0.category == .general }
            if let prompt = generalPrompts.randomElement() {
                prompts.append(JournalPrompt(promptText: prompt.promptText, category: prompt.category))
            } else {
                break
            }
        }
        
        // Trim to exactly 365
        return Array(prompts.prefix(365))
    }
    
    struct StoredPrompt: Codable {
        let promptText: String
        let category: JournalPrompt.PromptCategory
    }
}
