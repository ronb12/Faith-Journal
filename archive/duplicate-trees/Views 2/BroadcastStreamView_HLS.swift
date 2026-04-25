//
//  BroadcastStreamView_HLS.swift
//  Faith Journal
//
//  Fully functional broadcast mode using native iOS AVFoundation
//  One presenter streams their camera, others can watch
//

import SwiftUI
import AVFoundation
import AVKit
import SwiftData
import UIKit

@available(iOS 17.0, *)
struct BroadcastStreamView_HLS: View {
    let session: LiveSession?
    // Use regular property for singleton, not @StateObject
    private let streamingService = HLSStreamingService.shared
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    // Use regular property for singleton, not @StateObject
    private let analyticsService = StreamAnalyticsService.shared
    // Use regular property for singleton, not @StateObject
    private let reactionsService = StreamReactionsService.shared
    // Use regular property for singleton, not @StateObject
    private let recordingService = StreamRecordingService.shared
    // Use regular property for singleton, not @StateObject
    private let pollsService = StreamPollsService.shared
    // Use regular property for singleton, not @StateObject
    private let moderationService = StreamModerationService.shared
    // Use regular property for singleton, not @StateObject
    private let highlightsService = StreamHighlightsService.shared
    // Use regular property for singleton, not @StateObject
    private let captionsService = StreamCaptionsService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var allMessages: [ChatMessage]

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isUsingFrontCamera = true
    @State private var videoQuality: VideoQuality = .hd
    @State private var networkQuality: NetworkQuality = .good
    @State private var showingSettings = false
    @State private var isRecording = false
    @State private var showChatOverlay = false
    @State private var chatMessageText = ""
    // CloudKitPublicSyncService removed - use Firebase for sync in the future
    // @State private var syncService: CloudKitPublicSyncService?
    @State private var publicMessages: [ChatMessage] = []
    @State private var showingQuickSettings = false
    @State private var showingReactions = false
    @State private var showingPolls = false
    @State private var showingQnA = false
    @State private var showingAnalytics = false
    @State private var showingHighlights = false
    @State private var showingShareSheet = false
    @State private var backgroundBlurEnabled = false
    @State private var selectedFilter: VideoFilter = .none
    @State private var streamTimer: TimeInterval = 0
    @State private var networkUsage: DataUsage = DataUsage(bytesSent: 0, bytesReceived: 0)
    @State private var batterySaverEnabled = false
    @State private var timer: Timer?
    
    // Hybrid UI mode (YouTube-style for viewers, enhanced host mode)
    @State private var controlsVisible = true
    @State private var theaterMode = false
    @State private var autoHideControlsTimer: Timer?
    @State private var lastInteractionTime = Date()
    
    // Debug: Track if YouTube-style UI should be visible
    private var shouldShowYouTubeUI: Bool {
        !isHost && streamingService.isStreaming && streamingService.streamURL != nil
    }
    
    // Accessibility features
    @AppStorage("accessibilityHighContrast") private var highContrast = false
    @AppStorage("accessibilityLargerButtons") private var largerButtons = false
    @AppStorage("accessibilityClosedCaptions") private var closedCaptionsEnabled = false
    @AppStorage("accessibilityVoiceControl") private var voiceControlEnabled = false
    @State private var showingAccessibilitySettings = false
    
    // Technical improvements
    @State private var autoQualityAdjustment = true
    @State private var isOfflineMode = false
    @State private var backgroundAudioEnabled = false
    @State private var pipEnabled = false
    @State private var airPlayEnabled = false
    @State private var lastNetworkQualityCheck: Date?
    @State private var qualityAdjustmentTimer: Timer?
    
    // Picture-in-Picture
    @State private var pipController: AVPictureInPictureController?
    @State private var pipPlayer: AVPlayer?
    @State private var pipPlayerLayer: AVPlayerLayer?
    @State private var pipCoordinator: PiPCoordinator?
    
    enum VideoFilter: String, CaseIterable {
        case none = "None"
        case sepia = "Sepia"
        case blackAndWhite = "Black & White"
        case vibrant = "Vibrant"
        case cool = "Cool"
        case warm = "Warm"
    }
    
    struct DataUsage {
        var bytesSent: Int64
        var bytesReceived: Int64
        
        var formattedSent: String {
            formatBytes(bytesSent)
        }
        
        var formattedReceived: String {
            formatBytes(bytesReceived)
        }
        
