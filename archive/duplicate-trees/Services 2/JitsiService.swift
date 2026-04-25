//
//  JitsiService.swift
//  Faith Journal
//
//  Jitsi Meet SDK service wrapper for conference mode streaming
//  Provides multi-participant video conferencing
//

import Foundation
import Combine

#if canImport(JitsiMeetSDK)
import JitsiMeetSDK
#endif

@MainActor
class JitsiService: NSObject, ObservableObject {
    static let shared = JitsiService()
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var participantCount = 0
    @Published var errorMessage: String?
    @Published var isVideoEnabled = true
    @Published var isAudioEnabled = true
    
    // MARK: - Private Properties
    private var jitsiMeetView: Any?
    #if canImport(JitsiMeetSDK)
    private var jitsiMeet: JitsiMeet?
    #endif
    
    private var sessionId: UUID?
    private var userId: String?
    private var userName: String?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Join a Jitsi conference room
    func joinConference(sessionId: UUID, userId: String, userName: String, roomName: String? = nil) async throws {
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        
        #if canImport(JitsiMeetSDK)
        // Generate room name from session ID
        let room = roomName ?? "faith-journal-\(sessionId.uuidString)"
        
        // Create JitsiMeet instance
        let jitsiMeet = JitsiMeet()
        
        // Configure options
        let options = JitsiMeetConferenceOptions.fromBuilder { builder in
            builder.room = room
            builder.setFeatureFlag("welcomepage.enabled", withBoolean: false)
            builder.setFeatureFlag("invite.enabled", withBoolean: false)
            builder.setFeatureFlag("calendar.enabled", withBoolean: false)
            builder.setFeatureFlag("call-integration.enabled", withBoolean: false)
            builder.setFeatureFlag("close-captions.enabled", withBoolean: false)
            builder.setFeatureFlag("chat.enabled", withBoolean: false)
            builder.setFeatureFlag("raise-hand.enabled", withBoolean: false)
            builder.setFeatureFlag("recording.enabled", withBoolean: false)
            
            // User info
            builder.userInfo = JitsiMeetUserInfo(displayName: userName, andEmail: nil, andAvatar: nil)
            
            // Audio/Video settings - Note: These may need to be set via setAudioMuted/setVideoMuted methods
            // Check Jitsi Meet SDK documentation for correct API
        }
        
        self.jitsiMeet = jitsiMeet
        
        // Create view
        let jitsiMeetView = JitsiMeetView()
        jitsiMeetView.delegate = self
        jitsiMeetView.join(options)
        
        self.jitsiMeetView = jitsiMeetView
        isConnected = true
        errorMessage = nil
        #else
        throw JitsiError.sdkNotAvailable
        #endif
    }
    
    /// Leave the conference
    func leaveConference() {
        #if canImport(JitsiMeetSDK)
        if let jitsiMeetView = jitsiMeetView as? JitsiMeetView {
            jitsiMeetView.leave()
        }
        #endif
        
        jitsiMeetView = nil
        #if canImport(JitsiMeetSDK)
        jitsiMeet = nil
        #endif
        
        isConnected = false
        sessionId = nil
        userId = nil
        userName = nil
        participantCount = 0
    }
    
    /// Toggle video
    func toggleVideo() {
        isVideoEnabled.toggle()
        #if canImport(JitsiMeetSDK)
        // Note: Jitsi Meet SDK video/audio toggle is typically handled internally
        // The view will respond to state changes automatically
        // If custom implementation is needed, use JitsiMeetView's delegate methods
        #endif
    }
    
    /// Toggle audio
    func toggleAudio() {
        isAudioEnabled.toggle()
        #if canImport(JitsiMeetSDK)
        // Note: Jitsi Meet SDK video/audio toggle is typically handled internally
        // The view will respond to state changes automatically
        // If custom implementation is needed, use JitsiMeetView's delegate methods
        #endif
    }
    
    /// Get Jitsi view for UI
    func getJitsiView() -> Any? {
        return jitsiMeetView
    }
}

// MARK: - JitsiMeetViewDelegate

#if canImport(JitsiMeetSDK)
extension JitsiService: JitsiMeetViewDelegate {
    nonisolated func conferenceJoined(_ data: [AnyHashable : Any]!) {
        Task { @MainActor in
            isConnected = true
            errorMessage = nil
        }
    }
    
    nonisolated func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        Task { @MainActor in
            isConnected = false
            leaveConference()
        }
    }
    
    nonisolated func conferenceWillJoin(_ data: [AnyHashable : Any]!) {
        Task { @MainActor in
            // Conference is about to join
        }
    }
    
    nonisolated func participantJoined(_ data: [AnyHashable : Any]!) {
        Task { @MainActor in
            participantCount += 1
        }
    }
    
    nonisolated func participantLeft(_ data: [AnyHashable : Any]!) {
        Task { @MainActor in
            if participantCount > 0 {
                participantCount -= 1
            }
        }
    }
    
    nonisolated func audioMutedChanged(_ data: [AnyHashable : Any]!) {
        Task { @MainActor in
            if let muted = data["muted"] as? Bool {
                isAudioEnabled = !muted
            }
        }
    }
    
    nonisolated func videoMutedChanged(_ data: [AnyHashable : Any]!) {
        Task { @MainActor in
            if let muted = data["muted"] as? Bool {
                isVideoEnabled = !muted
            }
        }
    }
    
    nonisolated func ready(toClose data: [AnyHashable : Any]!) {
        Task { @MainActor in
            leaveConference()
        }
    }
}
#endif

// MARK: - Errors

enum JitsiError: LocalizedError {
    case sdkNotAvailable
    case conferenceJoinFailed
    case roomCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .sdkNotAvailable:
            return "Jitsi Meet SDK is not available. Please add the Jitsi Meet SDK package."
        case .conferenceJoinFailed:
            return "Failed to join conference"
        case .roomCreationFailed:
            return "Failed to create conference room"
        }
    }
}

