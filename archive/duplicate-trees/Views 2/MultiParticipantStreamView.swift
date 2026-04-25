//
//  MultiParticipantStreamView.swift
//  Faith Journal
//
//  Enhanced live streaming view with multiple participants support
//

import SwiftUI
import SwiftData
import AVFoundation

#if canImport(WebRTC)
import WebRTC
#endif

@available(iOS 17.0, *)
struct MultiParticipantStreamView: View {
    let session: LiveSession
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
    @State private var remoteVideoViews: [String: AnyView] = [:]
    @State private var localVideoView: AnyView?
    @State private var participantCount = 0
    @State private var layoutMode: LayoutMode = .grid // grid or speaker
    @State private var participants: [ParticipantInfo] = []
    @State private var spotlightedParticipant: String?
    @State private var isHost = false
    @State private var showingFullScreen = false
    @State private var fullScreenParticipant: String?
    
    struct ParticipantInfo: Identifiable {
        let id: String
        let name: String
        var isMuted: Bool
        var isVideoEnabled: Bool
        var isSpeaking: Bool
    }
    
    enum LayoutMode {
        case grid
        case speaker // One large, others small
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Video grid
                videoGridArea
                
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
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let participantId = fullScreenParticipant,
               let videoView = remoteVideoViews[participantId] {
                ZStack {
                    Color.black.ignoresSafeArea()
                    videoView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    VStack {
                        HStack {
                            Text(getUserName(for: participantId))
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Button(action: {
                                showingFullScreen = false
                                fullScreenParticipant = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func muteAllParticipants() {
        // Implement mute all functionality
        for _ in participants {
            // Mute participant logic
        }
    }
    
    // MARK: - View Components
    
    private var videoGridArea: some View {
        GeometryReader { geometry in
            if layoutMode == .grid {
                gridLayout(geometry: geometry)
            } else {
                speakerLayout(geometry: geometry)
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Session info and participant count
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(participantCount + 1) participant\(participantCount == 0 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                
                // Layout toggle
                Button(action: {
                    layoutMode = layoutMode == .grid ? .speaker : .grid
                }) {
                    Image(systemName: layoutMode == .grid ? "rectangle.grid.2x2" : "rectangle.3.group")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            
            // Control buttons
            controlButtons
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            // Toggle video
            Button(action: {
                Task { @MainActor in
                    streamingService.toggleVideo()
                    // Update local video view when toggling
                    if streamingService.isVideoEnabled {
                        await setupLocalVideoView()
                    } else {
                        localVideoView = nil
                    }
                    // Update participant info
                    if let index = participants.firstIndex(where: { $0.id == userService.userIdentifier }) {
                        participants[index].isVideoEnabled = streamingService.isVideoEnabled
                    }
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
                    // Update participant info
                    if let index = participants.firstIndex(where: { $0.id == userService.userIdentifier }) {
                        participants[index].isMuted = !streamingService.isAudioEnabled
                    }
                }
            }) {
                Image(systemName: streamingService.isAudioEnabled ? "mic.fill" : "mic.slash.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(streamingService.isAudioEnabled ? Color.blue : Color.gray)
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
    
    // MARK: - Layouts
    
    @ViewBuilder
    private func gridLayout(geometry: GeometryProxy) -> some View {
        let columns = participantCount <= 1 ? 1 : participantCount <= 4 ? 2 : 3
        let rows = Int(ceil(Double(participantCount + 1) / Double(columns)))
        let itemWidth = geometry.size.width / CGFloat(columns)
        let itemHeight = geometry.size.height / CGFloat(max(rows, 1))
        
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) {
                // Local video
                if let localView = localVideoView {
                    AnyView(localView)
                        .frame(width: itemWidth, height: itemHeight)
                        .cornerRadius(8)
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Text("You")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.black.opacity(0.5))
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                .padding(8)
                            }
                        )
                } else {
                    placeholderView(width: itemWidth, height: itemHeight, label: "You")
                }
                
                // Remote videos with enhanced features
                ForEach(Array(remoteVideoViews.keys.sorted()), id: \.self) { userId in
                    if let remoteView = remoteVideoViews[userId] {
                        AnyView(remoteView)
                            .frame(width: itemWidth, height: itemHeight)
                            .cornerRadius(8)
                            .overlay(
                                VStack {
                                    // Mute indicator
                                    HStack {
                                        if let participant = participants.first(where: { $0.id == userId }), participant.isMuted {
                                            Image(systemName: "mic.slash.fill")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .padding(4)
                                                .background(Color.black.opacity(0.7))
                                                .clipShape(Circle())
                                        }
                                        Spacer()
                                        
                                        // Full-screen button
                                        Button(action: {
                                            fullScreenParticipant = userId
                                            showingFullScreen = true
                                        }) {
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                                .padding(4)
                                                .background(Color.black.opacity(0.7))
                                                .clipShape(Circle())
                                        }
                                    }
                                    .padding(8)
                                    
                                    Spacer()
                                    
                                    // Name and speaking indicator
                                    HStack {
                                        if let participant = participants.first(where: { $0.id == userId }), participant.isSpeaking {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 8, height: 8)
                                        }
                                        Text(getUserName(for: userId))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.black.opacity(0.7))
                                            .cornerRadius(8)
                                        Spacer()
                                    }
                                    .padding(8)
                                }
                            )
                            .onTapGesture {
                                // Tap to spotlight
                                spotlightedParticipant = spotlightedParticipant == userId ? nil : userId
                            }
                    } else {
                        placeholderView(width: itemWidth, height: itemHeight, label: getUserName(for: userId))
                    }
                }
            }
            .padding(4)
        }
    }
    
    @ViewBuilder
    private func speakerLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            // Main speaker (first remote or local)
            if let firstRemote = remoteVideoViews.values.first {
                AnyView(firstRemote)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let localView = localVideoView {
                AnyView(localView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.black
            }
            
            // Small videos in corner
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        // Local video
                        if let localView = localVideoView {
                            AnyView(localView)
                                .frame(width: 120, height: 160)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                        
                        // Other remote videos
                        ForEach(Array(remoteVideoViews.keys.sorted().dropFirst()), id: \.self) { userId in
                            if let remoteView = remoteVideoViews[userId] {
                                AnyView(remoteView)
                                    .frame(width: 120, height: 160)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    @ViewBuilder
    private func placeholderView(width: CGFloat, height: CGFloat, label: String) -> some View {
        ZStack {
            Color.black.opacity(0.5)
            VStack {
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.5))
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(8)
    }
    
    // MARK: - Streaming Logic
    
    private func startStreaming() {
        let userId = userService.userIdentifier

        Task {
            do {
                let isHost = (userId == session.hostId)
                self.isHost = isHost
                
                // Request camera and microphone permissions before starting
                await requestPermissions()
                
                // Start the stream - use UserProfile name if available
                let userName = userService.getDisplayName(userProfile: userProfile)
                try await streamingService.startStream(sessionId: session.id, userId: userId, userName: userName, isBroadcastMode: isHost)
                isStreaming = true
                
                // Setup local video view after stream starts
                await setupLocalVideoView()
                
                // Update participant list
                await updateParticipants()
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
        // Wait a bit for the preview layer to be set up
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Try multiple times to get the preview layer (it may take a moment to initialize)
        for attempt in 1...3 {
            await MainActor.run {
                let hlsService = HLSStreamingService.shared
                if let previewLayer = hlsService.getPreviewLayer() {
                    localVideoView = AnyView(
                        VideoPreviewLayerView(previewLayer: previewLayer)
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    )
                    print("✅ [CAMERA] Local video view set up successfully (attempt \(attempt))")
                    return
                } else if attempt < 3 {
                    print("⚠️ [CAMERA] Preview layer not ready yet, attempt \(attempt)/3")
                }
            }
            
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait another 0.5 seconds
            }
        }
        
        // If still no preview layer, check if video is enabled
        await MainActor.run {
            if localVideoView == nil && streamingService.isVideoEnabled {
                print("⚠️ [CAMERA] Preview layer not available but video is enabled - may need permissions")
                // Show a placeholder or request permissions again
            }
        }
    }
    
    private func updateParticipants() async {
        // Update participant count and list
        // This would typically come from the streaming service
        await MainActor.run {
            participantCount = 1 // Start with self
            // Add self to participants
            let userId = userService.userIdentifier
            participants = [
                ParticipantInfo(
                    id: userId,
                    name: userService.getDisplayName(userProfile: userProfile),
                    isMuted: !streamingService.isAudioEnabled,
                    isVideoEnabled: streamingService.isVideoEnabled,
                    isSpeaking: false
                )
            ]
        }
    }
    
    private func setupSignalingCallbacks(userId: String) {
        // No-op: unified service handles signaling internally
    }
    
    private func startConnections(userId: String) async {
        // Connection orchestration handled by `UnifiedStreamingService`
    }
    
    private func getUserName(for userId: String) -> String {
        return participants.first(where: { $0.id == userId })?.name ?? "Participant"
    }
    
    private func leaveStream() {
        Task {
            _ = userService.userIdentifier
            streamingService.stopStream()
            isStreaming = false
        }
        
        dismiss()
    }
}

