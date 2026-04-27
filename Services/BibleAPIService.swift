import Foundation

enum BibleAPIError: Error {
    case invalidURL
    case noData
    case networkError
    case decodingError
}

@available(iOS 17.0, *)
class BibleAPIService {
    static let shared = BibleAPIService()
    private let baseURL = "https://bible-api.com/"
    
    private init() {}
    
    func fetchVerse(reference: String, version: BibleVersion) async throws -> BibleVerse {
        if let pro = await BibleTranslationProviders.tryFetchBibleAPIStyle(humanReference: reference, for: version) {
            return Self.verseFromProviderBibleResponse(pro, requestedLabel: version.rawValue)
        }
        let versionCode = version.bibleAPIComTranslationCode
        return try await fetchVerse(
            reference: reference,
            versionCode: versionCode,
            requestedLabel: version.rawValue,
            allowWebFallback: versionCode != "web"
        )
    }
    
    private func pathComponentForBibleAPI(reference: String) -> String {
        var ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let bookNameMap: [String: String] = ["Psalm": "Psalms", "psalm": "psalms"]
        let parts = ref.split(separator: " ", maxSplits: 1)
        if let first = parts.first, let normal = bookNameMap[String(first)] {
            ref = ref.replacingOccurrences(of: String(first), with: normal)
        }
        // Same path format as BibleView: genesis+1, john+3:16 (bible-api.com)
        return ref.lowercased().replacingOccurrences(of: " ", with: "+")
    }
    
    private func fetchVerse(reference: String, versionCode: String, requestedLabel: String, allowWebFallback: Bool) async throws -> BibleVerse {
        let path = pathComponentForBibleAPI(reference: reference)
        let urlString = "\(baseURL)\(path)?translation=\(versionCode)"
        
        print("🌐 [BibleAPIService] Fetching: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [BibleAPIService] Invalid URL: \(urlString)")
            throw BibleAPIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [BibleAPIService] Invalid HTTP response")
                throw BibleAPIError.networkError
            }
            
            print("📡 [BibleAPIService] HTTP Status: \(httpResponse.statusCode)")
            
