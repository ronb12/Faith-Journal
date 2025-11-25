import Foundation
import SwiftUI

struct Devotional: Identifiable, Codable {
    var id = UUID()
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
    
    let categories = ["All", "Faith", "Hope", "Love", "Prayer", "Gratitude", "Forgiveness", "Service", "Wisdom", "Courage", "Peace", "Growth"]
    
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
            // Faith Category
            Devotional(
                title: "Walking in Faith",
                scripture: "Hebrews 11:1",
                content: "Faith is the confidence that what we hope for will actually happen; it gives us assurance about things we cannot see. Today, let's reflect on what faith means in our daily lives. When we face uncertainty, faith reminds us that God is in control. When we feel overwhelmed, faith tells us that God will provide. Take a moment to consider: What are you trusting God for today? How can you step out in faith in your current situation?",
                author: "Daily Faith",
                date: calendar.date(byAdding: .day, value: 0, to: today) ?? today,
                category: "Faith"
            ),
            Devotional(
                title: "Trusting God's Plan",
                scripture: "Jeremiah 29:11",
                content: "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future. God has a plan for your life, and it's a good plan. Even when we can't see the way forward, we can trust that God is leading us. His timing is perfect, and His ways are higher than our ways. Today, surrender your plans to God and trust that He is working everything together for your good.",
                author: "Divine Purpose",
                date: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
                category: "Faith"
            ),
            Devotional(
                title: "Living by Faith",
                scripture: "2 Corinthians 5:7",
                content: "For we live by faith, not by sight. This powerful truth reminds us that our spiritual journey is not about what we can see or understand with our natural senses. Faith calls us to trust in God's promises even when circumstances seem contrary. Today, ask yourself: Am I making decisions based on what I can see, or am I trusting God's guidance? How can I step out in faith today?",
                author: "Faith Walk",
                date: calendar.date(byAdding: .day, value: -2, to: today) ?? today,
                category: "Faith"
            ),
            
            // Hope Category
            Devotional(
                title: "The Power of Hope",
                scripture: "Romans 15:13",
                content: "May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope by the power of the Holy Spirit. Hope is not wishful thinking—it's confident expectation based on God's promises. In difficult times, hope sustains us. It reminds us that our current circumstances are temporary and that God has a plan for our lives. Today, let's choose hope over despair, knowing that God is working all things for our good.",
                author: "Hope Daily",
                date: calendar.date(byAdding: .day, value: -3, to: today) ?? today,
                category: "Hope"
            ),
            Devotional(
                title: "New Mercies Every Morning",
                scripture: "Lamentations 3:22-23",
                content: "Because of the Lord's great love we are not consumed, for his compassions never fail. They are new every morning; great is your faithfulness. Each new day brings fresh opportunities and new mercies from God. No matter what yesterday held, today is a chance to start again. God's faithfulness never wavers, and His love never runs out. Today, embrace the new mercies God has prepared for you.",
                author: "Morning Grace",
                date: calendar.date(byAdding: .day, value: -4, to: today) ?? today,
                category: "Hope"
            ),
            Devotional(
                title: "Unshakeable Hope",
                scripture: "Psalm 27:1",
                content: "The Lord is my light and my salvation—whom shall I fear? The Lord is the stronghold of my life—of whom shall I be afraid? When we place our hope in God, we find an unshakeable foundation. He is our light in darkness, our salvation in trouble, and our stronghold in times of fear. Today, let this truth sink deep into your heart: with God as your stronghold, you have nothing to fear.",
                author: "Unshakeable",
                date: calendar.date(byAdding: .day, value: -5, to: today) ?? today,
                category: "Hope"
            ),
            
            // Love Category
            Devotional(
                title: "Love One Another",
                scripture: "1 John 4:7-8",
                content: "Dear friends, let us love one another, for love comes from God. Everyone who loves has been born of God and knows God. Whoever does not love does not know God, because God is love. Love is not just a feeling—it's an action. It's choosing to put others first, to forgive, to serve, to be patient and kind. Today, look for opportunities to show God's love to those around you. It might be a kind word, a helping hand, or simply being present for someone who needs you.",
                author: "Love in Action",
                date: calendar.date(byAdding: .day, value: -6, to: today) ?? today,
                category: "Love"
            ),
            Devotional(
                title: "The Greatest Commandment",
                scripture: "Matthew 22:37-39",
                content: "Jesus replied: \"Love the Lord your God with all your heart and with all your soul and with all your mind.\" This is the first and greatest commandment. And the second is like it: \"Love your neighbor as yourself.\" Love is the foundation of our faith. It's not just about feelings, but about commitment and action. Today, ask yourself: How am I showing love to God? How am I showing love to others? How am I showing love to myself?",
                author: "Love Foundation",
                date: calendar.date(byAdding: .day, value: -7, to: today) ?? today,
                category: "Love"
            ),
            Devotional(
                title: "Love is Patient",
                scripture: "1 Corinthians 13:4-7",
                content: "Love is patient, love is kind. It does not envy, it does not boast, it is not proud. It does not dishonor others, it is not self-seeking, it is not easily angered, it keeps no record of wrongs. Love does not delight in evil but rejoices with the truth. It always protects, always trusts, always hopes, always perseveres. This is the kind of love God calls us to practice. Today, reflect on how you can demonstrate this kind of love in your relationships.",
                author: "Patient Love",
                date: calendar.date(byAdding: .day, value: -8, to: today) ?? today,
                category: "Love"
            ),
            
