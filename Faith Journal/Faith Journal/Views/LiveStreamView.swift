//
//  LiveStreamView.swift
//  Faith Journal
//
//  Live video/audio streaming view
//

import SwiftUI
import SwiftData
import AVFoundation

#if canImport(WebRTC)
import WebRTC
#endif

@available(iOS 17.0, *)
struct LiveStreamView: View {
    let session: LiveSession?
    // Observe UnifiedStreamingService to get real-time updates for video/audio state
    @ObservedObject private var streamingService = UnifiedStreamingService.shared
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    @Environment(\.dismiss) private var dismiss
    @Query var userProfiles: [UserProfile]
    private var userProfile: UserProfile? { userProfiles.first }

    @State private var isStreaming = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var remoteVideoView: AnyView?
    @State private var localVideoView: AnyView?
    @State private var participants: [ParticipantInfo] = []
    @State private var spotlightedParticipant: String?
    @State private var showingParticipantGrid = false
    @State private var showingWhiteboard = false
    @State private var showingBreakoutRooms = false
    @State private var showingWaitingRoom = false
    @State private var isHost = false
    
    struct ParticipantInfo: Identifiable {
        let id: String
        let name: String
        let isMuted: Bool
        let isVideoEnabled: Bool
        let isSpeaking: Bool
    }

