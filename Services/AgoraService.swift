//
//  AgoraService.swift
//  Faith Journal
//
//  Agora RTC SDK service for multi-presenter video conferencing
//  Provides professional-grade video/audio streaming
//

import Foundation
import Combine

#if canImport(AgoraRtcKit)
import AgoraRtcKit
#endif

/// User role in the session
enum AgoraUserRole {
    case broadcaster // Can present with video/audio
    case audience    // Watch/listen only
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
    
    // MARK: - Private Properties
    #if canImport(AgoraRtcKit)
    private var agoraKit: AgoraRtcEngineKit?
    #endif
    
    private var sessionId: UUID?
    private var userId: String?
    private var userName: String?
    private var channelName: String?
    
    // Agora credentials - configured with your App ID
    private let appId = "89fdd88c9b594cf0947a48a8730e5f62"
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Join a video conference channel
    func joinChannel(sessionId: UUID, userId: String, userName: String, role: AgoraUserRole = .broadcaster, token: String? = nil) async throws {
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        self.channelName = "faith-journal-\(sessionId.uuidString)"
        self.currentRole = role
        
        #if canImport(AgoraRtcKit)
        guard !appId.isEmpty && appId != "YOUR_AGORA_APP_ID" else {
            errorMessage = "Agora App ID not configured"
            throw AgoraError.invalidAppId
        }
        
        // Initialize Agora Engine
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.channelProfile = .liveBroadcasting
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
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
        
        // Set video configuration
        let videoConfig = AgoraVideoEncoderConfiguration(
            size: CGSize(width: 1280, height: 720),
            frameRate: .fps30,
            bitrate: AgoraVideoBitrateStandard,
            orientationMode: .adaptative,
            mirrorMode: .auto
        )
        agoraKit?.setVideoEncoderConfiguration(videoConfig)
        
        // Join channel
        let result = agoraKit?.joinChannel(
            byToken: token,
            channelId: channelName!,
            info: nil,
            uid: 0
        ) { [weak self] channel, uid, elapsed in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = true
                print("✅ [AGORA] Joined channel: \(channel) with UID: \(uid)")
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
    
    /// Leave the conference
    func leaveChannel() {
        #if canImport(AgoraRtcKit)
        agoraKit?.leaveChannel { [weak self] stats in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = false
                self.remoteUsers.removeAll()
                self.participantCount = 0
                print("✅ [AGORA] Left channel")
            }
        }
        
        agoraKit?.stopPreview()
        AgoraRtcEngineKit.destroy()
        agoraKit = nil
        #endif
        
        channelName = nil
    }
    
    /// Toggle local video
    func toggleVideo() {
        isVideoEnabled.toggle()
        #if canImport(AgoraRtcKit)
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
        #if canImport(AgoraRtcKit)
        agoraKit?.muteLocalAudioStream(!isAudioEnabled)
        print("🎤 [AGORA] Audio \(isAudioEnabled ? "enabled" : "disabled")")
        #endif
    }
    
    /// Switch camera (front/back)
    func switchCamera() {
        #if canImport(AgoraRtcKit)
        agoraKit?.switchCamera()
        print("📷 [AGORA] Camera switched")
        #endif
    }
    
    /// Get local video view
    func setupLocalVideo() -> Any? {
        #if canImport(AgoraRtcKit)
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
    
    /// Setup remote video view for a user
    func setupRemoteVideo(for uid: UInt) -> Any? {
        #if canImport(AgoraRtcKit)
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.renderMode = .hidden
        agoraKit?.setupRemoteVideo(videoCanvas)
        return videoCanvas.view
        #else
        return nil
        #endif
    }
    
    /// Check if Agora SDK is available
    var isAvailable: Bool {
        #if canImport(AgoraRtcKit)
        return !appId.isEmpty && appId != "YOUR_AGORA_APP_ID"
        #else
        return false
        #endif
    }
    
    // MARK: - Role Management
    
    /// Promote audience member to broadcaster
    func promoteToPresenter() {
        #if canImport(AgoraRtcKit)
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
        #if canImport(AgoraRtcKit)
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
#if canImport(AgoraRtcKit)
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
            print("👋 [AGORA] User left: \(uid), total participants: \(participantCount)")
        }
    }
    
    /// Error callback
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        Task { @MainActor in
            errorMessage = "Agora error: \(errorCode.rawValue)"
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
                errorMessage = "Connection failed"
                print("❌ [AGORA] Connection failed")
            @unknown default:
                break
            }
        }
    }
    
    /// Network quality callback
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        // Can be used to show network quality indicators
        if uid == 0 { // Local user
            if txQuality == .poor || rxQuality == .poor {
                Task { @MainActor in
                    print("⚠️ [AGORA] Poor network quality")
                }
            }
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
