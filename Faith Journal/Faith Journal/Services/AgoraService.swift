//
//  AgoraService.swift
//  Faith Journal
//
//  Agora RTC SDK service for multi-presenter video conferencing
//  Provides professional-grade video/audio streaming
//

import Foundation
import Combine
#if os(iOS)
import AVFoundation
#endif

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
    // To get your App ID:
    // 1. Go to https://console.agora.io/
    // 2. Create a project or select an existing one
    // 3. Copy the App ID from project settings
    // 4. Replace the value below
    // Note: Error 110 means the App ID is invalid, expired, or token is required
    private let appId: String = {
        // Try to get from environment variable first (for CI/CD)
        if let envAppId = ProcessInfo.processInfo.environment["AGORA_APP_ID"], !envAppId.isEmpty {
            return envAppId
        }
        // Default App ID - replace with your valid App ID from Agora Console
        return "89fdd88c9b594cf0947a48a8730e5f62"
    }()
    
    // App Certificate (optional, needed for token generation)
    // Get this from Agora Console → Your Project → Edit → App Certificate
    private let appCertificate: String? = {
        return ProcessInfo.processInfo.environment["AGORA_APP_CERTIFICATE"]
    }()
    
    // Token configuration
    private var useTokenServer: Bool {
        // Always use token server in both Debug and Release builds
        // AgoraTokenService defaults to Vercel production URL for Release
        // For Debug, it uses localhost, but we can override with environment variable
        if let tokenServerURL = ProcessInfo.processInfo.environment["AGORA_TOKEN_SERVER_URL"],
           !tokenServerURL.isEmpty,
           tokenServerURL != "https://your-token-server.com/api/agora/token" {
            return true
        }
        // Default: Use token server (AgoraTokenService will use appropriate URL for Debug/Release)
        #if DEBUG
        // In Debug, token service defaults to localhost, but we can still enable token fetching
        // If you want to use Vercel in Debug, set AGORA_TOKEN_SERVER_URL environment variable
        return true // Enable token server in Debug too (will use localhost by default)
        #else
        // Production: Always use token server (AgoraTokenService defaults to Vercel)
        return true
        #endif
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Generate a temporary token for testing (if App Certificate is available)
    /// For production, use Agora's token server or generate tokens server-side
    private func generateTempToken(channelName: String, uid: UInt = 0) -> String? {
        // Note: Token generation requires server-side implementation for security
        // This is a placeholder - for testing, you can generate tokens at:
        // https://console.agora.io/ → Your Project → Generate Temp Token
        // Or use Agora's token generator tool
        return nil
    }
    
    /// Helper function to fetch token from server (iOS 17.0+)
    /// Note: Requires AgoraTokenService.swift to be included in the Xcode project target
    @available(iOS 17.0, *)
    private func fetchTokenFromServer(channelName: String, role: String) async throws -> String {
        // AgoraTokenService should be accessible from the same module
        // If you get a "Cannot find 'AgoraTokenService' in scope" error,
        // ensure AgoraTokenService.swift is included in your Xcode project target
        let tokenService = AgoraTokenService.shared
        return try await tokenService.fetchToken(
            channelName: channelName,
            uid: 0,
            role: role
        )
    }
    
    /// Join a video conference channel
    func joinChannel(sessionId: UUID, userId: String, userName: String, role: AgoraUserRole = .broadcaster, token: String? = nil, customChannelName: String? = nil) async throws {
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        // Use custom channel name if provided (for breakout rooms), otherwise use default
        self.channelName = customChannelName ?? "faith-journal-\(sessionId.uuidString)"
        self.currentRole = role
        
        #if canImport(AgoraRtcKit)
        guard !appId.isEmpty && appId != "YOUR_AGORA_APP_ID" else {
            errorMessage = "Agora App ID not configured. Please set your App ID in AgoraService.swift"
            throw AgoraError.invalidAppId
        }
        
        // Validate App ID format (should be 32 character hex string)
        guard appId.count == 32, appId.allSatisfy({ $0.isHexDigit }) else {
            errorMessage = "Invalid App ID format. App ID should be a 32-character hexadecimal string."
            print("❌ [AGORA] Invalid App ID format: \(appId)")
            throw AgoraError.invalidAppId
        }
        
        print("📝 [AGORA] Using App ID: \(appId.prefix(8))...")
        print("📝 [AGORA] Channel: \(channelName!)")
        print("📝 [AGORA] User ID: \(userId), Role: \(role)")
        
        // Initialize Agora Engine
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.channelProfile = .liveBroadcasting
        
        // Add area code for better connection (optional but recommended)
        config.areaCode = .global // Use .global for worldwide access
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        // Check if running on simulator
        #if targetEnvironment(simulator)
        let isSimulator = true
        print("⚠️ [AGORA] Running on iOS Simulator - camera/microphone warnings are expected")
        #else
        let isSimulator = false
        #endif
        
        // Set log level for debugging (optional)
        if let logPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("agora.log").path {
            agoraKit?.setLogFile(logPath)
        }
        agoraKit?.setLogFilter(AgoraLogFilter.info.rawValue)
        
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
        let videoConfig = AgoraVideoEncoderConfiguration()
        videoConfig.dimensions = CGSize(width: 1280, height: 720)
        // Agora SDK versions differ: `frameRate` may be an `Int` on some builds.
        // Use a safe numeric fps value for compatibility.
        videoConfig.frameRate = 30
        videoConfig.bitrate = AgoraVideoBitrateStandard
        videoConfig.orientationMode = .adaptative
        videoConfig.mirrorMode = .auto
        agoraKit?.setVideoEncoderConfiguration(videoConfig)
        
        // Fetch token if needed
        var tokenToUse: String? = token
        
        // If no token provided, try fetching from token server (if configured)
        if tokenToUse == nil && self.useTokenServer {
            if #available(iOS 17.0, *) {
                let roleString = role == .broadcaster ? "publisher" : "subscriber"
                print("📡 [AGORA] Fetching token from server...")
                do {
                    tokenToUse = try await self.fetchTokenFromServer(
                        channelName: channelName!,
                        role: roleString
                    )
                    print("✅ [AGORA] Token fetched successfully from server")
                } catch {
                    print("⚠️ [AGORA] Failed to fetch token from server: \(error.localizedDescription)")
                    print("⚠️ [AGORA] Attempting to join without token (may fail if tokens are required)")
                    // Continue without token - will fail with error 110 if tokens are required
                }
            }
        }
        
        if tokenToUse == nil {
            print("📝 [AGORA] Joining with App ID only (no token)")
            if self.useTokenServer {
                print("⚠️ [AGORA] Token server is configured but token fetch failed or returned nil")
            } else {
                print("📝 [AGORA] Token server not configured - using App ID only")
                print("📝 [AGORA] If you get error 110, configure AGORA_TOKEN_SERVER_URL environment variable")
            }
        } else {
            print("📝 [AGORA] Joining with token (length: \(tokenToUse!.count) chars)")
        }
        
        let result = agoraKit?.joinChannel(
            byToken: tokenToUse,
            channelId: channelName!,
            info: nil,
            uid: 0
        ) { [weak self] channel, uid, elapsed in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = true
                print("✅ [AGORA] Successfully joined channel: \(channel) with UID: \(uid)")
            }
        }
        
        if let errorCode = result, errorCode != 0 {
            var errorMsg = "Failed to join channel (error code: \(errorCode))"
            
            // Provide specific guidance for error 110
            if errorCode == 110 {
                if tokenToUse == nil {
                    errorMsg = "Invalid App ID or token required. Your Agora project may require tokens. Please generate a token in Agora Console or verify your App ID is correct."
                } else {
                    errorMsg = "Invalid or expired token. Please generate a new token in Agora Console."
                }
            }
            
            errorMessage = errorMsg
            print("❌ [AGORA] \(errorMsg)")
            print("""
            ⚠️ [AGORA] Join channel failed with code: \(errorCode)
            
            Common error codes:
            - 110: Invalid App ID or Invalid/Expired Token
            - 101: Invalid channel name
            - 102: Invalid token (when token is provided)
            - 17: Join channel rejected
            
            Troubleshooting for Error 110:
            1. If using App ID only (no token):
               - Verify App ID is correct: \(appId.prefix(8))...
               - Check if your project requires tokens (some projects do)
               - Go to Agora Console → Your Project → Edit → Check "Enable Token" setting
            
            2. If token is required:
               - Go to Agora Console → Your Project → Generate Temp Token
               - Or set up a token server for production
               - Pass the token when calling joinChannel()
            
            3. General checks:
               - Ensure App ID is active in Agora Console: https://console.agora.io/
               - Check project has video/audio features enabled
               - Verify network connectivity
            """)
            throw AgoraError.joinChannelFailed
        }
        
        print("✅ [AGORA] Join channel request sent for: \(channelName!)")
        #else
        errorMessage = "Agora SDK not installed"
        throw AgoraError.sdkNotInstalled
        #endif
    }
    
    /// Leave the conference (deactivate audio first and delay destroy to avoid AVFAudio _auv3 != nil crash)
    func leaveChannel() {
        #if canImport(AgoraRtcKit)
        guard let kit = agoraKit else {
            channelName = nil
            return
        }
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
                print("✅ [AGORA] Left channel")
            }
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
        #if canImport(AgoraRtcKit)
        if isVideoEnabled {
            agoraKit?.enableLocalVideo(true)
            // Re-setup local video canvas to ensure it's properly displayed
            // Note: The actual view will be provided by AgoraVideoView in SwiftUI
            agoraKit?.startPreview()
            print("📹 [AGORA] Video enabled - preview started")
        } else {
            agoraKit?.enableLocalVideo(false)
            agoraKit?.stopPreview()
            print("📹 [AGORA] Video disabled - preview stopped")
        }
        print("📹 [AGORA] Video toggled: \(isVideoEnabled ? "ON" : "OFF")")
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
    
    /// Setup local video view
    func setupLocalVideo(view: UIView) {
        #if canImport(AgoraRtcKit)
        // Check if running on simulator
        #if targetEnvironment(simulator)
        print("⚠️ [AGORA] Running on simulator - camera/microphone warnings are expected and can be ignored")
        #endif
        
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.view = view
        videoCanvas.renderMode = .hidden
        
        // Setup video (may show warnings on simulator but will still work for audio)
        agoraKit?.setupLocalVideo(videoCanvas)
        agoraKit?.startPreview()
        print("✅ [AGORA] Local video setup with view")
        #endif
    }
    
    /// Setup remote video view for a user
    func setupRemoteVideo(for uid: UInt, view: UIView) {
        #if canImport(AgoraRtcKit)
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = view
        videoCanvas.renderMode = .hidden
        agoraKit?.setupRemoteVideo(videoCanvas)
        print("✅ [AGORA] Remote video setup for UID \(uid) with view")
        #endif
    }
    
    /// Get local video view (legacy method - kept for compatibility)
    func setupLocalVideo() -> Any? {
        #if canImport(AgoraRtcKit)
        let view = UIView()
        setupLocalVideo(view: view)
        return view
        #else
        return nil
        #endif
    }
    
    /// Setup remote video view for a user (legacy method - kept for compatibility)
    func setupRemoteVideo(for uid: UInt) -> Any? {
        #if canImport(AgoraRtcKit)
        let view = UIView()
        setupRemoteVideo(for: uid, view: view)
        return view
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
            let errorDescription: String
            switch errorCode {
            case .invalidAppId:
                // Error 110 can mean either invalid App ID OR invalid token
                // Check if we're using a token to determine the actual issue
                if channelName != nil {
                    errorDescription = "Invalid App ID or token required (110). Your project may require tokens. Check Agora Console settings."
                } else {
                    errorDescription = "Invalid App ID (110). Please verify your Agora App ID is correct and active in the Agora Console."
                }
            case .invalidChannelId:
                errorDescription = "Invalid channel name"
            case .invalidToken:
                errorDescription = "Invalid or expired token. Please generate a new token in Agora Console."
            case .joinChannelRejected:
                errorDescription = "Join channel rejected"
            case .leaveChannelRejected:
                errorDescription = "Leave channel rejected"
            default:
                errorDescription = "Agora error: \(errorCode.rawValue)"
            }
            
            errorMessage = errorDescription
            print("❌ [AGORA] Error occurred: \(errorCode.rawValue) - \(errorDescription)")
            
            // For error 110, provide helpful instructions
            if errorCode == .invalidAppId {
                print("""
                ⚠️ [AGORA] Error 110 - Invalid App ID or Token Required
                
                This error can mean:
                1. Invalid App ID - The App ID is incorrect or expired
                2. Token Required - Your project requires tokens (not just App ID)
                
                To fix:
                
                Option A: If your project allows App ID only:
                - Go to https://console.agora.io/
                - Select your project
                - Edit project settings
                - Ensure "Enable Token" is DISABLED
                - Verify App ID: \(appId.prefix(8))...
                
                Option B: If tokens are required:
                - Configure AGORA_TOKEN_SERVER_URL environment variable
                - Or set up a token server and update AgoraTokenService.swift
                - The app will automatically fetch tokens from the server
                
                Current App ID: \(appId)
                """)
            }
        }
    }
    
    /// Token will expire soon - renew it
    nonisolated func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            print("⚠️ [AGORA] Token will expire soon, renewing...")
            
            guard let channelName = self.channelName else {
                print("❌ [AGORA] Cannot renew token: channel name not available")
                return
            }
            
            // Fetch new token from server
            if self.useTokenServer {
                if #available(iOS 17.0, *) {
                    let roleString = self.currentRole == .broadcaster ? "publisher" : "subscriber"
                    do {
                        let newToken = try await self.fetchTokenFromServer(
                            channelName: channelName,
                            role: roleString
                        )
                        
                        // Renew token in Agora engine
                        let result = self.agoraKit?.renewToken(newToken)
                        if let errorCode = result, errorCode != 0 {
                            print("❌ [AGORA] Failed to renew token: error code \(errorCode)")
                            self.errorMessage = "Failed to renew token. Please reconnect."
                        } else {
                            print("✅ [AGORA] Token renewed successfully")
                        }
                    } catch {
                        print("❌ [AGORA] Failed to fetch new token: \(error.localizedDescription)")
                        self.errorMessage = "Failed to renew token. Connection may be lost soon."
                    }
                }
            } else {
                print("⚠️ [AGORA] Token server not configured - cannot auto-renew token")
                self.errorMessage = "Token expired. Please reconnect."
            }
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