    var body: some View {
        if #available(iOS 17.0, *), session != nil {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Remote video (main view)
                    remoteVideoArea
                    // Local video (picture-in-picture)
                    localVideoPIP
                    // Controls
                    controlsSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        leaveStream()
                    }
                }
            }
            .onAppear {
                startStreaming()
            }
            .onDisappear {
                leaveStream()
            }
            .onChange(of: streamingService.isVideoEnabled) { _, newValue in
                // Update local video view when video is toggled
                if newValue {
                    Task {
                        await setupLocalVideoView()
                    }
                } else {
                    localVideoView = nil
                }
            }
            .onChange(of: HLSStreamingService.shared.previewLayer) { _, newValue in
                // Refresh camera preview when it becomes available
                if newValue != nil && isStreaming {
                    Task {
                        await setupLocalVideoView()
                    }
                }
            }
            .onChange(of: streamingService.isConnected) { _, newValue in
                // When connected, ensure camera preview is set up
                if newValue && isStreaming {
                    Task {
                        await setupLocalVideoView()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: streamingService.errorMessage) { _, newValue in
                if let error = newValue {
                    errorMessage = error
                    showingError = true
                }
            }
        } else {
            Text("Live streaming is only available on iOS 17+")
        }
    }
    
    // MARK: - View Components
    
    private var remoteVideoArea: some View {
        ZStack {
            // Use native AVFoundation-based streaming (HLS) which doesn't require WebRTC
            // For host, show local camera preview in main area
            if isHost, let previewLayer = HLSStreamingService.shared.getPreviewLayer() {
                VideoPreviewLayerView(previewLayer: previewLayer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let hlsService = HLSStreamingService.shared.getPreviewLayer() {
                VideoPreviewLayerView(previewLayer: hlsService)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let remoteView = remoteVideoView {
                AnyView(remoteView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.black
                    .overlay(
                        VStack {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Waiting for participants...")
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top)
                            if !streamingService.isConnected {
                                Text("Connecting to stream...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 4)
                            }
                        }
                    )
            }
            
            // Connection status overlay
            connectionStatusOverlay
        }
    }
    
    private var connectionStatusOverlay: some View {
        VStack {
            HStack {
                ConnectionStatusView(state: getConnectionStatus())
                Spacer()
            }
            .padding()
            Spacer()
        }
    }
    
    private func getConnectionStatus() -> String {
        if streamingService.isConnected {
            return "Connected"
        } else if isStreaming {
            return "Connecting..."
        } else if let error = streamingService.errorMessage {
            return error
        } else {
            return "Disconnected"
        }
    }
    
    @ViewBuilder
    private var localVideoPIP: some View {
        // Show local video preview using HLS service
        // For participants, show local camera in PIP; for host, show remote participants
        if !isHost, let previewLayer = HLSStreamingService.shared.getPreviewLayer() {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VideoPreviewLayerView(previewLayer: previewLayer)
                        .frame(width: 120, height: 160)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .padding()
                }
            }
        } else if let localView = localVideoView {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    AnyView(localView)
                        .frame(width: 120, height: 160)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .padding()
                }
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Participant list (if multiple participants)
            if participants.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(participants) { participant in
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.purple.opacity(0.3))
                                                    .frame(width: 60, height: 60)
                                                
                                                Image(systemName: "person.fill")
                                                    .font(.title2)
                                                    .foregroundColor(.purple)
                                                
                                                if participant.isMuted {
                                                    VStack {
                                                        HStack {
                                                            Image(systemName: "mic.slash.fill")
                                                                .font(.caption2)
                                                                .foregroundColor(.red)
                                                                .padding(4)
                                                                .background(Color.black.opacity(0.7))
                                                                .clipShape(Circle())
                                                            Spacer()
                                                        }
                                                        Spacer()
                                                    }
                                                    .padding(4)
                                                }
                                            }
                                            
                                            Text(participant.name)
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            
                                            if participant.isSpeaking {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 6, height: 6)
                                            }
                                        }
                                        .frame(width: 70)
                                        .padding(8)
                                        .background(spotlightedParticipant == participant.id ? Color.orange.opacity(0.3) : Color.clear)
                                        .cornerRadius(12)
                                        .onTapGesture {
                                            spotlightParticipant(participant.id)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
            }
            
            // Host controls (if host)
            if isHost {
                HStack(spacing: 12) {
                    Button(action: muteAllParticipants) {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.slash.fill")
                            Text("Mute All")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                    
                    Button(action: { showingParticipantGrid = true }) {
                        Image(systemName: "rectangle.grid.2x2")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { showingWhiteboard = true }) {
                        Image(systemName: "pencil.and.outline")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { showingBreakoutRooms = true }) {
                        Image(systemName: "rectangle.split.2x1")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // Control buttons
            HStack(spacing: 20) {
                // Toggle video
                Button(action: {
                    Task { @MainActor in
                        streamingService.toggleVideo()
                    }
                }) {
                    Image(systemName: streamingService.isVideoEnabled ? "video.fill" : "video.slash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(streamingService.isVideoEnabled ? Color.blue : Color.gray)
                        .clipShape(Circle())
                }
                
                // Toggle audio
                Button(action: {
                    Task { @MainActor in
                        streamingService.toggleAudio()
                    }
                }) {
                    Image(systemName: streamingService.isAudioEnabled ? "mic.fill" : "mic.slash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(streamingService.isAudioEnabled ? Color.blue : Color.gray)
                        .clipShape(Circle())
                }
                
                // Screen sharing
                Button(action: startScreenSharing) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.purple)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // End call
                Button(action: {
                    leaveStream()
                }) {
                    Image(systemName: "phone.down.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showingParticipantGrid) {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(participants) { participant in
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.3))
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.purple)
                                    
                                    if participant.isMuted {
                                        VStack {
                                            HStack {
                                                Spacer()
                                                Image(systemName: "mic.slash.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                                    .padding(6)
                                                    .background(Color.black.opacity(0.7))
                                                    .clipShape(Circle())
                                            }
                                            Spacer()
                                        }
                                        .padding(8)
                                    }
                                }
                                
                                Text(participant.name)
                                    .font(.headline)
                                
                                HStack(spacing: 8) {
                                    if participant.isMuted {
                                        Label("Muted", systemImage: "mic.slash.fill")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    
                                    if !participant.isVideoEnabled {
                                        Label("Video Off", systemImage: "video.slash.fill")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    if participant.isSpeaking {
                                        Label("Speaking", systemImage: "waveform")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Participants")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showingParticipantGrid = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showingWhiteboard) {
            NavigationStack {
                ZStack {
                    Color.white
                    Text("Whiteboard - Drawing functionality coming soon")
                        .foregroundColor(.gray)
                }
                .navigationTitle("Whiteboard")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showingWhiteboard = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showingBreakoutRooms) {
            NavigationStack {
                List {
                    Section(header: Text("Breakout Rooms")) {
                        Text("Breakout rooms feature coming soon")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("Breakout Rooms")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showingBreakoutRooms = false }
                    }
                }
            }
        }
    }
    
    private func muteAllParticipants() {
        // Implement mute all functionality
        for participant in participants {
            muteParticipant(participant.id)
        }
    }
    
    private func spotlightParticipant(_ participantId: String) {
        spotlightedParticipant = spotlightedParticipant == participantId ? nil : participantId
    }
    
    private func muteParticipant(_ participantId: String) {
        // Implement mute participant functionality
    }
    
    private func startScreenSharing() {
        // Implement screen sharing
    }
    
    private func getUserName(for userId: String) -> String {
        return participants.first(where: { $0.id == userId })?.name ?? "Participant"
    }
    
    private func startStreaming() {
        guard let session = session else { return }
        let userId = userService.userIdentifier

        Task {
            do {
                // Request camera and microphone permissions before starting
                await requestPermissions()
                
                // Conference mode uses HLS (not broadcast mode)
                // Both host and participants use the same HLS streaming
                // ALWAYS use profile name from settings - never device name
                // First check ProfileManager (Firebase) for name
                var userName: String = ""
                let profileManagerName = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !profileManagerName.isEmpty {
                    let isDeviceName = profileManagerName.contains("iPhone") || 
                                     profileManagerName.contains("iPad") || 
                                     profileManagerName == UIDevice.current.name
                    if !isDeviceName {
                        userName = profileManagerName
                    }
                }
                
                // Fallback to local UserProfile name
                if userName.isEmpty {
                    let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !profileName.isEmpty {
                        let isDeviceName = profileName.contains("iPhone") || 
                                         profileName.contains("iPad") || 
                                         profileName == UIDevice.current.name
                        if !isDeviceName {
                            userName = profileName
                        }
                    }
                }
                
                // If no valid profile name, user must set it
                guard !userName.isEmpty else {
                    errorMessage = "Please set your name in Settings > Profile before starting a stream."
                    showingError = true
                    print("⚠️ [STREAM] Cannot start stream - user has no profile name set")
                    return
                }
                
                try await streamingService.startStream(sessionId: session.id, userId: userId, userName: userName, isBroadcastMode: false)
                isStreaming = true
                
                // Setup local video view after stream starts
                await setupLocalVideoView()
            } catch {
                errorMessage = "Failed to start streaming: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func requestPermissions() async {
        // Request camera permission
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraStatus == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        
        // Request microphone permission
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
    }
    
    private func setupLocalVideoView() async {
        // Get the preview layer from the HLS service directly
        // Retry multiple times as the preview layer may take a moment to initialize
        for attempt in 1...5 {
            if let previewLayer = HLSStreamingService.shared.getPreviewLayer() {
                await MainActor.run {
                    localVideoView = AnyView(
                        VideoPreviewLayerView(previewLayer: previewLayer)
                    )
                }
                print("✅ [CAMERA] Local video preview set up successfully (attempt \(attempt))")
                return
            }
            
            // Wait before retrying (except on last attempt)
            if attempt < 5 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                print("⚠️ [CAMERA] Preview layer not ready yet, attempt \(attempt)/5")
            }
        }
        
        // If still no preview layer after retries, log warning
        print("⚠️ [CAMERA] Preview layer not available after 5 attempts")
    }
    
    private func setupSignalingCallbacks(userId: String) {
        // No-op: signaling handled by unified streaming service or server-side
    }
    
    private func startConnection(userId: String) async {
        // Connection orchestration handled by `UnifiedStreamingService` / backend
    }
    
    private func setupVideoViews() {
        // Video rendering handled by streaming service implementations
    }
    
    private func leaveStream() {
        Task {
            _ = userService.userIdentifier
            // Stop unified stream
            streamingService.stopStream()
            isStreaming = false
        }
        
        dismiss()
    }
}

struct ConnectionStatusView: View {
    let state: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(state)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5))
        .cornerRadius(16)
    }
    
    private var statusColor: Color {
        switch state {
        case "Connected":
            return .green
        case "Connecting...":
            return .yellow
        case "Failed":
            return .red
        default:
            return .gray
        }
    }
}



@available(iOS 17.0, *)
struct LiveStreamView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MultiParticipantStreamView(session: LiveSession(
                title: "Test Session",
                description: "Test",
                hostId: "test",
                category: "Prayer"
            ))
        }
    }
}

