import Foundation
import SwiftUI

struct Devotional: Identifiable, Codable {
    let id = UUID()
    let title: String
    let scripture: String
    let content: String
    let author: String
    let date: Date
    let category: String
    let isCompleted: Bool
    
    init(title: String, scripture: String, content: String, author: String, date: Date, category: String, isCompleted: Bool = false) {
        self.title = title
        self.scripture = scripture
        self.content = content
        self.author = author
        self.date = date
        self.category = category
        self.isCompleted = isCompleted
    }
}

class DevotionalManager: ObservableObject {
    @Published var devotionals: [Devotional] = []
    @Published var selectedCategory: String = "All"
    @Published var isLoading = false
    
    let categories = ["All", "Faith", "Hope", "Love", "Prayer", "Gratitude", "Forgiveness", "Service"]
    
    init() {
        loadDevotionals()
    }
    
    func loadDevotionals() {
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.devotionals = self.getSampleDevotionals()
            self.isLoading = false
        }
    }
    
    func getSampleDevotionals() -> [Devotional] {
        let calendar = Calendar.current
        let today = Date()
        
        return [
            Devotional(
                title: "Walking in Faith",
                scripture: "Hebrews 11:1",
                content: "Faith is the confidence that what we hope for will actually happen; it gives us assurance about things we cannot see. Today, let's reflect on what faith means in our daily lives. When we face uncertainty, faith reminds us that God is in control. When we feel overwhelmed, faith tells us that God will provide. Take a moment to consider: What are you trusting God for today? How can you step out in faith in your current situation?",
                author: "Daily Faith",
                date: calendar.date(byAdding: .day, value: 0, to: today) ?? today,
                category: "Faith"
            ),
            Devotional(
                title: "The Power of Hope",
                scripture: "Romans 15:13",
                content: "May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope by the power of the Holy Spirit. Hope is not wishful thinking—it's confident expectation based on God's promises. In difficult times, hope sustains us. It reminds us that our current circumstances are temporary and that God has a plan for our lives. Today, let's choose hope over despair, knowing that God is working all things for our good.",
                author: "Hope Daily",
                date: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
                category: "Hope"
            ),
            Devotional(
                title: "Love One Another",
                scripture: "1 John 4:7-8",
                content: "Dear friends, let us love one another, for love comes from God. Everyone who loves has been born of God and knows God. Whoever does not love does not know God, because God is love. Love is not just a feeling—it's an action. It's choosing to put others first, to forgive, to serve, to be patient and kind. Today, look for opportunities to show God's love to those around you. It might be a kind word, a helping hand, or simply being present for someone who needs you.",
                author: "Love in Action",
                date: calendar.date(byAdding: .day, value: -2, to: today) ?? today,
                category: "Love"
            ),
            Devotional(
                title: "Prayer Changes Things",
                scripture: "Philippians 4:6-7",
                content: "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus. Prayer is our direct line to God. It's not about changing God's mind—it's about aligning our hearts with His will. When we pray, we acknowledge our dependence on God and invite Him to work in our lives. Take time today to pray about your concerns, your gratitude, and your hopes.",
                author: "Prayer Warrior",
                date: calendar.date(byAdding: .day, value: -3, to: today) ?? today,
                category: "Prayer"
            ),
            Devotional(
                title: "Grateful Heart",
                scripture: "1 Thessalonians 5:18",
                content: "Give thanks in all circumstances; for this is God's will for you in Christ Jesus. Gratitude is a choice, not a feeling. Even in difficult times, we can find things to be thankful for. When we focus on our blessings rather than our problems, our perspective changes. Gratitude opens our hearts to God's presence and helps us see His hand at work in our lives. Today, make a list of things you're grateful for, no matter how small they may seem.",
                author: "Grateful Living",
                date: calendar.date(byAdding: .day, value: -4, to: today) ?? today,
                category: "Gratitude"
            ),
            Devotional(
                title: "Forgiveness Sets You Free",
                scripture: "Colossians 3:13",
                content: "Bear with each other and forgive one another if any of you has a grievance against someone. Forgive as the Lord forgave you. Forgiveness is not about excusing wrong behavior—it's about freeing yourself from the burden of bitterness and resentment. When we forgive, we choose to let go of the hurt and trust God to handle justice. Forgiveness is a gift we give ourselves. Today, consider if there's someone you need to forgive, or if you need to ask for forgiveness.",
                author: "Freedom in Christ",
                date: calendar.date(byAdding: .day, value: -5, to: today) ?? today,
                category: "Forgiveness"
            ),
            Devotional(
                title: "Serving Others",
                scripture: "Galatians 5:13",
                content: "You, my brothers and sisters, were called to be free. But do not use your freedom to indulge the flesh; rather, serve one another humbly in love. Service is love in action. When we serve others, we reflect God's love and demonstrate the heart of Christ. Service doesn't have to be grand gestures—it can be simple acts of kindness like listening to someone, helping with a task, or offering encouragement. Look for ways to serve those around you today.",
                author: "Service with Love",
                date: calendar.date(byAdding: .day, value: -6, to: today) ?? today,
                category: "Service"
            ),
            Devotional(
                title: "Trusting God's Plan",
                scripture: "Jeremiah 29:11",
                content: "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future. God has a plan for your life, and it's a good plan. Even when we can't see the way forward, we can trust that God is leading us. His timing is perfect, and His ways are higher than our ways. Today, surrender your plans to God and trust that He is working everything together for your good.",
                author: "Divine Purpose",
                date: calendar.date(byAdding: .day, value: -7, to: today) ?? today,
                category: "Faith"
            )
        ]
    }
    
    func filteredDevotionals() -> [Devotional] {
        if selectedCategory == "All" {
            return devotionals
        } else {
            return devotionals.filter { $0.category == selectedCategory }
        }
    }
    
    func markAsCompleted(_ devotional: Devotional) {
        if let index = devotionals.firstIndex(where: { $0.id == devotional.id }) {
            devotionals[index] = Devotional(
                title: devotional.title,
                scripture: devotional.scripture,
                content: devotional.content,
                author: devotional.author,
                date: devotional.date,
                category: devotional.category,
                isCompleted: true
            )
        }
    }
    
    func getTodaysDevotional() -> Devotional? {
        let calendar = Calendar.current
        let today = Date()
        return devotionals.first { devotional in
            calendar.isDate(devotional.date, inSameDayAs: today)
        }
    }
} 