            // Prayer Category
            Devotional(
                title: "Prayer Changes Things",
                scripture: "Philippians 4:6-7",
                content: "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus. Prayer is our direct line to God. It's not about changing God's mind—it's about aligning our hearts with His will. When we pray, we acknowledge our dependence on God and invite Him to work in our lives. Take time today to pray about your concerns, your gratitude, and your hopes.",
                author: "Prayer Warrior",
                date: calendar.date(byAdding: .day, value: -9, to: today) ?? today,
                category: "Prayer"
            ),
            Devotional(
                title: "Pray Continually",
                scripture: "1 Thessalonians 5:16-18",
                content: "Rejoice always, pray continually, give thanks in all circumstances; for this is God's will for you in Christ Jesus. Prayer is not just for crisis moments—it's a way of life. We are called to maintain an ongoing conversation with God throughout our day. This means bringing everything to Him: our joys, our struggles, our decisions, our gratitude. Today, practice praying continually by turning your thoughts into prayers.",
                author: "Prayer Life",
                date: calendar.date(byAdding: .day, value: -10, to: today) ?? today,
                category: "Prayer"
            ),
            Devotional(
                title: "The Power of Prayer",
                scripture: "James 5:16",
                content: "Therefore confess your sins to each other and pray for each other so that you may be healed. The prayer of a righteous person is powerful and effective. Prayer is not just a personal practice—it's also a communal one. When we pray for others and allow others to pray for us, we experience the power of intercession. Today, consider who you can pray for, and who you can ask to pray for you.",
                author: "Powerful Prayer",
                date: calendar.date(byAdding: .day, value: -11, to: today) ?? today,
                category: "Prayer"
            ),
            
            // Gratitude Category
            Devotional(
                title: "Grateful Heart",
                scripture: "1 Thessalonians 5:18",
                content: "Give thanks in all circumstances; for this is God's will for you in Christ Jesus. Gratitude is a choice, not a feeling. Even in difficult times, we can find things to be thankful for. When we focus on our blessings rather than our problems, our perspective changes. Gratitude opens our hearts to God's presence and helps us see His hand at work in our lives. Today, make a list of things you're grateful for, no matter how small they may seem.",
                author: "Grateful Living",
                date: calendar.date(byAdding: .day, value: -12, to: today) ?? today,
                category: "Gratitude"
            ),
            Devotional(
                title: "Enter with Thanksgiving",
                scripture: "Psalm 100:4",
                content: "Enter his gates with thanksgiving and his courts with praise; give thanks to him and praise his name. Thanksgiving is not just a holiday—it's an attitude of the heart. When we approach God with thanksgiving, we acknowledge His goodness and provision in our lives. Today, take time to thank God for His faithfulness, His love, and His provision in your life.",
                author: "Thanksgiving Heart",
                date: calendar.date(byAdding: .day, value: -13, to: today) ?? today,
                category: "Gratitude"
            ),
            Devotional(
                title: "Count Your Blessings",
                scripture: "Psalm 136:1",
                content: "Give thanks to the Lord, for he is good. His love endures forever. Sometimes we need to intentionally count our blessings to remember how good God has been to us. His love endures forever—this is a truth that never changes, regardless of our circumstances. Today, take time to count your blessings and thank God for His enduring love.",
                author: "Blessing Counter",
                date: calendar.date(byAdding: .day, value: -14, to: today) ?? today,
                category: "Gratitude"
            ),
            
