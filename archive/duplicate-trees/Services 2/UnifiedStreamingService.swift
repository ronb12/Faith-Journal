//
//  UnifiedStreamingService.swift
//  Faith Journal
//
//  Unified interface for streaming services
//  Automatically selects HLS for broadcast mode and Jitsi for conference mode
//

import Foundation
import Combine

@MainActor
@available(iOS 17.0, *)
class UnifiedStreamingService: ObservableObject {
    static let shared = UnifiedStreamingService()
    
    // MARK: - Services
    private let hlsService = HLSStreamingService.shared
    private let jitsiService = JitsiService.shared
    
    // MARK: - Published Properties (delegated to appropriate service)
    @Published var isStreaming = false
    @Published var isConnected = false
    @Published var errorMessage: String?
    @Published var viewerCount = 0
    @Published var participantCount = 0
    @Published var isVideoEnabled = true
    @Published var isAudioEnabled = true
    
    private var currentMode: StreamingMode?
    
    enum StreamingMode {
        case broadcast // HLS
        case conference // Jitsi
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Start streaming based on mode
    func startStream(sessionId: UUID, userId: String, userName: String, isBroadcastMode: Bool) async throws {
        // Use HLS for both broadcast and conference modes (native iOS, no WebRTC required)
        currentMode = isBroadcastMode ? .broadcast : .conference
        try await hlsService.startBroadcast(sessionId: sessionId, userId: userId)
        // Update properties immediately after starting
        await MainActor.run {
            isStreaming = hlsService.isStreaming
            isConnected = hlsService.isConnected
            errorMessage = hlsService.errorMessage
            viewerCount = hlsService.viewerCount
            isVideoEnabled = hlsService.isVideoEnabled
            isAudioEnabled = hlsService.isAudioEnabled
        }
    }
    
    /// Join as viewer (broadcast mode only)
    func joinAsViewer(streamURL: URL) async {
        currentMode = .broadcast
        await hlsService.joinAsViewer(streamURL: streamURL)
        await updatePublishedProperties()
    }
    
    /// Stop/Leave stream
    func stopStream() {
        // Both modes use HLS service
        hlsService.stopBroadcast()
        currentMode = nil
        resetProperties()
    }
    
    /// Toggle video
    func toggleVideo() {
        // Call the actual toggle method on HLS service
        hlsService.toggleVideo()
        isVideoEnabled = hlsService.isVideoEnabled
    }
    
    /// Toggle audio
    func toggleAudio() {
        // Call the actual toggle method on HLS service
        hlsService.toggleAudio()
        isAudioEnabled = hlsService.isAudioEnabled
    }
    
    /// Get preview/view for display
    func getVideoView() -> Any? {
        switch currentMode {
        case .broadcast, .conference:
            // Both broadcast and conference use HLS service
            return hlsService.getPreviewLayer()
        case .none:
            return nil
        }
    }
    
    /// Update viewer count (broadcast mode only)
    func updateViewerCount(_ count: Int) {
        hlsService.updateViewerCount(count)
        viewerCount = count
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe HLS service (used for both broadcast and conference modes)
        hlsService.$isStreaming
            .assign(to: &$isStreaming)
        
        hlsService.$isConnected
            .assign(to: &$isConnected)
        
        hlsService.$errorMessage
            .assign(to: &$errorMessage)
        
        hlsService.$viewerCount
            .assign(to: &$viewerCount)
        
        hlsService.$isVideoEnabled
            .assign(to: &$isVideoEnabled)
        
        hlsService.$isAudioEnabled
            .assign(to: &$isAudioEnabled)
        
        // Note: Jitsi service observers removed since we use HLS for both broadcast and conference
        // If Jitsi is needed in the future, add conditional observers based on currentMode
    }
    
    private func updatePublishedProperties() async {
        switch currentMode {
        case .broadcast:
            isStreaming = hlsService.isStreaming
            isConnected = hlsService.isConnected
            errorMessage = hlsService.errorMessage
            viewerCount = hlsService.viewerCount
            isVideoEnabled = hlsService.isVideoEnabled
            isAudioEnabled = hlsService.isAudioEnabled
        case .conference:
            // Conference mode also uses HLS service
            isStreaming = hlsService.isStreaming
            isConnected = hlsService.isConnected
            errorMessage = hlsService.errorMessage
            participantCount = 0 // HLS doesn't track participant count separately
            isVideoEnabled = hlsService.isVideoEnabled
            isAudioEnabled = hlsService.isAudioEnabled
        case .none:
            break
        }
    }
    
    private func resetProperties() {
        isStreaming = false
        isConnected = false
        errorMessage = nil
        viewerCount = 0
        participantCount = 0
        isVideoEnabled = true
        isAudioEnabled = true
    }
}

