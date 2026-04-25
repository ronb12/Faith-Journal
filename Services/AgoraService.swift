//
//  AgoraService.swift
//  Faith Journal
//
//  Agora RTC SDK service for multi-presenter video conferencing
//  Provides professional-grade video/audio streaming
//

import Foundation
import Combine
import AVFoundation
#if os(macOS)
import AppKit
#endif

#if os(macOS)
#if canImport(AgoraRtcKit1)
import AgoraRtcKit1
#elseif canImport(AgoraRtcKit)
import AgoraRtcKit
#endif
#else
#if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
import AgoraRtcKit
#endif
#endif

/// User role in the session
enum AgoraUserRole {
    case broadcaster // Can present with video/audio
    case audience    // Watch/listen only
}

/// Who should get the large “active speaker” tile when many participants are in the call.
enum AgoraSpotlightSubject: Equatable {
    case none
    case local
    case remote(UInt)
}

@MainActor
class AgoraService: NSObject, ObservableObject {
    static let shared = AgoraService()
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var participantCount = 0
    @Published var errorMessage: String?
    @Published var isVideoEnabled = true
    @Published var isAudioEnabled = true
    @Published var remoteUsers: [UInt] = []
    @Published var currentRole: AgoraUserRole = .audience
    @Published var canPromoteToPresenter = false
    /// Agora-assigned UID after join (join uses 0 = auto-assign). Used for active-speaker matching.
    @Published private(set) var localRtcUid: UInt = 0
    /// Who is currently driving the active-speaker spotlight (volume indication).
    @Published private(set) var spotlightSubject: AgoraSpotlightSubject = .none
    /// Last time we lowered encoder tier due to network (debounce adaptive video).
    private var lastAdaptiveVideoChange: Date = .distantPast
    private var adaptiveVideoTier: Int = 0 // 0 = HD, 1 = SD, 2 = low
    
    // MARK: - Private Properties
    #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1)) || (os(macOS) && canImport(AgoraRtcKit1))
    private var agoraKit: AgoraRtcEngineKit?
    #endif
    
    private var sessionId: UUID?
    private var userId: String?
    private var userName: String?
    private var channelName: String?
    