            // Check for API error response (bible-api.com often returns 200 with {"error":...} for bad translation)
            if let errorString = String(data: data, encoding: .utf8),
               errorString.contains("\"error\"") {
                print("❌ [BibleAPIService] API returned error: \(errorString)")
                if let errorData = errorString.data(using: .utf8),
                   let errorDict = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                   let errorMessage = errorDict["error"] as? String,
                   (errorMessage.contains("translation") || errorMessage.contains("not found")) {
                    if allowWebFallback {
                        print("⚠️ [BibleAPIService] Retrying with translation=web …")
                        return try await fetchVerse(
                            reference: reference,
                            versionCode: "web",
                            requestedLabel: requestedLabel,
                            allowWebFallback: false
                        )
                    }
                }
                if allowWebFallback {
                    return try await fetchVerse(
                        reference: reference,
                        versionCode: "web",
                        requestedLabel: requestedLabel,
                        allowWebFallback: false
                    )
                }
                throw BibleAPIError.networkError
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [BibleAPIService] HTTP Error: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("   Response: \(errorString)")
                }
                if allowWebFallback, httpResponse.statusCode == 404 || (400...499).contains(httpResponse.statusCode) {
                    print("⚠️ [BibleAPIService] Retrying with translation=web …")
                    return try await fetchVerse(
                        reference: reference,
                        versionCode: "web",
                        requestedLabel: requestedLabel,
                        allowWebFallback: false
                    )
                }
                throw BibleAPIError.networkError
            }
            
            guard !data.isEmpty else {
                print("❌ [BibleAPIService] Empty response data")
                throw BibleAPIError.noData
            }
            
            let decoder = JSONDecoder()
            do {
                // First check if response contains an error
                if let jsonString = String(data: data, encoding: .utf8),
                   let jsonData = jsonString.data(using: .utf8),
                   let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let errorMessage = jsonDict["error"] as? String {
                    print("❌ [BibleAPIService] API error in response: \(errorMessage)")
                    if allowWebFallback {
                        return try await fetchVerse(
                            reference: reference,
                            versionCode: "web",
                            requestedLabel: requestedLabel,
                            allowWebFallback: false
                        )
                    }
                    throw BibleAPIError.networkError
                }
                
                let apiResponse = try decoder.decode(BibleAPIResponse.self, from: data)
                print("✅ [BibleAPIService] Decoded response: \(apiResponse.reference) (\(apiResponse.verses.count) verses)")
                
                // Extract first verse or combine all verses
                let verseText = apiResponse.verses.isEmpty ? apiResponse.text : apiResponse.verses.map { $0.text }.joined(separator: " ")
                
                guard !verseText.isEmpty else {
                    print("❌ [BibleAPIService] Empty verse text")
                    throw BibleAPIError.noData
                }
                
                // Use the actual translation from API, or fallback to requested version
                let actualTranslation = apiResponse.translation_id?.uppercased() ?? requestedLabel
                print("📖 [BibleAPIService] Translation: \(actualTranslation) (requested: \(requestedLabel))")
                
                return BibleVerse(
                    reference: apiResponse.reference,
                    text: verseText.trimmingCharacters(in: .whitespacesAndNewlines),
                    translation: actualTranslation
                )
            } catch let decodingError as DecodingError {
                print("❌ [BibleAPIService] Decoding error: \(decodingError)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   JSON: \(jsonString.prefix(500))")
                }
                throw BibleAPIError.decodingError
            }
        } catch let error as BibleAPIError {
            print("❌ [BibleAPIService] BibleAPIError: \(error)")
            throw error
        } catch {
            print("❌ [BibleAPIService] Network error: \(error.localizedDescription)")
            throw BibleAPIError.networkError
        }
    }
    
    private static func verseFromProviderBibleResponse(_ p: BibleAPIResponse, requestedLabel: String) -> BibleVerse {
        let t = p.verses.isEmpty ? p.text : p.verses.map { $0.text }.joined(separator: " ")
        let tr = p.translation_id?.uppercased() ?? requestedLabel
        return BibleVerse(
            reference: p.reference,
            text: t.trimmingCharacters(in: .whitespacesAndNewlines),
            translation: tr
        )
    }
}

struct BibleAPIResponse: Codable {
    let reference: String
    let verses: [BibleAPIVerse]
    let text: String
    let translation_id: String?
    let translation_name: String?
    let translation_note: String?
}

struct BibleAPIVerse: Codable {
    let book_id: String
    let book_name: String
    let chapter: Int
    let verse: Int
    let text: String
}

// MARK: - Optional `APIDotBibleKey` (scripture.api.bible — use a plan that matches your app’s commercial status)

private enum BibleProviderConfig {
    static var apiBibleKey: String? {
        if let v = Bundle.main.object(forInfoDictionaryKey: "APIDotBibleKey") as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty { return v.trimmingCharacters(in: .whitespaces) }
        if let v = ProcessInfo.processInfo.environment["API_BIBLE_KEY"], !v.isEmpty { return v }
        return nil
    }
}

