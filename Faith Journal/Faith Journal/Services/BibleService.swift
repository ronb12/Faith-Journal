//
//  BibleService.swift
//  Faith Journal
//
//  Service for fetching Bible verses from public APIs
//

import Foundation

struct BibleVerseResponse: Codable {
    let reference: String
    let text: String
    let translation: String
}

@MainActor
class BibleService: ObservableObject {
    static let shared = BibleService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTranslation: String = "NIV"
    
    // Available translations
    let availableTranslations = [
        "NIV": "New International Version",
        "KJV": "King James Version",
        "ESV": "English Standard Version",
        "NLT": "New Living Translation",
        "NASB": "New American Standard Bible",
        "MSG": "The Message",
        "AMP": "Amplified Bible",
        "CSB": "Christian Standard Bible"
    ]
    
    private init() {}
    
    // Fetch a verse by reference (e.g., "John 3:16")
    func fetchVerse(reference: String, translation: String? = nil) async throws -> BibleVerseResponse {
        let useTranslation = translation ?? selectedTranslation
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Clean and format the reference
        let cleanReference = reference.trimmingCharacters(in: .whitespaces)
        
        // Try multiple API sources
        do {
            // Try ESV API first (requires API key but more reliable)
            return try await fetchFromESV(reference: cleanReference)
        } catch {
            // Fallback to Bible Gateway or manual parsing
            print("ESV API failed: \(error.localizedDescription)")
            
            // Try Bible Gateway web scraping approach (fallback)
            do {
                return try await fetchFromBibleGateway(reference: cleanReference, translation: useTranslation)
            } catch {
                // Last resort: try to parse common verses from our local database
                if let localVerse = getLocalVerse(reference: cleanReference) {
                    return BibleVerseResponse(
                        reference: localVerse.reference,
                        text: localVerse.text,
                        translation: localVerse.translation
                    )
                }
                
                errorMessage = "Unable to fetch verse. Please try entering the verse manually."
                throw BibleServiceError.verseNotFound
            }
        }
    }
    
    // Fetch from ESV API (requires free API key)
    private func fetchFromESV(reference: String) async throws -> BibleVerseResponse {
        // ESV API endpoint - you'll need to get a free API key from https://api.esv.org/
        // For now, we'll use a web-based approach
        
        // Using Bible Gateway as primary source since it's free and doesn't require auth
        return try await fetchFromBibleGateway(reference: reference, translation: "NIV")
    }
    
    // Fetch from Bible Gateway using their API (fallback to local verses)
    private func fetchFromBibleGateway(reference: String, translation: String = "NIV") async throws -> BibleVerseResponse {
        // First try to get from local database
        if let localVerse = getLocalVerse(reference: reference) {
            return BibleVerseResponse(
                reference: localVerse.reference,
                text: localVerse.text,
                translation: localVerse.translation
            )
        }
        
        // For now, since we don't have API access, we'll use the local database
        // In production, you would integrate with:
        // - ESV API (free tier available at https://api.esv.org/)
        // - Bible.com API (YouVersion - requires partnership)
        // - or use Bible Gateway's search with proper HTML parsing
        
        throw BibleServiceError.verseNotFound
    }
    
    // Get all available local verses
    func getAllLocalVerses() -> [BibleVerse] {
        return localVersesDatabase
    }
    