    // Agora credentials — read from AgoraSecrets.plist (add file to Copy Bundle Resources).
    private static func agoraSecrets() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "AgoraSecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return dict
    }

    private let appId: String = {
        if let id = AgoraService.agoraSecrets()?["AGORA_APP_ID"] as? String, !id.isEmpty { return id }
        return ""
    }()

    /// Token server (must use same App ID + certificate). Error 110 = token required or invalid.
    private let tokenServerURL: String = {
        if let url = AgoraService.agoraSecrets()?["AGORA_TOKEN_SERVER_URL"] as? String, !url.isEmpty { return url }
        return "https://token-server-eight.vercel.app/api/agora/token"
    }()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Token fetch (required when Agora project has certificate enabled)
    
    private struct TokenRequest: Encodable {
        let channelName: String
        let uid: UInt
        let role: String
    }
    
    private struct TokenResponse: Decodable {
        let token: String
        let expiresIn: Int?
    }
    
    private func fetchTokenFromServer(channelName: String, uid: UInt = 0, role: AgoraUserRole) async throws -> String {
        guard let url = URL(string: tokenServerURL) else {
            throw AgoraError.joinChannelFailed
        }
        let body = TokenRequest(
            channelName: channelName,
            uid: uid,
            role: role == .broadcaster ? "publisher" : "subscriber"
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        
        print("📡 [AGORA] Fetching token from server...")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            print("❌ [AGORA] Token server error: \(msg)")
            throw AgoraError.joinChannelFailed
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        let token = decoded.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw AgoraError.joinChannelFailed }
        print("✅ [AGORA] Token received")
        return token
    }
    
    // MARK: - Public Methods
    
    /// Join a video conference channel
    func joinChannel(sessionId: UUID, userId: String, userName: String, role: AgoraUserRole = .broadcaster, token: String? = nil) async throws {
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        self.channelName = "faith-journal-\(sessionId.uuidString)"
        self.currentRole = role
        self.localRtcUid = 0
        self.spotlightSubject = .none
        
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        guard !appId.isEmpty && appId != "YOUR_AGORA_APP_ID" else {
            errorMessage = "Agora App ID not configured"
            throw AgoraError.invalidAppId
        }
        
        // Initialize Agora Engine
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.channelProfile = .liveBroadcasting
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        // Configure audio session so remote audio plays and mic works
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        
        // Enable video module
        agoraKit?.enableVideo()
        agoraKit?.enableAudio()
        
        // Set client role based on parameter
        switch role {
        case .broadcaster:
            agoraKit?.setClientRole(.broadcaster)
        case .audience:
            agoraKit?.setClientRole(.audience)
        }
        
        // Set video configuration (frameRate: 30 = 30 fps; SDK may use Int or AgoraVideoFrameRate)
        let videoConfig = AgoraVideoEncoderConfiguration(
            size: CGSize(width: 1280, height: 720),
            frameRate: 30,
            bitrate: AgoraVideoBitrateStandard,
            orientationMode: .adaptative,
            mirrorMode: .auto
        )
        agoraKit?.setVideoEncoderConfiguration(videoConfig)
        
        // Use provided token or fetch from server (required when Agora project has certificate enabled; error 110 otherwise)
        var tokenToUse = token
        if tokenToUse == nil {
            do {
                tokenToUse = try await fetchTokenFromServer(channelName: channelName!, uid: 0, role: role)
            } catch {
                print("⚠️ [AGORA] Token fetch failed: \(error.localizedDescription). Joining without token (may get error 110 if token is required).")
            }
        }
        
        // Join channel
        let joinRole = role
        let result = agoraKit?.joinChannel(
            byToken: tokenToUse,
            channelId: channelName!,
            info: nil,
            uid: 0
        ) { [weak self] channel, uid, elapsed in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = true
                self.participantCount = 1 // local user
                self.localRtcUid = uid
                print("✅ [AGORA] Joined channel: \(channel) with UID: \(uid)")
                // Active speaker detection (needed for spotlight UI at 5+ participants).
                self.agoraKit?.enableAudioVolumeIndication(250, smooth: 3, reportVad: true)
                // Start camera immediately for broadcasters (fixes iPad where view bounds can be delayed)
                if case .broadcaster = joinRole, self.isVideoEnabled {
                    self.agoraKit?.enableLocalVideo(true)
                    self.agoraKit?.startPreview()
                }
            }
        }
        
        if result != 0 {
            errorMessage = "Failed to join channel"
            throw AgoraError.joinChannelFailed
        }
        
        print("✅ [AGORA] Joining channel: \(channelName!)")
        #else
        errorMessage = "Agora SDK not installed"
        throw AgoraError.sdkNotInstalled
        #endif
    }
    
    /// Leave the conference (teardown happens in completion to avoid use-after-free)
    func leaveChannel() {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        guard let kit = agoraKit else {
            channelName = nil
            return
        }
        // Deactivate audio session first to avoid AVFAudio _auv3 != nil crash during teardown
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        kit.stopPreview()
        kit.leaveChannel { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.isConnected = false
                self.remoteUsers.removeAll()
                self.participantCount = 0
                self.localRtcUid = 0
                self.spotlightSubject = .none
                self.adaptiveVideoTier = 0
                self.lastAdaptiveVideoChange = .distantPast
                print("✅ [AGORA] Left channel")
            }
            // Delay destroy so Core Audio can release the AU and avoid _auv3 != nil crash
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                AgoraRtcEngineKit.destroy()
            }
        }
        agoraKit = nil
        #endif
        channelName = nil
    }
    
    /// Toggle local video
    func toggleVideo() {
        isVideoEnabled.toggle()
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        if isVideoEnabled {
            agoraKit?.enableLocalVideo(true)
            agoraKit?.startPreview()
        } else {
            agoraKit?.enableLocalVideo(false)
            agoraKit?.stopPreview()
        }
        print("📹 [AGORA] Video \(isVideoEnabled ? "enabled" : "disabled")")
        #endif
    }
    
    /// Toggle local audio
    func toggleAudio() {
        isAudioEnabled.toggle()
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        agoraKit?.muteLocalAudioStream(!isAudioEnabled)
        print("🎤 [AGORA] Audio \(isAudioEnabled ? "enabled" : "disabled")")
        #endif
    }

    /// Set local audio muted (e.g. when host mutes this participant).
    func setAudioMuted(_ muted: Bool) {
        guard isAudioEnabled == !muted else { return }
        isAudioEnabled = !muted
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        agoraKit?.muteLocalAudioStream(muted)
        print("🎤 [AGORA] Audio \(muted ? "muted by host" : "unmuted")")
        #endif
    }
    
    /// Switch camera (front/back); iOS only (macOS has no front/back camera).
    func switchCamera() {
        #if os(iOS) && canImport(AgoraRtcKit)
        agoraKit?.switchCamera()
        print("📷 [AGORA] Camera switched")
        #endif
    }
    
    /// Get local video view (SDK may create one; can be nil or zero-sized)
    func setupLocalVideo() -> Any? {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.renderMode = .hidden
        agoraKit?.setupLocalVideo(videoCanvas)
        agoraKit?.startPreview()
        return videoCanvas.view
        #else
        return nil
        #endif
    }
    
    /// Setup local video to render into a specific view (recommended for SwiftUI so the view has valid bounds)
    #if os(iOS)
    func setupLocalVideo(view: UIView) {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.view = view
        videoCanvas.renderMode = .hidden
        agoraKit?.setupLocalVideo(videoCanvas)
        agoraKit?.startPreview()
        #endif
    }
    #elseif os(macOS)
    func setupLocalVideo(view: NSView) {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.view = view
        videoCanvas.renderMode = .hidden
        agoraKit?.setupLocalVideo(videoCanvas)
        agoraKit?.startPreview()
        #endif
    }
    #endif
    
    /// Setup remote video view for a user (returns view created by SDK if no container provided)
    func setupRemoteVideo(for uid: UInt) -> Any? {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.renderMode = .hidden
        agoraKit?.setupRemoteVideo(videoCanvas)
        return videoCanvas.view
        #else
        return nil
        #endif
    }
    
    /// Setup remote video to render into a specific view (for SwiftUI embedding)
    #if os(iOS)
    func setupRemoteVideo(for uid: UInt, view: UIView) {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = view
        videoCanvas.renderMode = .hidden
        agoraKit?.setupRemoteVideo(videoCanvas)
        #endif
    }
    #elseif os(macOS)
    func setupRemoteVideo(for uid: UInt, view: NSView) {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = view
        videoCanvas.renderMode = .hidden
        agoraKit?.setupRemoteVideo(videoCanvas)
        #endif
    }
    #endif
    
    /// Check if Agora SDK is available
    var isAvailable: Bool {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        return !appId.isEmpty && appId != "YOUR_AGORA_APP_ID"
        #else
        return false
        #endif
    }
    
    // MARK: - Role Management
    
    /// Promote audience member to broadcaster
    func promoteToPresenter() {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        agoraKit?.setClientRole(.broadcaster)
        currentRole = .broadcaster
        
        // Enable video and audio for new presenter
        agoraKit?.enableLocalVideo(true)
        agoraKit?.enableLocalAudio(true)
        agoraKit?.startPreview()
        
        isVideoEnabled = true
        isAudioEnabled = true
        
        print("✅ [AGORA] Promoted to presenter")
        #endif
    }
    
    /// Demote broadcaster back to audience
    func demoteToAudience() {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        // Disable video and audio
        agoraKit?.enableLocalVideo(false)
        agoraKit?.enableLocalAudio(false)
        agoraKit?.stopPreview()
        
        agoraKit?.setClientRole(.audience)
        currentRole = .audience
        
        isVideoEnabled = false
        isAudioEnabled = false
        
        print("✅ [AGORA] Demoted to audience")
        #endif
    }
    
    /// Re-fetch token and renew in-channel (long sessions; also used when SDK warns before expiry).
    func renewChannelToken() async {
        #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
        guard let channelName, let kit = agoraKit else { return }
        do {
            let newToken = try await fetchTokenFromServer(channelName: channelName, uid: localRtcUid == 0 ? 0 : localRtcUid, role: currentRole)
            let code = kit.renewToken(newToken)
            if code == 0 {
                print("✅ [AGORA] Token renewed")
            } else {
                print("⚠️ [AGORA] renewToken returned \(code)")
            }
        } catch {
            print("❌ [AGORA] Token renew failed: \(error.localizedDescription)")
        }
        #endif
    }
    
    #if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
    @MainActor
    private func applyAdaptiveVideoFromNetwork(tx: AgoraNetworkQuality, rx: AgoraNetworkQuality) {
        guard let kit = agoraKit else { return }
        let isBad = { (q: AgoraNetworkQuality) -> Bool in
            q == .poor || q == .bad || q == .vBad
        }
        let isVeryBad = { (q: AgoraNetworkQuality) -> Bool in
            q == .bad || q == .vBad
        }
        let now = Date()
        guard now.timeIntervalSince(lastAdaptiveVideoChange) > 8 else { return }
        var targetTier = adaptiveVideoTier
        if isVeryBad(tx) || isVeryBad(rx) {
            targetTier = 2
        } else if isBad(tx) || isBad(rx) {
            targetTier = max(adaptiveVideoTier, 1)
        } else if (tx == .good || tx == .excellent) && (rx == .good || rx == .excellent) {
            targetTier = 0
        }
        guard targetTier != adaptiveVideoTier else { return }
        adaptiveVideoTier = targetTier
        lastAdaptiveVideoChange = now
        let size: CGSize
        let fps: Int
        switch targetTier {
        case 2:
            size = CGSize(width: 640, height: 360)
            fps = 15
        case 1:
            size = CGSize(width: 854, height: 480)
            fps = 15
        default:
            size = CGSize(width: 1280, height: 720)
            fps = 30
        }
        let cfg = AgoraVideoEncoderConfiguration(
            size: size,
            frameRate: fps,
            bitrate: AgoraVideoBitrateStandard,
            orientationMode: .adaptative,
            mirrorMode: .auto
        )
        kit.setVideoEncoderConfiguration(cfg)
        print("📶 [AGORA] Adaptive video → \(Int(size.width))×\(Int(size.height)) @ \(fps)fps (tier \(targetTier))")
    }
    #endif
    
    /// Check if user is a broadcaster
    var isBroadcaster: Bool {
        return currentRole == .broadcaster
    }
    
    /// Check if user is audience
    var isAudience: Bool {
        return currentRole == .audience
    }
}