private enum BibleUSFMBookCodes {
    private static let nameToUSFM: [String: String] = [
        "genesis": "GEN", "exodus": "EXO", "leviticus": "LEV", "numbers": "NUM", "deuteronomy": "DEU",
        "joshua": "JOS", "judges": "JDG", "ruth": "RUT", "1 samuel": "1SA", "2 samuel": "2SA", "1 kings": "1KI", "2 kings": "2KI",
        "1 chronicles": "1CH", "2 chronicles": "2CH", "ezra": "EZR", "nehemiah": "NEH", "esther": "EST", "job": "JOB", "psalms": "PSA", "psalm": "PSA",
        "proverbs": "PRO", "ecclesiastes": "ECC", "song of solomon": "SNG", "songs of solomon": "SNG", "isaiah": "ISA", "jeremiah": "JER", "lamentations": "LAM",
        "ezekiel": "EZK", "daniel": "DAN", "hosea": "HOS", "joel": "JOL", "amos": "AMO", "obadiah": "OBA", "jonah": "JON", "micah": "MIC", "nahum": "NAH",
        "habakkuk": "HAB", "zephaniah": "ZEP", "haggai": "HAG", "zechariah": "ZEC", "malachi": "MAL", "matthew": "MAT", "mark": "MRK", "luke": "LUK", "john": "JHN",
        "acts": "ACT", "romans": "ROM", "1 corinthians": "1CO", "2 corinthians": "2CO", "galatians": "GAL", "ephesians": "EPH", "philippians": "PHP", "colossians": "COL",
        "1 thessalonians": "1TH", "2 thessalonians": "2TH", "1 timothy": "1TI", "2 timothy": "2TI", "titus": "TIT", "philemon": "PHM", "hebrews": "HEB", "james": "JAS",
        "1 peter": "1PE", "2 peter": "2PE", "1 john": "1JN", "2 john": "2JN", "3 john": "3JN", "jude": "JUD", "revelation": "REV"
    ]
    static func scriptureChapterId(fromReference reference: String) -> String? {
        var s = reference.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: "Psalm ", with: "Psalms ", options: .caseInsensitive, range: nil)
        let parts = s.split(separator: " ").map(String.init)
        guard !parts.isEmpty, let ch = Int(parts.last ?? "") else { return nil }
        let book = parts.dropLast().joined(separator: " ")
        let key = book.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty, let usfm = nameToUSFM[key] else { return nil }
        return "\(usfm).\(ch)"
    }
    static func normalizedSearchQuery(fromReference reference: String) -> String {
        var s = reference.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: "Psalm ", with: "Psalms ", options: .caseInsensitive, range: nil)
        return s
    }
}