            // Forgiveness Category
            Devotional(
                title: "Forgiveness Sets You Free",
                scripture: "Colossians 3:13",
                content: "Bear with each other and forgive one another if any of you has a grievance against someone. Forgive as the Lord forgave you. Forgiveness is not about excusing wrong behavior—it's about freeing yourself from the burden of bitterness and resentment. When we forgive, we choose to let go of the hurt and trust God to handle justice. Forgiveness is a gift we give ourselves. Today, consider if there's someone you need to forgive, or if you need to ask for forgiveness.",
                author: "Freedom in Christ",
                date: calendar.date(byAdding: .day, value: -15, to: today) ?? today,
                category: "Forgiveness"
            ),
            Devotional(
                title: "Forgive as You've Been Forgiven",
                scripture: "Ephesians 4:32",
                content: "Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you. We forgive because we have been forgiven. God's forgiveness of our sins through Christ is the model and motivation for our forgiveness of others. Today, reflect on the depth of God's forgiveness in your life and let that inspire you to extend forgiveness to others.",
                author: "Forgiven to Forgive",
                date: calendar.date(byAdding: .day, value: -16, to: today) ?? today,
                category: "Forgiveness"
            ),
            Devotional(
                title: "Confess and Be Forgiven",
                scripture: "1 John 1:9",
                content: "If we confess our sins, he is faithful and just and will forgive us our sins and purify us from all unrighteousness. God is always ready to forgive when we come to Him with a repentant heart. He doesn't just forgive—He also purifies us from all unrighteousness. Today, take time to confess any sins to God and receive His forgiveness and purification.",
                author: "Confession and Grace",
                date: calendar.date(byAdding: .day, value: -17, to: today) ?? today,
                category: "Forgiveness"
            ),
            
            // Service Category
            Devotional(
                title: "Serving Others",
                scripture: "Galatians 5:13",
                content: "You, my brothers and sisters, were called to be free. But do not use your freedom to indulge the flesh; rather, serve one another humbly in love. Service is love in action. When we serve others, we reflect God's love and demonstrate the heart of Christ. Service doesn't have to be grand gestures—it can be simple acts of kindness like listening to someone, helping with a task, or offering encouragement. Look for ways to serve those around you today.",
                author: "Service with Love",
                date: calendar.date(byAdding: .day, value: -18, to: today) ?? today,
                category: "Service"
            ),
            Devotional(
                title: "It is More Blessed to Give",
                scripture: "Acts 20:35",
                content: "In everything I did, I showed you that by this kind of hard work we must help the weak, remembering the words the Lord Jesus himself said: 'It is more blessed to give than to receive.' Jesus' words remind us that true blessing comes from giving rather than receiving. When we give of our time, resources, or talents to help others, we experience the joy that comes from serving. Today, look for opportunities to give to others.",
                author: "Blessed to Give",
                date: calendar.date(byAdding: .day, value: -19, to: today) ?? today,
                category: "Service"
            ),
            Devotional(
                title: "Do Good and Share",
                scripture: "Hebrews 13:16",
                content: "And do not forget to do good and to share with others, for with such sacrifices God is pleased. God is pleased when we do good and share with others. These acts of service are sacrifices that honor Him. Today, consider how you can do good and share with others. It might be sharing your time, your resources, your skills, or your encouragement.",
                author: "Good Deeds",
                date: calendar.date(byAdding: .day, value: -20, to: today) ?? today,
                category: "Service"
            ),
            
            // Wisdom Category
            Devotional(
                title: "Ask for Wisdom",
                scripture: "James 1:5",
                content: "If any of you lacks wisdom, you should ask God, who gives generously to all without finding fault, and it will be given to you. God is the source of all wisdom, and He promises to give it generously to those who ask. He doesn't find fault with our questions or our need for guidance. Today, if you're facing a decision or need wisdom, ask God for it with confidence.",
                author: "Wisdom Seeker",
                date: calendar.date(byAdding: .day, value: -21, to: today) ?? today,
                category: "Wisdom"
            ),
            Devotional(
                title: "God's Word is a Lamp",
                scripture: "Psalm 119:105",
                content: "Your word is a lamp for my feet, a light on my path. God's Word provides guidance and direction for our lives. It illuminates our path and helps us navigate through life's challenges and decisions. Today, spend time in God's Word and let it guide your steps and decisions.",
                author: "Word of Light",
                date: calendar.date(byAdding: .day, value: -22, to: today) ?? today,
                category: "Wisdom"
            ),
            Devotional(
                title: "Commit Your Plans",
                scripture: "Proverbs 16:3",
                content: "Commit to the Lord whatever you do, and he will establish your plans. When we commit our plans to the Lord, we acknowledge His sovereignty and invite His guidance. He promises to establish our plans when they align with His will. Today, commit your plans and decisions to the Lord and trust Him to guide you.",
                author: "Plans Committed",
                date: calendar.date(byAdding: .day, value: -23, to: today) ?? today,
                category: "Wisdom"
            ),
            