// MARK: - Agora Delegate
#if canImport(AgoraRtcKit) || (os(macOS) && canImport(AgoraRtcKit1))
extension AgoraService: AgoraRtcEngineDelegate {
    /// User joined callback
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        Task { @MainActor in
            if !remoteUsers.contains(uid) {
                remoteUsers.append(uid)
                participantCount = remoteUsers.count + 1 // +1 for local user
                print("✅ [AGORA] User joined: \(uid), total participants: \(participantCount)")
            }
        }
    }
    
    /// User left callback
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        Task { @MainActor in
            remoteUsers.removeAll { $0 == uid }
            participantCount = remoteUsers.count + 1
            if case .remote(let s) = self.spotlightSubject, s == uid {
                self.spotlightSubject = .none
            }
            print("👋 [AGORA] User left: \(uid), total participants: \(participantCount)")
        }
    }
    
    /// Error callback
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        Task { @MainActor in
            if errorCode.rawValue == 110 {
                errorMessage = "Invalid or missing token. Ensure the token server uses the same App ID and certificate as your Agora project."
                print("❌ [AGORA] Error 110 (invalid token): Check token server App ID/certificate and channel name.")
            } else {
                errorMessage = "Agora error: \(errorCode.rawValue)"
            }
            print("❌ [AGORA] Error occurred: \(errorCode.rawValue)")
        }
    }
    
    /// Connection state changed
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        Task { @MainActor in
            switch state {
            case .connected:
                isConnected = true
                print("✅ [AGORA] Connected")
            case .disconnected:
                isConnected = false
                print("❌ [AGORA] Disconnected")
            case .connecting, .reconnecting:
                print("🔄 [AGORA] Connecting...")
            case .failed:
                isConnected = false
                if errorMessage == nil { errorMessage = "Connection failed" }
                print("❌ [AGORA] Connection failed")
            @unknown default:
                break
            }
        }
    }
    
    /// Network quality callback — lower encoder resolution when uplink/downlink is weak.
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        guard uid == 0 else { return }
        Task { @MainActor in
            self.applyAdaptiveVideoFromNetwork(tx: txQuality, rx: rxQuality)
            if txQuality == .poor || rxQuality == .poor {
                print("⚠️ [AGORA] Poor network quality")
            }
        }
    }
    
    /// Active speaker levels for spotlight UI (requires enableAudioVolumeIndication after join).
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        Task { @MainActor in
            guard !speakers.isEmpty else {
                self.spotlightSubject = .none
                return
            }
            var bestUid: UInt = 0
            var bestVol: UInt = 0
            for s in speakers {
                if s.volume > bestVol {
                    bestVol = s.volume
                    bestUid = s.uid
                }
            }
            if bestVol < 8 {
                self.spotlightSubject = .none
                return
            }
            let local = self.localRtcUid
            if bestUid == 0 || (local != 0 && bestUid == local) {
                self.spotlightSubject = .local
            } else if self.remoteUsers.contains(bestUid) {
                self.spotlightSubject = .remote(bestUid)
            } else {
                self.spotlightSubject = .none
            }
        }
    }
    
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        Task { @MainActor in
            print("⚠️ [AGORA] Token will expire soon — renewing…")
            await self.renewChannelToken()
        }
    }
}
#endif

// MARK: - Errors
enum AgoraError: Error {
    case invalidAppId
    case joinChannelFailed
    case sdkNotInstalled
    case tokenExpired
    case channelNotFound
}

extension AgoraError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidAppId:
            return "Invalid Agora App ID. Please configure your App ID in AgoraService.swift"
        case .joinChannelFailed:
            return "Failed to join the video channel"
        case .sdkNotInstalled:
            return "Agora SDK is not installed. Please add it via Swift Package Manager"
        case .tokenExpired:
            return "Authentication token has expired"
        case .channelNotFound:
            return "Video channel not found"
        }
    }
}
