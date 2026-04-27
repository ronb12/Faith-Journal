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
        let versionCode = version.bibleAPIComTranslationCode
        let encodedReference = reference.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? reference
        let urlString = "\(baseURL)\(encodedReference)?translation=\(versionCode)"
        
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
            
            // Check for API error response (API returns 200 even for translation errors)
            if let errorString = String(data: data, encoding: .utf8),
               errorString.contains("\"error\"") {
                print("❌ [BibleAPIService] API returned error: \(errorString)")
                // Try to parse error
                if let errorData = errorString.data(using: .utf8),
                   let errorDict = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                   let errorMessage = errorDict["error"] as? String {
                    print("   Error message: \(errorMessage)")
                    if errorMessage.contains("translation") {
                        throw BibleAPIError.networkError  // Translation not supported
                    }
                }
                throw BibleAPIError.networkError
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [BibleAPIService] HTTP Error: \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("   Response: \(errorString)")
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
                let actualTranslation = apiResponse.translation_id?.uppercased() ?? version.rawValue
                print("📖 [BibleAPIService] Translation: \(actualTranslation) (requested: \(version.rawValue))")
                
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