        private func formatBytes(_ bytes: Int64) -> String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB]
            formatter.countStyle = .binary
            return formatter.string(fromByteCount: bytes)
        }
    }
    
    enum VideoQuality: String, CaseIterable {
        case low = "Low (240p)"
        case sd = "SD (480p)"
        case hd = "HD (720p)"
        case fullHD = "Full HD (1080p)"
    }
    
    enum NetworkQuality: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        
        var color: Color {
            switch self {
            case .excellent, .good: return .green
            case .fair: return .yellow
            case .poor: return .red
            }
        }
    }

    var isHost: Bool {
        guard let session = session else { return false }
        let userId = userService.userIdentifier
        return session.hostId == userId
    }
    
    // Chat messages for this session
    var sessionMessages: [ChatMessage] {
        guard let session = session else { return [] }
        var combined = allMessages.filter { $0.sessionId == session.id }
        // Add public messages that aren't already in local
        let localIds = Set(combined.map { $0.id })
        for publicMessage in publicMessages {
            if !localIds.contains(publicMessage.id) {
                combined.append(publicMessage)
            }
        }
        // Remove duplicates by ID, keeping most recent
        var unique: [ChatMessage] = []
        var seenIds: Set<UUID> = []
        for message in combined.sorted(by: { $0.timestamp < $1.timestamp }) {
            if !seenIds.contains(message.id) {
                unique.append(message)
                seenIds.insert(message.id)
            }
        }
        return unique
    }
    
    // Unread message count (messages received while chat is closed)
    var unreadMessageCount: Int {
        guard showChatOverlay == false else { return 0 }
        // Count messages from last 5 minutes that user hasn't seen
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        return sessionMessages.filter { $0.timestamp > fiveMinutesAgo && $0.userId != userService.userIdentifier }.count
    }

    var body: some View {
        if #available(iOS 17.0, *), session != nil {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 0) {
                        // Main video area
                        ZStack {
                        if isHost {
                            // Host sees live camera preview with tap-to-toggle controls
                            if streamingService.isStreaming {
                                // Check for preview layer with retry logic
                                if let previewLayer = streamingService.getPreviewLayer() ?? HLSStreamingService.shared.getPreviewLayer() {
                                    CameraPreviewView(
                                        previewLayer: previewLayer,
                                        backgroundBlurEnabled: backgroundBlurEnabled,
                                        selectedFilter: selectedFilter
                                    )
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .overlay(
                                            // Show indicator if video is disabled (simulator/audio-only mode)
                                            !streamingService.isVideoEnabled ?
                                            VStack {
                                                Spacer()
                                                HStack(spacing: 8) {
                                                    Image(systemName: "video.slash.fill")
                                                        .font(.title3)
                                                        .foregroundColor(.white)
                                                    Text("Audio-only mode")
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.black.opacity(0.7))
                                                .cornerRadius(8)
                                                .padding()
                                            } : nil
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                controlsVisible.toggle()
                                                resetAutoHideTimer()
                                            }
                                        }
                                        .gesture(
                                            DragGesture(minimumDistance: 30)
                                                .onEnded { value in
                                                    let verticalAmount = value.translation.height
                                                    if abs(verticalAmount) > 50 {
                                                        withAnimation(.easeInOut(duration: 0.3)) {
                                                            if verticalAmount > 0 {
                                                                // Swipe down - hide
                                                                controlsVisible = false
                                                            } else {
                                                                // Swipe up - show
                                                                controlsVisible = true
                                                                resetAutoHideTimer()
                                                            }
                                                        }
                                                    }
                                                }
                                        )
                                } else {
                                    // No preview layer available - show placeholder
                                    VStack(spacing: 20) {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.white.opacity(0.6))
                                        Text("Audio-only streaming")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Camera not available")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else if isLoading {
                                LoadingView(message: "Starting camera...")
                            } else {
                                VStack(spacing: 24) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Text("Tap Start to begin broadcasting")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Button(action: startBroadcasting) {
                                        HStack {
                                            Image(systemName: "play.circle.fill")
                                            Text("Start Broadcasting")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.red, Color.orange]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                    }
                                    .disabled(isLoading)
                                }
                            }
                        } else {
                            // Viewers see the video stream
                            if let streamURL = streamingService.streamURL {
                                // Use AVPlayer for viewers to enable PiP
                                let viewerPlayer = pipPlayer ?? {
                                    let p = AVPlayer(url: streamURL)
                                    p.allowsExternalPlayback = true
                                    return p
                                }()
                                
                                ZStack {
                                    // Main video player (full screen)
                                    VideoPlayer(player: viewerPlayer)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                controlsVisible.toggle()
                                            }
                                        }
                                        .onAppear {
                                            viewerPlayer.play()
                                        }
                                    
                                    // YouTube-style overlay for viewers
                                    YouTubeStyleStreamView(
                                        session: session,
                                        isHost: isHost,
                                        showChatOverlay: $showChatOverlay,
                                        showingReactions: $showingReactions,
                                        showingPolls: $showingPolls,
                                        showingQnA: $showingQnA,
                                        controlsVisible: $controlsVisible,
                                        theaterMode: $theaterMode,
                                        viewerCount: streamingService.viewerCount,
                                        onReaction: {
                                            reactionsService.addReaction(
                                                .heart,
                                                userId: userService.userIdentifier,
                                                userName: userService.displayName
                                            )
                                        },
                                        onToggleChat: {
                                            showChatOverlay.toggle()
                                        },
                                        onToggleTheater: {
                                            withAnimation {
                                                theaterMode.toggle()
                                            }
                                        },
                                        onShare: {
                                            showingShareSheet = true
                                        }
                                    )
                                    
                                    // Hidden player layer for PiP (must be in view hierarchy)
                                    if let playerLayer = pipPlayerLayer {
                                        PiPPlayerLayerView(playerLayer: playerLayer)
                                            .frame(width: 1, height: 1)
                                            .opacity(0)
                                    }
                                }
                            } else {
                                VStack(spacing: 20) {
                                    Image(systemName: "person.video.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Text("Waiting for broadcast to start...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        // Tap gesture for host view to toggle controls
                        if isHost {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        controlsVisible.toggle()
                                        resetAutoHideTimer()
                                    }
                                }
                        }
                        
                        // Status overlay - only show for hosts
                        if isHost {
                            VStack {
                                HStack {
                                    // Network quality indicator
                                    if streamingService.isStreaming {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(networkQuality.color)
                                                .frame(width: 8, height: 8)
                                            Text(networkQuality.rawValue)
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(8)
                                    }
                                    
                                    Spacer()
                                    
                                    if streamingService.isStreaming {
                                        HStack(spacing: 8) {
                                            if isRecording {
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(Color.red)
                                                        .frame(width: 8, height: 8)
                                                    Text("REC")
                                                        .font(.caption2)
                                                        .font(.body.weight(.bold))
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.black.opacity(0.6))
                                                .cornerRadius(8)
                                            }
                                            
                                            StatusPill(icon: "circle.fill", text: "LIVE", color: .red)
                                        }
                                    }
                                }
                                .padding()
                                .opacity(controlsVisible ? 1 : 0)
                                Spacer()
                                
                                // Reactions Overlay (for hosts)
                                if showingReactions {
                                    ReactionsOverlay(
                                        reactions: reactionsService.activeReactions,
                                        onReactionSelected: { reaction in
                                            reactionsService.addReaction(
                                                reaction,
                                                userId: userService.userIdentifier,
                                                userName: userService.displayName
                                            )
                                        },
                                        onDismiss: { showingReactions = false }
                                    )
                                }
                                
                                // Polls Overlay (for hosts)
                                if showingPolls {
                                    PollsOverlay(
                                        activePolls: pollsService.activePolls,
                                        onVote: { pollId, optionId in
                                            pollsService.voteOnPoll(
                                                pollId: pollId,
                                                optionId: optionId,
                                                userId: userService.userIdentifier
                                            )
                                        },
                                        onCreatePoll: { question, options in
                                            _ = pollsService.createPoll(question: question, options: options)
                                        },
                                        onDismiss: { showingPolls = false },
                                        isHost: isHost
                                    )
                                }
                                
                                // Q&A Overlay (for hosts)
                                if showingQnA {
                                    QnAOverlay(
                                        questions: pollsService.questionQueue,
                                        pinnedQuestions: pollsService.pinnedQuestions,
                                        onSubmitQuestion: { question in
                                            _ = pollsService.submitQuestion(
                                                question: question,
                                                userId: userService.userIdentifier,
                                                userName: userService.displayName
                                            )
                                        },
                                        onPinQuestion: { questionId in
                                            pollsService.pinQuestion(questionId)
                                        },
                                        onAnswerQuestion: { questionId, answer in
                                            pollsService.answerQuestion(questionId, answer: answer)
                                        },
                                        onDismiss: { showingQnA = false },
                                        isHost: isHost
                                    )
                                }
                                
                                // Closed Captions Overlay (for hosts)
                                if closedCaptionsEnabled && captionsService.isTranscribing {
                                    CaptionsOverlay(
                                        caption: captionsService.currentCaption,
                                        style: captionsService.captionStyle
                                    )
                                }
                            }
                        } else {
                            // For viewers, overlays are handled by YouTubeStyleStreamView
                            // Only show closed captions if enabled
                            if closedCaptionsEnabled {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Text("Closed Captions")
                                            .font(.caption)
                                            .foregroundColor(highContrast ? .black : .white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(highContrast ? Color.yellow.opacity(0.9) : Color.black.opacity(0.8))
                                            .cornerRadius(8)
                                            .padding()
                                    }
                                }
                            }
                        }
                        
                        // Chat Overlay (Messenger-style) - shown for both hosts and viewers
                        // Positioned at bottom to maximize video space
                        if showChatOverlay, let session = session {
                            VStack {
                                Spacer()
                                LiveStreamChatOverlay(
                                    session: session,
                                    messages: sessionMessages,
                                    messageText: $chatMessageText,
                                    onSend: sendChatMessage,
                                    onDismiss: { showChatOverlay = false }
                                )
                            }
                        }
                    }
                    // Controls (without bottom action bar - moved to safeAreaInset)
                    // Only show for hosts (viewers use YouTube-style UI)
                    if isHost {
                        VStack(spacing: 0) {
                            // Hide/Show button
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        controlsVisible.toggle()
                                        resetAutoHideTimer()
                                    }
                                }) {
                                    Image(systemName: controlsVisible ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(.trailing, 16)
                                .padding(.top, 8)
                            }
                            
                            if controlsVisible {
                                VStack(spacing: 16) {
                                    // Session info
                                    sessionInfoHeader
                                    
                                    // Stream stats overlay (when streaming)
                                    if streamingService.isStreaming {
                                        streamStatsView
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.bottom)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.9)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    let verticalAmount = value.translation.height
                                    if abs(verticalAmount) > 30 {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            if verticalAmount > 0 {
                                                // Swipe down - hide
                                                controlsVisible = false
                                            } else {
                                                // Swipe up - show
                                                controlsVisible = true
                                                resetAutoHideTimer()
                                            }
                                        }
                                    }
                                }
                        )
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottom action bar with hide/show button
                if isHost && streamingService.isStreaming {
                    VStack(spacing: 0) {
                        // Hide/Show button for bottom bar
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    controlsVisible.toggle()
                                    if controlsVisible {
                                        resetAutoHideTimer()
                                    }
                                }
                            }) {
                                Image(systemName: controlsVisible ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 4)
                        }
                        
                        if controlsVisible {
                            BottomActionBar(
                        onReactions: { 
                            showingReactions.toggle()
                            resetAutoHideTimer()
                        },
                        onPolls: { 
                            showingPolls.toggle()
                            resetAutoHideTimer()
                        },
                        onQnA: { 
                            showingQnA.toggle()
                            resetAutoHideTimer()
                        },
                        onFlipCamera: {
                            flipCamera()
                            resetAutoHideTimer()
                        },
                        onBackgroundBlur: { 
                            backgroundBlurEnabled.toggle()
                            resetAutoHideTimer()
                        },
                        onToggleVideo: {
                            toggleVideo()
                            resetAutoHideTimer()
                        },
                        onToggleAudio: { 
                            streamingService.toggleAudio()
                            resetAutoHideTimer()
                        },
                        onToggleChat: { 
                            showChatOverlay.toggle()
                            resetAutoHideTimer()
                        },
                        onHighlights: { 
                            showingHighlights.toggle()
                            resetAutoHideTimer()
                        },
                        onShare: { 
                            showingShareSheet = true
                            resetAutoHideTimer()
                        },
                        onAnalytics: { 
                            showingAnalytics.toggle()
                            resetAutoHideTimer()
                        },
                        onStop: stopAndDismiss,
                        showingReactions: showingReactions,
                        backgroundBlurEnabled: backgroundBlurEnabled,
                        isVideoEnabled: streamingService.isVideoEnabled,
                        isAudioEnabled: streamingService.isAudioEnabled,
                        showChatOverlay: showChatOverlay,
                        unreadMessageCount: unreadMessageCount,
                        largerButtons: largerButtons,
                        highContrast: highContrast
                            )
                            .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                let verticalAmount = value.translation.height
                                if abs(verticalAmount) > 30 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if verticalAmount > 0 {
                                            // Swipe down - hide
                                            controlsVisible = false
                                        } else {
                                            // Swipe up - show
                                            controlsVisible = true
                                            resetAutoHideTimer()
                                        }
                                    }
                                }
                            }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        stopAndDismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                        .font(.body)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        stopAndDismiss()
                    }
                    .foregroundColor(.white)
                    .font(.body)
                }
            }
            .onAppear {
                if isHost {
                    Task {
                        startBroadcasting()
                        startStreamTimer()
                        startNetworkMonitoring()
                        if autoQualityAdjustment {
                            startAutoQualityAdjustment()
                        }
                    }
                } else {
                    Task {
                        await joinAsViewer()
                    }
                }
                
                // Setup background audio if enabled
                if backgroundAudioEnabled {
                    setupBackgroundAudio()
                }
            }
            .onChange(of: HLSStreamingService.shared.previewLayer) { _, newValue in
                // Refresh view when preview layer becomes available
                if newValue != nil && streamingService.isStreaming {
                    print("✅ [CAMERA] Preview layer updated, refreshing view")
                }
            }
            .onChange(of: streamingService.isStreaming) { _, newValue in
                // When streaming starts, ensure camera preview is set up
                if newValue && isHost {
                    Task {
                        await setupLocalVideoView()
                    }
                }
                
                // Setup PiP if enabled
                if pipEnabled {
                    setupPictureInPicture()
                }
                
                // CloudKitPublicSyncService removed - use Firebase for sync
                // Chat initialization removed - implement Firebase chat in the future
                loadPublicMessages()
                setupMessageSubscription()
                
                // Initialize services
                reactionsService.setModelContext(modelContext)
                
                // Start analytics tracking
                analyticsService.updateViewerCount(streamingService.viewerCount)
                
                // Start closed captions if enabled
                if closedCaptionsEnabled && isHost {
                    Task {
                        try? await captionsService.startTranscription()
                    }
                }
                
                // Update analytics periodically
                Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                    Task { @MainActor in
                        let viewerCount = streamingService.viewerCount
                        analyticsService.updateViewerCount(viewerCount)
                        // Update stream metrics (mock data - replace with actual metrics)
                        analyticsService.updateStreamMetrics(
                            bitrate: 2.5,
                            frameRate: 30,
                            latency: 0.15,
                            resolution: videoQuality.rawValue
                        )
                    }
                }
                
                // Start auto-hide timer for controls (hosts only)
                if isHost {
                    resetAutoHideTimer()
                }
            }
            .onDisappear {
                stopStreamTimer()
                stopAutoQualityAdjustment()
                autoHideControlsTimer?.invalidate()
                autoHideControlsTimer = nil
                if isHost {
                    captionsService.stopTranscription()
                }
            }
            .background(highContrast ? Color.white : Color.black)
            .preferredColorScheme(highContrast ? .light : nil)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            }
        } else {
            Text("Broadcasting (HLS) is only available on iOS 17+")
        }
    }
    
    // MARK: - View Components
    
    // MARK: - View Components
    
    // Sheets are now attached to the main view
    
    private var sessionInfoHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session?.title ?? "Test")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(session?.category ?? "Prayer")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            
            // Quick settings and main settings buttons
            if isHost {
                HStack(spacing: 12) {
                    // Quick settings panel
                    Button(action: { showingQuickSettings.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    // Main settings
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var streamStatsView: some View {
        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
            HStack(spacing: 12) {
                // Timer
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                    Text(formatTime(streamTimer))
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                
                // Viewer count with trend
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                    Text("\(analyticsService.currentViewerCount)")
                    if analyticsService.peakViewerCount > 0 {
                        Text("(Peak: \(analyticsService.peakViewerCount))")
                            .font(.caption2)
                            .opacity(0.7)
                    }
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                
                // Bitrate
                if analyticsService.bitrate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text(String(format: "%.1f Mbps", analyticsService.bitrate))
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
                
                // Frame rate
                if analyticsService.frameRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                        Text(String(format: "%.0f fps", analyticsService.frameRate))
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
                
                // Network usage
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(networkUsage.formattedSent)
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                
                // Battery saver indicator
                if batterySaverEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "battery.25")
                        Text("Saver")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
                
                // Engagement rate
                if analyticsService.engagementRate > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                        Text(String(format: "%.0f%%", analyticsService.engagementRate))
                    }
                    .font(.caption)
                    .foregroundColor(.pink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .frame(height: 40)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
    }
    
    private var controlButtonsView: some View {
        HorizontalOnlyScrollView {
            HStack(alignment: .center, spacing: 12) {
                // Reactions button
                Button(action: { showingReactions.toggle() }) {
                    Image(systemName: "heart.fill")
                        .font(largerButtons ? .title2 : .title3)
                        .foregroundColor(.pink)
                        .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.pink, lineWidth: showingReactions ? 2 : 0)
                        )
                }
                .accessibilityLabel("Reactions")
                
                // Polls button
                Button(action: { showingPolls.toggle() }) {
                    Image(systemName: "chart.bar.fill")
                        .font(largerButtons ? .title2 : .title3)
                        .foregroundColor(highContrast ? .black : .white)
                        .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                        .background(highContrast ? Color.white : Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Polls")
                
                // Q&A button
                Button(action: { showingQnA.toggle() }) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(largerButtons ? .title2 : .title3)
                        .foregroundColor(highContrast ? .black : .white)
                        .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                        .background(highContrast ? Color.white : Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Q&A")
                
                // Camera flip
                Button(action: flipCamera) {
                    Image(systemName: "camera.rotate.fill")
                        .font(largerButtons ? .title2 : .title3)
                        .foregroundColor(highContrast ? .black : .white)
                        .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                        .background(highContrast ? Color.white : Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Flip Camera")
                .accessibilityHint("Switches between front and back camera")
                
                // Background blur toggle
            Button(action: { backgroundBlurEnabled.toggle() }) {
                Image(systemName: backgroundBlurEnabled ? "camera.filters" : "camera")
                    .font(largerButtons ? .title2 : .title3)
                    .foregroundColor(highContrast ? .black : .white)
                    .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                    .background(backgroundBlurEnabled ? (highContrast ? Color.yellow : Color.purple) : (highContrast ? Color.white : Color.white.opacity(0.2)))
                    .clipShape(Circle())
            }
            .accessibilityLabel(backgroundBlurEnabled ? "Background Blur On" : "Background Blur Off")
            .accessibilityHint("Toggles background blur effect")
            
            // Toggle video
            Button(action: toggleVideo) {
                Image(systemName: streamingService.isVideoEnabled ? "video.fill" : "video.slash.fill")
                    .font(largerButtons ? .title2 : .title3)
                    .foregroundColor(highContrast ? .black : .white)
                    .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                    .background(streamingService.isVideoEnabled ? (highContrast ? Color.green : Color.blue) : Color.gray)
                    .clipShape(Circle())
            }
            .accessibilityLabel(streamingService.isVideoEnabled ? "Video On" : "Video Off")
            .accessibilityHint("Toggles video stream")
            
            // Toggle audio
            Button(action: { streamingService.toggleAudio() }) {
                Image(systemName: streamingService.isAudioEnabled ? "mic.fill" : "mic.slash.fill")
                    .font(largerButtons ? .title2 : .title3)
                    .foregroundColor(highContrast ? .black : .white)
                    .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                    .background(streamingService.isAudioEnabled ? (highContrast ? Color.green : Color.blue) : Color.gray)
                    .clipShape(Circle())
            }
            .accessibilityLabel(streamingService.isAudioEnabled ? "Microphone On" : "Microphone Off")
            .accessibilityHint("Toggles microphone")
            
            // Toggle chat overlay
            Button(action: { showChatOverlay.toggle() }) {
                Image(systemName: showChatOverlay ? "bubble.left.fill" : "bubble.left")
                    .font(largerButtons ? .title2 : .title3)
                    .foregroundColor(highContrast ? .black : .white)
                    .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                    .background(showChatOverlay ? (highContrast ? Color.yellow : Color.purple) : (highContrast ? Color.white : Color.white.opacity(0.2)))
                    .clipShape(Circle())
                    .overlay(
                        Group {
                            if unreadMessageCount > 0 {
                                Text("\(unreadMessageCount)")
                                    .font(.caption2)
                                    .font(.body.weight(.bold))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 12, y: -12)
                            }
                        }
                    )
            }
            .accessibilityLabel(showChatOverlay ? "Chat Visible" : "Chat Hidden")
            .accessibilityHint("Toggles chat overlay")
            
            // Highlights button
            Button(action: { showingHighlights.toggle() }) {
                Image(systemName: "star.fill")
                    .font(largerButtons ? .title2 : .title3)
                    .foregroundColor(.yellow)
                    .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Highlights")
            
            // Share button
            Button(action: { showingShareSheet = true }) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(largerButtons ? .title2 : .title3)
                    .foregroundColor(highContrast ? .black : .white)
                    .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                    .background(highContrast ? Color.white : Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Share Stream")
            
            // Analytics button
            Button(action: { showingAnalytics.toggle() }) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(largerButtons ? .title2 : .title3)
                    .foregroundColor(highContrast ? .black : .white)
                    .frame(width: largerButtons ? 60 : 50, height: largerButtons ? 60 : 50)
                    .background(highContrast ? Color.white : Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Analytics")
            
            // Stop broadcasting
            Button(action: stopAndDismiss) {
                Image(systemName: "stop.circle.fill")
                    .font(largerButtons ? .title : .title2)
                    .foregroundColor(.white)
                    .frame(width: largerButtons ? 66 : 56, height: largerButtons ? 66 : 56)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Stop Broadcasting")
            .accessibilityHint("Ends the live stream")
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .frame(height: 80, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .frame(height: 80)
        .fixedSize(horizontal: false, vertical: true)
        .clipped()
        .contentShape(Rectangle())
    }
    
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Video Quality"),
                    footer: Text(getQualityDescription(videoQuality))
                ) {
                    // Use List-style picker for better interactivity
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        Button(action: {
                            videoQuality = quality
                            print("Video quality changed to: \(quality.rawValue)")
                        }) {
                            HStack {
                                Text(quality.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if videoQuality == quality {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .font(.body.weight(.semibold))
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Network Status")) {
                    HStack {
                        Text("Connection")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(networkQuality.color)
                                .frame(width: 8, height: 8)
                            Text(networkQuality.rawValue)
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("Recording")) {
                    Toggle("Record Session", isOn: $isRecording)
                }
                
                Section(header: Text("Performance")) {
                    Toggle("Battery Saver Mode", isOn: $batterySaverEnabled)
                        .onChange(of: batterySaverEnabled) { _, enabled in
                            if enabled {
                                videoQuality = .sd
                            }
                        }
                    
                    Toggle("Auto Quality Adjustment", isOn: $autoQualityAdjustment)
                        .onChange(of: autoQualityAdjustment) { _, enabled in
                            if enabled {
                                startAutoQualityAdjustment()
                            } else {
                                stopAutoQualityAdjustment()
                            }
                        }
                }
                
                Section(header: Text("Playback")) {
                    Toggle("Background Audio", isOn: $backgroundAudioEnabled)
                        .onChange(of: backgroundAudioEnabled) { _, enabled in
                            if enabled {
                                setupBackgroundAudio()
                            }
                        }
                    
                    Toggle("Picture-in-Picture", isOn: $pipEnabled)
                        .onChange(of: pipEnabled) { _, enabled in
                            if enabled {
                                setupPictureInPicture()
                            } else {
                                stopPictureInPicture()
                            }
                        }
                    
                    Toggle("AirPlay", isOn: $airPlayEnabled)
                        .onChange(of: airPlayEnabled) { _, enabled in
                            if enabled {
                                setupBackgroundAudio() // AirPlay requires background audio category
                            }
                        }
                }
                
                Section(header: Text("Network")) {
                    Toggle("Offline Mode", isOn: $isOfflineMode)
                    if isOfflineMode {
                        Text("Stream will be cached for offline viewing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Broadcast Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showingSettings = false }
                }
            }
        }
        .sheet(isPresented: $showingAccessibilitySettings) {
            accessibilitySettingsSheet
        }
    }
    
    private var accessibilitySettingsSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Visual")) {
                    Toggle("High Contrast Mode", isOn: $highContrast)
                    Toggle("Larger Buttons", isOn: $largerButtons)
                }
                
                Section(header: Text("Audio")) {
                    Toggle("Closed Captions", isOn: $closedCaptionsEnabled)
                    if closedCaptionsEnabled {
                        Text("Captions will appear when available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Control")) {
                    Toggle("Voice Control", isOn: $voiceControlEnabled)
                    if voiceControlEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Voice Commands:")
                                .font(.subheadline)
                                .font(.body.weight(.semibold))
                            Text("• \"Start stream\" - Begin broadcasting")
                            Text("• \"Stop stream\" - End broadcasting")
                            Text("• \"Mute\" - Toggle microphone")
                            Text("• \"Camera flip\" - Switch camera")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Accessibility Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showingAccessibilitySettings = false }
                }
            }
        }
    }
    
    private var quickSettingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Background Blur Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "camera.filters")
                                .font(.title3)
                                .foregroundColor(.purple)
                            Text("Background Blur")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Toggle(isOn: $backgroundBlurEnabled) {
                            Text("Enable background blur effect")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .tint(.purple)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Video Filters Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                            Text("Video Filter")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                            HStack(spacing: 12) {
                                ForEach(VideoFilter.allCases, id: \.self) { filter in
                                    Button(action: { selectedFilter = filter }) {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedFilter == filter ? Color.purple.opacity(0.2) : Color(.systemGray5))
                                                    .frame(width: 60, height: 60)
                                                
                                                Image(systemName: selectedFilter == filter ? "checkmark.circle.fill" : "circle")
                                                    .font(.title2)
                                                    .foregroundColor(selectedFilter == filter ? .purple : .gray)
                                            }
                                            
                                            Text(filter.rawValue)
                                                .font(.caption)
                                                .font(.body.weight(selectedFilter == filter ? .semibold : .regular))
                                                .foregroundColor(selectedFilter == filter ? .purple : .primary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedFilter == filter ? Color.purple.opacity(0.1) : Color(.systemGray6))
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Battery Saver Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "battery.25")
                                .font(.title3)
                                .foregroundColor(.orange)
                            Text("Battery Saver")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Toggle(isOn: $batterySaverEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable battery saver mode")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Reduces video quality to save battery")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.orange)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Quick Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingQuickSettings = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Deprecated: controlsSectionWithModifiers removed
    // This view is no longer needed as controls are now in safeAreaInset
    private var controlsSectionWithModifiers_DEPRECATED: some View {
        VStack(spacing: 16) {
            sessionInfoHeader
            if isHost && streamingService.isStreaming {
                streamStatsView
            }
        }
        .padding(.bottom)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
            .sheet(isPresented: $showingSettings) {
                settingsSheet
            }
            .sheet(isPresented: $showingQuickSettings) {
                quickSettingsSheet
            }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func flipCamera() {
        isUsingFrontCamera.toggle()
        streamingService.flipCamera(toFront: isUsingFrontCamera)
    }
    
    private func toggleVideo() {
        streamingService.toggleVideo()
    }
    
    private func startStreamTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            streamTimer += 1
        }
    }
    
    private func stopStreamTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startNetworkMonitoring() {
        // Monitor network usage (simplified - in production, use actual network monitoring)
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // Update network usage stats
            // This is a placeholder - implement actual network monitoring
            networkUsage.bytesSent += Int64.random(in: 100000...500000)
            
            // Auto quality adjustment based on network
            if autoQualityAdjustment {
                checkAndAdjustQuality()
            }
        }
    }
    
    private func startAutoQualityAdjustment() {
        qualityAdjustmentTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            checkAndAdjustQuality()
        }
    }
    
    private func stopAutoQualityAdjustment() {
        qualityAdjustmentTimer?.invalidate()
        qualityAdjustmentTimer = nil
    }
    
    // MARK: - Auto-Hide Controls
    
    private func resetAutoHideTimer() {
        lastInteractionTime = Date()
        autoHideControlsTimer?.invalidate()
        
        // Auto-hide controls after 3 seconds of inactivity (hosts only)
        // Only auto-hide if controls are currently visible
        if isHost && streamingService.isStreaming && controlsVisible {
            let startTime = Date()
            autoHideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                DispatchQueue.main.async {
                    // Only hide if still visible and enough time has passed
                    if self.controlsVisible && Date().timeIntervalSince(startTime) >= 3.0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.controlsVisible = false
                        }
                    }
                }
            }
        }
    }
    
    private func checkAndAdjustQuality() {
        // Simulate network quality check
        let currentQuality = networkQuality
        
        // Adjust quality based on network conditions
        switch currentQuality {
        case .poor:
            if videoQuality != .low {
                videoQuality = .low
                showQualityChangeNotification("Quality reduced due to poor connection")
            }
        case .fair:
            if videoQuality == .fullHD || videoQuality == .hd {
                videoQuality = .sd
                showQualityChangeNotification("Quality adjusted for better stability")
            }
        case .good, .excellent:
            // Can maintain or improve quality
            break
        }
    }
    
    private func showQualityChangeNotification(_ message: String) {
        // In production, show a toast or banner notification
        print("Quality adjustment: \(message)")
    }
    
    private func startBroadcasting() {
        guard let session = session else { return }
        isLoading = true
        
        Task {
            do {
                // Request camera and microphone permissions before starting
                await requestPermissions()
                
                let userId = userService.userIdentifier
                try await streamingService.startBroadcast(sessionId: session.id, userId: userId)
                isLoading = false
                
                // Setup local video view after broadcast starts
                await setupLocalVideoView()
                
                // Show info message if running in simulator or camera unavailable
                #if targetEnvironment(simulator)
                // In simulator, show a friendly message that audio-only streaming is active
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    errorMessage = "Streaming in audio-only mode (camera not available in simulator)"
                    showingError = true
                }
                #else
                if !streamingService.isVideoEnabled {
                    // Camera unavailable on real device - show info
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        errorMessage = "Streaming in audio-only mode (camera not available)"
                        showingError = true
                    }
                }
                #endif
            } catch {
                isLoading = false
                // Provide more helpful error messages
                if error.localizedDescription.contains("Camera") {
                    #if targetEnvironment(simulator)
                    errorMessage = "Camera is not available in simulator. Audio-only streaming is available. On a real device, camera will work normally."
                    #else
                    errorMessage = "Camera is not available. Please check camera permissions in Settings or use audio-only mode."
                    #endif
                } else {
                    errorMessage = "Failed to start broadcasting: \(error.localizedDescription)"
                }
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
                if hlsService.getPreviewLayer() != nil {
                    print("✅ [CAMERA] Local video preview layer set up successfully (attempt \(attempt))")
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
            if !streamingService.isVideoEnabled {
                print("⚠️ [CAMERA] Preview layer not available - video may be disabled or permissions not granted")
            }
        }
    }
    
    private func joinAsViewer() async {
        // In production, fetch stream URL from your backend
        if let streamURL = streamingService.streamURL {
            await streamingService.joinAsViewer(streamURL: streamURL)
        }
    }
    
    private func stopAndDismiss() {
        stopPictureInPicture()
        streamingService.stopBroadcast()
        stopAutoQualityAdjustment()
        dismiss()
    }
    
    // MARK: - Accessibility & Technical Features
    
    private func setupBackgroundAudio() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup background audio: \(error)")
        }
    }
    
    private func setupPictureInPicture() {
        // Check if PiP is supported on this device
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("⚠️ Picture-in-Picture is not supported on this device")
            Task { @MainActor in
                pipEnabled = false
            }
            return
        }
        
        // Check if streaming is active
        guard streamingService.isStreaming else {
            print("⚠️ Cannot setup PiP - stream not active")
            Task { @MainActor in
                pipEnabled = false
                errorMessage = "Please start streaming first to enable Picture-in-Picture"
                showingError = true
            }
            return
        }
        
        // For both hosts and viewers: Use the stream URL to create an AVPlayer
        // Note: In production, this would be a real HLS stream URL
        if let streamURL = streamingService.streamURL {
            setupPiPForViewer(streamURL: streamURL)
        } else {
            print("⚠️ Cannot setup PiP - stream URL not available")
            Task { @MainActor in
                pipEnabled = false
                errorMessage = "Stream URL not available. Please ensure the stream is active."
                showingError = true
            }
        }
    }
    
    private func setupPiPForViewer(streamURL: URL) {
        // Create AVPlayer with the stream URL
        let player = AVPlayer(url: streamURL)
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        
        // Create player layer - must be added to a view's layer hierarchy
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 1) // Small hidden frame
        
        // Create PiP controller
        guard let pipController = AVPictureInPictureController(playerLayer: playerLayer) else {
            print("❌ Failed to create PiP controller - not supported or unavailable")
            Task { @MainActor in
                pipEnabled = false
            }
            return
        }
        
        pipController.canStartPictureInPictureAutomaticallyFromInline = false
        
        // Set up coordinator for delegate methods
        let coordinator = PiPCoordinator(
            onStart: {
                print("✅ Picture-in-Picture started")
            },
            onStop: {
                print("✅ Picture-in-Picture stopped")
            },
            onFailed: { error in
                print("❌ Picture-in-Picture failed: \(error.localizedDescription)")
                Task { @MainActor in
                    self.pipEnabled = false
                }
            }
        )
        
        pipController.delegate = coordinator
        
        // Store references
        self.pipPlayer = player
        self.pipPlayerLayer = playerLayer
        self.pipController = pipController
        self.pipCoordinator = coordinator
        
        // Start playing
        player.play()
        
        // Wait a moment for player to be ready, then start PiP
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.pipEnabled && pipController.isPictureInPicturePossible {
                pipController.startPictureInPicture()
            } else if !pipController.isPictureInPicturePossible {
                print("⚠️ PiP is not possible yet - player may not be ready")
                // Try again after a longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.pipEnabled && pipController.isPictureInPicturePossible {
                        pipController.startPictureInPicture()
                    } else {
                        print("❌ PiP still not possible")
                        Task { @MainActor in
                            self.pipEnabled = false
                        }
                    }
                }
            }
        }
        
        print("✅ Picture-in-Picture setup complete for viewer")
    }
    
    private func setupPiPForHost() {
        // For host, we need to create a player from the preview layer
        // This is more complex and typically requires recording the preview
        // For now, we'll use the stream URL if available
        if let streamURL = streamingService.streamURL {
            setupPiPForViewer(streamURL: streamURL)
        } else {
            print("⚠️ Host PiP requires stream URL - not available yet")
            Task { @MainActor in
                pipEnabled = false
            }
        }
    }
    
    private func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
        pipPlayer?.pause()
        pipPlayer = nil
        pipPlayerLayer = nil
        pipController = nil
        pipCoordinator = nil
    }
    
    // Voice control handler
    private func handleVoiceCommand(_ command: String) {
        guard voiceControlEnabled else { return }
        
        let lowercased = command.lowercased()
        
        if lowercased.contains("start") && lowercased.contains("stream") {
            startBroadcasting()
        } else if lowercased.contains("stop") && lowercased.contains("stream") {
            stopAndDismiss()
        } else if lowercased.contains("mute") {
            streamingService.toggleAudio()
        } else if lowercased.contains("camera") && lowercased.contains("flip") {
            flipCamera()
        } else if lowercased.contains("video") {
            toggleVideo()
        }
    }
    
    // MARK: - Helper Functions
    
    private func getQualityDescription(_ quality: VideoQuality) -> String {
        switch quality {
        case .low:
            return "Best for slow connections, uses less data"
        case .sd:
            return "Good balance of quality and data usage"
        case .hd:
            return "High quality, recommended for most users"
        case .fullHD:
            return "Best quality, requires strong connection"
        }
    }
    
    // MARK: - Chat Functions
    
    private func sendChatMessage() {
        guard let session = session, !chatMessageText.isEmpty else { return }
        
        let userId = userService.userIdentifier
        let userName = userService.displayName
        
        let message = ChatMessage(
            sessionId: session.id,
            userId: userId,
            userName: userName,
            message: chatMessageText,
            messageType: .text
        )
        modelContext.insert(message)
        
        do {
            try modelContext.save()
            chatMessageText = ""
            
            // CloudKitPublicSyncService removed - use Firebase for sync
            // if userService.isAuthenticated && !session.isPrivate {
            //     // Sync message to Firebase
            // }
        } catch {
            print("Error sending chat message: \(error)")
        }
    }
    
    private func loadPublicMessages() {
        // CloudKitPublicSyncService removed - use Firebase for sync
        // guard let session = session, userService.isAuthenticated else { return }
        // Load messages from Firebase
        publicMessages = []
    }
    
    private func setupMessageSubscription() {
        // CloudKitPublicSyncService removed - use Firebase for sync
        // guard let session = session, userService.isAuthenticated else { return }
        // Setup Firebase message listener
        
        // CloudKitPublicSyncService removed - use Firebase for sync
        // Task {
        //     do {
        //         try await sync.subscribeToMessages(for: session.id)
        //         // Poll for new messages periodically
        //         Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
        //             loadPublicMessages()
        //         }
        //     } catch {
        //         print("Error setting up message subscription: \(error)")
        //     }
        // }
    }
}

