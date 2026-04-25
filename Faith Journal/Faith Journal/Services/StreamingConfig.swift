//
//  StreamingConfig.swift
//  Faith Journal
//
//  Configuration for LiveKit streaming server connection
//

import Foundation

struct StreamingConfig {
    // MARK: - Static Configuration
    static let shared = StreamingConfig()
    
    // Server configuration
    /// LiveKit server URL - use LiveKit Cloud (e.g. wss://your-project.livekit.cloud)
    let serverURL: String = {
        let envURL = ProcessInfo.processInfo.environment["LIVEKIT_SERVER_URL"]
        return envURL ?? "wss://faith-journal-juqej6sx.livekit.cloud"
    }()
    
    // HLS streaming server URL (optional; only if you use a separate HLS server)
    let hlsServerURL: String = {
        let envURL = ProcessInfo.processInfo.environment["HLS_SERVER_URL"]
        return envURL ?? ""
    }()
    
    /// Generate HLS stream URL for a session
    func hlsStreamURL(for sessionId: UUID) -> URL? {
        // HLS manifest URL format: https://server:port/hls/{sessionId}/index.m3u8
        let urlString = "\(hlsServerURL)/hls/\(sessionId.uuidString)/index.m3u8"
        return URL(string: urlString)
    }
    
    /// Generate HLS stream URL for a breakout room
    /// Each room gets its own stream endpoint: /hls/{sessionId}-{roomId}/index.m3u8
    func hlsStreamURL(for sessionId: UUID, roomId: UUID) -> URL? {
        // HLS manifest URL format: https://server:port/hls/{sessionId}-{roomId}/index.m3u8
        // This creates a separate stream endpoint for each breakout room
        let urlString = "\(hlsServerURL)/hls/\(sessionId.uuidString)-\(roomId.uuidString)/index.m3u8"
        return URL(string: urlString)
    }
    
    // LiveKit API credentials (from LiveKit Cloud project)
    let apiKey = ProcessInfo.processInfo.environment["LIVEKIT_API_KEY"] ?? "APIo3PpGD4FqusS"
    let apiSecret = ProcessInfo.processInfo.environment["LIVEKIT_API_SECRET"] ?? ""
    
    // Default room settings
    let defaultRoomName = "faith-bible-study"
    let streamingQuality = "720p"
    
    // Update server URL at runtime
    private static var customServerURL: String?
    
    static func setServerURL(_ url: String) {
        customServerURL = url
    }
    
    static func getServerURL() -> String {
        return customServerURL ?? StreamingConfig.shared.serverURL
    }
    
    // MARK: - Validation
    func isValidServerURL() -> Bool {
        return !serverURL.isEmpty && (serverURL.hasPrefix("wss://") || serverURL.hasPrefix("ws://"))
    }

    /// True if LiveKit URL is set to a real project (not the placeholder).
    var isLiveKitConfigured: Bool {
        let url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, url.hasPrefix("wss://") || url.hasPrefix("ws://") else { return false }
        return !url.contains("YOUR_PROJECT")
    }
}
