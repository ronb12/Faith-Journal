import Foundation

// Helper struct for Bible book information
struct BibleBookInfo {
    let name: String
    let abbreviation: String
    let chapters: Int
    let testament: Testament
    
    enum Testament {
        case old
        case new
    }
}

struct BibleBooks {
    static let allBooks: [BibleBookInfo] = [
        // Old Testament
        BibleBookInfo(name: "Genesis", abbreviation: "Gen", chapters: 50, testament: .old),
        BibleBookInfo(name: "Exodus", abbreviation: "Ex", chapters: 40, testament: .old),
        BibleBookInfo(name: "Leviticus", abbreviation: "Lev", chapters: 27, testament: .old),
        BibleBookInfo(name: "Numbers", abbreviation: "Num", chapters: 36, testament: .old),
        BibleBookInfo(name: "Deuteronomy", abbreviation: "Deut", chapters: 34, testament: .old),
        BibleBookInfo(name: "Joshua", abbreviation: "Josh", chapters: 24, testament: .old),
        BibleBookInfo(name: "Judges", abbreviation: "Judg", chapters: 21, testament: .old),
        BibleBookInfo(name: "Ruth", abbreviation: "Ruth", chapters: 4, testament: .old),
        BibleBookInfo(name: "1 Samuel", abbreviation: "1 Sam", chapters: 31, testament: .old),
        BibleBookInfo(name: "2 Samuel", abbreviation: "2 Sam", chapters: 24, testament: .old),
        BibleBookInfo(name: "1 Kings", abbreviation: "1 Kings", chapters: 22, testament: .old),
        BibleBookInfo(name: "2 Kings", abbreviation: "2 Kings", chapters: 25, testament: .old),
        BibleBookInfo(name: "1 Chronicles", abbreviation: "1 Chron", chapters: 29, testament: .old),
        BibleBookInfo(name: "2 Chronicles", abbreviation: "2 Chron", chapters: 36, testament: .old),
        BibleBookInfo(name: "Ezra", abbreviation: "Ezra", chapters: 10, testament: .old),
        BibleBookInfo(name: "Nehemiah", abbreviation: "Neh", chapters: 13, testament: .old),
        BibleBookInfo(name: "Esther", abbreviation: "Esth", chapters: 10, testament: .old),
        BibleBookInfo(name: "Job", abbreviation: "Job", chapters: 42, testament: .old),
        BibleBookInfo(name: "Psalms", abbreviation: "Ps", chapters: 150, testament: .old),
        BibleBookInfo(name: "Proverbs", abbreviation: "Prov", chapters: 31, testament: .old),
        BibleBookInfo(name: "Ecclesiastes", abbreviation: "Eccl", chapters: 12, testament: .old),
        BibleBookInfo(name: "Song of Songs", abbreviation: "Song", chapters: 8, testament: .old),
        BibleBookInfo(name: "Isaiah", abbreviation: "Isa", chapters: 66, testament: .old),
        BibleBookInfo(name: "Jeremiah", abbreviation: "Jer", chapters: 52, testament: .old),
        BibleBookInfo(name: "Lamentations", abbreviation: "Lam", chapters: 5, testament: .old),
        BibleBookInfo(name: "Ezekiel", abbreviation: "Ezek", chapters: 48, testament: .old),
        BibleBookInfo(name: "Daniel", abbreviation: "Dan", chapters: 12, testament: .old),
        BibleBookInfo(name: "Hosea", abbreviation: "Hos", chapters: 14, testament: .old),
        BibleBookInfo(name: "Joel", abbreviation: "Joel", chapters: 3, testament: .old),
        BibleBookInfo(name: "Amos", abbreviation: "Amos", chapters: 9, testament: .old),
        BibleBookInfo(name: "Obadiah", abbreviation: "Obad", chapters: 1, testament: .old),
        BibleBookInfo(name: "Jonah", abbreviation: "Jonah", chapters: 4, testament: .old),
        BibleBookInfo(name: "Micah", abbreviation: "Mic", chapters: 7, testament: .old),
        BibleBookInfo(name: "Nahum", abbreviation: "Nah", chapters: 3, testament: .old),
        BibleBookInfo(name: "Habakkuk", abbreviation: "Hab", chapters: 3, testament: .old),
        BibleBookInfo(name: "Zephaniah", abbreviation: "Zeph", chapters: 3, testament: .old),
        BibleBookInfo(name: "Haggai", abbreviation: "Hag", chapters: 2, testament: .old),
        BibleBookInfo(name: "Zechariah", abbreviation: "Zech", chapters: 14, testament: .old),
        BibleBookInfo(name: "Malachi", abbreviation: "Mal", chapters: 4, testament: .old),
        
        // New Testament
        BibleBookInfo(name: "Matthew", abbreviation: "Matt", chapters: 28, testament: .new),
        BibleBookInfo(name: "Mark", abbreviation: "Mark", chapters: 16, testament: .new),
        BibleBookInfo(name: "Luke", abbreviation: "Luke", chapters: 24, testament: .new),
        BibleBookInfo(name: "John", abbreviation: "John", chapters: 21, testament: .new),
        BibleBookInfo(name: "Acts", abbreviation: "Acts", chapters: 28, testament: .new),
        BibleBookInfo(name: "Romans", abbreviation: "Rom", chapters: 16, testament: .new),
        BibleBookInfo(name: "1 Corinthians", abbreviation: "1 Cor", chapters: 16, testament: .new),
        BibleBookInfo(name: "2 Corinthians", abbreviation: "2 Cor", chapters: 13, testament: .new),
        BibleBookInfo(name: "Galatians", abbreviation: "Gal", chapters: 6, testament: .new),
        BibleBookInfo(name: "Ephesians", abbreviation: "Eph", chapters: 6, testament: .new),
        BibleBookInfo(name: "Philippians", abbreviation: "Phil", chapters: 4, testament: .new),
        BibleBookInfo(name: "Colossians", abbreviation: "Col", chapters: 4, testament: .new),
        BibleBookInfo(name: "1 Thessalonians", abbreviation: "1 Thess", chapters: 5, testament: .new),
        BibleBookInfo(name: "2 Thessalonians", abbreviation: "2 Thess", chapters: 3, testament: .new),
        BibleBookInfo(name: "1 Timothy", abbreviation: "1 Tim", chapters: 6, testament: .new),
        BibleBookInfo(name: "2 Timothy", abbreviation: "2 Tim", chapters: 4, testament: .new),
        BibleBookInfo(name: "Titus", abbreviation: "Titus", chapters: 3, testament: .new),
        BibleBookInfo(name: "Philemon", abbreviation: "Phlm", chapters: 1, testament: .new),
        BibleBookInfo(name: "Hebrews", abbreviation: "Heb", chapters: 13, testament: .new),
        BibleBookInfo(name: "James", abbreviation: "James", chapters: 5, testament: .new),
        BibleBookInfo(name: "1 Peter", abbreviation: "1 Pet", chapters: 5, testament: .new),
        BibleBookInfo(name: "2 Peter", abbreviation: "2 Pet", chapters: 3, testament: .new),
        BibleBookInfo(name: "1 John", abbreviation: "1 John", chapters: 5, testament: .new),
        BibleBookInfo(name: "2 John", abbreviation: "2 John", chapters: 1, testament: .new),
        BibleBookInfo(name: "3 John", abbreviation: "3 John", chapters: 1, testament: .new),
        BibleBookInfo(name: "Jude", abbreviation: "Jude", chapters: 1, testament: .new),
        BibleBookInfo(name: "Revelation", abbreviation: "Rev", chapters: 22, testament: .new)
    ]
    
    static let oldTestament: [BibleBookInfo] = allBooks.filter { $0.testament == .old }
    static let newTestament: [BibleBookInfo] = allBooks.filter { $0.testament == .new }
    
    static func book(named name: String) -> BibleBookInfo? {
        allBooks.first { $0.name == name || $0.abbreviation == name }
    }
    
    static func chapters(for bookName: String) -> Int {
        book(named: bookName)?.chapters ?? 0
    }
}

