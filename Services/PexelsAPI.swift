//
//  PexelsAPI.swift
//  Faith Journal
//
//  Fetches faith-based stock photos from Pexels for live session thumbnails.
//  API key: copy PexelsSecrets-template.plist to PexelsSecrets.plist and set PEXELS_API_KEY.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum PexelsAPI {
    private static let baseURL = "https://api.pexels.com/v1"

    struct Photo: Identifiable, Hashable {
        let id: Int
        let photographer: String
        let photographerURL: URL?
        let pageURL: URL?
        let source: Source

        var previewURL: URL? {
            source.landscape ?? source.large2x ?? source.large ?? source.medium
        }

        var downloadURL: URL? {
            source.large2x ?? source.large ?? source.landscape ?? source.original
        }
    }

    struct Source: Hashable {
        let original: URL?
        let large2x: URL?
        let large: URL?
        let medium: URL?
        let landscape: URL?
    }

    fileprivate struct SearchResponse: Decodable {
        let photos: [PhotoResponse]
    }

    fileprivate struct PhotoResponse: Decodable {
        let id: Int
        let url: String?
        let photographer: String
        let photographerURL: String?
        let src: SourceResponse

        enum CodingKeys: String, CodingKey {
            case id
            case url
            case photographer
            case photographerURL = "photographer_url"
            case src
        }
    }

    fileprivate struct SourceResponse: Decodable {
        let original: String?
        let large2x: String?
        let large: String?
        let medium: String?
        let landscape: String?

        enum CodingKeys: String, CodingKey {
            case original
            case large2x = "large2x"
            case large
            case medium
            case landscape
        }
    }
    
    /// Load API key from PexelsSecrets.plist in the app bundle. Do not commit the real plist.
    static var apiKey: String? {
        let key = "PEXELS_API_KEY"
        var candidates: [URL] = []
        if let url = Bundle.main.url(forResource: "PexelsSecrets", withExtension: "plist") {
            candidates.append(url)
        }
        if let url = Bundle.main.url(forResource: "PexelsSecrets", withExtension: "plist", subdirectory: "Faith Journal") {
            candidates.append(url)
        }
        if let base = Bundle.main.resourceURL {
            candidates.append(base.appendingPathComponent("PexelsSecrets.plist"))
            candidates.append(base.appendingPathComponent("Faith Journal/PexelsSecrets.plist"))
        }
        #if os(macOS)
        if let bundleURL = Bundle.main.bundleURL as URL? {
            candidates.append(bundleURL.appendingPathComponent("Contents/Resources/PexelsSecrets.plist"))
        }
        #endif
        for url in candidates where FileManager.default.isReadableFile(atPath: url.path) {
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let value = plist[key] as? String,
                  !value.isEmpty,
                  !isPlaceholder(value) else { continue }
            return value
        }
        return nil
    }
    
    private static func isPlaceholder(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.contains("your_pexels") || t.contains("your_here") || t == "yours" || t == "placeholder"
    }
    
    /// Search Pexels for one photo and return its URL (medium size, good for thumbnails). Returns nil if no key, no results, or network error.
    static func searchPhoto(query: String, perPage: Int = 1) async -> URL? {
        let photos = await searchPhotos(query: query, perPage: perPage)
        return photos.first?.previewURL
    }

    /// Search Pexels for landscape photos that work well as live stream virtual backgrounds.
    static func searchPhotos(query: String, perPage: Int = 12) async -> [Photo] {
        guard let key = apiKey else { return [] }
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "orientation", value: "landscape"),
            URLQueryItem(name: "size", value: "large"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            return decoded.photos.compactMap(Photo.init(response:))
        } catch {
            return []
        }
    }

    /// Downloads a Pexels photo into Caches and returns a local file URL suitable for Agora image backgrounds.
    static func cachedBackgroundURL(for photo: Photo) async throws -> URL {
        guard let url = photo.downloadURL else {
            throw NSError(domain: "PexelsAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pexels did not return a downloadable image."])
        }
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FaithLiveBackgrounds/Pexels", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("pexels-\(photo.id).jpg")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "PexelsAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not download the selected Pexels photo."])
        }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        return fileURL
    }
}

private extension PexelsAPI.Photo {
    init?(response: PexelsAPI.PhotoResponse) {
        let source = PexelsAPI.Source(response: response.src)
        guard source.previewURL != nil else { return nil }
        self.id = response.id
        self.photographer = response.photographer
        self.photographerURL = response.photographerURL.flatMap(URL.init(string:))
        self.pageURL = response.url.flatMap(URL.init(string:))
        self.source = source
    }
}

private extension PexelsAPI.Source {
    init(response: PexelsAPI.SourceResponse) {
        self.original = response.original.flatMap(URL.init(string:))
        self.large2x = response.large2x.flatMap(URL.init(string:))
        self.large = response.large.flatMap(URL.init(string:))
        self.medium = response.medium.flatMap(URL.init(string:))
        self.landscape = response.landscape.flatMap(URL.init(string:))
    }

    var previewURL: URL? {
        landscape ?? large2x ?? large ?? medium
    }
}
