import Foundation
import SwiftUI

@available(iOS 17.0, *)
@MainActor
class BibleVerseOfTheDayManager: ObservableObject {
        /// Loads a random verse from the local verses array and updates currentVerse.
        func loadRandomVerse() {
            guard !verses.isEmpty else { return }
            let randomIndex = Int.random(in: 0..<verses.count)
            DispatchQueue.main.async {
                self.currentVerse = self.verses[randomIndex]
            }
        }
    static let shared = BibleVerseOfTheDayManager()
    
    @Published var currentVerse: BibleVerse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedVersion: BibleVersion = .niv
    @Published var useAPI: Bool = false  // Toggle between API and local verses
    
    // Cached verses for offline use - accessed only on MainActor
    private var cachedVerses: [String: BibleVerse] = [:]
    
    // Local fallback verses (NIV) for offline use
    private let verses = [
        // Core Faith Verses
        BibleVerse(reference: "John 3:16", text: "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.", translation: "NIV"),
        BibleVerse(reference: "Romans 10:9", text: "If you declare with your mouth, \"Jesus is Lord,\" and believe in your heart that God raised him from the dead, you will be saved.", translation: "NIV"),
        BibleVerse(reference: "Ephesians 2:8-9", text: "For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—not by works, so that no one can boast.", translation: "NIV"),
        
        // Strength and Courage
        BibleVerse(reference: "Philippians 4:13", text: "I can do all this through him who gives me strength.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:31", text: "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.", translation: "NIV"),
        BibleVerse(reference: "Joshua 1:9", text: "Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 31:6", text: "Be strong and courageous. Do not be afraid or terrified because of them, for the Lord your God goes with you; he will never leave you nor forsake you.", translation: "NIV"),
        BibleVerse(reference: "2 Timothy 1:7", text: "For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline.", translation: "NIV"),
        
        // God's Plans and Purpose
        BibleVerse(reference: "Jeremiah 29:11", text: "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.", translation: "NIV"),
        BibleVerse(reference: "Romans 8:28", text: "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:5-6", text: "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.", translation: "NIV"),
        BibleVerse(reference: "Psalm 37:4", text: "Take delight in the Lord, and he will give you the desires of your heart.", translation: "NIV"),
        
        // Peace and Comfort
        BibleVerse(reference: "John 14:27", text: "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.", translation: "NIV"),
        BibleVerse(reference: "Philippians 4:6-7", text: "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.", translation: "NIV"),
        BibleVerse(reference: "Matthew 11:28-30", text: "Come to me, all you who are weary and burdened, and I will give you rest. Take my yoke upon you and learn from me, for I am gentle and humble in heart, and you will find rest for your souls. For my yoke is easy and my burden is light.", translation: "NIV"),
        BibleVerse(reference: "1 Peter 5:7", text: "Cast all your anxiety on him because he cares for you.", translation: "NIV"),
        BibleVerse(reference: "Psalm 23:1-4", text: "The Lord is my shepherd, I lack nothing. He makes me lie down in green pastures, he leads me beside quiet waters, he refreshes my soul. He guides me along the right paths for his name's sake. Even though I walk through the darkest valley, I will fear no evil, for you are with me; your rod and your staff, they comfort me.", translation: "NIV"),
        
        // Love and Relationships
        BibleVerse(reference: "1 Corinthians 13:4-7", text: "Love is patient, love is kind. It does not envy, it does not boast, it is not proud. It does not dishonor others, it is not self-seeking, it is not easily angered, it keeps no record of wrongs. Love does not delight in evil but rejoices with the truth. It always protects, always trusts, always hopes, always perseveres.", translation: "NIV"),
        BibleVerse(reference: "1 John 4:7-8", text: "Dear friends, let us love one another, for love comes from God. Everyone who loves has been born of God and knows God. Whoever does not love does not know God, because God is love.", translation: "NIV"),
        BibleVerse(reference: "John 15:12", text: "My command is this: Love each other as I have loved you.", translation: "NIV"),
        BibleVerse(reference: "Romans 12:10", text: "Be devoted to one another in love. Honor one another above yourselves.", translation: "NIV"),
        
        // Prayer and Worship
        BibleVerse(reference: "1 Thessalonians 5:16-18", text: "Rejoice always, pray continually, give thanks in all circumstances; for this is God's will for you in Christ Jesus.", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:33", text: "But seek first his kingdom and his righteousness, and all these things will be given to you as well.", translation: "NIV"),
        BibleVerse(reference: "Psalm 100:4", text: "Enter his gates with thanksgiving and his courts with praise; give thanks to him and praise his name.", translation: "NIV"),
        BibleVerse(reference: "James 5:16", text: "Therefore confess your sins to each other and pray for each other so that you may be healed. The prayer of a righteous person is powerful and effective.", translation: "NIV"),
        
        // Forgiveness and Grace
        BibleVerse(reference: "Colossians 3:13", text: "Bear with each other and forgive one another if any of you has a grievance against someone. Forgive as the Lord forgave you.", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:14-15", text: "For if you forgive other people when they sin against you, your heavenly Father will also forgive you. But if you do not forgive others their sins, your Father will not forgive your sins.", translation: "NIV"),
        BibleVerse(reference: "Ephesians 4:32", text: "Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you.", translation: "NIV"),
        BibleVerse(reference: "1 John 1:9", text: "If we confess our sins, he is faithful and just and will forgive us our sins and purify us from all unrighteousness.", translation: "NIV"),
        
        // Hope and Encouragement
        BibleVerse(reference: "Romans 15:13", text: "May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope by the power of the Holy Spirit.", translation: "NIV"),
        BibleVerse(reference: "Lamentations 3:22-23", text: "Because of the Lord's great love we are not consumed, for his compassions never fail. They are new every morning; great is your faithfulness.", translation: "NIV"),
        BibleVerse(reference: "Psalm 27:1", text: "The Lord is my light and my salvation—whom shall I fear? The Lord is the stronghold of my life—of whom shall I be afraid?", translation: "NIV"),
        BibleVerse(reference: "2 Corinthians 4:16-18", text: "Therefore we do not lose heart. Though outwardly we are wasting away, yet inwardly we are being renewed day by day. For our light and momentary troubles are achieving for us an eternal glory that far outweighs them all. So we fix our eyes not on what is seen, but on what is unseen, since what is seen is temporary, but what is unseen is eternal.", translation: "NIV"),
        
        // Wisdom and Guidance
        BibleVerse(reference: "James 1:5", text: "If any of you lacks wisdom, you should ask God, who gives generously to all without finding fault, and it will be given to you.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:105", text: "Your word is a lamp for my feet, a light on my path.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:3", text: "Commit to the Lord whatever you do, and he will establish your plans.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 30:21", text: "Whether you turn to the right or to the left, your ears will hear a voice behind you, saying, \"This is the way; walk in it.\"", translation: "NIV"),
        
        // Gratitude and Thankfulness
        BibleVerse(reference: "Psalm 136:1", text: "Give thanks to the Lord, for he is good. His love endures forever.", translation: "NIV"),
        BibleVerse(reference: "Colossians 3:15", text: "Let the peace of Christ rule in your hearts, since as members of one body you were called to peace. And be thankful.", translation: "NIV"),
        BibleVerse(reference: "Psalm 107:1", text: "Give thanks to the Lord, for he is good; his love endures forever.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 16:34", text: "Give thanks to the Lord, for he is good; his love endures forever.", translation: "NIV"),
        
        // Service and Generosity
        BibleVerse(reference: "Galatians 5:13", text: "You, my brothers and sisters, were called to be free. But do not use your freedom to indulge the flesh; rather, serve one another humbly in love.", translation: "NIV"),
        BibleVerse(reference: "Matthew 20:28", text: "Just as the Son of Man did not come to be served, but to serve, and to give his life as a ransom for many.", translation: "NIV"),
        BibleVerse(reference: "Acts 20:35", text: "In everything I did, I showed you that by this kind of hard work we must help the weak, remembering the words the Lord Jesus himself said: 'It is more blessed to give than to receive.'", translation: "NIV"),
        BibleVerse(reference: "Hebrews 13:16", text: "And do not forget to do good and to share with others, for with such sacrifices God is pleased.", translation: "NIV"),
        
        // Faith and Trust
        BibleVerse(reference: "Hebrews 11:1", text: "Now faith is confidence in what we hope for and assurance about what we do not see.", translation: "NIV"),
        BibleVerse(reference: "2 Corinthians 5:7", text: "For we live by faith, not by sight.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:5", text: "Trust in the Lord with all your heart and lean not on your own understanding.", translation: "NIV"),
        BibleVerse(reference: "Psalm 56:3", text: "When I am afraid, I put my trust in you.", translation: "NIV"),
        
        // God's Presence
        BibleVerse(reference: "Matthew 28:20", text: "And surely I am with you always, to the very end of the age.", translation: "NIV"),
        BibleVerse(reference: "Psalm 139:7-10", text: "Where can I go from your Spirit? Where can I flee from your presence? If I go up to the heavens, you are there; if I make my bed in the depths, you are there. If I rise on the wings of the dawn, if I settle on the far side of the sea, even there your hand will guide me, your right hand will hold me fast.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 41:10", text: "So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.", translation: "NIV"),
        BibleVerse(reference: "Joshua 1:5", text: "No one will be able to stand against you all the days of your life. As I was with Moses, so I will be with you; I will never leave you nor forsake you.", translation: "NIV"),
        
        // Transformation and Growth
        BibleVerse(reference: "2 Corinthians 5:17", text: "Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here!", translation: "NIV"),
        BibleVerse(reference: "Romans 12:2", text: "Do not conform to the pattern of this world, but be transformed by the renewing of your mind. Then you will be able to test and approve what God's will is—his good, pleasing and perfect will.", translation: "NIV"),
        BibleVerse(reference: "Galatians 5:22-23", text: "But the fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control. Against such things there is no law.", translation: "NIV"),
        BibleVerse(reference: "Philippians 1:6", text: "Being confident of this, that he who began a good work in you will carry it on to completion until the day of Christ Jesus.", translation: "NIV"),
        
        // Perseverance and Endurance
        BibleVerse(reference: "James 1:2-4", text: "Consider it pure joy, my brothers and sisters, whenever you face trials of many kinds, because you know that the testing of your faith produces perseverance. Let perseverance finish its work so that you may be mature and complete, not lacking anything.", translation: "NIV"),
        BibleVerse(reference: "Hebrews 12:1-2", text: "Therefore, since we are surrounded by such a great cloud of witnesses, let us throw off everything that hinders and the sin that so easily entangles. And let us run with perseverance the race marked out for us, fixing our eyes on Jesus, the pioneer and perfecter of faith.", translation: "NIV"),
        BibleVerse(reference: "Romans 5:3-4", text: "Not only so, but we also glory in our sufferings, because we know that suffering produces perseverance; perseverance, character; and character, hope.", translation: "NIV"),
        BibleVerse(reference: "1 Corinthians 9:24", text: "Do you not know that in a race all the runners run, but only one gets the prize? Run in such a way as to get the prize.", translation: "NIV")
    ]
    
    init() {
        // Load preferences first, in correct order
        loadSelectedVersion()
        loadAPIPreference()
        
        // Ensure API mode is enabled if a non-NIV version is selected
        if selectedVersion != .niv && !useAPI {
            print("🔄 [BibleVerseOfTheDayManager] Init: Non-NIV version (\(selectedVersion.rawValue)) selected but API disabled, enabling API mode")
            useAPI = true
            UserDefaults.standard.set(true, forKey: "useBibleAPI")
        }
        
        // Now load the verse with correct settings
        loadTodaysVerse()
        
        // Observe UserDefaults changes for selectedBibleVersion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func userDefaultsDidChange() {
        // This method is called on a background thread by NotificationCenter.
        // All UI updates or @Published property changes must be on the MainActor.
        Task { @MainActor in
            // Check if selectedBibleVersion changed
            if let versionString = UserDefaults.standard.string(forKey: "selectedBibleVersion"),
               let version = BibleVersion(rawValue: versionString),
               version != self.selectedVersion {
                // Version changed externally (e.g., from SettingsView), update it
                print("🔄 [BibleVerseOfTheDayManager] Detected UserDefaults change for selectedBibleVersion: \(version.rawValue)")
                self.updateVersion(version)
            }
            
            // Check if useBibleAPI changed
            let currentAPIUsage = UserDefaults.standard.bool(forKey: "useBibleAPI")
            if currentAPIUsage != self.useAPI {
                print("🔄 [BibleVerseOfTheDayManager] Detected UserDefaults change for useBibleAPI: \(currentAPIUsage)")
                self.toggleAPIUsage(currentAPIUsage)
            }
        }
    }
    
    func loadSelectedVersion() {
        if let versionString = UserDefaults.standard.string(forKey: "selectedBibleVersion"),
           let version = BibleVersion(rawValue: versionString) {
            selectedVersion = version
        }
    }
    
    func loadAPIPreference() {
        useAPI = UserDefaults.standard.bool(forKey: "useBibleAPI")
        // If a non-NIV version is selected, ensure API mode is enabled
        if selectedVersion != .niv && !useAPI {
            print("🔄 [BibleVerseOfTheDayManager] loadAPIPreference: Non-NIV version (\(selectedVersion.rawValue)) requires API mode, enabling it")
            useAPI = true
            UserDefaults.standard.set(true, forKey: "useBibleAPI")
        }
    }
    
    func toggleAPIUsage(_ enabled: Bool) {
        useAPI = enabled
        UserDefaults.standard.set(enabled, forKey: "useBibleAPI")
        loadTodaysVerse()
    }
    
    func updateVersion(_ version: BibleVersion) {
        let oldVersion = selectedVersion
        selectedVersion = version
        UserDefaults.standard.set(version.rawValue, forKey: "selectedBibleVersion")
        
        // Clear cache for old version to force fresh fetch
        if oldVersion != version {
            print("🔄 [BibleVerseOfTheDayManager] Version changed from \(oldVersion.rawValue) to \(version.rawValue), clearing cache")
            // Clear all cached verses for the old version to ensure fresh fetch
            let keysToRemove = self.cachedVerses.keys.filter { $0.contains("-\(oldVersion.rawValue)") }
            for key in keysToRemove {
                self.cachedVerses.removeValue(forKey: key)
            }
            print("🗑️ [BibleVerseOfTheDayManager] Cleared \(keysToRemove.count) cached verses for old version")
        }
        
        // If user selected a version other than NIV, automatically use API mode
        // since local verses are only available in NIV
        let shouldEnableAPI = version != .niv
        if shouldEnableAPI && !useAPI {
            print("🔄 [BibleVerseOfTheDayManager] Non-NIV version selected (\(version.rawValue)), automatically enabling API mode")
            useAPI = true
            UserDefaults.standard.set(true, forKey: "useBibleAPI")
            print("✅ [BibleVerseOfTheDayManager] API mode enabled, useAPI=\(useAPI)")
        } else if !shouldEnableAPI && useAPI {
            // If switching back to NIV, we can use local verses (API optional)
            print("🔄 [BibleVerseOfTheDayManager] NIV selected, API mode can be disabled (currently: \(useAPI))")
        }
        
        print("📖 [BibleVerseOfTheDayManager] Loading verse with version=\(version.rawValue), useAPI=\(useAPI)")
        loadTodaysVerse()
    }
    
    func loadTodaysVerse() {
        print("🔄 [BibleVerseOfTheDayManager] loadTodaysVerse() called - version: \(selectedVersion.rawValue), useAPI: \(useAPI)")
        isLoading = true
        errorMessage = nil
        
        if useAPI {
            print("📡 [BibleVerseOfTheDayManager] Loading from API...")
            loadVerseFromAPI()
        } else {
            print("📚 [BibleVerseOfTheDayManager] Loading from local verses...")
            loadVerseFromLocal()
        }
    }
    
    private func loadVerseFromLocal() {
        // Use local verses - these are hardcoded as NIV
        // IMPORTANT: Only use NIV for the translation label since local text is always NIV
        print("📖 [BibleVerseOfTheDayManager] loadVerseFromLocal() - getting verse from local array")
        
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let verseIndex = (dayOfYear - 1) % self.verses.count
        let baseVerse = self.verses[verseIndex]
        
        print("✅ [BibleVerseOfTheDayManager] Selected local verse: \(baseVerse.reference) (index: \(verseIndex))")
        
        // Always use NIV for local verses since the text is hardcoded as NIV
        // Don't lie to the user by showing a different version label
        let verseWithVersion = BibleVerse(
            reference: baseVerse.reference,
            text: baseVerse.text,
            translation: "NIV"  // Always NIV for local verses
        )
        
        // Update on main thread (we're already on MainActor since the class is @MainActor)
        self.currentVerse = verseWithVersion
        self.isLoading = false
        print("✅ [BibleVerseOfTheDayManager] Local verse loaded: \(verseWithVersion.reference) (\(verseWithVersion.translation))")
        
        // If user selected a version other than NIV, show an error message
        if self.selectedVersion != .niv {
            self.errorMessage = "Local verses are NIV only. Enable API mode in settings for \(self.selectedVersion.rawValue) translation."
            print("⚠️ [BibleVerseOfTheDayManager] User selected \(self.selectedVersion.rawValue) but using local NIV verse (API mode: \(self.useAPI))")
        } else {
            self.errorMessage = nil
        }
    }
    
    private func loadVerseFromAPI() {
        // Set loading state immediately (we're already on MainActor)
        self.isLoading = true
        self.errorMessage = nil
        
        Task { @MainActor in
            do {
                // Get today's verse reference from local array
                let calendar = Calendar.current
                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
                let verseIndex = (dayOfYear - 1) % self.verses.count
                let localVerse = self.verses[verseIndex]
                
                // Check cache first
                let cacheKey = "\(localVerse.reference)-\(self.selectedVersion.rawValue)"
                if let cachedVerse = self.cachedVerses[cacheKey] {
                    self.currentVerse = cachedVerse
                    self.isLoading = false
                    print("📦 [BibleVerseOfTheDayManager] Using cached verse: \(cachedVerse.reference) (\(cachedVerse.translation))")
                    return
                }
                
                // Fetch from API with selected version (with timeout)
                print("🌐 [BibleVerseOfTheDayManager] Fetching verse from API: \(localVerse.reference) in \(self.selectedVersion.rawValue)")
                
                let apiVerse = try await withTimeout(seconds: 10) {
                    try await BibleAPIService.shared.fetchVerse(reference: localVerse.reference, version: self.selectedVersion)
                }
                
                print("✅ [BibleVerseOfTheDayManager] Successfully fetched verse: \(apiVerse.reference) (\(apiVerse.translation))")
                
                // Cache the verse (we're already on MainActor in this Task)
                self.cachedVerses[cacheKey] = apiVerse
                
                // Update UI on main thread
                self.currentVerse = apiVerse
                self.isLoading = false
                self.errorMessage = nil
                
                print("📱 [BibleVerseOfTheDayManager] Updated currentVerse to: \(apiVerse.reference) (\(apiVerse.translation))")
            } catch {
                print("❌ [BibleVerseOfTheDayManager] API fetch failed: \(error)")
                let errorDescription: String
                if let apiError = error as? BibleAPIError {
                    switch apiError {
                    case .invalidURL:
                        errorDescription = "Invalid URL"
                    case .noData:
                        errorDescription = "No data received"
                    case .networkError:
                        errorDescription = "Network error"
                    case .decodingError:
                        errorDescription = "Invalid response format"
                    }
                } else {
                    errorDescription = error.localizedDescription
                }
                
                // Always clear loading and fallback to local verse
                self.isLoading = false
                self.errorMessage = "Failed to load verse from API: \(errorDescription). Using local verse (NIV only)."
                
                print("⚠️ [BibleVerseOfTheDayManager] Falling back to local NIV verse")
                self.loadVerseFromLocal()
            }
        }
    }
    
    // Helper function to add timeout to async operations
    @available(iOS 17.0, *)
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])
            }
            
            // Return first completed result and cancel the other
            guard let result = try await group.next() else {
                group.cancelAll()
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])
            }
            group.cancelAll()
            return result
        }
    }

    func refreshVerse() {
        loadTodaysVerse()
    }
}