private actor APIScriptureBibleRegistry {
    static let shared = APIScriptureBibleRegistry()
    private var cache: [String: String] = [:]
    private var bibles: [(id: String, abbr: String, name: String)]?
    func bibleId(key: String, for version: BibleVersion) async -> String? {
        if let c = cache[version.rawValue] { return c }
        if version == .kjv || version == .web { return nil }
        let list: [(id: String, abbr: String, name: String)]
        if let e = bibles { list = e } else {
            var req = URLRequest(url: URL(string: "https://api.scripture.api.bible/v1/bibles?language=eng&limit=500")!)
            req.setValue(key, forHTTPHeaderField: "api-key")
            guard let (d, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let arr = json["data"] as? [[String: Any]] else { bibles = []; return nil }
            bibles = arr.compactMap { o in
                guard let id = o["id"] as? String else { return nil }
                return (id, o["abbreviation"] as? String ?? "", o["name"] as? String ?? "")
            }
            list = bibles!
        }
        if list.isEmpty { return nil }
        let (prefer, hints): (String, [String]) = {
            switch version {
            case .niv: return ("NIV", ["NIV", "New International Version"])
            case .nlt: return ("NLT", ["NLT", "New Living"])
            case .nasb: return ("NASB", ["NASB", "New American Standard"])
            case .msg: return ("MSG", ["MSG", "The Message", "Eugene Peterson"])
            case .amp: return ("AMP", ["AMP", "Amplified Bible"])
            case .csb: return ("CSB", ["CSB", "Christian Standard Bible"])
            case .esv: return ("ESV", ["ESV", "English Standard Version"])
            case .kjv, .web: return ("", [])
            }
        }()
        if prefer.isEmpty { return nil }
        for h in [prefer] + hints {
            if let f = list.first(where: { $0.abbr.uppercased() == h.uppercased() }) { cache[version.rawValue] = f.id; return f.id }
        }
        for h in hints {
            if let f = list.first(where: { $0.name.range(of: h, options: .caseInsensitive) != nil }) { cache[version.rawValue] = f.id; return f.id }
        }
        if let f = list.first(where: { $0.abbr.uppercased().hasPrefix(prefer) }) { cache[version.rawValue] = f.id; return f.id }
        return nil
    }
}

@available(iOS 17.0, *)
enum BibleTranslationProviders {
    static func tryFetchBibleAPIStyle(humanReference: String, for version: BibleVersion) async -> BibleAPIResponse? {
        if version == .kjv || version == .web { return nil }
        guard let k = BibleProviderConfig.apiBibleKey, !k.isEmpty else { return nil }
        return try? await scriptureBibleData(human: humanReference, for: version, key: k)
    }
    private static func scriptureBibleData(human: String, for version: BibleVersion, key: String) async throws -> BibleAPIResponse? {
        guard !key.isEmpty, let bid = await APIScriptureBibleRegistry.shared.bibleId(key: key, for: version) else { return nil }
        if !human.contains(":"), let chid = BibleUSFMBookCodes.scriptureChapterId(fromReference: human) {
            return try await fetchScriptureChapter(bibleId: bid, chapterId: chid, key: key, display: version.rawValue)
        }
        return try await fetchScriptureSearch(natural: human, bibleId: bid, key: key, display: version.rawValue)
    }
    private static func fetchScriptureChapter(bibleId: String, chapterId: String, key: String, display: String) async throws -> BibleAPIResponse? {
        var c = URLComponents(string: "https://api.scripture.api.bible/v1/bibles/\(bibleId)/chapters/\(chapterId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? chapterId)")!
        c.queryItems = [.init(name: "content-type", value: "json"), .init(name: "include-verse-numbers", value: "true")]
        var req = URLRequest(url: c.url!)
        req.setValue(key, forHTTPHeaderField: "api-key")
        let (body, r) = try await URLSession.shared.data(for: req)
        guard (r as? HTTPURLResponse)?.statusCode == 200, !body.isEmpty,
              let o = try? JSONSerialization.jsonObject(with: body) as? [String: Any], let d2 = o["data"] as? [String: Any] else { return nil }
        if let vlist = d2["verses"] as? [[String: Any]], !vlist.isEmpty {
            var out: [BibleAPIVerse] = []
            for v in vlist {
                let t = (v["text"] as? String) ?? (v["content"] as? String) ?? ""
                if t.isEmpty { continue }
                let vid = (v["id"] as? String) ?? ""
                var chap = 1, ver = 1, bid = (v["bookId"] as? String) ?? "BOK"
                if !vid.isEmpty, vid.split(separator: ".").count >= 2 { bid = String(vid.split(separator: ".").first!) }
                if !vid.isEmpty, let last = vid.split(separator: ".").last, let cno = last.split(separator: ":").first, let c = Int(cno) { chap = c }
                if !vid.isEmpty, let last = vid.split(separator: ":").last, let vv = Int(last) { ver = vv } else {
                    ver = (v["verse"] as? String).flatMap { Int($0) } ?? (v["number"] as? String).flatMap { Int($0) } ?? 1
                }
                out.append(BibleAPIVerse(book_id: bid, book_name: bid, chapter: chap, verse: ver, text: t))
            }
            if out.isEmpty { return nil }
            return BibleAPIResponse(
                reference: (d2["reference"] as? String) ?? chapterId, verses: out, text: out.map { $0.text }.joined(separator: " "),
                translation_id: display.uppercased(), translation_name: display, translation_note: nil
            )
        }
        return nil
    }
    private static func fetchScriptureSearch(natural: String, bibleId: String, key: String, display: String) async throws -> BibleAPIResponse? {
        var c = URLComponents(string: "https://api.scripture.api.bible/v1/bibles/\(bibleId)/search")!
        c.queryItems = [.init(name: "query", value: BibleUSFMBookCodes.normalizedSearchQuery(fromReference: natural)), .init(name: "limit", value: "5"), .init(name: "offset", value: "0")]
        var req = URLRequest(url: c.url!)
        req.setValue(key, forHTTPHeaderField: "api-key")
        let (d, r) = try await URLSession.shared.data(for: req)
        guard (r as? HTTPURLResponse)?.statusCode == 200, let top = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        var first: [String: Any]?
        if let arr = top["data"] as? [[String: Any]] { first = arr.first }
        if first == nil, let arr = (top["data"] as? [String: Any])?["verses"] as? [[String: Any]] { first = arr.first }
        guard let f = first, let t = f["text"] as? String, !t.isEmpty else { return nil }
        return BibleAPIResponse(
            reference: (f["reference"] as? String) ?? natural,
            verses: [BibleAPIVerse(book_id: (f["bookId"] as? String) ?? "BOK", book_name: (f["bookId"] as? String) ?? "BOK", chapter: 1, verse: 1, text: t)],
            text: t, translation_id: display.uppercased(), translation_name: display, translation_note: nil
        )
    }
}