    // Local verses database - 1000 verses covering all 66 books of the Bible
    private let localVersesDatabase: [BibleVerse] = [
        // Core Faith Verses (1-5)
        BibleVerse(reference: "John 3:16", text: "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.", translation: "NIV"),
        BibleVerse(reference: "Romans 10:9", text: "If you declare with your mouth, \"Jesus is Lord,\" and believe in your heart that God raised him from the dead, you will be saved.", translation: "NIV"),
        BibleVerse(reference: "Ephesians 2:8-9", text: "For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—not by works, so that no one can boast.", translation: "NIV"),
        BibleVerse(reference: "Acts 16:31", text: "They replied, \"Believe in the Lord Jesus, and you will be saved—you and your household.\"", translation: "NIV"),
        BibleVerse(reference: "Romans 3:23", text: "For all have sinned and fall short of the glory of God.", translation: "NIV"),
        
        // Strength and Courage (6-15)
        BibleVerse(reference: "Philippians 4:13", text: "I can do all this through him who gives me strength.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:31", text: "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.", translation: "NIV"),
        BibleVerse(reference: "Joshua 1:9", text: "Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 31:6", text: "Be strong and courageous. Do not be afraid or terrified because of them, for the Lord your God goes with you; he will never leave you nor forsake you.", translation: "NIV"),
        BibleVerse(reference: "2 Timothy 1:7", text: "For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline.", translation: "NIV"),
        BibleVerse(reference: "1 Corinthians 16:13", text: "Be on your guard; stand firm in the faith; be courageous; be strong.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 41:10", text: "So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.", translation: "NIV"),
        BibleVerse(reference: "Psalm 27:1", text: "The Lord is my light and my salvation—whom shall I fear? The Lord is the stronghold of my life—of whom shall I be afraid?", translation: "NIV"),
        BibleVerse(reference: "Psalm 46:1", text: "God is our refuge and strength, an ever-present help in trouble.", translation: "NIV"),
        BibleVerse(reference: "Ephesians 6:10", text: "Finally, be strong in the Lord and in his mighty power.", translation: "NIV"),
        
        // God's Plans and Purpose (16-25)
        BibleVerse(reference: "Jeremiah 29:11", text: "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.", translation: "NIV"),
        BibleVerse(reference: "Romans 8:28", text: "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:5-6", text: "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.", translation: "NIV"),
        BibleVerse(reference: "Psalm 37:4", text: "Take delight in the Lord, and he will give you the desires of your heart.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:3", text: "Commit to the Lord whatever you do, and he will establish your plans.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 55:8-9", text: "\"For my thoughts are not your thoughts, neither are your ways my ways,\" declares the Lord. \"As the heavens are higher than the earth, so are my ways higher than your ways and my thoughts than your thoughts.\"", translation: "NIV"),
        BibleVerse(reference: "Proverbs 19:21", text: "Many are the plans in a person's heart, but it is the Lord's purpose that prevails.", translation: "NIV"),
        BibleVerse(reference: "Psalm 32:8", text: "I will instruct you and teach you in the way you should go; I will counsel you with my loving eye on you.", translation: "NIV"),
        BibleVerse(reference: "Ephesians 2:10", text: "For we are God's handiwork, created in Christ Jesus to do good works, which God prepared in advance for us to do.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 26:3", text: "You will keep in perfect peace those whose minds are steadfast, because they trust in you.", translation: "NIV"),
        
        // Peace and Comfort (26-35)
        BibleVerse(reference: "John 14:27", text: "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.", translation: "NIV"),
        BibleVerse(reference: "Philippians 4:6-7", text: "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.", translation: "NIV"),
        BibleVerse(reference: "Matthew 11:28-30", text: "Come to me, all you who are weary and burdened, and I will give you rest. Take my yoke upon you and learn from me, for I am gentle and humble in heart, and you will find rest for your souls. For my yoke is easy and my burden is light.", translation: "NIV"),
        BibleVerse(reference: "1 Peter 5:7", text: "Cast all your anxiety on him because he cares for you.", translation: "NIV"),
        BibleVerse(reference: "Psalm 23:1-4", text: "The Lord is my shepherd, I lack nothing. He makes me lie down in green pastures, he leads me beside quiet waters, he refreshes my soul. He guides me along the right paths for his name's sake. Even though I walk through the darkest valley, I will fear no evil, for you are with me; your rod and your staff, they comfort me.", translation: "NIV"),
        BibleVerse(reference: "Psalm 34:4", text: "I sought the Lord, and he answered me; he delivered me from all my fears.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 26:3", text: "You will keep in perfect peace those whose minds are steadfast, because they trust in you.", translation: "NIV"),
        BibleVerse(reference: "2 Thessalonians 3:16", text: "Now may the Lord of peace himself give you peace at all times and in every way. The Lord be with all of you.", translation: "NIV"),
        BibleVerse(reference: "Psalm 55:22", text: "Cast your cares on the Lord and he will sustain you; he will never let the righteous be shaken.", translation: "NIV"),
        BibleVerse(reference: "Romans 15:13", text: "May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope by the power of the Holy Spirit.", translation: "NIV"),
        
        // Love and Relationships (36-45)
        BibleVerse(reference: "1 Corinthians 13:4-7", text: "Love is patient, love is kind. It does not envy, it does not boast, it is not proud. It does not dishonor others, it is not self-seeking, it is not easily angered, it keeps no record of wrongs. Love does not delight in evil but rejoices with the truth. It always protects, always trusts, always hopes, always perseveres.", translation: "NIV"),
        BibleVerse(reference: "1 John 4:7-8", text: "Dear friends, let us love one another, for love comes from God. Everyone who loves has been born of God and knows God. Whoever does not love does not know God, because God is love.", translation: "NIV"),
        BibleVerse(reference: "John 15:12", text: "My command is this: Love each other as I have loved you.", translation: "NIV"),
        BibleVerse(reference: "Romans 12:10", text: "Be devoted to one another in love. Honor one another above yourselves.", translation: "NIV"),
        BibleVerse(reference: "Ephesians 4:2", text: "Be completely humble and gentle; be patient, bearing with one another in love.", translation: "NIV"),
        BibleVerse(reference: "1 John 4:19", text: "We love because he first loved us.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 17:17", text: "A friend loves at all times, and a brother is born for a time of adversity.", translation: "NIV"),
        BibleVerse(reference: "1 Peter 4:8", text: "Above all, love each other deeply, because love covers over a multitude of sins.", translation: "NIV"),
        BibleVerse(reference: "Colossians 3:14", text: "And over all these virtues put on love, which binds them all together in perfect unity.", translation: "NIV"),
        BibleVerse(reference: "Song of Songs 8:6", text: "Place me like a seal over your heart, like a seal on your arm; for love is as strong as death, its jealousy unyielding as the grave. It burns like blazing fire, like a mighty flame.", translation: "NIV"),
        
        // Prayer and Worship (46-55)
        BibleVerse(reference: "1 Thessalonians 5:16-18", text: "Rejoice always, pray continually, give thanks in all circumstances; for this is God's will for you in Christ Jesus.", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:33", text: "But seek first his kingdom and his righteousness, and all these things will be given to you as well.", translation: "NIV"),
        BibleVerse(reference: "Psalm 100:4", text: "Enter his gates with thanksgiving and his courts with praise; give thanks to him and praise his name.", translation: "NIV"),
        BibleVerse(reference: "James 5:16", text: "Therefore confess your sins to each other and pray for each other so that you may be healed. The prayer of a righteous person is powerful and effective.", translation: "NIV"),
        BibleVerse(reference: "Matthew 21:22", text: "If you believe, you will receive whatever you ask for in prayer.", translation: "NIV"),
        BibleVerse(reference: "Philippians 4:6", text: "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.", translation: "NIV"),
        BibleVerse(reference: "Mark 11:24", text: "Therefore I tell you, whatever you ask for in prayer, believe that you have received it, and it will be yours.", translation: "NIV"),
        BibleVerse(reference: "Psalm 145:18", text: "The Lord is near to all who call on him, to all who call on him in truth.", translation: "NIV"),
        BibleVerse(reference: "John 15:7", text: "If you remain in me and my words remain in you, ask whatever you wish, and it will be done for you.", translation: "NIV"),
        BibleVerse(reference: "Hebrews 4:16", text: "Let us then approach God's throne of grace with confidence, so that we may receive mercy and find grace to help us in our time of need.", translation: "NIV"),
        
        // Forgiveness and Grace (56-65)
        BibleVerse(reference: "Colossians 3:13", text: "Bear with each other and forgive one another if any of you has a grievance against someone. Forgive as the Lord forgave you.", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:14-15", text: "For if you forgive other people when they sin against you, your heavenly Father will also forgive you. But if you do not forgive others their sins, your Father will not forgive your sins.", translation: "NIV"),
        BibleVerse(reference: "Ephesians 4:32", text: "Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you.", translation: "NIV"),
        BibleVerse(reference: "1 John 1:9", text: "If we confess our sins, he is faithful and just and will forgive us our sins and purify us from all unrighteousness.", translation: "NIV"),
        BibleVerse(reference: "Luke 6:37", text: "Do not judge, and you will not be judged. Do not condemn, and you will not be condemned. Forgive, and you will be forgiven.", translation: "NIV"),
        BibleVerse(reference: "Psalm 103:12", text: "As far as the east is from the west, so far has he removed our transgressions from us.", translation: "NIV"),
        BibleVerse(reference: "Micah 7:18", text: "Who is a God like you, who pardons sin and forgives the transgression of the remnant of his inheritance? You do not stay angry forever but delight to show mercy.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 1:18", text: "\"Come now, let us settle the matter,\" says the Lord. \"Though your sins are like scarlet, they shall be as white as snow; though they are red as crimson, they shall be like wool.\"", translation: "NIV"),
        BibleVerse(reference: "Ephesians 1:7", text: "In him we have redemption through his blood, the forgiveness of sins, in accordance with the riches of God's grace.", translation: "NIV"),
        BibleVerse(reference: "Acts 13:38", text: "Therefore, my friends, I want you to know that through Jesus the forgiveness of sins is proclaimed to you.", translation: "NIV"),
        
        // Hope and Encouragement (66-75)
        BibleVerse(reference: "Lamentations 3:22-23", text: "Because of the Lord's great love we are not consumed, for his compassions never fail. They are new every morning; great is your faithfulness.", translation: "NIV"),
        BibleVerse(reference: "2 Corinthians 4:16-18", text: "Therefore we do not lose heart. Though outwardly we are wasting away, yet inwardly we are being renewed day by day. For our light and momentary troubles are achieving for us an eternal glory that far outweighs them all. So we fix our eyes not on what is seen, but on what is unseen, since what is seen is temporary, but what is unseen is eternal.", translation: "NIV"),
        BibleVerse(reference: "Psalm 34:18", text: "The Lord is close to the brokenhearted and saves those who are crushed in spirit.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:8", text: "The grass withers and the flowers fall, but the word of our God endures forever.", translation: "NIV"),
        BibleVerse(reference: "Hebrews 10:23", text: "Let us hold unswervingly to the hope we profess, for he who promised is faithful.", translation: "NIV"),
        BibleVerse(reference: "1 Peter 1:3", text: "Praise be to the God and Father of our Lord Jesus Christ! In his great mercy he has given us new birth into a living hope through the resurrection of Jesus Christ from the dead.", translation: "NIV"),
        BibleVerse(reference: "Psalm 42:11", text: "Why, my soul, are you downcast? Why so disturbed within me? Put your hope in God, for I will yet praise him, my Savior and my God.", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 17:7", text: "But blessed is the one who trusts in the Lord, whose confidence is in him.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 23:18", text: "There is surely a future hope for you, and your hope will not be cut off.", translation: "NIV"),
        BibleVerse(reference: "Psalm 71:14", text: "As for me, I will always have hope; I will praise you more and more.", translation: "NIV"),
        
        // Wisdom and Guidance (76-85)
        BibleVerse(reference: "James 1:5", text: "If any of you lacks wisdom, you should ask God, who gives generously to all without finding fault, and it will be given to you.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:105", text: "Your word is a lamp for my feet, a light on my path.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 30:21", text: "Whether you turn to the right or to the left, your ears will hear a voice behind you, saying, \"This is the way; walk in it.\"", translation: "NIV"),
        BibleVerse(reference: "Proverbs 2:6", text: "For the Lord gives wisdom; from his mouth come knowledge and understanding.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 9:10", text: "The fear of the Lord is the beginning of wisdom, and knowledge of the Holy One is understanding.", translation: "NIV"),
        BibleVerse(reference: "Colossians 2:3", text: "In whom are hidden all the treasures of wisdom and knowledge.", translation: "NIV"),
        BibleVerse(reference: "Psalm 32:8", text: "I will instruct you and teach you in the way you should go; I will counsel you with my loving eye on you.", translation: "NIV"),
        BibleVerse(reference: "James 3:17", text: "But the wisdom that comes from heaven is first of all pure; then peace-loving, considerate, submissive, full of mercy and good fruit, impartial and sincere.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 4:6-7", text: "Do not forsake wisdom, and she will protect you; love her, and she will watch over you. The beginning of wisdom is this: Get wisdom. Though it cost all you have, get understanding.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 7:12", text: "Wisdom is a shelter as money is a shelter, but the advantage of knowledge is this: Wisdom preserves those who have it.", translation: "NIV"),
        
        // Gratitude and Thankfulness (86-90)
        BibleVerse(reference: "Psalm 136:1", text: "Give thanks to the Lord, for he is good. His love endures forever.", translation: "NIV"),
        BibleVerse(reference: "Colossians 3:15", text: "Let the peace of Christ rule in your hearts, since as members of one body you were called to peace. And be thankful.", translation: "NIV"),
        BibleVerse(reference: "Psalm 107:1", text: "Give thanks to the Lord, for he is good; his love endures forever.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 16:34", text: "Give thanks to the Lord, for he is good; his love endures forever.", translation: "NIV"),
        BibleVerse(reference: "Ephesians 5:20", text: "Always giving thanks to God the Father for everything, in the name of our Lord Jesus Christ.", translation: "NIV"),
        
        // Service and Generosity (91-95)
        BibleVerse(reference: "Galatians 5:13", text: "You, my brothers and sisters, were called to be free. But do not use your freedom to indulge the flesh; rather, serve one another humbly in love.", translation: "NIV"),
        BibleVerse(reference: "Matthew 20:28", text: "Just as the Son of Man did not come to be served, but to serve, and to give his life as a ransom for many.", translation: "NIV"),
        BibleVerse(reference: "Acts 20:35", text: "In everything I did, I showed you that by this kind of hard work we must help the weak, remembering the words the Lord Jesus himself said: 'It is more blessed to give than to receive.'", translation: "NIV"),
        BibleVerse(reference: "Hebrews 13:16", text: "And do not forget to do good and to share with others, for with such sacrifices God is pleased.", translation: "NIV"),
        BibleVerse(reference: "2 Corinthians 9:7", text: "Each of you should give what you have decided in your heart to give, not reluctantly or under compulsion, for God loves a cheerful giver.", translation: "NIV"),
        
        // Faith and Trust (96-100)
        BibleVerse(reference: "Hebrews 11:1", text: "Now faith is confidence in what we hope for and assurance about what we do not see.", translation: "NIV"),
        BibleVerse(reference: "2 Corinthians 5:7", text: "For we live by faith, not by sight.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:5", text: "Trust in the Lord with all your heart and lean not on your own understanding.", translation: "NIV"),
        BibleVerse(reference: "Psalm 56:3", text: "When I am afraid, I put my trust in you.", translation: "NIV"),
        BibleVerse(reference: "Mark 9:23", text: "\"'If you can'?\" said Jesus. \"Everything is possible for one who believes.\"", translation: "NIV"),
        
        // ========== OLD TESTAMENT - Pentateuch ==========
        
        // Genesis (101-120)
        BibleVerse(reference: "Genesis 1:1", text: "In the beginning God created the heavens and the earth.", translation: "NIV"),
        BibleVerse(reference: "Genesis 1:27", text: "So God created mankind in his own image, in the image of God he created them; male and female he created them.", translation: "NIV"),
        BibleVerse(reference: "Genesis 2:7", text: "Then the Lord God formed a man from the dust of the ground and breathed into his nostrils the breath of life, and the man became a living being.", translation: "NIV"),
        BibleVerse(reference: "Genesis 2:18", text: "The Lord God said, \"It is not good for the man to be alone. I will make a helper suitable for him.\"", translation: "NIV"),
        BibleVerse(reference: "Genesis 3:15", text: "And I will put enmity between you and the woman, and between your offspring and hers; he will crush your head, and you will strike his heel.", translation: "NIV"),
        BibleVerse(reference: "Genesis 9:13", text: "I have set my rainbow in the clouds, and it will be the sign of the covenant between me and the earth.", translation: "NIV"),
        BibleVerse(reference: "Genesis 12:2-3", text: "\"I will make you into a great nation, and I will bless you; I will make your name great, and you will be a blessing. I will bless those who bless you, and whoever curses you I will curse; and all peoples on earth will be blessed through you.\"", translation: "NIV"),
        BibleVerse(reference: "Genesis 15:5", text: "He took him outside and said, \"Look up at the sky and count the stars—if indeed you can count them.\" Then he said to him, \"So shall your offspring be.\"", translation: "NIV"),
        BibleVerse(reference: "Genesis 18:14", text: "Is anything too hard for the Lord? I will return to you at the appointed time next year, and Sarah will have a son.", translation: "NIV"),
        BibleVerse(reference: "Genesis 22:14", text: "So Abraham called that place The Lord Will Provide. And to this day it is said, \"On the mountain of the Lord it will be provided.\"", translation: "NIV"),
        BibleVerse(reference: "Genesis 28:15", text: "I am with you and will watch over you wherever you go, and I will bring you back to this land. I will not leave you until I have done what I have promised you.", translation: "NIV"),
        BibleVerse(reference: "Genesis 32:28", text: "Then the man said, \"Your name will no longer be Jacob, but Israel, because you have struggled with God and with humans and have overcome.\"", translation: "NIV"),
        BibleVerse(reference: "Genesis 39:2", text: "The Lord was with Joseph so that he prospered, and he lived in the house of his Egyptian master.", translation: "NIV"),
        BibleVerse(reference: "Genesis 39:21", text: "The Lord was with him; he showed him kindness and granted him favor in the eyes of the prison warden.", translation: "NIV"),
        BibleVerse(reference: "Genesis 50:20", text: "You intended to harm me, but God intended it for good to accomplish what is now being done, the saving of many lives.", translation: "NIV"),
        BibleVerse(reference: "Genesis 50:24", text: "Then Joseph said to his brothers, \"I am about to die. But God will surely come to your aid and take you up out of this land to the land he promised on oath to Abraham, Isaac and Jacob.\"", translation: "NIV"),
        BibleVerse(reference: "Genesis 1:31", text: "God saw all that he had made, and it was very good. And there was evening, and there was morning—the sixth day.", translation: "NIV"),
        BibleVerse(reference: "Genesis 6:22", text: "Noah did everything just as God commanded him.", translation: "NIV"),
        BibleVerse(reference: "Genesis 17:1", text: "When Abram was ninety-nine years old, the Lord appeared to him and said, \"I am God Almighty; walk before me faithfully and be blameless.\"", translation: "NIV"),
        BibleVerse(reference: "Genesis 24:27", text: "He said, \"Praise be to the Lord, the God of my master Abraham, who has not abandoned his kindness and faithfulness to my master.", translation: "NIV"),
        
        // Exodus (121-145)
        BibleVerse(reference: "Exodus 3:14", text: "God said to Moses, \"I am who I am. This is what you are to say to the Israelites: 'I am has sent me to you.'\"", translation: "NIV"),
        BibleVerse(reference: "Exodus 4:12", text: "Now go; I will help you speak and will teach you what to say.", translation: "NIV"),
        BibleVerse(reference: "Exodus 14:14", text: "The Lord will fight for you; you need only to be still.", translation: "NIV"),
        BibleVerse(reference: "Exodus 15:2", text: "The Lord is my strength and my defense; he has become my salvation. He is my God, and I will praise him, my father's God, and I will exalt him.", translation: "NIV"),
        BibleVerse(reference: "Exodus 20:3", text: "You shall have no other gods before me.", translation: "NIV"),
        BibleVerse(reference: "Exodus 20:12", text: "Honor your father and your mother, so that you may live long in the land the Lord your God is giving you.", translation: "NIV"),
        BibleVerse(reference: "Exodus 20:13-17", text: "You shall not murder. You shall not commit adultery. You shall not steal. You shall not give false testimony against your neighbor. You shall not covet your neighbor's house.", translation: "NIV"),
        BibleVerse(reference: "Exodus 23:25", text: "Worship the Lord your God, and his blessing will be on your food and water. I will take away sickness from among you.", translation: "NIV"),
        BibleVerse(reference: "Exodus 33:14", text: "The Lord replied, \"My Presence will go with you, and I will give you rest.\"", translation: "NIV"),
        BibleVerse(reference: "Exodus 34:6", text: "And he passed in front of Moses, proclaiming, \"The Lord, the Lord, the compassionate and gracious God, slow to anger, abounding in love and faithfulness.\"", translation: "NIV"),
        BibleVerse(reference: "Exodus 34:14", text: "Do not worship any other god, for the Lord, whose name is Jealous, is a jealous God.", translation: "NIV"),
        BibleVerse(reference: "Exodus 15:26", text: "He said, \"If you listen carefully to the Lord your God and do what is right in his eyes, if you pay attention to his commands and keep all his decrees, I will not bring on you any of the diseases I brought on the Egyptians, for I am the Lord, who heals you.\"", translation: "NIV"),
        BibleVerse(reference: "Exodus 16:4", text: "Then the Lord said to Moses, \"I will rain down bread from heaven for you. The people are to go out each day and gather enough for that day.", translation: "NIV"),
        BibleVerse(reference: "Exodus 19:5", text: "Now if you obey me fully and keep my covenant, then out of all nations you will be my treasured possession.", translation: "NIV"),
        BibleVerse(reference: "Exodus 31:3", text: "And I have filled him with the Spirit of God, with wisdom, with understanding, with knowledge and with all kinds of skills.", translation: "NIV"),
        BibleVerse(reference: "Exodus 40:34", text: "Then the cloud covered the tent of meeting, and the glory of the Lord filled the tabernacle.", translation: "NIV"),
        BibleVerse(reference: "Exodus 2:24", text: "God heard their groaning and he remembered his covenant with Abraham, with Isaac and with Jacob.", translation: "NIV"),
        BibleVerse(reference: "Exodus 6:7", text: "I will take you as my own people, and I will be your God. Then you will know that I am the Lord your God, who brought you out from under the yoke of the Egyptians.", translation: "NIV"),
        BibleVerse(reference: "Exodus 12:13", text: "The blood will be a sign for you on the houses where you are, and when I see the blood, I will pass over you. No destructive plague will touch you when I strike Egypt.", translation: "NIV"),
        BibleVerse(reference: "Exodus 13:21", text: "By day the Lord went ahead of them in a pillar of cloud to guide them on their way and by night in a pillar of fire to give them light, so that they could travel by day or night.", translation: "NIV"),
        BibleVerse(reference: "Exodus 20:7", text: "You shall not misuse the name of the Lord your God, for the Lord will not hold anyone guiltless who misuses his name.", translation: "NIV"),
        BibleVerse(reference: "Exodus 20:8", text: "Remember the Sabbath day by keeping it holy.", translation: "NIV"),
        BibleVerse(reference: "Exodus 29:45", text: "Then I will dwell among the Israelites and be their God.", translation: "NIV"),
        BibleVerse(reference: "Exodus 32:26", text: "So he stood at the entrance to the camp and said, \"Whoever is for the Lord, come to me.\"", translation: "NIV"),
        BibleVerse(reference: "Exodus 35:31", text: "And he has filled him with the Spirit of God, with wisdom, with understanding, with knowledge and with all kinds of skills.", translation: "NIV"),
        
        // Leviticus (146-165)
        BibleVerse(reference: "Leviticus 11:45", text: "I am the Lord, who brought you up out of Egypt to be your God; therefore be holy, because I am holy.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 19:2", text: "Speak to the entire assembly of Israel and say to them: 'Be holy because I, the Lord your God, am holy.'", translation: "NIV"),
        BibleVerse(reference: "Leviticus 19:18", text: "Do not seek revenge or bear a grudge against anyone among your people, but love your neighbor as yourself. I am the Lord.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 20:26", text: "You are to be holy to me because I, the Lord, am holy, and I have set you apart from the nations to be my own.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 26:12", text: "I will walk among you and be your God, and you will be my people.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 27:30", text: "A tithe of everything from the land, whether grain from the soil or fruit from the trees, belongs to the Lord; it is holy to the Lord.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 6:7", text: "In this way the priest will make atonement for them before the Lord, and they will be forgiven for any of the things they did that made them guilty.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 10:3", text: "Moses then said to Aaron, \"This is what the Lord spoke of when he said: 'Among those who approach me I will be proved holy; in the sight of all the people I will be honored.'\"", translation: "NIV"),
        BibleVerse(reference: "Leviticus 16:30", text: "Because on this day atonement will be made for you, to cleanse you. Then, before the Lord, you will be clean from all your sins.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 17:11", text: "For the life of a creature is in the blood, and I have given it to you to make atonement for yourselves on the altar; it is the blood that makes atonement for one's life.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 19:34", text: "The foreigner residing among you must be treated as your native-born. Love them as yourself, for you were foreigners in Egypt. I am the Lord your God.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 20:7-8", text: "Consecrate yourselves and be holy, because I am the Lord your God. Keep my decrees and follow them. I am the Lord, who makes you holy.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 22:31", text: "Keep my commands and follow them. I am the Lord.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 23:22", text: "When you reap the harvest of your land, do not reap to the very edges of your field or gather the gleanings of your harvest. Leave them for the poor and for the foreigner residing among you. I am the Lord your God.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 25:17", text: "Do not take advantage of each other, but fear your God. I am the Lord your God.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 26:13", text: "I am the Lord your God, who brought you out of Egypt so that you would no longer be slaves to the Egyptians; I broke the bars of your yoke and enabled you to walk with heads held high.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 26:44-45", text: "Yet in spite of this, when they are in the land of their enemies, I will not reject them or abhor them so as to destroy them completely, breaking my covenant with them. I am the Lord their God.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 9:6", text: "Moses said, \"This is what the Lord has commanded you to do, so that the glory of the Lord may appear to you.\"", translation: "NIV"),
        BibleVerse(reference: "Leviticus 19:9", text: "When you reap the harvest of your land, do not reap to the very edges of your field or gather the gleanings of your harvest.", translation: "NIV"),
        BibleVerse(reference: "Leviticus 19:15", text: "Do not pervert justice; do not show partiality to the poor or favoritism to the great, but judge your neighbor fairly.", translation: "NIV"),
        
        // Numbers (166-185)
        BibleVerse(reference: "Numbers 6:24-26", text: "The Lord bless you and keep you; the Lord make his face shine on you and be gracious to you; the Lord turn his face toward you and give you peace.", translation: "NIV"),
        BibleVerse(reference: "Numbers 14:18", text: "The Lord is slow to anger, abounding in love and forgiving sin and rebellion.", translation: "NIV"),
        BibleVerse(reference: "Numbers 23:19", text: "God is not human, that he should lie, not a human being, that he should change his mind. Does he speak and then not act? Does he promise and not fulfill?", translation: "NIV"),
        BibleVerse(reference: "Numbers 6:25", text: "The Lord make his face shine on you and be gracious to you.", translation: "NIV"),
        BibleVerse(reference: "Numbers 11:23", text: "The Lord answered Moses, \"Is the Lord's arm too short? Now you will see whether or not what I say will come true for you.\"", translation: "NIV"),
        BibleVerse(reference: "Numbers 14:8", text: "If the Lord is pleased with us, he will lead us into that land, a land flowing with milk and honey, and will give it to us.", translation: "NIV"),
        BibleVerse(reference: "Numbers 21:9", text: "So Moses made a bronze snake and put it up on a pole. Then when anyone was bitten by a snake and looked at the bronze snake, they lived.", translation: "NIV"),
        BibleVerse(reference: "Numbers 22:12", text: "But God said to Balaam, \"Do not go with them. You must not put a curse on those people, because they are blessed.\"", translation: "NIV"),
        BibleVerse(reference: "Numbers 23:8", text: "How can I curse those whom God has not cursed? How can I denounce those whom the Lord has not denounced?", translation: "NIV"),
        BibleVerse(reference: "Numbers 24:5", text: "How beautiful are your tents, Jacob, your dwelling places, Israel!", translation: "NIV"),
        BibleVerse(reference: "Numbers 13:30", text: "Then Caleb silenced the people before Moses and said, \"We should go up and take possession of the land, for we can certainly do it.\"", translation: "NIV"),
        BibleVerse(reference: "Numbers 14:9", text: "Only do not rebel against the Lord. And do not be afraid of the people of the land, because we will devour them. Their protection is gone, but the Lord is with us. Do not be afraid of them.", translation: "NIV"),
        BibleVerse(reference: "Numbers 15:40", text: "Then you will remember to obey all my commands and will be consecrated to your God.", translation: "NIV"),
        BibleVerse(reference: "Numbers 16:48", text: "He stood between the living and the dead, and the plague stopped.", translation: "NIV"),
        BibleVerse(reference: "Numbers 20:12", text: "But the Lord said to Moses and Aaron, \"Because you did not trust in me enough to honor me as holy in the sight of the Israelites, you will not bring this community into the land I give them.\"", translation: "NIV"),
        BibleVerse(reference: "Numbers 21:4", text: "They traveled from Mount Hor along the route to the Red Sea, to go around Edom. But the people grew impatient on the way.", translation: "NIV"),
        BibleVerse(reference: "Numbers 22:38", text: "\"Well, I have come to you now,\" Balaam replied. \"But I can't say whatever I please. I must speak only what God puts in my mouth.\"", translation: "NIV"),
        BibleVerse(reference: "Numbers 24:17", text: "I see him, but not now; I behold him, but not near. A star will come out of Jacob; a scepter will rise out of Israel.", translation: "NIV"),
        BibleVerse(reference: "Numbers 27:18", text: "So the Lord said to Moses, \"Take Joshua son of Nun, a man in whom is the spirit of leadership, and lay your hand on him.\"", translation: "NIV"),
        BibleVerse(reference: "Numbers 32:23", text: "But if you fail to do this, you will be sinning against the Lord; and you may be sure that your sin will find you out.", translation: "NIV"),
        
        // Deuteronomy (186-220)
        BibleVerse(reference: "Deuteronomy 6:4-5", text: "Hear, O Israel: The Lord our God, the Lord is one. Love the Lord your God with all your heart and with all your soul and with all your strength.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 6:7", text: "Impress them on your children. Talk about them when you sit at home and when you walk along the road, when you lie down and when you get up.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 7:9", text: "Know therefore that the Lord your God is God; he is the faithful God, keeping his covenant of love to a thousand generations of those who love him and keep his commands.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 10:12", text: "And now, Israel, what does the Lord your God ask of you but to fear the Lord your God, to walk in obedience to him, to love him, to serve the Lord your God with all your heart and with all your soul.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 10:17", text: "For the Lord your God is God of gods and Lord of lords, the great God, mighty and awesome, who shows no partiality and accepts no bribes.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 11:26-28", text: "See, I am setting before you today a blessing and a curse—the blessing if you obey the commands of the Lord your God that I am giving you today; the curse if you disobey the commands of the Lord your God.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 28:2", text: "All these blessings will come on you and accompany you if you obey the Lord your God.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 30:19-20", text: "This day I call the heavens and the earth as witnesses against you that I have set before you life and death, blessings and curses. Now choose life, so that you and your children may live and that you may love the Lord your God, listen to his voice, and hold fast to him.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 31:8", text: "The Lord himself goes before you and will be with you; he will never leave you nor forsake you. Do not be afraid; do not be discouraged.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 32:4", text: "He is the Rock, his works are perfect, and all his ways are just. A faithful God who does no wrong, upright and just is he.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 33:27", text: "The eternal God is your refuge, and underneath are the everlasting arms. He will drive out your enemies before you, saying, 'Destroy them!'", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 4:2", text: "Do not add to what I command you and do not subtract from it, but keep the commands of the Lord your God that I give you.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 4:24", text: "For the Lord your God is a consuming fire, a jealous God.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 4:31", text: "For the Lord your God is a merciful God; he will not abandon or destroy you or forget the covenant with your ancestors, which he confirmed to them by oath.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 5:33", text: "Walk in obedience to all that the Lord your God has commanded you, so that you may live and prosper and prolong your days in the land that you will possess.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 8:2", text: "Remember how the Lord your God led you all the way in the wilderness these forty years, to humble and test you in order to know what was in your heart, whether or not you would keep his commands.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 8:3", text: "He humbled you, causing you to hunger and then feeding you with manna, which neither you nor your ancestors had known, to teach you that man does not live on bread alone but on every word that comes from the mouth of the Lord.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 13:4", text: "It is the Lord your God you must follow, and him you must revere. Keep his commands and obey him; serve him and hold fast to him.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 13:18", text: "The Lord your God will be merciful to you and will bless and increase the numbers of your people, as he promised on oath to your ancestors.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 14:2", text: "For you are a people holy to the Lord your God. Out of all the peoples on the face of the earth, the Lord has chosen you to be his treasured possession.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 16:20", text: "Follow justice and justice alone, so that you may live and possess the land the Lord your God is giving you.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 17:20", text: "And not consider himself better than his fellow Israelites and turn from the law to the right or to the left. Then he and his descendants will reign a long time over his kingdom in Israel.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 18:13", text: "You must be blameless before the Lord your God.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 18:15", text: "The Lord your God will raise up for you a prophet like me from among you, from your fellow Israelites. You must listen to him.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 20:4", text: "For the Lord your God is the one who goes with you to fight for you against your enemies to give you victory.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 23:5", text: "However, the Lord your God would not listen to Balaam but turned the curse into a blessing for you, because the Lord your God loves you.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 26:18", text: "And the Lord has declared this day that you are his people, his treasured possession as he promised, and that you are to keep all his commands.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 29:29", text: "The secret things belong to the Lord our God, but the things revealed belong to us and to our children forever, that we may follow all the words of this law.", translation: "NIV"),
        BibleVerse(reference: "Deuteronomy 31:6", text: "Be strong and courageous. Do not be afraid or terrified because of them, for the Lord your God goes with you; he will never leave you nor forsake you.", translation: "NIV"),
        
        // ========== OLD TESTAMENT - Historical Books ==========
        
        // Joshua (221-240)
        BibleVerse(reference: "Joshua 1:8", text: "Keep this Book of the Law always on your lips; meditate on it day and night, so that you may be careful to do everything written in it. Then you will be prosperous and successful.", translation: "NIV"),
        BibleVerse(reference: "Joshua 1:9", text: "Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.", translation: "NIV"),
        BibleVerse(reference: "Joshua 24:15", text: "But as for me and my household, we will serve the Lord.", translation: "NIV"),
        BibleVerse(reference: "Joshua 1:5", text: "No one will be able to stand against you all the days of your life. As I was with Moses, so I will be with you; I will never leave you nor forsake you.", translation: "NIV"),
        BibleVerse(reference: "Joshua 3:5", text: "Joshua told the people, \"Consecrate yourselves, for tomorrow the Lord will do amazing things among you.\"", translation: "NIV"),
        BibleVerse(reference: "Joshua 7:13", text: "Go, consecrate the people. Tell them, 'Consecrate yourselves in preparation for tomorrow; for this is what the Lord, the God of Israel, says: There are devoted things among you, Israel. You cannot stand against your enemies until you remove them.'", translation: "NIV"),
        BibleVerse(reference: "Joshua 10:25", text: "Joshua said to them, \"Do not be afraid; do not be discouraged. Be strong and courageous. This is what the Lord will do to all the enemies you are going to fight.\"", translation: "NIV"),
        BibleVerse(reference: "Joshua 14:8", text: "But my fellow Israelites who went up with me made the hearts of the people melt in fear. I, however, followed the Lord my God wholeheartedly.", translation: "NIV"),
        BibleVerse(reference: "Joshua 21:45", text: "Not one of all the Lord's good promises to Israel failed; every one was fulfilled.", translation: "NIV"),
        BibleVerse(reference: "Joshua 22:5", text: "But be very careful to keep the commandment and the law that Moses the servant of the Lord gave you: to love the Lord your God, to walk in obedience to him, to keep his commands, to hold fast to him and to serve him with all your heart and with all your soul.", translation: "NIV"),
        BibleVerse(reference: "Joshua 23:3", text: "You yourselves have seen everything the Lord your God has done to all these nations for your sake; it was the Lord your God who fought for you.", translation: "NIV"),
        BibleVerse(reference: "Joshua 23:10", text: "One of you routs a thousand, because the Lord your God fights for you, just as he promised.", translation: "NIV"),
        BibleVerse(reference: "Joshua 23:14", text: "Now I am about to go the way of all the earth. You know with all your heart and soul that not one of all the good promises the Lord your God gave you has failed. Every promise has been fulfilled; not one has failed.", translation: "NIV"),
        BibleVerse(reference: "Joshua 4:24", text: "He did this so that all the peoples of the earth might know that the hand of the Lord is powerful and so that you might always fear the Lord your God.", translation: "NIV"),
        BibleVerse(reference: "Joshua 5:15", text: "The commander of the Lord's army replied, \"Take off your sandals, for the place where you are standing is holy.\" And Joshua did so.", translation: "NIV"),
        BibleVerse(reference: "Joshua 8:1", text: "Then the Lord said to Joshua, \"Do not be afraid; do not be discouraged. Take the whole army with you, and go up and attack Ai.", translation: "NIV"),
        BibleVerse(reference: "Joshua 11:23", text: "So Joshua took the entire land, just as the Lord had directed Moses, and he gave it as an inheritance to Israel according to their tribal divisions. Then the land had rest from war.", translation: "NIV"),
        BibleVerse(reference: "Joshua 13:1", text: "When Joshua had grown old, the Lord said to him, \"You are now very old, and there are still very large areas of land to be taken over.", translation: "NIV"),
        BibleVerse(reference: "Joshua 17:18", text: "The hill country will be yours as well. Although it is forested, you will clear it and possess it to its farthest borders. You will drive out the Canaanites, though they have chariots fitted with iron and though they are strong.", translation: "NIV"),
        BibleVerse(reference: "Joshua 22:34", text: "And the Reubenites and the Gadites gave the altar this name: A Witness Between Us—that the Lord is God.", translation: "NIV"),
        
        // Judges (241-255)
        BibleVerse(reference: "Judges 2:18", text: "Whenever the Lord raised up a judge for them, he was with the judge and saved them out of the hands of their enemies as long as the judge lived; for the Lord relented because of their groaning under those who oppressed and afflicted them.", translation: "NIV"),
        BibleVerse(reference: "Judges 6:12", text: "When the angel of the Lord appeared to Gideon, he said, \"The Lord is with you, mighty warrior.\"", translation: "NIV"),
        BibleVerse(reference: "Judges 6:14", text: "The Lord turned to him and said, \"Go in the strength you have and save Israel out of Midian's hand. Am I not sending you?\"", translation: "NIV"),
        BibleVerse(reference: "Judges 6:16", text: "The Lord answered, \"I will be with you, and you will strike down all the Midianites, leaving none alive.\"", translation: "NIV"),
        BibleVerse(reference: "Judges 13:24", text: "The woman gave birth to a boy and named him Samson. He grew and the Lord blessed him.", translation: "NIV"),
        BibleVerse(reference: "Judges 16:28", text: "Then Samson prayed to the Lord, \"Sovereign Lord, remember me. Please, God, strengthen me just once more, and let me with one blow get revenge on the Philistines for my two eyes.\"", translation: "NIV"),
        BibleVerse(reference: "Judges 17:6", text: "In those days Israel had no king; everyone did as they saw fit.", translation: "NIV"),
        BibleVerse(reference: "Judges 21:25", text: "In those days Israel had no king; everyone did as they saw fit.", translation: "NIV"),
        BibleVerse(reference: "Judges 3:10", text: "The Spirit of the Lord came on him, so that he became Israel's judge and went to war. The Lord gave Cushan-Rishathaim king of Aram into the hands of Othniel, who overpowered him.", translation: "NIV"),
        BibleVerse(reference: "Judges 4:14", text: "Then Deborah said to Barak, \"Go! This is the day the Lord has given Sisera into your hands. Has not the Lord gone ahead of you?\"", translation: "NIV"),
        BibleVerse(reference: "Judges 5:2", text: "When the princes in Israel take the lead, when the people willingly offer themselves—praise the Lord!", translation: "NIV"),
        BibleVerse(reference: "Judges 7:2", text: "The Lord said to Gideon, \"You have too many men. I cannot deliver Midian into their hands, or Israel would boast against me, 'My own strength has saved me.'\"", translation: "NIV"),
        BibleVerse(reference: "Judges 8:23", text: "But Gideon told them, \"I will not rule over you, nor will my son rule over you. The Lord will rule over you.\"", translation: "NIV"),
        BibleVerse(reference: "Judges 11:36", text: "His father replied, \"You have given your word to the Lord. Do to him just as you promised, now that the Lord has avenged you of your enemies, the Ammonites.\"", translation: "NIV"),
        BibleVerse(reference: "Judges 15:18", text: "Because he was very thirsty, he cried out to the Lord, \"You have given your servant this great victory. Must I now die of thirst and fall into the hands of the uncircumcised?\"", translation: "NIV"),
        
        // Ruth (256-265)
        BibleVerse(reference: "Ruth 1:16", text: "But Ruth replied, \"Don't urge me to leave you or to turn back from you. Where you go I will go, and where you stay I will stay. Your people will be my people and your God my God.\"", translation: "NIV"),
        BibleVerse(reference: "Ruth 2:12", text: "May the Lord repay you for what you have done. May you be richly rewarded by the Lord, the God of Israel, under whose wings you have come to take refuge.", translation: "NIV"),
        BibleVerse(reference: "Ruth 3:11", text: "And now, my daughter, don't be afraid. I will do for you all you ask. All the people of my town know that you are a woman of noble character.", translation: "NIV"),
        BibleVerse(reference: "Ruth 4:14", text: "The women said to Naomi: \"Praise be to the Lord, who this day has not left you without a guardian-redeemer. May he become famous throughout Israel!\"", translation: "NIV"),
        BibleVerse(reference: "Ruth 1:13", text: "No, my daughters. It is more bitter for me than for you, because the Lord's hand has turned against me!", translation: "NIV"),
        BibleVerse(reference: "Ruth 2:20", text: "\"The Lord bless him!\" Naomi said to her daughter-in-law. \"He has not stopped showing his kindness to the living and the dead.\"", translation: "NIV"),
        BibleVerse(reference: "Ruth 4:13", text: "So Boaz took Ruth and she became his wife. When he made love to her, the Lord enabled her to conceive, and she gave birth to a son.", translation: "NIV"),
        BibleVerse(reference: "Ruth 1:20", text: "\"Don't call me Naomi,\" she told them. \"Call me Mara, because the Almighty has made my life very bitter.", translation: "NIV"),
        BibleVerse(reference: "Ruth 2:4", text: "Just then Boaz arrived from Bethlehem and greeted the harvesters, \"The Lord be with you!\" \"The Lord bless you!\" they answered.", translation: "NIV"),
        BibleVerse(reference: "Ruth 3:18", text: "Then Naomi said, \"Wait, my daughter, until you find out what happens. For the man will not rest until the matter is settled today.\"", translation: "NIV"),
        
        // 1 Samuel (266-290)
        BibleVerse(reference: "1 Samuel 2:2", text: "There is no one holy like the Lord; there is no one besides you; there is no Rock like our God.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 3:9", text: "So Eli told Samuel, \"Go and lie down, and if he calls you, say, 'Speak, Lord, for your servant is listening.'\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 3:10", text: "The Lord came and stood there, calling as at the other times, \"Samuel! Samuel!\" Then Samuel said, \"Speak, for your servant is listening.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 12:24", text: "But be sure to fear the Lord and serve him faithfully with all your heart; consider what great things he has done for you.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 15:22", text: "But Samuel replied: \"Does the Lord delight in burnt offerings and sacrifices as much as in obeying the Lord? To obey is better than sacrifice, and to heed is better than the fat of rams.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 16:7", text: "But the Lord said to Samuel, \"Do not consider his appearance or his height, for I have rejected him. The Lord does not look at the things people look at. People look at the outward appearance, but the Lord looks at the heart.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 17:45", text: "David said to the Philistine, \"You come against me with sword and spear and javelin, but I come against you in the name of the Lord Almighty, the God of the armies of Israel, whom you have defied.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 17:47", text: "All those gathered here will know that it is not by sword or spear that the Lord saves; for the battle is the Lord's, and he will give all of you into our hands.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 18:14", text: "In everything he did he had great success, because the Lord was with him.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 20:42", text: "Jonathan said to David, \"Go in peace, for we have sworn friendship with each other in the name of the Lord, saying, 'The Lord is witness between you and me, and between your descendants and my descendants forever.'\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 23:16", text: "And Saul's son Jonathan went to David at Horesh and helped him find strength in God.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 24:12", text: "May the Lord judge between you and me. And may the Lord avenge the wrongs you have done to me, but my hand will not touch you.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 26:23", text: "The Lord rewards everyone for their righteousness and faithfulness. The Lord delivered you into my hands today, but I would not lay a hand on the Lord's anointed.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 28:6", text: "He inquired of the Lord, but the Lord did not answer him by dreams or Urim or prophets.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 2:30", text: "Therefore the Lord, the God of Israel, declares: 'I promised that members of your family would minister before me forever.' But now the Lord declares: 'Far be it from me! Those who honor me I will honor, but those who despise me will be disdained.'", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 4:3", text: "When the soldiers returned to camp, the elders of Israel asked, \"Why did the Lord bring defeat on us today before the Philistines? Let us bring the ark of the Lord's covenant from Shiloh, so that he may go with us and save us from the hand of our enemies.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 7:3", text: "And Samuel said to the whole house of Israel, \"If you are returning to the Lord with all your hearts, then rid yourselves of the foreign gods and the Ashtoreths and commit yourselves to the Lord and serve him only, and he will deliver you out of the hand of the Philistines.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 8:7", text: "And the Lord told him: \"Listen to all that the people are saying to you; it is not you they have rejected, but they have rejected me as their king.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 9:17", text: "When Samuel caught sight of Saul, the Lord said to him, \"This is the man I spoke to you about; he will govern my people.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 10:24", text: "Samuel said to all the people, \"Do you see the man the Lord has chosen? There is no one like him among all the people.\" Then the people shouted, \"Long live the king!\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 13:14", text: "But now your kingdom will not endure; the Lord has sought out a man after his own heart and appointed him ruler of his people, because you have not kept the Lord's command.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 14:6", text: "Jonathan said to his young armor-bearer, \"Come, let's go over to the outpost of those uncircumcised men. Perhaps the Lord will act in our behalf. Nothing can hinder the Lord from saving, whether by many or by few.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 15:29", text: "He who is the Glory of Israel does not lie or change his mind; for he is not a human being, that he should change his mind.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 17:34", text: "But David said to Saul, \"Your servant has been keeping his father's sheep. When a lion or a bear came and carried off a sheep from the flock,", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 19:5", text: "He took his life in his hands when he killed the Philistine. The Lord won a great victory for all Israel, and you saw it and were glad. Why then would you do wrong to an innocent man like David by killing him for no reason?\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 22:23", text: "Stay with me; don't be afraid. The man who wants to kill you is trying to kill me too. You will be safe with me.\"", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 25:32", text: "David said to Abigail, \"Praise be to the Lord, the God of Israel, who has sent you today to meet me.", translation: "NIV"),
        BibleVerse(reference: "1 Samuel 30:6", text: "David was greatly distressed because the men were talking of stoning him; each one was bitter in spirit because of his sons and daughters. But David found strength in the Lord his God.", translation: "NIV"),
        
        // 2 Samuel (291-310)
        BibleVerse(reference: "2 Samuel 7:22", text: "How great you are, Sovereign Lord! There is no one like you, and there is no God but you, as we have heard with our own ears.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 22:2", text: "He said: \"The Lord is my rock, my fortress and my deliverer.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 22:31", text: "As for God, his way is perfect: The Lord's word is flawless; he shields all who take refuge in him.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 22:33", text: "It is God who arms me with strength and keeps my way secure.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 23:5", text: "If my house were not right with God, surely he would not have made with me an everlasting covenant, arranged and secured in every part; surely he would not bring to fruition my salvation and grant me my every desire.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 6:14", text: "Wearing a linen ephod, David was dancing before the Lord with all his might.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 12:13", text: "Then David said to Nathan, \"I have sinned against the Lord.\" Nathan replied, \"The Lord has taken away your sin. You are not going to die.\"", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 22:47", text: "The Lord lives! Praise be to my Rock! Exalted be my God, the Rock, my Savior!", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 24:14", text: "David said to Gad, \"I am in deep distress. Let us fall into the hands of the Lord, for his mercy is great; but do not let me fall into human hands.\"", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 5:12", text: "Then David knew that the Lord had established him as king over Israel and had exalted his kingdom for the sake of his people Israel.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 9:3", text: "The king asked, \"Is there no one still alive from the house of Saul to whom I can show God's kindness?\"", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 15:26", text: "But if he says, 'I am not pleased with you,' then I am ready; let him do to me whatever seems good to him.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 22:20", text: "He brought me out into a spacious place; he rescued me because he delighted in me.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 22:29", text: "You, Lord, are my lamp; the Lord turns my darkness into light.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 22:36", text: "You make your saving help my shield; your help has made me great.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 22:50", text: "Therefore I will praise you, Lord, among the nations; I will sing the praises of your name.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 23:2", text: "The Spirit of the Lord spoke through me; his word was on my tongue.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 23:4", text: "He is like the light of morning at sunrise on a cloudless morning, like the brightness after rain that brings grass from the earth.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 14:14", text: "Like water spilled on the ground, which cannot be recovered, so we must die. But that is not what God desires; rather, he devises ways so that a banished person does not remain banished from him.", translation: "NIV"),
        BibleVerse(reference: "2 Samuel 22:3", text: "My God is my rock, in whom I take refuge, my shield and the horn of my salvation. He is my stronghold, my refuge and my savior.", translation: "NIV"),
        
        // 1 Kings (311-325)
        BibleVerse(reference: "1 Kings 3:9", text: "So give your servant a discerning heart to govern your people and to distinguish between right and wrong. For who is able to govern this great people of yours?\"", translation: "NIV"),
        BibleVerse(reference: "1 Kings 3:12", text: "I will do what you have asked. I will give you a wise and discerning heart, so that there will never have been anyone like you, nor will there ever be.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 8:23", text: "Lord, the God of Israel, there is no God like you in heaven above or on earth below—you who keep your covenant of love with your servants who continue wholeheartedly in your way.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 8:56", text: "Praise be to the Lord, who has given rest to his people Israel just as he promised. Not one word has failed of all the good promises he gave through his servant Moses.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 8:60", text: "so that all the peoples of the earth may know that the Lord is God and that there is no other.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 17:24", text: "Then the woman said to Elijah, \"Now I know that you are a man of God and that the word of the Lord from your mouth is the truth.\"", translation: "NIV"),
        BibleVerse(reference: "1 Kings 18:21", text: "Elijah went before the people and said, \"How long will you waver between two opinions? If the Lord is God, follow him; but if Baal is God, follow him.\" But the people said nothing.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 18:39", text: "When all the people saw this, they fell prostrate and cried, \"The Lord—he is God! The Lord—he is God!\"", translation: "NIV"),
        BibleVerse(reference: "1 Kings 19:11-12", text: "The Lord said, \"Go out and stand on the mountain in the presence of the Lord, for the Lord is about to pass by.\" Then a great and powerful wind tore the mountains apart and shattered the rocks before the Lord, but the Lord was not in the wind. After the wind there was an earthquake, but the Lord was not in the earthquake.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 2:2", text: "\"I am about to go the way of all the earth,\" he said. \"So be strong, act like a man.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 4:29", text: "God gave Solomon wisdom and very great insight, and a breadth of understanding as measureless as the sand on the seashore.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 5:4", text: "But now the Lord my God has given me rest on every side, and there is no adversary or disaster.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 6:12", text: "As for this temple you are building, if you follow my decrees, observe my laws and keep all my commands and obey them, I will fulfill through you the promise I gave to David your father.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 11:4", text: "As Solomon grew old, his wives turned his heart after other gods, and his heart was not fully devoted to the Lord his God, as the heart of David his father had been.", translation: "NIV"),
        BibleVerse(reference: "1 Kings 19:18", text: "Yet I reserve seven thousand in Israel—all whose knees have not bowed down to Baal and whose mouths have not kissed him.\"", translation: "NIV"),
        
        // 2 Kings (326-335)
        BibleVerse(reference: "2 Kings 2:9", text: "When they had crossed, Elijah said to Elisha, \"Tell me, what can I do for you before I am taken from you?\" \"Let me inherit a double portion of your spirit,\" Elisha replied.", translation: "NIV"),
        BibleVerse(reference: "2 Kings 4:26", text: "Run to meet her and ask her, 'Are you all right? Is your husband all right? Is your child all right?'' \"Everything is all right,\" she said.", translation: "NIV"),
        BibleVerse(reference: "2 Kings 6:16", text: "\"Don't be afraid,\" the prophet answered. \"Those who are with us are more than those who are with them.\"", translation: "NIV"),
        BibleVerse(reference: "2 Kings 6:17", text: "And Elisha prayed, \"Open his eyes, Lord, so that he may see.\" Then the Lord opened the servant's eyes, and he looked and saw the hills full of horses and chariots of fire all around Elisha.", translation: "NIV"),
        BibleVerse(reference: "2 Kings 13:4", text: "But Jehoahaz sought the Lord's favor, and the Lord listened to him, for he saw how severely the king of Aram was oppressing Israel.", translation: "NIV"),
        BibleVerse(reference: "2 Kings 17:39", text: "Rather, worship the Lord your God; it is he who will deliver you from the hand of all your enemies.", translation: "NIV"),
        BibleVerse(reference: "2 Kings 18:5", text: "Hezekiah trusted in the Lord, the God of Israel. There was no one like him among all the kings of Judah, either before him or after him.", translation: "NIV"),
        BibleVerse(reference: "2 Kings 19:19", text: "Now, Lord our God, deliver us from his hand, so that all the kingdoms of the earth may know that you alone, Lord, are God.", translation: "NIV"),
        BibleVerse(reference: "2 Kings 20:5", text: "Go back and tell Hezekiah, the ruler of my people, 'This is what the Lord, the God of your father David, says: I have heard your prayer and seen your tears; I will heal you.", translation: "NIV"),
        BibleVerse(reference: "2 Kings 23:25", text: "Neither before nor after Josiah was there a king like him who turned to the Lord as he did—with all his heart and with all his soul and with all his strength, in accordance with all the Law of Moses.", translation: "NIV"),
        
        // 1 Chronicles (336-345)
        BibleVerse(reference: "1 Chronicles 16:11", text: "Look to the Lord and his strength; seek his face always.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 16:23", text: "Sing to the Lord, all the earth; proclaim his salvation day after day.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 16:25", text: "For great is the Lord and most worthy of praise; he is to be feared above all gods.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 16:29", text: "Ascribe to the Lord the glory due his name; bring an offering and come before him. Worship the Lord in the splendor of his holiness.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 28:9", text: "And you, my son Solomon, acknowledge the God of your father, and serve him with wholehearted devotion and with a willing mind, for the Lord searches every heart and understands every desire and every thought.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 28:20", text: "David also said to Solomon his son, \"Be strong and courageous, and do the work. Do not be afraid or discouraged, for the Lord God, my God, is with you.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 29:11", text: "Yours, Lord, is the greatness and the power and the glory and the majesty and the splendor, for everything in heaven and earth is yours.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 29:14", text: "But who am I, and who are my people, that we should be able to give as generously as this? Everything comes from you, and we have given you only what comes from your hand.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 17:20", text: "There is no one like you, Lord, and there is no God but you, as we have heard with our own ears.", translation: "NIV"),
        BibleVerse(reference: "1 Chronicles 22:13", text: "Then you will have success if you are careful to observe the decrees and laws that the Lord gave Moses for Israel. Be strong and courageous. Do not be afraid or discouraged.", translation: "NIV"),
        
        // 2 Chronicles (346-360)
        BibleVerse(reference: "2 Chronicles 1:10", text: "Give me wisdom and knowledge, that I may lead this people, for who is able to govern this great people of yours?\"", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 6:14", text: "He said: \"Lord, the God of Israel, there is no God like you in heaven or on earth—you who keep your covenant of love with your servants who continue wholeheartedly in your way.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 7:14", text: "If my people, who are called by my name, will humble themselves and pray and seek my face and turn from their wicked ways, then I will hear from heaven, and I will forgive their sin and will heal their land.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 15:7", text: "But as for you, be strong and do not give up, for your work will be rewarded.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 16:9", text: "For the eyes of the Lord range throughout the earth to strengthen those whose hearts are fully committed to him.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 20:15", text: "He said: \"Listen, King Jehoshaphat and all who live in Judah and Jerusalem! This is what the Lord says to you: 'Do not be afraid or discouraged because of this vast army. For the battle is not yours, but God's.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 20:20", text: "Early in the morning they left for the Desert of Tekoa. As they set out, Jehoshaphat stood and said, \"Listen to me, Judah and people of Jerusalem! Have faith in the Lord your God and you will be upheld; have faith in his prophets and you will be successful.\"", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 30:9", text: "If you return to the Lord, then your fellow Israelites and your children will be shown compassion by their captors and will return to this land, for the Lord your God is gracious and compassionate. He will not turn his face from you if you return to him.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 32:7", text: "\"Be strong and courageous. Do not be afraid or discouraged because of the king of Assyria and the vast army with him, for there is a greater power with us than with him.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 33:13", text: "And when he prayed to him, the Lord was moved by his entreaty and listened to his plea; so he brought him back to Jerusalem and to his kingdom. Then Manasseh knew that the Lord is God.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 34:27", text: "Because your heart was responsive and you humbled yourself before God when you heard what he spoke against this place and its people, and because you humbled yourself before me and tore your robes and wept in my presence, I have heard you, declares the Lord.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 36:23", text: "This is what Cyrus king of Persia says: \"'The Lord, the God of heaven, has given me all the kingdoms of the earth and he has appointed me to build a temple for him at Jerusalem in Judah.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 5:14", text: "and the priests could not perform their service because of the cloud, for the glory of the Lord filled the temple of God.", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 6:18", text: "But will God really dwell on earth with humans? The heavens, even the highest heavens, cannot contain you. How much less this temple I have built!", translation: "NIV"),
        BibleVerse(reference: "2 Chronicles 14:11", text: "Then Asa called to the Lord his God and said, \"Lord, there is no one like you to help the powerless against the mighty. Help us, Lord our God, for we rely on you, and in your name we have come against this vast army. Lord, you are our God; do not let mere mortals prevail against you.\"", translation: "NIV"),
        
        // Ezra, Nehemiah, Esther, Job (361-390)
        BibleVerse(reference: "Ezra 8:22", text: "I was ashamed to ask the king for soldiers and horsemen to protect us from enemies on the road, because we had told the king, \"The gracious hand of our God is on everyone who looks to him, but his great anger is against all who forsake him.\"", translation: "NIV"),
        BibleVerse(reference: "Nehemiah 1:11", text: "Lord, let your ear be attentive to the prayer of this your servant and to the prayer of your servants who delight in revering your name. Give your servant success today by granting him favor in the presence of this man.\"", translation: "NIV"),
        BibleVerse(reference: "Nehemiah 8:10", text: "Nehemiah said, \"Go and enjoy choice food and sweet drinks, and send some to those who have nothing prepared. This day is holy to our Lord. Do not grieve, for the joy of the Lord is your strength.\"", translation: "NIV"),
        BibleVerse(reference: "Esther 4:14", text: "For if you remain silent at this time, relief and deliverance for the Jews will arise from another place, but you and your father's family will perish. And who knows but that you have come to your royal position for such a time as this?\"", translation: "NIV"),
        BibleVerse(reference: "Job 1:21", text: "Naked I came from my mother's womb, and naked I will depart. The Lord gave and the Lord has taken away; may the name of the Lord be praised.\"", translation: "NIV"),
        BibleVerse(reference: "Job 2:10", text: "He replied, \"You are talking like a foolish woman. Shall we accept good from God, and not trouble?\" In all this, Job did not sin in what he said.", translation: "NIV"),
        BibleVerse(reference: "Job 13:15", text: "Though he slay me, yet will I hope in him; I will surely defend my ways to his face.", translation: "NIV"),
        BibleVerse(reference: "Job 19:25", text: "I know that my redeemer lives, and that in the end he will stand on the earth.", translation: "NIV"),
        BibleVerse(reference: "Job 23:10", text: "But he knows the way that I take; when he has tested me, I will come forth as gold.", translation: "NIV"),
        BibleVerse(reference: "Job 28:28", text: "And he said to the human race, \"The fear of the Lord—that is wisdom, and to shun evil is understanding.\"", translation: "NIV"),
        BibleVerse(reference: "Job 37:23", text: "The Almighty is beyond our reach and exalted in power; in his justice and great righteousness, he does not oppress.", translation: "NIV"),
        BibleVerse(reference: "Job 42:2", text: "I know that you can do all things; no purpose of yours can be thwarted.", translation: "NIV"),
        BibleVerse(reference: "Job 42:5", text: "My ears had heard of you but now my eyes have seen you.", translation: "NIV"),
        BibleVerse(reference: "Ezra 7:10", text: "For Ezra had devoted himself to the study and observance of the Law of the Lord, and to teaching its decrees and laws in Israel.", translation: "NIV"),
        BibleVerse(reference: "Nehemiah 2:20", text: "I answered them by saying, \"The God of heaven will give us success. We his servants will start rebuilding, but as for you, you have no share in Jerusalem or any claim or historic right to it.\"", translation: "NIV"),
        BibleVerse(reference: "Nehemiah 6:9", text: "They were all trying to frighten us, thinking, \"Their hands will get too weak for the work, and it will not be completed.\" But I prayed, \"Now strengthen my hands.\"", translation: "NIV"),
        BibleVerse(reference: "Esther 2:17", text: "Now the king was attracted to Esther more than to any of the other women, and she won his favor and approval more than any of the other virgins. So he set a royal crown on her head and made her queen instead of Vashti.", translation: "NIV"),
        BibleVerse(reference: "Job 5:17", text: "Blessed is the one whom God corrects; so do not despise the discipline of the Almighty.", translation: "NIV"),
        BibleVerse(reference: "Job 12:13", text: "To God belong wisdom and power; counsel and understanding are his.", translation: "NIV"),
        BibleVerse(reference: "Job 22:21", text: "Submit to God and be at peace with him; in this way prosperity will come to you.", translation: "NIV"),
        BibleVerse(reference: "Job 26:14", text: "And these are but the outer fringe of his works; how faint the whisper we hear of him! Who then can understand the thunder of his power?\"", translation: "NIV"),
        BibleVerse(reference: "Job 31:4", text: "Does he not see my ways and count my every step?\"", translation: "NIV"),
        BibleVerse(reference: "Job 33:4", text: "The Spirit of God has made me; the breath of the Almighty gives me life.", translation: "NIV"),
        BibleVerse(reference: "Job 36:22", text: "God is exalted in his power. Who is a teacher like him?\"", translation: "NIV"),
        BibleVerse(reference: "Job 38:4", text: "Where were you when I laid the earth's foundation? Tell me, if you understand.", translation: "NIV"),
        BibleVerse(reference: "Job 38:7", text: "while the morning stars sang together and all the angels shouted for joy?\"", translation: "NIV"),
        BibleVerse(reference: "Job 41:11", text: "Who has a claim against me that I must pay? Everything under heaven belongs to me.", translation: "NIV"),
        BibleVerse(reference: "Job 5:8", text: "But if I were you, I would appeal to God; I would lay my cause before him.", translation: "NIV"),
        BibleVerse(reference: "Job 11:7", text: "Can you fathom the mysteries of God? Can you probe the limits of the Almighty?\"", translation: "NIV"),
        BibleVerse(reference: "Job 27:5", text: "I will never admit you are in the right; till I die, I will not deny my integrity.", translation: "NIV"),
        
        // Psalms - Book 1 (391-460) - Adding 70 key Psalms
        BibleVerse(reference: "Psalm 1:1-2", text: "Blessed is the one who does not walk in step with the wicked or stand in the way that sinners take or sit in the company of mockers, but whose delight is in the law of the Lord, and who meditates on his law day and night.", translation: "NIV"),
        BibleVerse(reference: "Psalm 1:3", text: "That person is like a tree planted by streams of water, which yields its fruit in season and whose leaf does not wither—whatever they do prospers.", translation: "NIV"),
        BibleVerse(reference: "Psalm 2:11", text: "Serve the Lord with fear and celebrate his rule with trembling.", translation: "NIV"),
        BibleVerse(reference: "Psalm 3:3", text: "But you, Lord, are a shield around me, my glory, the One who lifts my head high.", translation: "NIV"),
        BibleVerse(reference: "Psalm 3:8", text: "From the Lord comes deliverance. May your blessing be on your people.", translation: "NIV"),
        BibleVerse(reference: "Psalm 4:8", text: "In peace I will lie down and sleep, for you alone, Lord, make me dwell in safety.", translation: "NIV"),
        BibleVerse(reference: "Psalm 5:3", text: "In the morning, Lord, you hear my voice; in the morning I lay my requests before you and wait expectantly.", translation: "NIV"),
        BibleVerse(reference: "Psalm 6:9", text: "The Lord has heard my cry for mercy; the Lord accepts my prayer.", translation: "NIV"),
        BibleVerse(reference: "Psalm 7:10", text: "My shield is God Most High, who saves the upright in heart.", translation: "NIV"),
        BibleVerse(reference: "Psalm 8:1", text: "Lord, our Lord, how majestic is your name in all the earth! You have set your glory in the heavens.", translation: "NIV"),
        BibleVerse(reference: "Psalm 8:3-4", text: "When I consider your heavens, the work of your fingers, the moon and the stars, which you have set in place, what is mankind that you are mindful of them, human beings that you care for them?", translation: "NIV"),
        BibleVerse(reference: "Psalm 9:1", text: "I will give thanks to you, Lord, with all my heart; I will tell of all your wonderful deeds.", translation: "NIV"),
        BibleVerse(reference: "Psalm 9:10", text: "Those who know your name trust in you, for you, Lord, have never forsaken those who seek you.", translation: "NIV"),
        BibleVerse(reference: "Psalm 10:17", text: "You, Lord, hear the desire of the afflicted; you encourage them, and you listen to their cry.", translation: "NIV"),
        BibleVerse(reference: "Psalm 11:7", text: "For the Lord is righteous, he loves justice; the upright will see his face.", translation: "NIV"),
        BibleVerse(reference: "Psalm 12:6", text: "And the words of the Lord are flawless, like silver purified in a crucible, like gold refined seven times.", translation: "NIV"),
        BibleVerse(reference: "Psalm 13:5", text: "But I trust in your unfailing love; my heart rejoices in your salvation.", translation: "NIV"),
        BibleVerse(reference: "Psalm 14:1", text: "The fool says in his heart, \"There is no God.\" They are corrupt, their deeds are vile; there is no one who does good.", translation: "NIV"),
        BibleVerse(reference: "Psalm 15:1-2", text: "Lord, who may dwell in your sacred tent? Who may live on your holy mountain? The one whose walk is blameless, who does what is righteous, who speaks the truth from their heart.", translation: "NIV"),
        BibleVerse(reference: "Psalm 16:8", text: "I keep my eyes always on the Lord. With him at my right hand, I will not be shaken.", translation: "NIV"),
        BibleVerse(reference: "Psalm 16:11", text: "You make known to me the path of life; you will fill me with joy in your presence, with eternal pleasures at your right hand.", translation: "NIV"),
        BibleVerse(reference: "Psalm 17:7", text: "Show me the wonders of your great love, you who save by your right hand those who take refuge in you from their foes.", translation: "NIV"),
        BibleVerse(reference: "Psalm 18:2", text: "The Lord is my rock, my fortress and my deliverer; my God is my rock, in whom I take refuge, my shield and the horn of my salvation, my stronghold.", translation: "NIV"),
        BibleVerse(reference: "Psalm 18:30", text: "As for God, his way is perfect: The Lord's word is flawless; he shields all who take refuge in him.", translation: "NIV"),
        BibleVerse(reference: "Psalm 19:1", text: "The heavens declare the glory of God; the skies proclaim the work of his hands.", translation: "NIV"),
        BibleVerse(reference: "Psalm 19:14", text: "May these words of my mouth and this meditation of my heart be pleasing in your sight, Lord, my Rock and my Redeemer.", translation: "NIV"),
        BibleVerse(reference: "Psalm 20:7", text: "Some trust in chariots and some in horses, but we trust in the name of the Lord our God.", translation: "NIV"),
        BibleVerse(reference: "Psalm 21:13", text: "Be exalted in your strength, Lord; we will sing and praise your might.", translation: "NIV"),
        BibleVerse(reference: "Psalm 22:28", text: "For dominion belongs to the Lord and he rules over the nations.", translation: "NIV"),
        BibleVerse(reference: "Psalm 23:1", text: "The Lord is my shepherd, I lack nothing.", translation: "NIV"),
        BibleVerse(reference: "Psalm 23:4", text: "Even though I walk through the darkest valley, I will fear no evil, for you are with me; your rod and your staff, they comfort me.", translation: "NIV"),
        BibleVerse(reference: "Psalm 23:6", text: "Surely your goodness and love will follow me all the days of my life, and I will dwell in the house of the Lord forever.", translation: "NIV"),
        BibleVerse(reference: "Psalm 24:1", text: "The earth is the Lord's, and everything in it, the world, and all who live in it.", translation: "NIV"),
        BibleVerse(reference: "Psalm 24:10", text: "Who is he, this King of glory? The Lord Almighty—he is the King of glory.", translation: "NIV"),
        BibleVerse(reference: "Psalm 25:4", text: "Show me your ways, Lord, teach me your paths.", translation: "NIV"),
        BibleVerse(reference: "Psalm 25:9", text: "He guides the humble in what is right and teaches them his way.", translation: "NIV"),
        BibleVerse(reference: "Psalm 26:12", text: "My feet stand on level ground; in the great congregation I will praise the Lord.", translation: "NIV"),
        BibleVerse(reference: "Psalm 27:4", text: "One thing I ask from the Lord, this only do I seek: that I may dwell in the house of the Lord all the days of my life, to gaze on the beauty of the Lord and to seek him in his temple.", translation: "NIV"),
        BibleVerse(reference: "Psalm 27:13", text: "I remain confident of this: I will see the goodness of the Lord in the land of the living.", translation: "NIV"),
        BibleVerse(reference: "Psalm 28:7", text: "The Lord is my strength and my shield; my heart trusts in him, and he helps me. My heart leaps for joy, and with my song I praise him.", translation: "NIV"),
        BibleVerse(reference: "Psalm 29:11", text: "The Lord gives strength to his people; the Lord blesses his people with peace.", translation: "NIV"),
        BibleVerse(reference: "Psalm 30:5", text: "For his anger lasts only a moment, but his favor lasts a lifetime; weeping may stay for the night, but rejoicing comes in the morning.", translation: "NIV"),
        BibleVerse(reference: "Psalm 30:11", text: "You turned my wailing into dancing; you removed my sackcloth and clothed me with joy.", translation: "NIV"),
        BibleVerse(reference: "Psalm 31:14", text: "But I trust in you, Lord; I say, \"You are my God.\"", translation: "NIV"),
        BibleVerse(reference: "Psalm 31:24", text: "Be strong and take heart, all you who hope in the Lord.", translation: "NIV"),
        BibleVerse(reference: "Psalm 32:7", text: "You are my hiding place; you will protect me from trouble and surround me with songs of deliverance.", translation: "NIV"),
        BibleVerse(reference: "Psalm 32:11", text: "Rejoice in the Lord and be glad, you righteous; sing, all you who are upright in heart!", translation: "NIV"),
        BibleVerse(reference: "Psalm 33:4", text: "For the word of the Lord is right and true; he is faithful in all he does.", translation: "NIV"),
        BibleVerse(reference: "Psalm 33:20", text: "We wait in hope for the Lord; he is our help and our shield.", translation: "NIV"),
        BibleVerse(reference: "Psalm 34:8", text: "Taste and see that the Lord is good; blessed is the one who takes refuge in him.", translation: "NIV"),
        BibleVerse(reference: "Psalm 34:17", text: "The righteous cry out, and the Lord hears them; he delivers them from all their troubles.", translation: "NIV"),
        BibleVerse(reference: "Psalm 35:9", text: "Then my soul will rejoice in the Lord and delight in his salvation.", translation: "NIV"),
        BibleVerse(reference: "Psalm 36:7", text: "How priceless is your unfailing love, O God! People take refuge in the shadow of your wings.", translation: "NIV"),
        BibleVerse(reference: "Psalm 37:3", text: "Trust in the Lord and do good; dwell in the land and enjoy safe pasture.", translation: "NIV"),
        BibleVerse(reference: "Psalm 37:5", text: "Commit your way to the Lord; trust in him and he will do this.", translation: "NIV"),
        BibleVerse(reference: "Psalm 37:7", text: "Be still before the Lord and wait patiently for him; do not fret when people succeed in their ways, when they carry out their wicked schemes.", translation: "NIV"),
        BibleVerse(reference: "Psalm 37:23", text: "The Lord makes firm the steps of the one who delights in him.", translation: "NIV"),
        BibleVerse(reference: "Psalm 37:39", text: "The salvation of the righteous comes from the Lord; he is their stronghold in time of trouble.", translation: "NIV"),
        BibleVerse(reference: "Psalm 38:15", text: "Lord, I wait for you; you will answer, Lord my God.", translation: "NIV"),
        BibleVerse(reference: "Psalm 39:4", text: "Show me, Lord, my life's end and the number of my days; let me know how fleeting my life is.", translation: "NIV"),
        BibleVerse(reference: "Psalm 40:1", text: "I waited patiently for the Lord; he turned to me and heard my cry.", translation: "NIV"),
        BibleVerse(reference: "Psalm 40:8", text: "I desire to do your will, my God; your law is within my heart.", translation: "NIV"),
        BibleVerse(reference: "Psalm 41:1", text: "Blessed are those who have regard for the weak; the Lord delivers them in times of trouble.", translation: "NIV"),
        BibleVerse(reference: "Psalm 42:1", text: "As the deer pants for streams of water, so my soul pants for you, my God.", translation: "NIV"),
        BibleVerse(reference: "Psalm 42:8", text: "By day the Lord directs his love, at night his song is with me—a prayer to the God of my life.", translation: "NIV"),
        BibleVerse(reference: "Psalm 43:3", text: "Send me your light and your faithful care, let them lead me; let them bring me to your holy mountain, to the place where you dwell.", translation: "NIV"),
        BibleVerse(reference: "Psalm 44:3", text: "It was not by their sword that they won the land, nor did their arm bring them victory; it was your right hand, your arm, and the light of your face, for you loved them.", translation: "NIV"),
        BibleVerse(reference: "Psalm 45:1", text: "My heart is stirred by a noble theme as I recite my verses for the king; my tongue is the pen of a skillful writer.", translation: "NIV"),
        BibleVerse(reference: "Psalm 46:10", text: "He says, \"Be still, and know that I am God; I will be exalted among the nations, I will be exalted in the earth.\"", translation: "NIV"),
        BibleVerse(reference: "Psalm 47:1", text: "Clap your hands, all you nations; shout to God with cries of joy.", translation: "NIV"),
        BibleVerse(reference: "Psalm 48:14", text: "For this God is our God for ever and ever; he will be our guide even to the end.", translation: "NIV"),
        BibleVerse(reference: "Psalm 49:15", text: "But God will redeem me from the realm of the dead; he will surely take me to himself.", translation: "NIV"),
        BibleVerse(reference: "Psalm 50:15", text: "Call on me in the day of trouble; I will deliver you, and you will honor me.\"", translation: "NIV"),
        BibleVerse(reference: "Psalm 51:10", text: "Create in me a pure heart, O God, and renew a steadfast spirit within me.", translation: "NIV"),
        BibleVerse(reference: "Psalm 51:12", text: "Restore to me the joy of your salvation and grant me a willing spirit, to sustain me.", translation: "NIV"),
        BibleVerse(reference: "Psalm 52:8", text: "But I am like an olive tree flourishing in the house of God; I trust in God's unfailing love for ever and ever.", translation: "NIV"),
        BibleVerse(reference: "Psalm 55:16", text: "As for me, I call to God, and the Lord saves me.", translation: "NIV"),
        BibleVerse(reference: "Psalm 55:22", text: "Cast your cares on the Lord and he will sustain you; he will never let the righteous be shaken.", translation: "NIV"),
        BibleVerse(reference: "Psalm 56:3", text: "When I am afraid, I put my trust in you.", translation: "NIV"),
        BibleVerse(reference: "Psalm 56:11", text: "in God I trust and am not afraid. What can man do to me?", translation: "NIV"),
        BibleVerse(reference: "Psalm 57:2", text: "I cry out to God Most High, to God, who vindicates me.", translation: "NIV"),
        BibleVerse(reference: "Psalm 58:11", text: "Then people will say, \"Surely the righteous still are rewarded; surely there is a God who judges the earth.\"", translation: "NIV"),
        BibleVerse(reference: "Psalm 59:16", text: "But I will sing of your strength, in the morning I will sing of your love; for you are my fortress, my refuge in times of trouble.", translation: "NIV"),
        BibleVerse(reference: "Psalm 61:2", text: "From the ends of the earth I call to you, I call as my heart grows faint; lead me to the rock that is higher than I.", translation: "NIV"),
        BibleVerse(reference: "Psalm 62:1", text: "Truly my soul finds rest in God; my salvation comes from him.", translation: "NIV"),
        BibleVerse(reference: "Psalm 62:6", text: "Truly he is my rock and my salvation; he is my fortress, I will not be shaken.", translation: "NIV"),
        BibleVerse(reference: "Psalm 63:1", text: "You, God, are my God, earnestly I seek you; I thirst for you, my whole being longs for you, in a dry and parched land where there is no water.", translation: "NIV"),
        BibleVerse(reference: "Psalm 64:10", text: "The righteous will rejoice in the Lord and take refuge in him; all the upright in heart will glory in him!", translation: "NIV"),
        BibleVerse(reference: "Psalm 65:2", text: "You who answer prayer, to you all people will come.", translation: "NIV"),
        BibleVerse(reference: "Psalm 66:5", text: "Come and see what God has done, his awesome deeds for mankind!", translation: "NIV"),
        BibleVerse(reference: "Psalm 67:1", text: "May God be gracious to us and bless us and make his face shine on us.", translation: "NIV"),
        BibleVerse(reference: "Psalm 68:19", text: "Praise be to the Lord, to God our Savior, who daily bears our burdens.", translation: "NIV"),
        BibleVerse(reference: "Psalm 69:33", text: "The Lord hears the needy and does not despise his captive people.", translation: "NIV"),
        BibleVerse(reference: "Psalm 70:4", text: "But may all who seek you rejoice and be glad in you; may those who long for your saving help always say, \"The Lord is great!\"", translation: "NIV"),
        BibleVerse(reference: "Psalm 71:5", text: "For you have been my hope, Sovereign Lord, my confidence since my youth.", translation: "NIV"),
        BibleVerse(reference: "Psalm 73:25", text: "Whom have I in heaven but you? And earth has nothing I desire besides you.", translation: "NIV"),
        BibleVerse(reference: "Psalm 73:26", text: "My flesh and my heart may fail, but God is the strength of my heart and my portion forever.", translation: "NIV"),
        BibleVerse(reference: "Psalm 84:10", text: "Better is one day in your courts than a thousand elsewhere; I would rather be a doorkeeper in the house of my God than dwell in the tents of the wicked.", translation: "NIV"),
        BibleVerse(reference: "Psalm 86:11", text: "Teach me your way, Lord, that I may rely on your faithfulness; give me an undivided heart, that I may fear your name.", translation: "NIV"),
        BibleVerse(reference: "Psalm 89:1", text: "I will sing of the Lord's great love forever; with my mouth I will make your faithfulness known through all generations.", translation: "NIV"),
        BibleVerse(reference: "Psalm 91:1", text: "Whoever dwells in the shelter of the Most High will rest in the shadow of the Almighty.", translation: "NIV"),
        BibleVerse(reference: "Psalm 91:4", text: "He will cover you with his feathers, and under his wings you will find refuge; his faithfulness will be your shield and rampart.", translation: "NIV"),
        BibleVerse(reference: "Psalm 94:19", text: "When anxiety was great within me, your consolation brought me joy.", translation: "NIV"),
        BibleVerse(reference: "Psalm 95:1", text: "Come, let us sing for joy to the Lord; let us shout aloud to the Rock of our salvation.", translation: "NIV"),
        BibleVerse(reference: "Psalm 95:6", text: "Come, let us bow down in worship, let us kneel before the Lord our Maker.", translation: "NIV"),
        BibleVerse(reference: "Psalm 96:9", text: "Worship the Lord in the splendor of his holiness; tremble before him, all the earth.", translation: "NIV"),
        BibleVerse(reference: "Psalm 97:1", text: "The Lord reigns, let the earth be glad; let the distant shores rejoice.", translation: "NIV"),
        BibleVerse(reference: "Psalm 100:1", text: "Shout for joy to the Lord, all the earth.", translation: "NIV"),
        BibleVerse(reference: "Psalm 100:3", text: "Know that the Lord is God. It is he who made us, and we are his; we are his people, the sheep of his pasture.", translation: "NIV"),
        BibleVerse(reference: "Psalm 103:1", text: "Praise the Lord, my soul; all my inmost being, praise his holy name.", translation: "NIV"),
        BibleVerse(reference: "Psalm 103:8", text: "The Lord is compassionate and gracious, slow to anger, abounding in love.", translation: "NIV"),
        BibleVerse(reference: "Psalm 103:13", text: "As a father has compassion on his children, so the Lord has compassion on those who fear him.", translation: "NIV"),
        BibleVerse(reference: "Psalm 104:1", text: "Praise the Lord, my soul. Lord my God, you are very great; you are clothed with splendor and majesty.", translation: "NIV"),
        BibleVerse(reference: "Psalm 105:4", text: "Look to the Lord and his strength; seek his face always.", translation: "NIV"),
        BibleVerse(reference: "Psalm 106:1", text: "Praise the Lord. Give thanks to the Lord, for he is good; his love endures forever.", translation: "NIV"),
        BibleVerse(reference: "Psalm 107:1", text: "Give thanks to the Lord, for he is good; his love endures forever.", translation: "NIV"),
        BibleVerse(reference: "Psalm 108:1", text: "My heart, O God, is steadfast; I will sing and make music with all my soul.", translation: "NIV"),
        BibleVerse(reference: "Psalm 112:1", text: "Praise the Lord. Blessed are those who fear the Lord, who find great delight in his commands.", translation: "NIV"),
        BibleVerse(reference: "Psalm 115:1", text: "Not to us, Lord, not to us but to your name be the glory, because of your love and faithfulness.", translation: "NIV"),
        BibleVerse(reference: "Psalm 118:6", text: "The Lord is with me; I will not be afraid. What can mere mortals do to me?", translation: "NIV"),
        BibleVerse(reference: "Psalm 118:24", text: "The Lord has done it this very day; let us rejoice today and be glad.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:11", text: "I have hidden your word in my heart that I might not sin against you.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:18", text: "Open my eyes that I may see wonderful things in your law.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:50", text: "My comfort in my suffering is this: Your promise preserves my life.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:67", text: "Before I was afflicted I went astray, but now I obey your word.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:89", text: "Your word, Lord, is eternal; it stands firm in the heavens.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:105", text: "Your word is a lamp for my feet, a light on my path.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:114", text: "You are my refuge and my shield; I have put my hope in your word.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:130", text: "The unfolding of your words gives light; it gives understanding to the simple.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:133", text: "Direct my footsteps according to your word; let no sin rule over me.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:165", text: "Great peace have those who love your law, and nothing can make them stumble.", translation: "NIV"),
        BibleVerse(reference: "Psalm 119:176", text: "I have strayed like a lost sheep. Seek your servant, for I have not forgotten your commands.", translation: "NIV"),
        BibleVerse(reference: "Psalm 121:1-2", text: "I lift up my eyes to the mountains—where does my help come from? My help comes from the Lord, the Maker of heaven and earth.", translation: "NIV"),
        BibleVerse(reference: "Psalm 121:5", text: "The Lord watches over you—the Lord is your shade at your right hand.", translation: "NIV"),
        BibleVerse(reference: "Psalm 121:8", text: "The Lord will watch over your coming and going both now and forevermore.", translation: "NIV"),
        BibleVerse(reference: "Psalm 122:1", text: "I rejoiced with those who said to me, \"Let us go to the house of the Lord.\"", translation: "NIV"),
        BibleVerse(reference: "Psalm 125:1", text: "Those who trust in the Lord are like Mount Zion, which cannot be shaken but endures forever.", translation: "NIV"),
        BibleVerse(reference: "Psalm 126:5", text: "Those who sow with tears will reap with songs of joy.", translation: "NIV"),
        BibleVerse(reference: "Psalm 127:1", text: "Unless the Lord builds the house, the builders labor in vain. Unless the Lord watches over the city, the guards stand watch in vain.", translation: "NIV"),
        BibleVerse(reference: "Psalm 128:1", text: "Blessed are all who fear the Lord, who walk in obedience to him.", translation: "NIV"),
        BibleVerse(reference: "Psalm 130:5", text: "I wait for the Lord, my whole being waits, and in his word I put my hope.", translation: "NIV"),
        BibleVerse(reference: "Psalm 133:1", text: "How good and pleasant it is when God's people live together in unity!", translation: "NIV"),
        BibleVerse(reference: "Psalm 136:1", text: "Give thanks to the Lord, for he is good. His love endures forever.", translation: "NIV"),
        BibleVerse(reference: "Psalm 138:8", text: "The Lord will vindicate me; your love, Lord, endures forever—do not abandon the works of your hands.", translation: "NIV"),
        BibleVerse(reference: "Psalm 139:1", text: "You have searched me, Lord, and you know me.", translation: "NIV"),
        BibleVerse(reference: "Psalm 139:14", text: "I praise you because I am fearfully and wonderfully made; your works are wonderful, I know that full well.", translation: "NIV"),
        BibleVerse(reference: "Psalm 139:23-24", text: "Search me, God, and know my heart; test me and know my anxious thoughts. See if there is any offensive way in me, and lead me in the way everlasting.", translation: "NIV"),
        BibleVerse(reference: "Psalm 140:6", text: "I say to the Lord, \"You are my God.\" Hear, Lord, my cry for mercy.", translation: "NIV"),
        BibleVerse(reference: "Psalm 141:2", text: "May my prayer be set before you like incense; may the lifting up of my hands be like the evening sacrifice.", translation: "NIV"),
        BibleVerse(reference: "Psalm 142:5", text: "I cry to you, Lord; I say, \"You are my refuge, my portion in the land of the living.\"", translation: "NIV"),
        BibleVerse(reference: "Psalm 143:8", text: "Let the morning bring me word of your unfailing love, for I have put my trust in you. Show me the way I should go, for to you I entrust my life.", translation: "NIV"),
        BibleVerse(reference: "Psalm 144:1", text: "Praise be to the Lord my Rock, who trains my hands for war, my fingers for battle.", translation: "NIV"),
        BibleVerse(reference: "Psalm 145:8", text: "The Lord is gracious and compassionate, slow to anger and rich in love.", translation: "NIV"),
        BibleVerse(reference: "Psalm 145:18", text: "The Lord is near to all who call on him, to all who call on him in truth.", translation: "NIV"),
        BibleVerse(reference: "Psalm 146:5", text: "Blessed are those whose help is the God of Jacob, whose hope is in the Lord their God.", translation: "NIV"),
        BibleVerse(reference: "Psalm 147:3", text: "He heals the brokenhearted and binds up their wounds.", translation: "NIV"),
        BibleVerse(reference: "Psalm 148:1", text: "Praise the Lord. Praise the Lord from the heavens; praise him in the heights above.", translation: "NIV"),
        BibleVerse(reference: "Psalm 149:1", text: "Praise the Lord. Sing to the Lord a new song, his praise in the assembly of his faithful people.", translation: "NIV"),
        BibleVerse(reference: "Psalm 150:6", text: "Let everything that has breath praise the Lord. Praise the Lord.", translation: "NIV"),
        
        // Proverbs (706-770) - 65 key verses
        BibleVerse(reference: "Proverbs 1:7", text: "The fear of the Lord is the beginning of knowledge, but fools despise wisdom and instruction.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 2:6", text: "For the Lord gives wisdom; from his mouth come knowledge and understanding.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:3", text: "Let love and faithfulness never leave you; bind them around your neck, write them on the tablet of your heart.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:9-10", text: "Honor the Lord with your wealth, with the firstfruits of all your crops; then your barns will be filled to overflowing, and your vats will brim over with new wine.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:11-12", text: "My son, do not despise the Lord's discipline, and do not resent his rebuke, because the Lord disciplines those he loves, as a father the son he delights in.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:13", text: "Blessed are those who find wisdom, those who gain understanding.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:19", text: "By wisdom the Lord laid the earth's foundations, by understanding he set the heavens in place.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:21", text: "My son, do not let wisdom and understanding out of your sight, preserve sound judgment and discretion.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:24", text: "When you lie down, you will not be afraid; when you lie down, your sleep will be sweet.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:26", text: "For the Lord will be at your side and will keep your foot from being snared.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:27", text: "Do not withhold good from those to whom it is due, when it is in your power to act.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:31", text: "Do not envy the violent or choose any of their ways.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 3:33", text: "The Lord's curse is on the house of the wicked, but he blesses the home of the righteous.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 4:11", text: "I instruct you in the way of wisdom and lead you along straight paths.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 4:13", text: "Hold on to instruction, do not let it go; guard it well, for it is your life.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 4:18", text: "The path of the righteous is like the morning sun, shining ever brighter till the full light of day.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 4:23", text: "Above all else, guard your heart, for everything you do flows from it.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 4:26", text: "Give careful thought to the paths for your feet and be steadfast in all your ways.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 6:6", text: "Go to the ant, you sluggard; consider its ways and be wise!", translation: "NIV"),
        BibleVerse(reference: "Proverbs 8:11", text: "for wisdom is more precious than rubies, and nothing you desire can compare with her.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 9:10", text: "The fear of the Lord is the beginning of wisdom, and knowledge of the Holy One is understanding.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 10:12", text: "Hatred stirs up conflict, but love covers over all wrongs.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 11:2", text: "When pride comes, then comes disgrace, but with humility comes wisdom.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 11:25", text: "A generous person will prosper; whoever refreshes others will be refreshed.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 12:15", text: "The way of fools seems right to them, but the wise listen to advice.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 13:3", text: "Those who guard their lips preserve their lives, but those who speak rashly will come to ruin.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 14:12", text: "There is a way that appears to be right, but in the end it leads to death.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 14:27", text: "The fear of the Lord is a fountain of life, turning a person from the snares of death.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 14:30", text: "A heart at peace gives life to the body, but envy rots the bones.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 15:1", text: "A gentle answer turns away wrath, but a harsh word stirs up anger.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 15:3", text: "The eyes of the Lord are everywhere, keeping watch on the wicked and the good.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 15:16", text: "Better a little with the fear of the Lord than great wealth with turmoil.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 15:29", text: "The Lord is far from the wicked, but he hears the prayer of the righteous.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:1", text: "To humans belong the plans of the heart, but from the Lord comes the proper answer of the tongue.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:2", text: "All a person's ways seem pure to them, but motives are weighed by the Lord.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:7", text: "When the Lord takes pleasure in anyone's way, he causes their enemies to make peace with them.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:9", text: "In their hearts humans plan their course, but the Lord establishes their steps.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:20", text: "Whoever gives heed to instruction prospers, and blessed is the one who trusts in the Lord.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:24", text: "Gracious words are a honeycomb, sweet to the soul and healing to the bones.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:25", text: "There is a way that appears to be right, but in the end it leads to death.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:31", text: "Gray hair is a crown of splendor; it is attained in the way of righteousness.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 16:32", text: "Better a patient person than a warrior, one with self-control than one who takes a city.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 17:9", text: "Whoever would foster love covers over an offense, but whoever repeats the matter separates close friends.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 17:22", text: "A cheerful heart is good medicine, but a crushed spirit dries up the bones.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 18:10", text: "The name of the Lord is a fortified tower; the righteous run to it and are safe.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 18:22", text: "He who finds a wife finds what is good and receives favor from the Lord.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 19:11", text: "A person's wisdom yields patience; it is to one's glory to overlook an offense.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 19:17", text: "Whoever is kind to the poor lends to the Lord, and he will reward them for what they have done.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 19:21", text: "Many are the plans in a person's heart, but it is the Lord's purpose that prevails.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 20:1", text: "Wine is a mocker and beer a brawler; whoever is led astray by them is not wise.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 20:5", text: "The purposes of a person's heart are deep waters, but one who has insight draws them out.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 20:24", text: "A person's steps are directed by the Lord. How then can anyone understand their own way?", translation: "NIV"),
        BibleVerse(reference: "Proverbs 21:1", text: "In the Lord's hand the king's heart is a stream of water that he channels toward all who please him.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 21:3", text: "To do what is right and just is more acceptable to the Lord than sacrifice.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 21:21", text: "Whoever pursues righteousness and love finds life, prosperity and honor.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 21:31", text: "The horse is made ready for the day of battle, but victory rests with the Lord.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 22:1", text: "A good name is more desirable than great riches; to be esteemed is better than silver or gold.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 22:4", text: "Humility is the fear of the Lord; its wages are riches and honor and life.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 22:6", text: "Start children off on the way they should go, and even when they are old they will not turn from it.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 22:9", text: "The generous will themselves be blessed, for they share their food with the poor.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 23:4", text: "Do not wear yourself out to get rich; do not trust your own cleverness.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 23:12", text: "Apply your heart to instruction and your ears to words of knowledge.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 24:3", text: "By wisdom a house is built, and through understanding it is established.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 24:14", text: "Know also that wisdom is like honey for you: If you find it, there is a future hope for you, and your hope will not be cut off.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 24:16", text: "for though the righteous fall seven times, they rise again, but the wicked stumble when calamity strikes.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 25:21", text: "If your enemy is hungry, give him food to eat; if he is thirsty, give him water to drink.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 27:1", text: "Do not boast about tomorrow, for you do not know what a day may bring.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 27:17", text: "As iron sharpens iron, so one person sharpens another.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 28:13", text: "Whoever conceals their sins does not prosper, but the one who confesses and renounces them finds mercy.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 28:14", text: "Blessed is the one who always trembles before God, but whoever hardens their heart falls into trouble.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 28:25", text: "The greedy stir up conflict, but those who trust in the Lord will prosper.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 29:11", text: "Fools give full vent to their rage, but the wise bring calm in the end.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 29:18", text: "Where there is no revelation, people cast off restraint; but blessed is the one who heeds wisdom's instruction.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 30:5", text: "Every word of God is flawless; he is a shield to those who take refuge in him.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 31:8", text: "Speak up for those who cannot speak for themselves, for the rights of all who are destitute.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 31:10", text: "A wife of noble character who can find? She is worth far more than rubies.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 31:25", text: "She is clothed with strength and dignity; she can laugh at the days to come.", translation: "NIV"),
        BibleVerse(reference: "Proverbs 31:30", text: "Charm is deceptive, and beauty is fleeting; but a woman who fears the Lord is to be praised.", translation: "NIV"),
        
        // Ecclesiastes & Song of Songs (771-785)
        BibleVerse(reference: "Ecclesiastes 3:1", text: "There is a time for everything, and a season for every activity under the heavens.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 3:11", text: "He has made everything beautiful in its time. He has also set eternity in the human heart; yet no one can fathom what God has done from beginning to end.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 4:9", text: "Two are better than one, because they have a good return for their labor.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 5:2", text: "Do not be quick with your mouth, do not be hasty in your heart to utter anything before God. God is in heaven and you are on earth, so let your words be few.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 7:14", text: "When times are good, be happy; but when times are bad, consider this: God has made the one as well as the other. Therefore, no one can discover anything about their future.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 9:10", text: "Whatever your hand finds to do, do it with all your might, for in the realm of the dead, where you are going, there is neither working nor planning nor knowledge nor wisdom.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 12:13", text: "Now all has been heard; here is the conclusion of the matter: Fear God and keep his commandments, for this is the duty of all mankind.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 12:14", text: "For God will bring every deed into judgment, including every hidden thing, whether it is good or evil.", translation: "NIV"),
        BibleVerse(reference: "Song of Songs 2:4", text: "Let him lead me to the banquet hall, and let his banner over me be love.", translation: "NIV"),
        BibleVerse(reference: "Song of Songs 8:7", text: "Many waters cannot quench love; rivers cannot sweep it away. If one were to give all the wealth of one's house for love, it would be utterly scorned.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 1:9", text: "What has been will be again, what has been done will be done again; there is nothing new under the sun.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 2:26", text: "To the person who pleases him, God gives wisdom, knowledge and happiness, but to the sinner he gives the task of gathering and storing up wealth to hand it over to the one who pleases God.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 5:19", text: "Moreover, when God gives someone wealth and possessions, and the ability to enjoy them, to accept their lot and be happy in their toil—this is a gift of God.", translation: "NIV"),
        BibleVerse(reference: "Ecclesiastes 11:9", text: "You who are young, be happy while you are young, and let your heart give you joy in the days of your youth. Follow the ways of your heart and whatever your eyes see, but know that for all these things God will bring you into judgment.", translation: "NIV"),
        BibleVerse(reference: "Song of Songs 4:7", text: "You are altogether beautiful, my darling; there is no flaw in you.", translation: "NIV"),
        
        // Isaiah - Major Prophet (786-850) - 65 verses
        BibleVerse(reference: "Isaiah 1:18", text: "\"Come now, let us settle the matter,\" says the Lord. \"Though your sins are like scarlet, they shall be as white as snow; though they are red as crimson, they shall be like wool.\"", translation: "NIV"),
        BibleVerse(reference: "Isaiah 6:3", text: "And they were calling to one another: \"Holy, holy, holy is the Lord Almighty; the whole earth is full of his glory.\"", translation: "NIV"),
        BibleVerse(reference: "Isaiah 6:8", text: "Then I heard the voice of the Lord saying, \"Whom shall I send? And who will go for us?\" And I said, \"Here am I. Send me!\"", translation: "NIV"),
        BibleVerse(reference: "Isaiah 7:14", text: "Therefore the Lord himself will give you a sign: The virgin will conceive and give birth to a son, and will call him Immanuel.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 9:2", text: "The people walking in darkness have seen a great light; on those living in the land of deep darkness a light has dawned.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 9:6", text: "For to us a child is born, to us a son is given, and the government will be on his shoulders. And he will be called Wonderful Counselor, Mighty God, Everlasting Father, Prince of Peace.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 11:2", text: "The Spirit of the Lord will rest on him—the Spirit of wisdom and of understanding, the Spirit of counsel and of might, the Spirit of the knowledge and fear of the Lord.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 12:2", text: "Surely God is my salvation; I will trust and not be afraid. The Lord, the Lord himself, is my strength and my defense; he has become my salvation.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 25:1", text: "Lord, you are my God; I will exalt you and praise your name, for in perfect faithfulness you have done wonderful things, things planned long ago.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 26:3", text: "You will keep in perfect peace those whose minds are steadfast, because they trust in you.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 26:4", text: "Trust in the Lord forever, for the Lord, the Lord himself, is the Rock eternal.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 30:15", text: "This is what the Sovereign Lord, the Holy One of Israel, says: \"In repentance and rest is your salvation, in quietness and trust is your strength, but you would have none of it.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 30:18", text: "Yet the Lord longs to be gracious to you; therefore he will rise up to show you compassion. For the Lord is a God of justice. Blessed are all who wait for him!", translation: "NIV"),
        BibleVerse(reference: "Isaiah 31:1", text: "Woe to those who go down to Egypt for help, who rely on horses, who trust in the multitude of their chariots and in the great strength of their horsemen, but do not look to the Holy One of Israel, or seek help from the Lord.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 32:17", text: "The fruit of that righteousness will be peace; its effect will be quietness and confidence forever.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 33:2", text: "Lord, be gracious to us; we long for you. Be our strength every morning, our salvation in time of distress.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 35:4", text: "say to those with fearful hearts, \"Be strong, do not fear; your God will come, he will come with vengeance; with divine retribution he will come to save you.\"", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:3", text: "A voice of one calling: \"In the wilderness prepare the way for the Lord; make straight in the desert a highway for our God.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:5", text: "And the glory of the Lord will be revealed, and all people will see it together. For the mouth of the Lord has spoken.\"", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:6", text: "A voice says, \"Cry out.\" And I said, \"What shall I cry?\" \"All people are like grass, and all their faithfulness is like the flowers of the field.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:10", text: "See, the Sovereign Lord comes with power, and he rules with a mighty arm. See, his reward is with him, and his recompense accompanies him.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:11", text: "He tends his flock like a shepherd: He gathers the lambs in his arms and carries them close to his heart; he gently leads those that have young.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:28", text: "Do you not know? Have you not heard? The Lord is the everlasting God, the Creator of the ends of the earth. He will not grow tired or weary, and his understanding no one can fathom.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 40:29", text: "He gives strength to the weary and increases the power of the weak.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 41:10", text: "So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 41:13", text: "For I am the Lord your God who takes hold of your right hand and says to you, Do not fear; I will help you.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 43:1", text: "But now, this is what the Lord says—he who created you, Jacob, he who formed you, Israel: \"Do not fear, for I have redeemed you; I have summoned you by name; you are mine.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 43:2", text: "When you pass through the waters, I will be with you; and when you pass through the rivers, they will not sweep over you. When you walk through the fire, you will not be burned; the flames will not set you ablaze.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 43:4", text: "Since you are precious and honored in my sight, and because I love you, I will give people in exchange for you, nations in exchange for your life.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 43:11", text: "I, even I, am the Lord, and apart from me there is no savior.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 43:25", text: "I, even I, am he who blots out your transgressions, for my own sake, and remembers your sins no more.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 44:3", text: "For I will pour water on the thirsty land, and streams on the dry ground; I will pour out my Spirit on your offspring, and my blessing on your descendants.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 44:6", text: "This is what the Lord says—Israel's King and Redeemer, the Lord Almighty: I am the first and I am the last; apart from me there is no God.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 44:22", text: "I have swept away your offenses like a cloud, your sins like the morning mist. Return to me, for I have redeemed you.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 45:5", text: "I am the Lord, and there is no other; apart from me there is no God. I will strengthen you, though you have not acknowledged me.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 46:4", text: "Even to your old age and gray hairs I am he, I am he who will sustain you. I have made you and I will carry you; I will sustain you and I will rescue you.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 48:17", text: "This is what the Lord says—your Redeemer, the Holy One of Israel: \"I am the Lord your God, who teaches you what is best for you, who directs you in the way you should go.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 49:15", text: "Can a mother forget the baby at her breast and have no compassion on the child she has borne? Though she may forget, I will not forget you!", translation: "NIV"),
        BibleVerse(reference: "Isaiah 50:7", text: "Because the Sovereign Lord helps me, I will not be disgraced. Therefore have I set my face like flint, and I know I will not be put to shame.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 52:7", text: "How beautiful on the mountains are the feet of those who bring good news, who proclaim peace, who bring good tidings, who proclaim salvation, who say to Zion, \"Your God reigns!\"", translation: "NIV"),
        BibleVerse(reference: "Isaiah 53:5", text: "But he was pierced for our transgressions, he was crushed for our iniquities; the punishment that brought us peace was on him, and by his wounds we are healed.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 53:6", text: "We all, like sheep, have gone astray, each of us has turned to our own way; and the Lord has laid on him the iniquity of us all.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 54:10", text: "Though the mountains be shaken and the hills be removed, yet my unfailing love for you will not be shaken nor my covenant of peace be removed,\" says the Lord, who has compassion on you.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 55:6", text: "Seek the Lord while he may be found; call on him while he is near.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 55:8-9", text: "\"For my thoughts are not your thoughts, neither are your ways my ways,\" declares the Lord. \"As the heavens are higher than the earth, so are my ways higher than your ways and my thoughts than your thoughts.\"", translation: "NIV"),
        BibleVerse(reference: "Isaiah 55:11", text: "so is my word that goes out from my mouth: It will not return to me empty, but will accomplish what I desire and achieve the purpose for which I sent it.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 57:15", text: "For this is what the high and exalted One says—he who lives forever, whose name is holy: \"I live in a high and holy place, but also with the one who is contrite and lowly in spirit, to revive the spirit of the lowly and to revive the heart of the contrite.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 58:11", text: "The Lord will guide you always; he will satisfy your needs in a sun-scorched land and will strengthen your frame. You will be like a well-watered garden, like a spring whose waters never fail.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 59:1", text: "Surely the arm of the Lord is not too short to save, nor his ear too dull to hear.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 60:1", text: "Arise, shine, for your light has come, and the glory of the Lord rises upon you.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 61:1", text: "The Spirit of the Sovereign Lord is on me, because the Lord has anointed me to proclaim good news to the poor. He has sent me to bind up the brokenhearted, to proclaim freedom for the captives and release from darkness for the prisoners.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 61:3", text: "and provide for those who grieve in Zion—to bestow on them a crown of beauty instead of ashes, the oil of joy instead of mourning, and a garment of praise instead of a spirit of despair.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 62:1", text: "For Zion's sake I will not keep silent, for Jerusalem's sake I will not remain quiet, till her vindication shines out like the dawn, her salvation like a blazing torch.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 64:8", text: "Yet you, Lord, are our Father. We are the clay, you are the potter; we are all the work of your hand.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 65:24", text: "Before they call I will answer; while they are still speaking I will hear.", translation: "NIV"),
        BibleVerse(reference: "Isaiah 66:1", text: "This is what the Lord says: \"Heaven is my throne, and the earth is my footstool. Where is the house you will build for me? Where will my resting place be?", translation: "NIV"),
        BibleVerse(reference: "Isaiah 66:2", text: "Has not my hand made all these things, and so they came into being?\" declares the Lord. \"These are the ones I look on with favor: those who are humble and contrite in spirit, and who tremble at my word.", translation: "NIV"),
        
        // Minor Prophets & Daniel (851-890) - Continuing to reach 1000
        BibleVerse(reference: "Jeremiah 1:5", text: "Before I formed you in the womb I knew you, before you were born I set you apart; I appointed you as a prophet to the nations.\"", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 9:24", text: "but let the one who boasts boast about this: that they have the understanding to know me, that I am the Lord, who exercises kindness, justice and righteousness on earth, for in these I delight,\" declares the Lord.", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 17:7", text: "But blessed is the one who trusts in the Lord, whose confidence is in him.", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 29:11", text: "For I know the plans I have for you,\" declares the Lord, \"plans to prosper you and not to harm you, plans to give you hope and a future.", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 29:12-13", text: "Then you will call on me and come and pray to me, and I will listen to you. You will seek me and find me when you seek me with all your heart.", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 31:3", text: "The Lord appeared to us in the past, saying: \"I have loved you with an everlasting love; I have drawn you with unfailing kindness.", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 32:17", text: "Ah, Sovereign Lord, you have made the heavens and the earth by your great power and outstretched arm. Nothing is too hard for you.", translation: "NIV"),
        BibleVerse(reference: "Lamentations 3:22-23", text: "Because of the Lord's great love we are not consumed, for his compassions never fail. They are new every morning; great is your faithfulness.", translation: "NIV"),
        BibleVerse(reference: "Ezekiel 36:26", text: "I will give you a new heart and put a new spirit in you; I will remove from you your heart of stone and give you a heart of flesh.", translation: "NIV"),
        BibleVerse(reference: "Daniel 3:17-18", text: "If we are thrown into the blazing furnace, the God we serve is able to deliver us from it, and he will deliver us from Your Majesty's hand. But even if he does not, we want you to know, Your Majesty, that we will not serve your gods or worship the image of gold you have set up.\"", translation: "NIV"),
        BibleVerse(reference: "Daniel 6:23", text: "The king was overjoyed and gave orders to lift Daniel out of the den. And when Daniel was lifted from the den, no wound was found on him, because he had trusted in his God.", translation: "NIV"),
        BibleVerse(reference: "Hosea 6:6", text: "For I desire mercy, not sacrifice, and acknowledgment of God rather than burnt offerings.", translation: "NIV"),
        BibleVerse(reference: "Joel 2:28", text: "And afterward, I will pour out my Spirit on all people. Your sons and daughters will prophesy, your old men will dream dreams, your young men will see visions.", translation: "NIV"),
        BibleVerse(reference: "Amos 5:24", text: "But let justice roll on like a river, righteousness like a never-failing stream!", translation: "NIV"),
        BibleVerse(reference: "Obadiah 1:15", text: "The day of the Lord is near for all nations. As you have done, it will be done to you; your deeds will return upon your own head.", translation: "NIV"),
        BibleVerse(reference: "Jonah 2:9", text: "But I, with shouts of grateful praise, will sacrifice to you. What I have vowed I will make good. I will say, 'Salvation comes from the Lord.'\"", translation: "NIV"),
        BibleVerse(reference: "Micah 6:8", text: "He has shown you, O mortal, what is good. And what does the Lord require of you? To act justly and to love mercy and to walk humbly with your God.", translation: "NIV"),
        BibleVerse(reference: "Nahum 1:7", text: "The Lord is good, a refuge in times of trouble. He cares for those who trust in him.", translation: "NIV"),
        BibleVerse(reference: "Habakkuk 2:4", text: "See, the enemy is puffed up; his desires are not upright—but the righteous person will live by his faithfulness.", translation: "NIV"),
        BibleVerse(reference: "Zephaniah 3:17", text: "The Lord your God is with you, the Mighty Warrior who saves. He will take great delight in you; in his love he will no longer rebuke you, but will rejoice over you with singing.\"", translation: "NIV"),
        BibleVerse(reference: "Haggai 2:4", text: "But now be strong, Zerubbabel,\" declares the Lord. \"Be strong, Joshua son of Jozadak, the high priest. Be strong, all you people of the land,\" declares the Lord, \"and work. For I am with you,\" declares the Lord Almighty.", translation: "NIV"),
        BibleVerse(reference: "Zechariah 4:6", text: "So he said to me, \"This is the word of the Lord to Zerubbabel: 'Not by might nor by power, but by my Spirit,' says the Lord Almighty.", translation: "NIV"),
        BibleVerse(reference: "Malachi 3:10", text: "Bring the whole tithe into the storehouse, that there may be food in my house. Test me in this,\" says the Lord Almighty, \"and see if I will not throw open the floodgates of heaven and pour out so much blessing that there will not be room enough to store it.", translation: "NIV"),
        BibleVerse(reference: "Malachi 4:2", text: "But for you who revere my name, the sun of righteousness will rise with healing in its rays. And you will go out and frolic like well-fed calves.", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 10:12", text: "But God made the earth by his power; he founded the world by his wisdom and stretched out the heavens by his understanding.", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 23:24", text: "Who can hide in secret places so that I cannot see them?\" declares the Lord. \"Do not I fill heaven and earth?\" declares the Lord.", translation: "NIV"),
        BibleVerse(reference: "Jeremiah 33:3", text: "Call to me and I will answer you and tell you great and unsearchable things you do not know.\"", translation: "NIV"),
        BibleVerse(reference: "Lamentations 3:24", text: "I say to myself, \"The Lord is my portion; therefore I will wait for him.\"", translation: "NIV"),
        BibleVerse(reference: "Ezekiel 11:19", text: "I will give them an undivided heart and put a new spirit in them; I will remove from them their heart of stone and give them a heart of flesh.", translation: "NIV"),
        BibleVerse(reference: "Daniel 2:20", text: "Daniel said: \"Praise be to the name of God for ever and ever; wisdom and power are his.", translation: "NIV"),
        BibleVerse(reference: "Daniel 2:22", text: "He reveals deep and hidden things; he knows what lies in darkness, and light dwells with him.", translation: "NIV"),
        BibleVerse(reference: "Hosea 14:2", text: "Take words with you and return to the Lord. Say to him: \"Forgive all our sins and receive us graciously, that we may offer the fruit of our lips.", translation: "NIV"),
        BibleVerse(reference: "Joel 2:13", text: "Rend your heart and not your garments. Return to the Lord your God, for he is gracious and compassionate, slow to anger and abounding in love, and he relents from sending calamity.", translation: "NIV"),
        BibleVerse(reference: "Amos 4:13", text: "He who forms the mountains, who creates the wind, and who reveals his thoughts to mankind, who turns dawn to darkness, and treads on the heights of the earth—the Lord God Almighty is his name.", translation: "NIV"),
        BibleVerse(reference: "Micah 7:18", text: "Who is a God like you, who pardons sin and forgives the transgression of the remnant of his inheritance? You do not stay angry forever but delight to show mercy.", translation: "NIV"),
        BibleVerse(reference: "Habakkuk 3:18", text: "yet I will rejoice in the Lord, I will be joyful in God my Savior.", translation: "NIV"),
        BibleVerse(reference: "Zechariah 8:16", text: "These are the things you are to do: Speak the truth to each other, and render true and sound judgment in your courts.", translation: "NIV"),
        
        // New Testament - Gospels (891-970) - 80 verses from Matthew, Mark, Luke, John
        BibleVerse(reference: "Matthew 1:23", text: "\"The virgin will conceive and give birth to a son, and they will call him Immanuel\" (which means \"God with us\").", translation: "NIV"),
        BibleVerse(reference: "Matthew 4:4", text: "Jesus answered, \"It is written: 'Man shall not live on bread alone, but on every word that comes from the mouth of God.'\"", translation: "NIV"),
        BibleVerse(reference: "Matthew 4:19", text: "\"Come, follow me,\" Jesus said, \"and I will send you out to fish for people.\"", translation: "NIV"),
        BibleVerse(reference: "Matthew 5:3", text: "\"Blessed are the poor in spirit, for theirs is the kingdom of heaven.", translation: "NIV"),
        BibleVerse(reference: "Matthew 5:4", text: "Blessed are those who mourn, for they will be comforted.", translation: "NIV"),
        BibleVerse(reference: "Matthew 5:8", text: "Blessed are the pure in heart, for they will see God.", translation: "NIV"),
        BibleVerse(reference: "Matthew 5:14-16", text: "\"You are the light of the world. A town built on a hill cannot be hidden. Neither do people light a lamp and put it under a bowl. Instead they put it on its stand, and it gives light to everyone in the house. In the same way, let your light shine before others, that they may see your good deeds and glorify your Father in heaven.", translation: "NIV"),
        BibleVerse(reference: "Matthew 5:44", text: "But I tell you, love your enemies and pray for those who persecute you.", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:9-10", text: "This, then, is how you should pray: \"'Our Father in heaven, hallowed be your name, your kingdom come, your will be done, on earth as it is in heaven.", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:14", text: "For if you forgive other people when they sin against you, your heavenly Father will also forgive you.", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:21", text: "For where your treasure is, there your heart will be also.", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:25", text: "Therefore I tell you, do not worry about your life, what you will eat or drink; or about your body, what you will wear. Is not life more than food, and the body more than clothes?", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:26", text: "Look at the birds of the air; they do not sow or reap or store away in barns, and yet your heavenly Father feeds them. Are you not much more valuable than they?", translation: "NIV"),
        BibleVerse(reference: "Matthew 6:34", text: "Therefore do not worry about tomorrow, for tomorrow will worry about itself. Each day has enough trouble of its own.", translation: "NIV"),
        BibleVerse(reference: "Matthew 7:7", text: "\"Ask and it will be given to you; seek and you will find; knock and the door will be opened to you.", translation: "NIV"),
        BibleVerse(reference: "Matthew 7:12", text: "So in everything, do to others what you would have them do to you, for this sums up the Law and the Prophets.", translation: "NIV"),
        BibleVerse(reference: "Matthew 7:13-14", text: "\"Enter through the narrow gate. For wide is the gate and broad is the road that leads to destruction, and many enter through it. But small is the gate and narrow the road that leads to life, and only a few find it.", translation: "NIV"),
        BibleVerse(reference: "Matthew 11:28-30", text: "\"Come to me, all you who are weary and burdened, and I will give you rest. Take my yoke upon you and learn from me, for I am gentle and humble in heart, and you will find rest for your souls. For my yoke is easy and my burden is light.\"", translation: "NIV"),
        BibleVerse(reference: "Matthew 16:24", text: "Then Jesus said to his disciples, \"Whoever wants to be my disciple must deny themselves and take up their cross and follow me.", translation: "NIV"),
        BibleVerse(reference: "Matthew 16:26", text: "What good will it be for someone to gain the whole world, yet forfeit their soul? Or what can anyone give in exchange for their soul?", translation: "NIV"),
        BibleVerse(reference: "Matthew 18:20", text: "For where two or three gather in my name, there am I with them.\"", translation: "NIV"),
        BibleVerse(reference: "Matthew 19:26", text: "Jesus looked at them and said, \"With man this is impossible, but with God all things are possible.\"", translation: "NIV"),
        BibleVerse(reference: "Matthew 22:37-39", text: "Jesus replied: \"'Love the Lord your God with all your heart and with all your soul and with all your mind.' This is the first and greatest commandment. And the second is like it: 'Love your neighbor as yourself.'", translation: "NIV"),
        BibleVerse(reference: "Matthew 28:18-20", text: "Then Jesus came to them and said, \"All authority in heaven and on earth has been given to me. Therefore go and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit, and teaching them to obey everything I have commanded you. And surely I am with you always, to the very end of the age.\"", translation: "NIV"),
        BibleVerse(reference: "Mark 1:15", text: "\"The time has come,\" he said. \"The kingdom of God has come near. Repent and believe the good news!\"", translation: "NIV"),
        BibleVerse(reference: "Mark 9:23", text: "\"'If you can'?\" said Jesus. \"Everything is possible for one who believes.\"", translation: "NIV"),
        BibleVerse(reference: "Mark 10:27", text: "Jesus looked at them and said, \"With man this is impossible, but not with God; all things are possible with God.\"", translation: "NIV"),
        BibleVerse(reference: "Mark 11:24", text: "Therefore I tell you, whatever you ask for in prayer, believe that you have received it, and it will be yours.", translation: "NIV"),
        BibleVerse(reference: "Mark 12:30-31", text: "Love the Lord your God with all your heart and with all your soul and with all your mind and with all your strength.' The second is this: 'Love your neighbor as yourself.' There is no commandment greater than these.\"", translation: "NIV"),
        BibleVerse(reference: "Mark 16:15", text: "He said to them, \"Go into all the world and preach the gospel to all creation.", translation: "NIV"),
        BibleVerse(reference: "Luke 1:37", text: "For no word from God will ever fail.\"", translation: "NIV"),
        BibleVerse(reference: "Luke 2:14", text: "\"Glory to God in the highest heaven, and on earth peace to those on whom his favor rests.\"", translation: "NIV"),
        BibleVerse(reference: "Luke 6:27-28", text: "\"But to you who are listening I say: Love your enemies, do good to those who hate you, bless those who curse you, pray for those who mistreat you.", translation: "NIV"),
        BibleVerse(reference: "Luke 6:31", text: "Do to others as you would have them do to you.", translation: "NIV"),
        BibleVerse(reference: "Luke 6:38", text: "Give, and it will be given to you. A good measure, pressed down, shaken together and running over, will be poured into your lap. For with the measure you use, it will be measured to you.\"", translation: "NIV"),
        BibleVerse(reference: "Luke 9:23", text: "Then he said to them all: \"Whoever wants to be my disciple must deny themselves and take up their cross daily and follow me.", translation: "NIV"),
        BibleVerse(reference: "Luke 10:27", text: "He answered, \"'Love the Lord your God with all your heart and with all your soul and with all your strength and with all your mind'; and, 'Love your neighbor as yourself.'\"", translation: "NIV"),
        BibleVerse(reference: "Luke 11:9", text: "So I say to you: Ask and it will be given to you; seek and you will find; knock and the door will be opened to you.", translation: "NIV"),
        BibleVerse(reference: "Luke 12:7", text: "Indeed, the very hairs of your head are all numbered. Don't be afraid; you are worth more than many sparrows.", translation: "NIV"),
        BibleVerse(reference: "Luke 12:31", text: "But seek his kingdom, and these things will be given to you as well.", translation: "NIV"),
        BibleVerse(reference: "Luke 12:34", text: "For where your treasure is, there your heart will be also.", translation: "NIV"),
        BibleVerse(reference: "Luke 18:27", text: "Jesus replied, \"What is impossible with man is possible with God.\"", translation: "NIV"),
        BibleVerse(reference: "Luke 23:34", text: "Jesus said, \"Father, forgive them, for they do not know what they are doing.\"", translation: "NIV"),
        BibleVerse(reference: "John 1:1", text: "In the beginning was the Word, and the Word was with God, and the Word was God.", translation: "NIV"),
        BibleVerse(reference: "John 1:14", text: "The Word became flesh and made his dwelling among us. We have seen his glory, the glory of the one and only Son, who came from the Father, full of grace and truth.", translation: "NIV"),
        BibleVerse(reference: "John 3:16", text: "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.", translation: "NIV"),
        BibleVerse(reference: "John 3:17", text: "For God did not send his Son into the world to condemn the world, but to save the world through him.", translation: "NIV"),
        BibleVerse(reference: "John 4:24", text: "God is spirit, and his worshipers must worship in the Spirit and in truth.\"", translation: "NIV"),
        BibleVerse(reference: "John 6:35", text: "Then Jesus declared, \"I am the bread of life. Whoever comes to me will never go hungry, and whoever believes in me will never be thirsty.", translation: "NIV"),
        BibleVerse(reference: "John 8:12", text: "When Jesus spoke again to the people, he said, \"I am the light of the world. Whoever follows me will never walk in darkness, but will have the light of life.\"", translation: "NIV"),
        BibleVerse(reference: "John 8:32", text: "Then you will know the truth, and the truth will set you free.\"", translation: "NIV"),
        BibleVerse(reference: "John 10:10", text: "The thief comes only to steal and kill and destroy; I have come that they may have life, and have it to the full.", translation: "NIV"),
        BibleVerse(reference: "John 10:11", text: "\"I am the good shepherd. The good shepherd lays down his life for the sheep.", translation: "NIV"),
        BibleVerse(reference: "John 10:27-28", text: "My sheep listen to my voice; I know them, and they follow me. I give them eternal life, and they shall never perish; no one will snatch them out of my hand.", translation: "NIV"),
        BibleVerse(reference: "John 11:25", text: "Jesus said to her, \"I am the resurrection and the life. The one who believes in me will live, even though they die.", translation: "NIV"),
        BibleVerse(reference: "John 14:1", text: "\"Do not let your hearts be troubled. You believe in God; believe also in me.", translation: "NIV"),
        BibleVerse(reference: "John 14:6", text: "Jesus answered, \"I am the way and the truth and the life. No one comes to the Father except through me.", translation: "NIV"),
        BibleVerse(reference: "John 14:13-14", text: "And I will do whatever you ask in my name, so that the Father may be glorified in the Son. You may ask me for anything in my name, and I will do it.", translation: "NIV"),
        BibleVerse(reference: "John 14:15", text: "\"If you love me, keep my commands.", translation: "NIV"),
        BibleVerse(reference: "John 14:16", text: "And I will ask the Father, and he will give you another advocate to help you and be with you forever—", translation: "NIV"),
        BibleVerse(reference: "John 14:27", text: "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.", translation: "NIV"),
        BibleVerse(reference: "John 15:5", text: "\"I am the vine; you are the branches. If you remain in me and I in you, you will bear much fruit; apart from me you can do nothing.", translation: "NIV"),
        BibleVerse(reference: "John 15:7", text: "If you remain in me and my words remain in you, ask whatever you wish, and it will be done for you.", translation: "NIV"),
        BibleVerse(reference: "John 15:13", text: "Greater love has no one than this: to lay down one's life for one's friends.", translation: "NIV"),
        BibleVerse(reference: "John 15:16", text: "You did not choose me, but I chose you and appointed you so that you might go and bear fruit—fruit that will last—and so that whatever you ask in my name the Father will give you.", translation: "NIV"),
        BibleVerse(reference: "John 16:13", text: "But when he, the Spirit of truth, comes, he will guide you into all the truth. He will not speak on his own; he will speak only what he hears, and he will tell you what is yet to come.", translation: "NIV"),
        BibleVerse(reference: "John 16:33", text: "\"I have told you these things, so that in me you may have peace. In this world you will have trouble. But take heart! I have overcome the world.\"", translation: "NIV"),
        BibleVerse(reference: "John 17:3", text: "Now this is eternal life: that they know you, the only true God, and Jesus Christ, whom you have sent.", translation: "NIV"),
        BibleVerse(reference: "John 20:28", text: "Thomas said to him, \"My Lord and my God!\"", translation: "NIV"),
        BibleVerse(reference: "John 20:31", text: "But these are written that you may believe that Jesus is the Messiah, the Son of God, and that by believing you may have life in his name.", translation: "NIV"),
        
        // Acts & Romans (971-1000) - Final 30 verses to reach 1000
        BibleVerse(reference: "Acts 1:8", text: "But you will receive power when the Holy Spirit comes on you; and you will be my witnesses in Jerusalem, and in all Judea and Samaria, and to the ends of the earth.\"", translation: "NIV"),
        BibleVerse(reference: "Acts 2:38", text: "Peter replied, \"Repent and be baptized, every one of you, in the name of Jesus Christ for the forgiveness of your sins. And you will receive the gift of the Holy Spirit.", translation: "NIV"),
        BibleVerse(reference: "Acts 4:12", text: "Salvation is found in no one else, for there is no other name under heaven given to mankind by which we must be saved.\"", translation: "NIV"),
        BibleVerse(reference: "Acts 16:31", text: "They replied, \"Believe in the Lord Jesus, and you will be saved—you and your household.\"", translation: "NIV"),
        BibleVerse(reference: "Acts 17:28", text: "'For in him we live and move and have our being.' As some of your own poets have said, 'We are his offspring.'", translation: "NIV"),
        BibleVerse(reference: "Romans 1:16", text: "For I am not ashamed of the gospel, because it is the power of God that brings salvation to everyone who believes: first to the Jew, then to the Gentile.", translation: "NIV"),
        BibleVerse(reference: "Romans 3:23", text: "For all have sinned and fall short of the glory of God.", translation: "NIV"),
        BibleVerse(reference: "Romans 3:24", text: "and all are justified freely by his grace through the redemption that came by Christ Jesus.", translation: "NIV"),
        BibleVerse(reference: "Romans 5:8", text: "But God demonstrates his own love for us in this: While we were still sinners, Christ died for us.", translation: "NIV"),
        BibleVerse(reference: "Romans 6:23", text: "For the wages of sin is death, but the gift of God is eternal life in Christ Jesus our Lord.", translation: "NIV"),
        BibleVerse(reference: "Romans 8:1", text: "Therefore, there is now no condemnation for those who are in Christ Jesus.", translation: "NIV"),
        BibleVerse(reference: "Romans 8:28", text: "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.", translation: "NIV"),
        BibleVerse(reference: "Romans 8:31", text: "What, then, shall we say in response to these things? If God is for us, who can be against us?", translation: "NIV"),
        BibleVerse(reference: "Romans 8:37", text: "No, in all these things we are more than conquerors through him who loved us.", translation: "NIV"),
        BibleVerse(reference: "Romans 8:38-39", text: "For I am convinced that neither death nor life, neither angels nor demons, neither the present nor the future, nor any powers, neither height nor depth, nor anything else in all creation, will be able to separate us from the love of God that is in Christ Jesus our Lord.", translation: "NIV"),
        BibleVerse(reference: "Romans 10:9-10", text: "If you declare with your mouth, \"Jesus is Lord,\" and believe in your heart that God raised him from the dead, you will be saved. For it is with your heart that you believe and are justified, and it is with your mouth that you profess your faith and are saved.", translation: "NIV"),
        BibleVerse(reference: "Romans 10:13", text: "for, \"Everyone who calls on the name of the Lord will be saved.\"", translation: "NIV"),
        BibleVerse(reference: "Romans 10:17", text: "Consequently, faith comes from hearing the message, and the message is heard through the word about Christ.", translation: "NIV"),
        BibleVerse(reference: "Romans 12:1", text: "Therefore, I urge you, brothers and sisters, in view of God's mercy, to offer your bodies as a living sacrifice, holy and pleasing to God—this is your true and proper worship.", translation: "NIV"),
        BibleVerse(reference: "Romans 12:2", text: "Do not conform to the pattern of this world, but be transformed by the renewing of your mind. Then you will be able to test and approve what God's will is—his good, pleasing and perfect will.", translation: "NIV"),
        BibleVerse(reference: "Romans 12:9", text: "Love must be sincere. Hate what is evil; cling to what is good.", translation: "NIV"),
        BibleVerse(reference: "Romans 12:12", text: "Be joyful in hope, patient in affliction, faithful in prayer.", translation: "NIV"),
        BibleVerse(reference: "Romans 12:21", text: "Do not be overcome by evil, but overcome evil with good.", translation: "NIV"),
        BibleVerse(reference: "Romans 13:8", text: "Let no debt remain outstanding, except the continuing debt to love one another, for whoever loves others has fulfilled the law.", translation: "NIV"),
        BibleVerse(reference: "Romans 13:10", text: "Love does no harm to a neighbor. Therefore love is the fulfillment of the law.", translation: "NIV"),
        BibleVerse(reference: "Romans 14:8", text: "If we live, we live for the Lord; and if we die, we die for the Lord. So, whether we live or die, we belong to the Lord.", translation: "NIV"),
        BibleVerse(reference: "Romans 15:4", text: "For everything that was written in the past was written to teach us, so that through the endurance taught in the Scriptures and the encouragement they provide we might have hope.", translation: "NIV"),
        BibleVerse(reference: "Romans 15:13", text: "May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope by the power of the Holy Spirit.", translation: "NIV"),
        BibleVerse(reference: "Romans 16:20", text: "The God of peace will soon crush Satan under your feet. The grace of our Lord Jesus be with you.", translation: "NIV"),
    ]
    
    // Fallback to local verses database (expanded list)
    func getLocalVerse(reference: String) -> BibleVerse? {
        
        // Try to match reference (case-insensitive, handle variations)
        let cleanRef = reference.lowercased().trimmingCharacters(in: .whitespaces)
        
        return localVersesDatabase.first { verse in
            let verseRef = verse.reference.lowercased()
            return verseRef == cleanRef ||
                   verseRef.contains(cleanRef) ||
                   cleanRef.contains(verseRef) ||
                   // Handle partial matches like "John 3" matching "John 3:16"
                   (cleanRef.split(separator: " ").count >= 2 &&
                    verseRef.hasPrefix(cleanRef.split(separator: " ").prefix(2).joined(separator: " ")))
        }
    }
    
    // Search for verses by keyword
    func searchVerses(keyword: String, translation: String = "NIV") async throws -> [BibleVerseResponse] {
        // This could search Bible Gateway or use a local index
        // For now, return empty array - can be enhanced later
        return []
    }
}

enum BibleServiceError: LocalizedError {
    case invalidURL
    case networkError
    case parsingError
    case verseNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid verse reference format"
        case .networkError:
            return "Unable to connect to Bible service"
        case .parsingError:
            return "Unable to parse verse from response"
        case .verseNotFound:
            return "Verse not found. Please try entering it manually."
        }
    }
}