            // Courage Category
            Devotional(
                title: "Be Strong and Courageous",
                scripture: "Joshua 1:9",
                content: "Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go. God commands us to be strong and courageous, not because we have the strength within ourselves, but because He is with us. His presence gives us the courage to face any challenge. Today, remember that God is with you and let that give you courage.",
                author: "Courageous Heart",
                date: calendar.date(byAdding: .day, value: -24, to: today) ?? today,
                category: "Courage"
            ),
            Devotional(
                title: "Power, Love, and Self-Discipline",
                scripture: "2 Timothy 1:7",
                content: "For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline. The Holy Spirit gives us power, love, and self-discipline—not timidity. We have been equipped with everything we need to live courageously. Today, tap into the power, love, and self-discipline that the Holy Spirit provides.",
                author: "Spirit Empowered",
                date: calendar.date(byAdding: .day, value: -25, to: today) ?? today,
                category: "Courage"
            ),
            Devotional(
                title: "The Lord is My Light",
                scripture: "Psalm 27:1",
                content: "The Lord is my light and my salvation—whom shall I fear? The Lord is the stronghold of my life—of whom shall I be afraid? When the Lord is our light and stronghold, we have nothing to fear. He illuminates our path and protects us from harm. Today, let this truth give you courage: with God as your light and stronghold, you are safe and secure.",
                author: "Fearless in Christ",
                date: calendar.date(byAdding: .day, value: -26, to: today) ?? today,
                category: "Courage"
            ),
            
            // Peace Category
            Devotional(
                title: "Peace I Leave with You",
                scripture: "John 14:27",
                content: "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid. Jesus gives us a peace that is different from the world's peace. It's a deep, abiding peace that transcends circumstances. Today, receive the peace that Jesus offers and let it guard your heart against trouble and fear.",
                author: "Peace of Christ",
                date: calendar.date(byAdding: .day, value: -27, to: today) ?? today,
                category: "Peace"
            ),
            Devotional(
                title: "Peace that Transcends Understanding",
                scripture: "Philippians 4:6-7",
                content: "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus. God's peace transcends our understanding—it doesn't always make sense in human terms, but it guards our hearts and minds. Today, present your requests to God and receive His peace.",
                author: "Transcendent Peace",
                date: calendar.date(byAdding: .day, value: -28, to: today) ?? today,
                category: "Peace"
            ),
            Devotional(
                title: "Come to Me and Rest",
                scripture: "Matthew 11:28-30",
                content: "Come to me, all you who are weary and burdened, and I will give you rest. Take my yoke upon you and learn from me, for I am gentle and humble in heart, and you will find rest for your souls. For my yoke is easy and my burden is light. Jesus invites us to come to Him when we're weary and burdened. He promises to give us rest and make our burdens light. Today, come to Jesus with your weariness and burdens and find rest for your soul.",
                author: "Rest in Christ",
                date: calendar.date(byAdding: .day, value: -29, to: today) ?? today,
                category: "Peace"
            ),
            
            // Growth Category
            Devotional(
                title: "New Creation",
                scripture: "2 Corinthians 5:17",
                content: "Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here! In Christ, we are new creations. The old has passed away and the new has come. This transformation is ongoing as we grow in our relationship with Christ. Today, embrace your identity as a new creation and allow God to continue His transforming work in your life.",
                author: "New Creation",
                date: calendar.date(byAdding: .day, value: -30, to: today) ?? today,
                category: "Growth"
            ),
            Devotional(
                title: "Transformed by Renewing",
                scripture: "Romans 12:2",
                content: "Do not conform to the pattern of this world, but be transformed by the renewing of your mind. Then you will be able to test and approve what God's will is—his good, pleasing and perfect will. Transformation happens through the renewing of our minds. As we align our thoughts with God's truth, we are transformed and better able to discern His will. Today, focus on renewing your mind with God's Word and truth.",
                author: "Mind Renewal",
                date: calendar.date(byAdding: .day, value: -31, to: today) ?? today,
                category: "Growth"
            ),
            Devotional(
                title: "Fruit of the Spirit",
                scripture: "Galatians 5:22-23",
                content: "But the fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control. Against such things there is no law. The Holy Spirit produces fruit in our lives as we grow in our relationship with God. These qualities are evidence of spiritual growth and maturity. Today, ask the Holy Spirit to produce His fruit in your life.",
                author: "Spiritual Fruit",
                date: calendar.date(byAdding: .day, value: -32, to: today) ?? today,
                category: "Growth"
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
