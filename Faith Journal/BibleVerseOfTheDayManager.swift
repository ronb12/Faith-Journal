import Foundation
import SwiftUI

struct BibleVerse: Identifiable, Codable {
    let id = UUID()
    let reference: String
    let text: String
    let translation: String
}

class BibleVerseOfTheDayManager: ObservableObject {
    @Published var currentVerse: BibleVerse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let verses = [
        // Core Faith Verses
        BibleVerse(reference: "John 3:16", text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.", translation: "KJV"),
        BibleVerse(reference: "Romans 10:9", text: "That if thou shalt confess with thy mouth the Lord Jesus, and shalt believe in thine heart that God hath raised him from the dead, thou shalt be saved.", translation: "KJV"),
        BibleVerse(reference: "Ephesians 2:8-9", text: "For by grace are ye saved through faith; and that not of yourselves: it is the gift of God: Not of works, lest any man should boast.", translation: "KJV"),
        
        // Strength and Courage
        BibleVerse(reference: "Philippians 4:13", text: "I can do all things through Christ which strengtheneth me.", translation: "KJV"),
        BibleVerse(reference: "Isaiah 40:31", text: "But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.", translation: "KJV"),
        BibleVerse(reference: "Joshua 1:9", text: "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest.", translation: "KJV"),
        BibleVerse(reference: "Deuteronomy 31:6", text: "Be strong and of a good courage, fear not, nor be afraid of them: for the LORD thy God, he it is that doth go with thee; he will not fail thee, nor forsake thee.", translation: "KJV"),
        BibleVerse(reference: "2 Timothy 1:7", text: "For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind.", translation: "KJV"),
        
        // God's Plans and Purpose
        BibleVerse(reference: "Jeremiah 29:11", text: "For I know the thoughts that I think toward you, saith the LORD, thoughts of peace, and not of evil, to give you an expected end.", translation: "KJV"),
        BibleVerse(reference: "Romans 8:28", text: "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.", translation: "KJV"),
        BibleVerse(reference: "Proverbs 3:5-6", text: "Trust in the LORD with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.", translation: "KJV"),
        BibleVerse(reference: "Psalm 37:4", text: "Delight thyself also in the LORD; and he shall give thee the desires of thine heart.", translation: "KJV"),
        
        // Peace and Comfort
        BibleVerse(reference: "John 14:27", text: "Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you. Let not your heart be troubled, neither let it be afraid.", translation: "KJV"),
        BibleVerse(reference: "Philippians 4:6-7", text: "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus.", translation: "KJV"),
        BibleVerse(reference: "Matthew 11:28-30", text: "Come unto me, all ye that labour and are heavy laden, and I will give you rest. Take my yoke upon you, and learn of me; for I am meek and lowly in heart: and ye shall find rest unto your souls. For my yoke is easy, and my burden is light.", translation: "KJV"),
        BibleVerse(reference: "1 Peter 5:7", text: "Casting all your care upon him; for he careth for you.", translation: "KJV"),
        BibleVerse(reference: "Psalm 23:1-4", text: "The LORD is my shepherd; I shall not want. He maketh me to lie down in green pastures: he leadeth me beside the still waters. He restoreth my soul: he leadeth me in the paths of righteousness for his name's sake. Yea, though I walk through the valley of the shadow of death, I will fear no evil: for thou art with me; thy rod and thy staff they comfort me.", translation: "KJV"),
        
        // Love and Relationships
        BibleVerse(reference: "1 Corinthians 13:4-7", text: "Charity suffereth long, and is kind; charity envieth not; charity vaunteth not itself, is not puffed up, Doth not behave itself unseemly, seeketh not her own, is not easily provoked, thinketh no evil; Rejoiceth not in iniquity, but rejoiceth in the truth; Beareth all things, believeth all things, hopeth all things, endureth all things.", translation: "KJV"),
        BibleVerse(reference: "1 John 4:7-8", text: "Beloved, let us love one another: for love is of God; and every one that loveth is born of God, and knoweth God. He that loveth not knoweth not God; for God is love.", translation: "KJV"),
        BibleVerse(reference: "John 15:12", text: "This is my commandment, That ye love one another, as I have loved you.", translation: "KJV"),
        BibleVerse(reference: "Romans 12:10", text: "Be kindly affectioned one to another with brotherly love; in honour preferring one another;", translation: "KJV"),
        
        // Prayer and Worship
        BibleVerse(reference: "1 Thessalonians 5:16-18", text: "Rejoice evermore. Pray without ceasing. In every thing give thanks: for this is the will of God in Christ Jesus concerning you.", translation: "KJV"),
        BibleVerse(reference: "Matthew 6:33", text: "But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.", translation: "KJV"),
        BibleVerse(reference: "Psalm 100:4", text: "Enter into his gates with thanksgiving, and into his courts with praise: be thankful unto him, and bless his name.", translation: "KJV"),
        BibleVerse(reference: "James 5:16", text: "Confess your faults one to another, and pray one for another, that ye may be healed. The effectual fervent prayer of a righteous man availeth much.", translation: "KJV"),
        
        // Forgiveness and Grace
        BibleVerse(reference: "Colossians 3:13", text: "Forbearing one another, and forgiving one another, if any man have a quarrel against any: even as Christ forgave you, so also do ye.", translation: "KJV"),
        BibleVerse(reference: "Matthew 6:14-15", text: "For if ye forgive men their trespasses, your heavenly Father will also forgive you: But if ye forgive not men their trespasses, neither will your Father forgive your trespasses.", translation: "KJV"),
        BibleVerse(reference: "Ephesians 4:32", text: "And be ye kind one to another, tenderhearted, forgiving one another, even as God for Christ's sake hath forgiven you.", translation: "KJV"),
        BibleVerse(reference: "1 John 1:9", text: "If we confess our sins, he is faithful and just to forgive us our sins, and to cleanse us from all unrighteousness.", translation: "KJV"),
        
        // Hope and Encouragement
        BibleVerse(reference: "Romans 15:13", text: "Now the God of hope fill you with all joy and peace in believing, that ye may abound in hope, through the power of the Holy Ghost.", translation: "KJV"),
        BibleVerse(reference: "Lamentations 3:22-23", text: "It is of the LORD's mercies that we are not consumed, because his compassions fail not. They are new every morning: great is thy faithfulness.", translation: "KJV"),
        BibleVerse(reference: "Psalm 27:1", text: "The LORD is my light and my salvation; whom shall I fear? the LORD is the strength of my life; of whom shall I be afraid?", translation: "KJV"),
        BibleVerse(reference: "2 Corinthians 4:16-18", text: "For which cause we faint not; but though our outward man perish, yet the inward man is renewed day by day. For our light affliction, which is but for a moment, worketh for us a far more exceeding and eternal weight of glory; While we look not at the things which are seen, but at the things which are not seen: for the things which are seen are temporal; but the things which are not seen are eternal.", translation: "KJV"),
        
        // Wisdom and Guidance
        BibleVerse(reference: "James 1:5", text: "If any of you lack wisdom, let him ask of God, that giveth to all men liberally, and upbraideth not; and it shall be given him.", translation: "KJV"),
        BibleVerse(reference: "Psalm 119:105", text: "Thy word is a lamp unto my feet, and a light unto my path.", translation: "KJV"),
        BibleVerse(reference: "Proverbs 16:3", text: "Commit thy works unto the LORD, and thy thoughts shall be established.", translation: "KJV"),
        BibleVerse(reference: "Isaiah 30:21", text: "And thine ears shall hear a word behind thee, saying, This is the way, walk ye in it, when ye turn to the right hand, and when ye turn to the left.", translation: "KJV"),
        
        // Gratitude and Thankfulness
        BibleVerse(reference: "Psalm 136:1", text: "O give thanks unto the LORD; for he is good: for his mercy endureth for ever.", translation: "KJV"),
        BibleVerse(reference: "Colossians 3:15", text: "And let the peace of God rule in your hearts, to the which also ye are called in one body; and be ye thankful.", translation: "KJV"),
        BibleVerse(reference: "Psalm 107:1", text: "O give thanks unto the LORD, for he is good: for his mercy endureth for ever.", translation: "KJV"),
        BibleVerse(reference: "1 Chronicles 16:34", text: "O give thanks unto the LORD; for he is good; for his mercy endureth for ever.", translation: "KJV"),
        
        // Service and Generosity
        BibleVerse(reference: "Galatians 5:13", text: "For, brethren, ye have been called unto liberty; only use not liberty for an occasion to the flesh, but by love serve one another.", translation: "KJV"),
        BibleVerse(reference: "Matthew 20:28", text: "Even as the Son of man came not to be ministered unto, but to minister, and to give his life a ransom for many.", translation: "KJV"),
        BibleVerse(reference: "Acts 20:35", text: "I have shewed you all things, how that so labouring ye ought to support the weak, and to remember the words of the Lord Jesus, how he said, It is more blessed to give than to receive.", translation: "KJV"),
        BibleVerse(reference: "Hebrews 13:16", text: "But to do good and to communicate forget not: for with such sacrifices God is well pleased.", translation: "KJV"),
        
        // Faith and Trust
        BibleVerse(reference: "Hebrews 11:1", text: "Now faith is the substance of things hoped for, the evidence of things not seen.", translation: "KJV"),
        BibleVerse(reference: "2 Corinthians 5:7", text: "(For we walk by faith, not by sight:)", translation: "KJV"),
        BibleVerse(reference: "Proverbs 3:5", text: "Trust in the LORD with all thine heart; and lean not unto thine own understanding.", translation: "KJV"),
        BibleVerse(reference: "Psalm 56:3", text: "What time I am afraid, I will trust in thee.", translation: "KJV"),
        
        // God's Presence
        BibleVerse(reference: "Matthew 28:20", text: "Teaching them to observe all things whatsoever I have commanded you: and, lo, I am with you alway, even unto the end of the world. Amen.", translation: "KJV"),
        BibleVerse(reference: "Psalm 139:7-10", text: "Whither shall I go from thy spirit? or whither shall I flee from thy presence? If I ascend up into heaven, thou art there: if I make my bed in hell, behold, thou art there. If I take the wings of the morning, and dwell in the uttermost parts of the sea; Even there shall thy hand lead me, and thy right hand shall hold me.", translation: "KJV"),
        BibleVerse(reference: "Isaiah 41:10", text: "Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.", translation: "KJV"),
        BibleVerse(reference: "Joshua 1:5", text: "There shall not any man be able to stand before thee all the days of thy life: as I was with Moses, so I will be with thee: I will not fail thee, nor forsake thee.", translation: "KJV"),
        
        // Transformation and Growth
        BibleVerse(reference: "2 Corinthians 5:17", text: "Therefore if any man be in Christ, he is a new creature: old things are passed away; behold, all things are become new.", translation: "KJV"),
        BibleVerse(reference: "Romans 12:2", text: "And be not conformed to this world: but be ye transformed by the renewing of your mind, that ye may prove what is that good, and acceptable, and perfect, will of God.", translation: "KJV"),
        BibleVerse(reference: "Galatians 5:22-23", text: "But the fruit of the Spirit is love, joy, peace, longsuffering, gentleness, goodness, faith, Meekness, temperance: against such there is no law.", translation: "KJV"),
        BibleVerse(reference: "Philippians 1:6", text: "Being confident of this very thing, that he which hath begun a good work in you will perform it until the day of Jesus Christ:", translation: "KJV"),
        
        // Perseverance and Endurance
        BibleVerse(reference: "James 1:2-4", text: "My brethren, count it all joy when ye fall into divers temptations; Knowing this, that the trying of your faith worketh patience. But let patience have her perfect work, that ye may be perfect and entire, wanting nothing.", translation: "KJV"),
        BibleVerse(reference: "Hebrews 12:1-2", text: "Wherefore seeing we also are compassed about with so great a cloud of witnesses, let us lay aside every weight, and the sin which doth so easily beset us, and let us run with patience the race that is set before us, Looking unto Jesus the author and finisher of our faith; who for the joy that was set before him endured the cross, despising the shame, and is set down at the right hand of the throne of God.", translation: "KJV"),
        BibleVerse(reference: "Romans 5:3-4", text: "And not only so, but we glory in tribulations also: knowing that tribulation worketh patience; And patience, experience; and experience, hope:", translation: "KJV"),
        BibleVerse(reference: "1 Corinthians 9:24", text: "Know ye not that they which run in a race run all, but one receiveth the prize? So run, that ye may obtain.", translation: "KJV")
    ]
    
    init() {
        loadTodaysVerse()
    }
    
    func loadTodaysVerse() {
        isLoading = true
        errorMessage = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Use date to select a consistent verse for the day
            let calendar = Calendar.current
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
            let verseIndex = (dayOfYear - 1) % self.verses.count
            self.currentVerse = self.verses[verseIndex]
            self.isLoading = false
        }
    }
    
    func refreshVerse() {
        loadTodaysVerse()
    }
} 