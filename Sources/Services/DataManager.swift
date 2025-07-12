import Foundation
import SwiftData
import SwiftUI

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    private init() {}
    
    // MARK: - Journal Entries
    func addJournalEntry(_ entry: JournalEntry, context: ModelContext) {
        context.insert(entry)
        try? context.save()
    }
    
    func deleteJournalEntry(_ entry: JournalEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }
    
    func updateJournalEntry(_ entry: JournalEntry, context: ModelContext) {
        entry.updatedAt = Date()
        try? context.save()
    }
    
    // MARK: - Prayer Requests
    func addPrayerRequest(_ request: PrayerRequest, context: ModelContext) {
        context.insert(request)
        try? context.save()
    }
    
    func deletePrayerRequest(_ request: PrayerRequest, context: ModelContext) {
        context.delete(request)
        try? context.save()
    }
    
    func updatePrayerRequest(_ request: PrayerRequest, context: ModelContext) {
        request.updatedAt = Date()
        try? context.save()
    }
    
    // MARK: - Devotionals
    func addDevotional(_ devotional: Devotional, context: ModelContext) {
        context.insert(devotional)
        try? context.save()
    }
    
    func deleteDevotional(_ devotional: Devotional, context: ModelContext) {
        context.delete(devotional)
        try? context.save()
    }
    
    func updateDevotional(_ devotional: Devotional, context: ModelContext) {
        try? context.save()
    }
    
    // MARK: - Bible Verse of the Day
    func addBibleVerseOfTheDay(_ verse: BibleVerseOfTheDay, context: ModelContext) {
        context.insert(verse)
        try? context.save()
    }
    
    func deleteBibleVerseOfTheDay(_ verse: BibleVerseOfTheDay, context: ModelContext) {
        context.delete(verse)
        try? context.save()
    }
    
    // MARK: - Mood Entries
    func addMoodEntry(_ entry: MoodEntry, context: ModelContext) {
        context.insert(entry)
        try? context.save()
    }
    
    func deleteMoodEntry(_ entry: MoodEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }
    
    // MARK: - Live Sessions
    func addLiveSession(_ session: LiveSession, context: ModelContext) {
        context.insert(session)
        try? context.save()
    }
    
    func deleteLiveSession(_ session: LiveSession, context: ModelContext) {
        context.delete(session)
        try? context.save()
    }
    
    func updateLiveSession(_ session: LiveSession, context: ModelContext) {
        try? context.save()
    }
    
    // MARK: - Sample Data
    func addSampleDevotionals(context: ModelContext) {
        let sampleDevotionals = [
            Devotional(
                title: "Finding Peace in God's Presence",
                content: "In the midst of life's chaos, we often forget that God is always with us. Take a moment today to simply be still and know that He is God. His presence brings peace that surpasses all understanding.",
                author: "Sarah Johnson",
                category: "Peace",
                tags: ["peace", "presence", "meditation"]
            ),
            Devotional(
                title: "The Power of Gratitude",
                content: "Gratitude transforms our perspective and opens our hearts to God's blessings. When we focus on what we have rather than what we lack, we discover joy in unexpected places.",
                author: "Michael Chen",
                category: "Gratitude",
                tags: ["gratitude", "joy", "blessings"]
            ),
            Devotional(
                title: "Walking in Faith",
                content: "Faith is not the absence of doubt, but the courage to trust God even when we don't understand. Each step of faith brings us closer to His perfect plan for our lives.",
                author: "David Rodriguez",
                category: "Faith",
                tags: ["faith", "trust", "courage"]
            ),
            Devotional(
                title: "God's Unfailing Love",
                content: "No matter what you've done or where you've been, God's love for you never changes. His love is unconditional, unfailing, and everlasting. Rest in that truth today.",
                author: "Emily Thompson",
                category: "Love",
                tags: ["love", "forgiveness", "grace"]
            ),
            Devotional(
                title: "Finding Strength in Weakness",
                content: "When we feel weak and inadequate, that's when God's strength is most evident. His power is made perfect in our weakness. Don't be afraid to admit your need for Him.",
                author: "James Wilson",
                category: "Strength",
                tags: ["strength", "weakness", "power"]
            )
        ]
        
        for devotional in sampleDevotionals {
            context.insert(devotional)
        }
        
        try? context.save()
    }
    
    func addSampleBibleVerses(context: ModelContext) {
        let sampleVerses = [
            BibleVerseOfTheDay(
                verse: "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.",
                reference: "Jeremiah 29:11",
                translation: "NIV"
            ),
            BibleVerseOfTheDay(
                verse: "I can do all this through him who gives me strength.",
                reference: "Philippians 4:13",
                translation: "NIV"
            ),
            BibleVerseOfTheDay(
                verse: "Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.",
                reference: "Joshua 1:9",
                translation: "NIV"
            ),
            BibleVerseOfTheDay(
                verse: "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.",
                reference: "Proverbs 3:5-6",
                translation: "NIV"
            ),
            BibleVerseOfTheDay(
                verse: "The Lord is my shepherd, I lack nothing.",
                reference: "Psalm 23:1",
                translation: "NIV"
            )
        ]
        
        for verse in sampleVerses {
            context.insert(verse)
        }
        
        try? context.save()
    }
} 