//
//  MultiParticipantStreamView.swift
//  Faith Journal
//
//  Enhanced live streaming view with multiple participants support
//

import SwiftUI
import SwiftData
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers
import PDFKit
import UIKit

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

    // Presentation tools
    @State private var showingPresentation = false
    @State private var activePresentation: ActivePresentation?
    @State private var selectedPDFURLs: [URL] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isScreenSharing = false
    @State private var screenShareError: String?
    @State private var showingChat = false

    enum ActivePresentation: Equatable {
        case bibleStudy
        case pdf(URL)
        case image(Data)
    }
    
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
        .alert("Screen Sharing", isPresented: Binding(get: { screenShareError != nil }, set: { if !$0 { screenShareError = nil } })) {
            Button("OK", role: .cancel) {
                screenShareError = nil
            }
        } message: {
            Text(screenShareError ?? "Unable to share your screen.")
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
        .sheet(isPresented: $showingPresentation) {
            NavigationStack {
                InSessionPresentationSheet(
                    selectedPDFURLs: $selectedPDFURLs,
                    selectedPhotoItem: $selectedPhotoItem,
                    activePresentation: $activePresentation
                )
                .navigationTitle("Presentation")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showingChat) {
            LiveSessionChatView(session: session, canSend: true)
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
            ZStack {
                if layoutMode == .grid {
                    gridLayout(geometry: geometry)
                } else {
                    speakerLayout(geometry: geometry)
                }

                if let activePresentation {
                    PresentedContentOverlay(
                        activePresentation: activePresentation,
                        stop: { self.activePresentation = nil }
                    )
                    .padding(12)
                }
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

                // Countdown (if time limit is enabled)
                if session.durationLimitMinutes > 0 {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let remaining = remainingTimeSeconds(now: timeline.date)
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .foregroundColor(remaining <= 300 ? .orange : .white.opacity(0.8))
                            Text(formatDuration(seconds: remaining))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(remaining <= 60 ? .red : (remaining <= 300 ? .orange : .white.opacity(0.9)))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityLabel("Time remaining \(formatDuration(seconds: remaining))")
                    }
                }
                
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

    // MARK: - Countdown helpers

    private func remainingTimeSeconds(now: Date) -> Int {
        let limitMinutes = session.durationLimitMinutes
        guard limitMinutes > 0 else { return 0 }
        let endAt = session.startTime.addingTimeInterval(TimeInterval(limitMinutes * 60))
        return max(0, Int(endAt.timeIntervalSince(now)))
    }

    private func formatDuration(seconds: Int) -> String {
        let s = max(0, seconds)
        let hours = s / 3600
        let minutes = (s % 3600) / 60
        let secs = s % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private var controlButtons: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 380
            let buttonSize: CGFloat = isCompact ? 48 : 56
            let iconFont: Font = isCompact ? .title3 : .title2
            let spacing: CGFloat = isCompact ? 14 : 20

            VStack(spacing: 12) {
                // Primary controls row (always fits)
                HStack(spacing: spacing) {
                    // Video
                    Button(action: {
                        Task { @MainActor in
                            streamingService.toggleVideo()
                            if streamingService.isVideoEnabled {
                                await setupLocalVideoView()
                            } else {
                                localVideoView = nil
                            }
                            if let index = participants.firstIndex(where: { $0.id == userService.userIdentifier }) {
                                participants[index].isVideoEnabled = streamingService.isVideoEnabled
                            }
                        }
                    }) {
                        Image(systemName: streamingService.isVideoEnabled ? "video.fill" : "video.slash.fill")
                            .font(iconFont)
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(streamingService.isVideoEnabled ? Color.blue : Color.gray)
                            .clipShape(Circle())
                    }

                    // Audio
                    Button(action: {
                        Task { @MainActor in
                            streamingService.toggleAudio()
                            if let index = participants.firstIndex(where: { $0.id == userService.userIdentifier }) {
                                participants[index].isMuted = !streamingService.isAudioEnabled
                            }
                        }
                    }) {
                        Image(systemName: streamingService.isAudioEnabled ? "mic.fill" : "mic.slash.fill")
                            .font(iconFont)
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(streamingService.isAudioEnabled ? Color.blue : Color.gray)
                            .clipShape(Circle())
                    }

                    // Chat (always available for participants; host gets it in the second row to avoid overflow)
                    if !isHost {
                        Button(action: { showingChat = true }) {
                            Image(systemName: "message.fill")
                                .font(iconFont)
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                )
                        }
                    }

                    // Screen share (host only)
                    if isHost {
                        Button(action: toggleScreenSharing) {
                            Image(systemName: isScreenSharing ? "rectangle.slash" : "rectangle.on.rectangle")
                                .font(iconFont)
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(isScreenSharing ? Color.green : Color.purple)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                        }
                    }

                    // End
                    Button(action: { leaveStream() }) {
                        Image(systemName: "phone.down.fill")
                            .font(iconFont)
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Presentation tools row (host only) — separate row to avoid overflow
                if isHost {
                    HStack(spacing: spacing) {
                        Button(action: { showingChat = true }) {
                            Image(systemName: "message.fill")
                                .font(iconFont)
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                )
                        }

                        Button(action: { showingPresentation = true }) {
                            Image(systemName: "play.rectangle.on.rectangle")
                                .font(iconFont)
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(height: isHost ? 140 : 80)
    }

    // MARK: - Presentation UI

    private struct InSessionPresentationSheet: View {
        @Binding var selectedPDFURLs: [URL]
        @Binding var selectedPhotoItem: PhotosPickerItem?
        @Binding var activePresentation: ActivePresentation?
        @Environment(\.dismiss) private var dismiss
        @State private var showingPDFPicker = false

        var body: some View {
            List {
                Section("Present") {
                    Button {
                        activePresentation = .bibleStudy
                        dismiss()
                    } label: {
                        Label("Bible Study", systemImage: "book.fill")
                    }

                    Button {
                        showingPDFPicker = true
                    } label: {
                        Label("Pick PDF", systemImage: "doc.richtext")
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Pick Image", systemImage: "photo")
                    }
                }

                if let activePresentation {
                    Section("Now presenting") {
                        Text(presentationTitle(activePresentation))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button(role: .destructive) {
                            self.activePresentation = nil
                        } label: {
                            Label("Stop presenting", systemImage: "xmark.circle.fill")
                        }
                    }
                }
            }
            .onChange(of: selectedPDFURLs) { _, newValue in
                if let url = newValue.first {
                    activePresentation = .pdf(url)
                    dismiss()
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            activePresentation = .image(data)
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPDFPicker) {
                DocumentPickerView(
                    selectedFileURLs: $selectedPDFURLs,
                    allowedContentTypes: [UTType.pdf],
                    allowsMultipleSelection: false
                )
            }
        }

        private func presentationTitle(_ active: ActivePresentation) -> String {
            switch active {
            case .bibleStudy: return "Bible Study"
            case .pdf(let url): return "PDF: \(url.lastPathComponent)"
            case .image: return "Image"
            }
        }
    }

    private struct PresentedContentOverlay: View {
        let activePresentation: ActivePresentation
        let stop: () -> Void

        var body: some View {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Button(action: stop) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.65))
                .cornerRadius(12)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(14)
            }
        }

        private var title: String {
            switch activePresentation {
            case .bibleStudy: return "Bible Study"
            case .pdf(let url): return url.lastPathComponent
            case .image: return "Image"
            }
        }

        @ViewBuilder
        private var content: some View {
            switch activePresentation {
            case .bibleStudy:
                NavigationStack {
                    BibleStudyView()
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            case .pdf(let url):
                PDFKitView(url: url)

            case .image(let data):
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else {
                    Text("Unable to load image")
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                }
            }
        }
    }

    private struct PDFKitView: UIViewRepresentable {
        let url: URL

        func makeUIView(context: Context) -> PDFView {
            let view = PDFView()
            view.autoScales = true
            view.displayMode = .singlePageContinuous
            view.displayDirection = .vertical
            view.backgroundColor = .black
            view.document = PDFDocument(url: url)
            return view
        }

        func updateUIView(_ uiView: PDFView, context: Context) {
            if uiView.document?.documentURL != url {
                uiView.document = PDFDocument(url: url)
            }
        }
    }

    private func toggleScreenSharing() {
        if isScreenSharing {
            HLSStreamingService.shared.stopScreenBroadcast()
            isScreenSharing = false
            return
        }

        Task {
            do {
                try await HLSStreamingService.shared.startScreenBroadcast()
                await MainActor.run {
                    isScreenSharing = true
                }
            } catch {
                await MainActor.run {
                    screenShareError = error.localizedDescription
                    isScreenSharing = false
                }
            }
        }
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
            let hlsService = HLSStreamingService.shared
            var didSetPreview = false
            await MainActor.run {
                if let previewLayer = hlsService.getPreviewLayer() {
                    self.localVideoView = AnyView(
                        VideoPreviewLayerView(previewLayer: previewLayer)
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    )
                    print("✅ [CAMERA] Local video view set up successfully (attempt \(attempt))")
                    didSetPreview = true
                }
            }
            if didSetPreview {
                break
            } else if attempt < 3 {
                print("⚠️ [CAMERA] Preview layer not ready yet, attempt \(attempt)/3")
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

