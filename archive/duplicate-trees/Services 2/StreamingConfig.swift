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
    /// LiveKit server URL - update this with your Oracle VM public IP
    /// Format: wss://YOUR_PUBLIC_IP:7880 or wss://YOUR_DOMAIN:7880
    let serverURL: String = {
        // Development server - Oracle Cloud instance
        let envURL = ProcessInfo.processInfo.environment["LIVEKIT_SERVER_URL"]
        return envURL ?? "wss://129.213.114.10:7880" // Your Oracle LiveKit server
    }()
    
    // HLS streaming server URL (Oracle server)
    /// HLS server URL for streaming - Oracle Cloud instance
    /// Format: https://YOUR_PUBLIC_IP:8080 or https://YOUR_DOMAIN:8080
    let hlsServerURL: String = {
        let envURL = ProcessInfo.processInfo.environment["HLS_SERVER_URL"]
        // Convert WebSocket URL to HTTP/HTTPS for HLS
        let baseURL = envURL ?? "https://129.213.114.10:8080"
        return baseURL
    }()
    
    /// Generate HLS stream URL for a session
    func hlsStreamURL(for sessionId: UUID) -> URL? {
        // HLS manifest URL format: https://server:port/hls/{sessionId}/index.m3u8
        let urlString = "\(hlsServerURL)/hls/\(sessionId.uuidString)/index.m3u8"
        return URL(string: urlString)
    }
    
    // API credentials (for token generation on server)
    let apiKey = "devkey"
    let apiSecret = "devsecret"
    
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
}
