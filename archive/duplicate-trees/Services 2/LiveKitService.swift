//
//  LiveKitService.swift
//  Faith Journal
//
//  LiveKit WebRTC integration for cross-location streaming
//  Handles both single and multi-presenter modes
//

import Foundation
import AVFoundation
import Combine

// LiveKit will be added via SPM - for now, we'll create a wrapper
// that can be integrated once the SDK is available

@available(iOS 17.0, *)
@MainActor
class LiveKitService: NSObject, ObservableObject {
    static let shared = LiveKitService()
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var isPublishing = false
    @Published var isSubscribing = false
    @Published var remoteParticipants: [RemoteParticipant] = []
    @Published var errorMessage: String?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var viewerCount = 0
    @Published var activePresenters: [RemoteParticipant] = [] // Only video-enabled participants
    @Published var presentationMode: PresentationMode = .singlePresenter
    
    // MARK: - Private Properties
    private var room: LiveKitService.LiveKitRoom?
    private var localParticipant: LiveKitService.LocalParticipant?
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    enum PresentationMode {
        case singlePresenter  // One main presenter
        case multiPresenter   // Multiple presenters in grid
    }
    
    struct RemoteParticipant {
        let id: String
        let name: String
        let displayName: String
        let isAudioEnabled: Bool
        let isVideoEnabled: Bool
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration
    
    /// Set presentation mode (single vs multi-presenter)
    func setPresentationMode(_ mode: PresentationMode) {
        presentationMode = mode
    }
    
    // MARK: - Connection Management
    
    /// Connect to LiveKit server and join room as publisher (host/presenter)
    func connectAsHost(roomName: String, userName: String) async throws {
        connectionState = .connecting
        
        let serverURL = "http://localhost:7880"
        
        guard !serverURL.isEmpty else {
            let error = "Invalid server URL: \(serverURL)"
            errorMessage = error
            connectionState = .error(error)
            throw LiveKitError.invalidServerURL
        }
        
        // Initialize room connection
        // NOTE: LiveKit SDK needs to be added via SPM
        // GitHub: https://github.com/livekit/client-sdk-swift
        // Once added, uncomment below:
        /*
        let room = try await LiveKit.Room()
        
        // Connect to server
        try await room.connect(
            url: serverURL,
            token: generateToken(roomName: roomName, userName: userName, isPublisher: true)
        )
        
        self.room = room
        self.localParticipant = room.localParticipant
        
        // Setup local tracks
        try await publishLocalTracks()
        
        self.isPublishing = true
        self.isConnected = true
        self.connectionState = .connected
        self.errorMessage = nil
        */
        
        // Temporary: Log that we're ready to connect
        print("🎬 Ready to connect as host to \(serverURL) in room '\(roomName)'")
        isPublishing = true
        isConnected = true
        connectionState = .connected
    }
    
    /// Connect to LiveKit server as viewer (subscriber only)
    func connectAsViewer(roomName: String, userName: String) async throws {
        connectionState = .connecting
        
        let serverURL = "http://localhost:7880"
        
        guard !serverURL.isEmpty else {
            let error = "Invalid server URL: \(serverURL)"
            errorMessage = error
            connectionState = .error(error)
            throw LiveKitError.invalidServerURL
        }
        
        // Connect as viewer (receive only)
        // NOTE: LiveKit SDK needs to be added via SPM
        /*
        let room = try await LiveKit.Room()
        
        try await room.connect(
            url: serverURL,
            token: generateToken(roomName: roomName, userName: userName, isPublisher: false)
        )
        
        self.room = room
        self.isSubscribing = true
        self.isConnected = true
        self.connectionState = .connected
        self.errorMessage = nil
        
        // Listen for new participants
        setupParticipantListeners()
        */
        
        print("👁️ Ready to connect as viewer to \(serverURL) in room '\(roomName)'")
        isSubscribing = true
        isConnected = true
        connectionState = .connected
    }
    
    /// Disconnect from room
    func disconnect() async {
        if room != nil {
            // try await room?.disconnect()
            self.room = nil
        }
        isConnected = false
        isPublishing = false
        isSubscribing = false
        connectionState = .disconnected
        remoteParticipants = []
        viewerCount = 0
        errorMessage = nil
    }
    