// MARK: - Supporting Views

@available(iOS 17.0, *)
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    var backgroundBlurEnabled: Bool = false
    var selectedFilter: BroadcastStreamView_HLS.VideoFilter = .none
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        // Apply initial filter
        applyFilter(to: previewLayer, filter: selectedFilter, blur: backgroundBlurEnabled)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
            applyFilter(to: previewLayer, filter: selectedFilter, blur: backgroundBlurEnabled)
        }
    }
    
    private func applyFilter(to layer: CALayer, filter: BroadcastStreamView_HLS.VideoFilter, blur: Bool) {
        // Remove existing filters
        layer.filters = nil
        
        var filters: [CIFilter] = []
        
        // Apply video filter
        switch filter {
        case .none:
            break
        case .sepia:
            if let sepiaFilter = CIFilter(name: "CISepiaTone") {
                sepiaFilter.setValue(0.8, forKey: kCIInputIntensityKey)
                filters.append(sepiaFilter)
            }
        case .blackAndWhite:
            if let bwFilter = CIFilter(name: "CIColorMonochrome") {
                bwFilter.setValue(CIColor.gray, forKey: kCIInputColorKey)
                bwFilter.setValue(1.0, forKey: kCIInputIntensityKey)
                filters.append(bwFilter)
            }
        case .vibrant:
            if let vibrantFilter = CIFilter(name: "CIColorControls") {
                vibrantFilter.setValue(1.2, forKey: kCIInputSaturationKey)
                vibrantFilter.setValue(1.1, forKey: kCIInputContrastKey)
                filters.append(vibrantFilter)
            }
        case .cool:
            if let coolFilter = CIFilter(name: "CITemperatureAndTint") {
                coolFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                coolFilter.setValue(CIVector(x: 8000, y: 0), forKey: "inputTargetNeutral")
                filters.append(coolFilter)
            }
        case .warm:
            if let warmFilter = CIFilter(name: "CITemperatureAndTint") {
                warmFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                warmFilter.setValue(CIVector(x: 5000, y: 0), forKey: "inputTargetNeutral")
                filters.append(warmFilter)
            }
        }
        
        // Apply background blur if enabled
        if blur {
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(10.0, forKey: kCIInputRadiusKey)
                filters.append(blurFilter)
            }
        }
        
        // Apply filters to layer
        if !filters.isEmpty {
            layer.filters = filters
        }
    }
}

