//
//  StreamingConfig.swift
//  Faith Journal
//
//  Configuration for LiveKit streaming server connection.
//  Use LiveKit Cloud (no Oracle/VPS needed) + Vercel for token server.
//

import Foundation

struct StreamingConfig {
    // MARK: - Static Configuration
    static let shared = StreamingConfig()
    
    // Server configuration
    /// LiveKit server URL. From env (LIVEKIT_SERVER_URL or LIVEKIT_URL), then LiveKitSecret.plist, then default.
    let serverURL: String = {
        if let env = ProcessInfo.processInfo.environment["LIVEKIT_SERVER_URL"], !env.isEmpty { return env }
        if let env = ProcessInfo.processInfo.environment["LIVEKIT_URL"], !env.isEmpty { return env }
        if let plist = Self.liveKitSecretFromBundle()?["LIVEKIT_SERVER_URL"] as? String, !plist.isEmpty { return plist }
        if let plist = Self.liveKitSecretFromBundle()?["LIVEKIT_URL"] as? String, !plist.isEmpty { return plist }
        return "wss://faith-journal-juqej6sx.livekit.cloud"
    }()
    
    // HLS streaming server URL (optional; only if you use HLS streaming)
    /// Set HLS_SERVER_URL if you have an HLS server; otherwise leave unset.
    /// Not required when using LiveKit for live streams.
    let hlsServerURL: String = {
        let envURL = ProcessInfo.processInfo.environment["HLS_SERVER_URL"]
        let baseURL = envURL ?? "" // No default; set if you use HLS
        return baseURL
    }()
    
    /// Generate HLS stream URL for a session
    /// Format: https://server:port/hls/{sessionId}/index.m3u8
    /// The Oracle HLS server must be reachable and pushing the stream for playback to work.
    func hlsStreamURL(for sessionId: UUID) -> URL? {
        let base = hlsServerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = "\(base)/hls/\(sessionId.uuidString)/index.m3u8"
        return URL(string: urlString)
    }
    
    /// Whether the HLS server URL is configured and well-formed.
    var isHLSServerConfigured: Bool {
        guard let url = URL(string: hlsServerURL),
              url.scheme == "https" || url.scheme == "http",
              let host = url.host, !host.isEmpty else { return false }
        return true
    }
    
    // LiveKit API credentials (from your LiveKit Cloud project at https://cloud.livekit.io)
    /// Source order: 1) Environment variables (when run from Xcode), 2) LiveKitSecret.plist in bundle (for archived/TestFlight builds).
    let apiKey: String = {
        if let env = ProcessInfo.processInfo.environment["LIVEKIT_API_KEY"], !env.isEmpty { return env }
        if let plist = Self.liveKitSecretFromBundle()?["LIVEKIT_API_KEY"] as? String, !plist.isEmpty { return plist }
        return "APIo3PpGD4FqusS"
    }()
    let apiSecret: String = {
        if let env = ProcessInfo.processInfo.environment["LIVEKIT_API_SECRET"], !env.isEmpty, !Self.isPlaceholderSecret(env) { return env }
        if let plist = Self.liveKitSecretFromBundle()?["LIVEKIT_API_SECRET"] as? String, !plist.isEmpty, !Self.isPlaceholderSecret(plist) { return plist }
        return "devsecret"
    }()

    /// Read LiveKitSecret.plist from the app bundle (for Run from Xcode, TestFlight, App Store).
    /// Tries bundle root first, then "Faith Journal" subpath (in case Copy Bundle Resources preserved path).
    /// Add LiveKitSecret.plist to BOTH targets’ Copy Bundle Resources (Faith Journal + Faith Journal macOS). See LiveKitSecret-template.plist.
    private static func isPlaceholderSecret(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.isEmpty || t == "devsecret" || t.contains("your_livekit") || t.contains("your secret") || t.contains("_here") || t == "yours"
    }