    // MARK: - Publishing (Host)
    
    /// Publish local camera and microphone tracks
    private func publishLocalTracks() async throws {
        // Request permissions
        let cameraGranted = await requestCameraPermission()
        let micGranted = await requestMicrophonePermission()
        
        guard cameraGranted else {
            throw LiveKitError.permissionDenied("Camera")
        }
        
        guard micGranted else {
            throw LiveKitError.permissionDenied("Microphone")
        }
        
        // NOTE: Once LiveKit SDK is added:
        /*
        if let localParticipant = localParticipant {
            // Publish camera
            let videoTrack = try await LocalVideoTrack.createCameraTrack(
                options: VideoCodecOptions(maxBitrate: 2500000) // 2.5 Mbps for 720p
            )
            try await localParticipant.publishVideoTrack(videoTrack)
            
            // Publish microphone
            let audioTrack = try await LocalAudioTrack.createMicrophoneTrack()
            try await localParticipant.publishAudioTrack(audioTrack)
        }
        */
    }
    
    /// Stop publishing camera track
    func stopPublishingCamera() async {
        // try await localParticipant?.unpublishVideoTracks()
        isPublishing = false
    }
    
    /// Stop publishing microphone track
    func stopPublishingAudio() async {
        // try await localParticipant?.unpublishAudioTracks()
    }
    
    // MARK: - Subscription (Viewer)
    
    /// Setup listeners for remote participant changes
    private func setupParticipantListeners() {
        // Listen for participant joined/left events
        // room?.participantJoined
        //    .sink { [weak self] participant in
        //        self?.handleRemoteParticipantJoined(participant)
        //    }
        //    .store(in: &cancellables)
    }
    
    private func handleRemoteParticipantJoined(_ participant: RemoteParticipant) {
        // Add participant to list and update counts
        viewerCount += 1
        
        // Update presenter list if they have video enabled
        if participant.isVideoEnabled {
            activePresenters.append(participant)
        }
    }
    
    private func handleRemoteParticipantLeft(_ participant: RemoteParticipant) {
        // Remove participant from list and update counts
        viewerCount = max(0, viewerCount - 1)
        activePresenters.removeAll { $0.id == participant.id }
    }
    
    // MARK: - Multi-Presenter Support
    
    /// Get grid layout dimensions for multi-presenter view
    func getGridLayout() -> (cols: Int, rows: Int) {
        let count = activePresenters.count
        
        switch count {
        case 0, 1: return (1, 1)
        case 2: return (2, 1)
        case 3, 4: return (2, 2)
        case 5, 6: return (3, 2)
        case 7, 8, 9: return (3, 3)
        default: return (4, 3)
        }
    }
    
    /// Get visible presenters based on presentation mode
    func getVisiblePresenters() -> [RemoteParticipant] {
        switch presentationMode {
        case .singlePresenter:
            return activePresenters.prefix(1).map { $0 }
        case .multiPresenter:
            return activePresenters
        }
    }
    
    // MARK: - Permissions
    
    private func requestCameraPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Token Generation
    
    /// Generate JWT token for LiveKit room access
    private func generateToken(roomName: String, userName: String, isPublisher: Bool) -> String {
        // NOTE: In production, get this from your backend server
        return "your-jwt-token-here"
    }
    
    // MARK: - Utility
    
    func getConnectionStatus() -> String {
        switch connectionState {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
}

// MARK: - Error Types

enum LiveKitError: LocalizedError {
    case invalidServerURL
    case permissionDenied(String)
    case connectionFailed(String)
    case tokenGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Invalid LiveKit server URL format"
        case .permissionDenied(let resource):
            return "Permission denied for \(resource)"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .tokenGenerationFailed:
            return "Failed to generate room access token"
        }
    }
}

// MARK: - Placeholder Types (to be replaced by LiveKit SDK)
// These are namespaced within LiveKitService to avoid conflicts with any imported LiveKit SDK

extension LiveKitService {
    struct LiveKitRoom {}
    struct LocalParticipant {}
    struct RemoteParticipantInfo {}
}