// Note: Shared helper views `PlaceholderView`, `LoadingView`, and `StatusPill`
// are defined in the LiveKit view to avoid duplicate global declarations.

// MARK: - Custom TextField Component

struct CustomTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.textColor = .white
        textField.tintColor = .white
        textField.font = .systemFont(ofSize: 17)
        
        // Set placeholder with white color that's visible in dark mode
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
        )
        
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = .white
        uiView.tintColor = .white
        
        // Update placeholder color every time to ensure it's visible
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}

// MARK: - Chat Overlay Component

@available(iOS 17.0, *)
struct LiveStreamChatOverlay: View {
    let session: LiveSession
    let messages: [ChatMessage]
    @Binding var messageText: String
    let onSend: () -> Void
    let onDismiss: () -> Void
    
    @State private var showingEmojiPicker = false
    @State private var isMinimized = false
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0
    
    private let minimizedHeight: CGFloat = 60
    private let expandedHeight: CGFloat = 220
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.vertical, 8)
                Spacer()
            }
            .background(Color.black.opacity(0.8))
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isMinimized.toggle()
                }
            }
            
            if !isMinimized {
                // Compact header
                HStack {
                    Text("Chat")
                        .font(.subheadline)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                
                // Messages list (compact)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(messages) { message in
                                ChatMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .onAppear {
                            if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                    .background(Color.black.opacity(0.6))
                }
                
                // Input area (already compact)
                HStack(spacing: 10) {
                    // Emoji button
                    Button(action: { showingEmojiPicker.toggle() }) {
                        Image(systemName: "face.smiling")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    // Text input with pill shape
                    CustomTextField(placeholder: "Type a message...", text: $messageText)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(18)
                        .frame(minHeight: 28)
                        .onSubmit {
                            if !messageText.isEmpty {
                                onSend()
                            }
                        }
                    
                    Button(action: {
                        if !messageText.isEmpty {
                            onSend()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(messageText.isEmpty ? .gray : .purple)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.8))
            } else {
                // Minimized state - just show message count and input
                HStack(spacing: 10) {
                    // Message count badge
                    if !messages.isEmpty {
                        Text("\(messages.count)")
                            .font(.caption)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                    
                    // Compact input
                    CustomTextField(placeholder: "Type a message...", text: $messageText)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(18)
                        .frame(minHeight: 28)
                        .onSubmit {
                            if !messageText.isEmpty {
                                onSend()
                            }
                        }
                    
                    Button(action: {
                        if !messageText.isEmpty {
                            onSend()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundColor(messageText.isEmpty ? .gray : .purple)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isMinimized ? minimizedHeight : expandedHeight)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.9))
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newOffset = value.translation.height + lastDragValue
                    // Only allow dragging up (negative) or down (positive) within bounds
                    if newOffset <= 0 && newOffset >= -(expandedHeight - minimizedHeight) {
                        dragOffset = newOffset
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 30
                    if value.translation.height > threshold {
                        // Dragged down - minimize
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMinimized = true
                            dragOffset = 0
                        }
                    } else if value.translation.height < -threshold {
                        // Dragged up - expand
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMinimized = false
                            dragOffset = 0
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                    lastDragValue = 0
                }
        )
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView { emoji in
                messageText += emoji
                showingEmojiPicker = false
            }
        }
    }
}

// MARK: - Emoji Picker Component

@available(iOS 17.0, *)
struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void
    
    // Popular emojis organized by category
    let emojiCategories: [(String, [String])] = [
        ("Smileys & People", ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "🤭", "🤫", "🤥", "😶", "😐", "😑", "😬", "🙄", "😯", "😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪", "😵", "🤐", "🥴", "🤢", "🤮", "🤧", "😷", "🤒", "🤕", "🤑", "🤠", "😈", "👿", "👹", "👺", "🤡", "💩", "👻", "💀", "☠️", "👽", "👾", "🤖", "🎃"]),
        ("Hands & Gestures", ["👋", "🤚", "🖐", "✋", "🖖", "👌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏", "✍️", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🧠", "🦷", "🦴", "👀", "👁", "👅", "👄"]),
        ("Hearts & Emotions", ["💋", "💘", "💝", "💖", "💗", "💓", "💞", "💕", "💟", "❣️", "💔", "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💯", "💢", "💥", "💫", "💦", "💨", "🕳️", "💣", "💬", "👁️‍🗨️", "🗨️", "🗯️", "💭", "💤"]),
        ("Prayer & Faith", ["🙏", "✝️", "☦️", "☪️", "🕉️", "🕎", "☸️", "☯️", "🛐", "⛪", "🕌", "🕍", "⛩️", "🕋", "⛲", "⛺", "🌁", "🌃", "🌄", "🌅", "🌆", "🌇", "🌉", "♨️", "🎆", "🎇", "✨", "🌟", "💫", "⭐", "🌠", "☄️", "💥", "🔥", "🌈", "☀️", "⛅", "☁️", "⛈️", "🌤️", "🌦️", "🌧️", "⛈️", "🌩️", "🌨️", "❄️", "☃️", "⛄", "🌬️", "💨", "💧", "💦", "☔", "☂️", "🌊", "🌫️"]),
        ("Celebration", ["🎉", "🎊", "🎈", "🎁", "🎀", "🎂", "🍰", "🧁", "🍭", "🍬", "🍫", "🍿", "🍩", "🍪", "🌰", "🥜", "🍯", "🥛", "🍼", "☕", "🍵", "🧃", "🥤", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹", "🧉", "🍾", "🧊"]),
        ("Common Reactions", ["👍", "👎", "❤️", "🔥", "😊", "😍", "😂", "😮", "😢", "🙏", "👏", "🎉", "💯", "✨", "🌟", "🙌", "👌", "💪", "🤔", "😎"])
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(emojiCategories, id: \.0) { category, emojis in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Button(action: {
                                        onSelect(emoji)
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 40))
                                            .frame(width: 50, height: 50)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Emoji Picker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar placeholder
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(message.userName.prefix(1)).uppercased())
                        .font(.caption)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Username
                Text(message.userName)
                    .font(.caption)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                // Message bubble
                Text(message.message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.messageType == .prayer ?
                        Color.purple.opacity(0.7) :
                        Color.white.opacity(0.2)
                    )
                    .cornerRadius(12)
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}

struct StreamInfoView: View {
    let url: URL
    
    var body: some View {
        Color.black
            .overlay(
                VStack(spacing: 20) {
                    Image(systemName: "video.badge.checkmark")
                        .font(.system(size: 60))
                        .foregroundColor(.green.opacity(0.7))
                    
                    Text("Stream is Live")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Broadcasting via native iOS camera")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    VStack(spacing: 8) {
                        Text("Stream URL:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Text(url.absoluteString)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                    }
                }
            )
    }
}

// MARK: - PiP Player Layer View

@available(iOS 17.0, *)
struct PiPPlayerLayerView: UIViewRepresentable {
    let playerLayer: AVPlayerLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.backgroundColor = .clear
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            playerLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Picture-in-Picture Coordinator

class PiPCoordinator: NSObject, AVPictureInPictureControllerDelegate {
    let onStart: () -> Void
    let onStop: () -> Void
    let onFailed: (Error) -> Void
    
    init(onStart: @escaping () -> Void, onStop: @escaping () -> Void, onFailed: @escaping (Error) -> Void) {
        self.onStart = onStart
        self.onStop = onStop
        self.onFailed = onFailed
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        onStart()
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("✅ PiP started successfully")
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        onStop()
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("✅ PiP stopped")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        onFailed(error)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // Restore the user interface when PiP stops
        completionHandler(true)
    }
}

// MARK: - Preview


// MARK: - Horizontal Only ScrollView

@available(iOS 17.0, *)
struct HorizontalOnlyScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false // Disable horizontal bouncing to prevent scrolling off left edge
        scrollView.alwaysBounceVertical = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.isScrollEnabled = true
        scrollView.bounces = false // Disable all bouncing to prevent scrolling past edges
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = context.coordinator
        
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        scrollView.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.hostingController = hostingController
        context.coordinator.scrollView = scrollView
        
        // Set up constraints - lock height to prevent vertical movement
        // Add leading padding to match the HStack padding
        let heightConstraint = hostingController.view.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        heightConstraint.priority = .required
        // Use contentInset for padding instead of constraints to prevent scroll position issues
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 0), // Start at 0, padding via contentInset
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 0),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            heightConstraint
        ])
        
        // Update content size after layout
        DispatchQueue.main.async {
            hostingController.view.setNeedsLayout()
            hostingController.view.layoutIfNeeded()
            let contentWidth = hostingController.view.systemLayoutSizeFitting(
                CGSize(width: UIView.layoutFittingExpandedSize.width, height: scrollView.frame.height),
                withHorizontalFittingPriority: .defaultLow,
                verticalFittingPriority: .required
            ).width
            // Content width already includes padding from constraints, so use it directly
            // Ensure content size is at least the frame width to prevent scrolling when content is smaller
            let minContentWidth = max(contentWidth, scrollView.frame.width)
            scrollView.contentSize = CGSize(width: minContentWidth, height: scrollView.frame.height)
            // Set content inset for padding (this doesn't affect scroll position)
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            // With contentInset.left = 16, offset of -16 shows content at left edge
            scrollView.contentOffset = CGPoint(x: -16, y: 0)
            scrollView.bounces = false
            scrollView.alwaysBounceHorizontal = false
            // Set content inset to 0 to prevent any offset issues
            scrollView.contentInset = .zero
            scrollView.scrollIndicatorInsets = .zero
        }
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        guard let hostingView = context.coordinator.hostingController?.view else { return }
        
        // Ensure vertical scrolling is completely disabled and disable bouncing
        uiView.alwaysBounceHorizontal = false // Disable horizontal bouncing
        uiView.alwaysBounceVertical = false
        uiView.showsVerticalScrollIndicator = false
        uiView.isDirectionalLockEnabled = true
        uiView.contentInsetAdjustmentBehavior = .never
        uiView.bounces = false // Disable all bouncing to prevent scrolling past edges
        
        // Lock vertical offset to 0 and prevent negative x scrolling immediately
        var currentOffset = uiView.contentOffset
        if currentOffset.y != 0 {
            currentOffset.y = 0
        }
        if currentOffset.x < 0 {
            currentOffset.x = 0
        }
        if currentOffset != uiView.contentOffset {
            uiView.contentOffset = currentOffset
        }
        
        // Update content size
        DispatchQueue.main.async {
            hostingView.setNeedsLayout()
            hostingView.layoutIfNeeded()
            let contentWidth = hostingView.systemLayoutSizeFitting(
                CGSize(width: UIView.layoutFittingExpandedSize.width, height: uiView.frame.height),
                withHorizontalFittingPriority: .defaultLow,
                verticalFittingPriority: .required
            ).width
            // Add 16pt for leading padding when calculating content size
            let totalContentWidth = contentWidth + 16
            uiView.contentSize = CGSize(width: max(totalContentWidth, uiView.frame.width), height: uiView.frame.height)
            // Ensure bouncing is disabled to prevent scrolling past edges
            uiView.bounces = false
            uiView.alwaysBounceHorizontal = false
            
            // Ensure vertical offset stays at 0 and prevent negative x scrolling
            var newOffset = uiView.contentOffset
            if newOffset.y != 0 {
                newOffset.y = 0
            }
            if newOffset.x < 0 {
                newOffset.x = 0
            }
            if newOffset != uiView.contentOffset {
                uiView.setContentOffset(newOffset, animated: false)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?
        var scrollView: UIScrollView?
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Lock vertical scrolling - if user tries to scroll vertically, reset to 0
            var newOffset = scrollView.contentOffset
            var needsUpdate = false
            
            if newOffset.y != 0 {
                newOffset.y = 0
                needsUpdate = true
            }
            // Prevent scrolling to negative x (left edge) - buttons must always be visible
            // Account for contentInset: with left inset of 16, minimum offset is -16
            let minOffset: CGFloat = -16.0
            if newOffset.x < minOffset {
                newOffset.x = minOffset
                needsUpdate = true
            }
            
            // Apply the corrected offset immediately without animation
            if needsUpdate {
                scrollView.setContentOffset(newOffset, animated: false)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            // Prevent scrolling to negative x even when dragging ends
            // Account for contentInset: minimum offset is -16
            let minOffset: CGFloat = -16.0
            if targetContentOffset.pointee.x < minOffset {
                targetContentOffset.pointee.x = minOffset
            }
            if targetContentOffset.pointee.y != 0 {
                targetContentOffset.pointee.y = 0
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            // Final check after deceleration to ensure we're not at negative offset
            // Account for contentInset: minimum offset is -16
            let minOffset: CGFloat = -16.0
            if scrollView.contentOffset.x < minOffset {
                scrollView.setContentOffset(CGPoint(x: minOffset, y: 0), animated: false)
            }
            if scrollView.contentOffset.y != 0 {
                scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: 0), animated: false)
            }
        }
    }
}

// Preview for iOS 17+
@available(iOS 17.0, *)
struct BroadcastStreamView_HLS_Previews: PreviewProvider {
    static var previews: some View {
        let session = LiveSession(
            title: "Sunday Morning Service",
            description: "Join us for worship",
            hostId: "test-user",
            category: "Worship"
        )
        NavigationStack {
            BroadcastStreamView_HLS(session: session)
        }
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    let message: String
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}

struct StatusPill: View {
    let icon: String
    let text: String
    let color: Color

    init(icon: String, text: String, color: Color = .gray) {
        self.icon = icon
        self.text = text
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption2)
                .font(.body.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.8))
        .cornerRadius(12)
    }
}