    private static func liveKitSecretFromBundle() -> [String: Any]? {
        var candidates: [URL?] = [
            Bundle.main.url(forResource: "LiveKitSecret", withExtension: "plist"),
            Bundle.main.url(forResource: "LiveKitSecret", withExtension: "plist", subdirectory: "Faith Journal"),
        ]
        if let base = Bundle.main.resourceURL {
            candidates.append(base.appendingPathComponent("LiveKitSecret.plist"))
            candidates.append(base.appendingPathComponent("Faith Journal/LiveKitSecret.plist"))
        }
        #if os(macOS)
        if let bundleURL = Bundle.main.bundleURL as URL? {
            candidates.append(bundleURL.appendingPathComponent("Contents/Resources/LiveKitSecret.plist"))
        }
        #endif
        for case let url? in candidates {
            guard FileManager.default.isReadableFile(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  !plist.isEmpty else { continue }
            return plist
        }
        return nil
    }
    
    // Default room settings
    let defaultRoomName = "faith-bible-study"
    let streamingQuality = "720p"
    
    // Update server URL at runtime
    private static var customServerURL: String?
    
    static func setServerURL(_ url: String) {
        customServerURL = url
    }
    
    static func getServerURL() -> String {
        let raw = customServerURL ?? StreamingConfig.shared.serverURL
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// Check LiveKit API key/secret are set and not placeholders. Does not hit the server.
    static func checkLiveKitCredentials() -> (ok: Bool, message: String) {
        let config = StreamingConfig.shared
        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = config.apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let secretFromEnv = ProcessInfo.processInfo.environment["LIVEKIT_API_SECRET"] != nil
        if key.isEmpty { return (false, "LIVEKIT_API_KEY is empty. Set in Xcode: Edit Scheme → Run → Environment Variables.") }
        if secret.isEmpty { return (false, "LIVEKIT_API_SECRET is empty. Set in Xcode scheme environment.") }
        if secret == "devsecret" && !secretFromEnv { return (false, "Using default \"devsecret\". Set LIVEKIT_API_SECRET to your LiveKit Cloud secret.") }
        return (true, "Credentials set (key: \(key.prefix(8))…).")
    }

    // MARK: - LiveKit server connection check

    /// Check whether the LiveKit server is reachable (WebSocket connect to same URL LiveKit uses).
    static func checkLiveKitServerReachability() async -> (reachable: Bool, message: String) {
        let urlString = getServerURL().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty,
              urlString.hasPrefix("wss://") || urlString.hasPrefix("ws://"),
              let wsURL = URL(string: urlString) else {
            return (false, "Invalid LiveKit URL")
        }
        if #available(iOS 13.0, macOS 10.15, *) {
            var request = URLRequest(url: wsURL)
            request.timeoutInterval = 10
            let delegate = WebSocketReachabilityDelegate()
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.webSocketTask(with: request)
            task.resume()
            do {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    delegate.continuation = cont
                }
                task.cancel(with: .goingAway, reason: nil)
                session.finishTasksAndInvalidate()
                return (true, "Server reachable (WebSocket OK)")
            } catch {
                session.finishTasksAndInvalidate()
                let msg = (error as NSError).localizedDescription.lowercased()
                // "Bad response" = server replied but rejected plain WebSocket (LiveKit expects token). Server is reachable.
                if msg.contains("bad response") || msg.contains("response from the server") || msg.contains("unacceptable") {
                    return (true, "Server reachable (rejects plain WebSocket; join with app to connect.)")
                }
                return (false, "Unreachable: \((error as NSError).localizedDescription)")
            }
        }
        return (false, "Unsupported")
    }
}

@available(iOS 13.0, macOS 10.15, *)
private class WebSocketReachabilityDelegate: NSObject, URLSessionWebSocketDelegate {
    var continuation: CheckedContinuation<Void, Error>?

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        continuation?.resume()
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let c = continuation else { return }
        if let e = error {
            c.resume(throwing: e)
        }
        continuation = nil
    }
}
