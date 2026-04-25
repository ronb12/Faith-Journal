//
//  MultiParticipantStreamView.swift
//  Faith Journal
//
//  Enhanced live streaming view with multiple participants support using Agora
//
//  MODES:
//  - Broadcast: One presenter (host), many viewers (audience). Host can promote viewers to presenters.
//  - Conference: All participants can share video/audio. Grid view by default, shows all participants.
//                 Best for small to medium groups (2-10 people).
//  - Multi-Participant: All participants can share with enhanced features for larger groups.
//                       Speaker view by default, auto-focuses on active speaker, limits visible tiles
//                       for performance. Best for larger groups (10+ people).
//

import QuickLook
import SwiftUI
import SwiftData
import AVFoundation
import UIKit
import UniformTypeIdentifiers
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@available(iOS 17.0, *)
struct MultiParticipantStreamView: View {
    let session: LiveSession
    let customChannelName: String?
    let breakoutRoomTitle: String?
    let streamMode: StreamMode // Add stream mode to differentiate behavior
    // Use AgoraService instead of UnifiedStreamingService
    @ObservedObject private var agoraService = AgoraService.shared
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    @ObservedObject private var presentationService = PresentationService.shared
    @State private var showingMaterialPicker = false
    @State private var showingPresentationSheet = false
    @State private var showingBibleStudySelector = false
    @State private var isHostPaused = false
    @State private var hostPausedVideoState: Bool?
    @State private var hostPausedAudioState: Bool?
    @State private var countdownSeconds: Int? = nil
    @State private var countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Stream mode enum (matches LiveSessionsView)
    enum StreamMode {
        case broadcast    // One presenter, many viewers
        case conference   // All can present
        case multiParticipant // All can present with enhanced features
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var userProfiles: [UserProfile]
    @Query var allMessages: [ChatMessage]
    @Query(filter: #Predicate<LiveSessionParticipant> { $0.isActive == true }) var allParticipants: [LiveSessionParticipant]
    private var userProfile: UserProfile? { userProfiles.first }
    
    // Get the current user's session display name (prioritizes edited session name over profile name)
    private var sessionDisplayName: String {
        // ALWAYS use profile name from settings - never device name
        // First check the LocalUserService (or stored profile) for a name
        let profileName = userService.getDisplayName(userProfile: userProfile).trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileName.isEmpty {
            let isDeviceName = profileName.contains("iPhone") || 
                             profileName.contains("iPad") || 
                             profileName == UIDevice.current.name
            if !isDeviceName {
                return profileName
            }
        }
        if !profileName.isEmpty {
            let isDeviceName = profileName.contains("iPhone") || 
                             profileName.contains("iPad") || 
                             profileName == UIDevice.current.name
            if !isDeviceName {
                return profileName
            }
        }
        
        // Check if participant has a valid edited name (not device name)
        let userId = userService.userIdentifier
        if let currentUserParticipant = sessionParticipants.first(where: { $0.userId == userId }) {
            let storedName = currentUserParticipant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || 
                                   storedName.contains("iPad") || 
                                   storedName == UIDevice.current.name
            
            // Use stored name only if it's not a device name
            if !storedName.isEmpty && !isStoredNameDevice {
                return storedName
            }
        }
        
        // No valid profile name - return empty string (should prompt user to set name)
        // Never return device name as fallback
        return ""
    }
    
    // Get participants for this session
    private var sessionParticipants: [LiveSessionParticipant] {
        allParticipants.filter { $0.sessionId == session.id }
    }
    
    @State private var isStreaming = false
    @State private var showingError = false
    @State private var errorMessage = ""
    // Default layout mode based on stream mode
    // Conference: Grid view (all participants visible)
    // Multi-Participant: Speaker view (focus on active speaker, optimized for larger groups)
    @State private var layoutMode: LayoutMode = .grid
    @State private var participants: [ParticipantInfo] = []
    @State private var spotlightedParticipant: UInt?
    @State private var isHost = false
    @State private var showingFullScreen = false
    @State private var fullScreenParticipant: UInt?
    
    // Chat state
    @State private var showChatOverlay = false
    @State private var chatMessageText = ""
    @State private var requestState: RequestState = .idle
    
    private enum RequestState {
        case idle
        case requesting
        case requested
    }
    @State private var publicMessages: [ChatMessage] = []
    @State private var chatMessageListener: Any? // ListenerRegistration
    @State private var showingPromoteMenu = false
    @State private var selectedParticipantForPromotion: UInt?
    @State private var activeSpeakerTimer: Timer? // Timer for tracking active speakers in multi-participant mode
    
    // Cache for user names fetched from Firebase (to avoid repeated calls)
    @State private var userNameCache: [String: String] = [:]
    
    /// When the host entered the stream view. Used to avoid ending the session on immediate onDisappear (e.g. SwiftUI re-render or accidental dismiss before stream really started).
    @State private var streamEnteredAt: Date?
    
    // Mode indicator properties
    private var modeIndicator: String {
        switch streamMode {
        case .broadcast: return "📺 Broadcast"
        case .conference: return "💬 Conference"
        case .multiParticipant: return "👥 Multi"
        }
    }

    private var countdownDisplay: String? {
        guard let seconds = countdownSeconds, seconds > 0 else { return nil }
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "Time left %02d:%02d", mins, secs)
    }

    private func shareBibleStudyTopic(_ topic: BibleStudyTopic) async {
        do {
            try await presentationService.presentBibleStudy(topic: topic)
            showingPresentationSheet = true
            showingBibleStudySelector = false
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func updateSessionCountdown() {
        guard session.durationLimitMinutes > 0 else {
            countdownSeconds = nil
            return
        }
        let totalSeconds = session.durationLimitMinutes * 60
        let elapsed = Int(Date().timeIntervalSince(session.startTime))
        let remaining = max(totalSeconds - elapsed, 0)
        countdownSeconds = remaining
    }

    private var hostPauseOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "pause.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Host Away")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("The session continues for attendees. Tap resume when you return.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Button {
                    toggleHostPauseState()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(14)
            .padding(.horizontal)
            .padding(.top, 48)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .transition(.move(edge: .top))
    }

    private func toggleHostPauseState() {
        guard isHost else { return }

        if isHostPaused {
            isHostPaused = false
            if let wasVideoEnabled = hostPausedVideoState, wasVideoEnabled != agoraService.isVideoEnabled {
                agoraService.toggleVideo()
            }
            if let wasAudioEnabled = hostPausedAudioState, wasAudioEnabled != agoraService.isAudioEnabled {
                agoraService.toggleAudio()
            }
            hostPausedVideoState = nil
            hostPausedAudioState = nil
        } else {
            hostPausedVideoState = agoraService.isVideoEnabled
            hostPausedAudioState = agoraService.isAudioEnabled

            if agoraService.isVideoEnabled {
                agoraService.toggleVideo()
            }
            if agoraService.isAudioEnabled {
                agoraService.toggleAudio()
            }

            isHostPaused = true
        }
    }

    private var modeColor: Color {
        switch streamMode {
        case .broadcast: return Color.red.opacity(0.8)
        case .conference: return Color.blue.opacity(0.8)
        case .multiParticipant: return Color.purple.opacity(0.8)
        }
    }
    
    struct ParticipantInfo: Identifiable {
        let id: UInt // Agora UID
        let name: String
        var isMuted: Bool
        var isVideoEnabled: Bool
        var isSpeaking: Bool
        var isLocal: Bool // true for local user (UID 0)
    }
    
    enum LayoutMode {
        case grid
        case speaker // One large, others small
    }
    
    init(session: LiveSession, streamMode: StreamMode = .conference, customChannelName: String? = nil, breakoutRoomTitle: String? = nil) {
        self.session = session
        self.streamMode = streamMode
        self.customChannelName = customChannelName
        self.breakoutRoomTitle = breakoutRoomTitle
    }

    var body: some View {
        let titleLayer = mainContent
            .navigationTitle(breakoutRoomTitle ?? session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        leaveStream(shouldEndSessionIfHost: true)
                    }
                }
            }

        let lifecycleLayer = titleLayer
            .onAppear {
                streamEnteredAt = Date()
                updateSessionCountdown()
                Task { @MainActor in
                    if let currentUserParticipant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier }) {
                        let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !profileName.isEmpty {
                            let isProfileNameDevice = profileName.contains("iPhone") || profileName.contains("iPad")
                            let isCurrentNameDevice = currentUserParticipant.userName.contains("iPhone") || currentUserParticipant.userName.contains("iPad")
                            if isCurrentNameDevice && !isProfileNameDevice {
                                currentUserParticipant.userName = profileName
                                try? modelContext.save()
                                await FirebaseSyncService.shared.syncSessionParticipant(currentUserParticipant)
                                print("✅ [STREAM] Updated participant name to: \(profileName)")
                            }
                        }
                    }
                }
                startStreaming()
                setupMessageSubscription()

                if streamMode == .multiParticipant {
                    layoutMode = .speaker
                    startActiveSpeakerTracking()
                }
            }
            .onDisappear {
                // Only end session if host has been in stream for 5+ seconds (avoids ending when view disappears before stream really started, e.g. SwiftUI re-render or accidental dismiss)
                let shouldEnd = isHost ? (streamEnteredAt.map { Date().timeIntervalSince($0) >= 5 } ?? false) : false
                leaveStream(shouldEndSessionIfHost: shouldEnd)
                #if canImport(FirebaseFirestore)
                if let listener = chatMessageListener as? ListenerRegistration {
                    listener.remove()
                    chatMessageListener = nil
                    print("✅ [CHAT] Stopped listening to messages")
                }
                #endif
                activeSpeakerTimer?.invalidate()
                activeSpeakerTimer = nil
                userNameCache.removeAll()
            }
            .onReceive(countdownTimer) { _ in
                updateSessionCountdown()
            }
            .onChange(of: agoraService.isVideoEnabled) { _, newValue in
                if let index = participants.firstIndex(where: { $0.isLocal }) {
                    participants[index].isVideoEnabled = newValue
                }
                print("📹 [MULTI] Video toggled: \(newValue ? "ON" : "OFF")")
            }
            .onChange(of: agoraService.isAudioEnabled) { _, newValue in
                if let index = participants.firstIndex(where: { $0.isLocal }) {
                    participants[index].isMuted = !newValue
                }
            }
            .onChange(of: agoraService.remoteUsers) { _, _ in
                Task { @MainActor in
                    await updateParticipantsList()
                }
            }
            .onChange(of: agoraService.participantCount) { _, _ in
                Task { @MainActor in
                    await updateParticipantsList()
                }
            }
            .onChange(of: sessionParticipants.count) { _, _ in
                Task { @MainActor in
                    await updateParticipantsList()
                }
            }
            .onChange(of: streamMode) { _, newMode in
                if newMode != .broadcast {
                    requestState = .idle
                }
            }
            .onChange(of: agoraService.currentRole) { _, newRole in
                if newRole != .audience {
                    requestState = .idle
                }
            }

        let alertLayer = lifecycleLayer
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: agoraService.errorMessage) { _, newValue in
                if let error = newValue {
                    errorMessage = error
                    showingError = true
                }
            }

        let interactiveLayer = alertLayer
            .fullScreenCover(isPresented: $showingFullScreen) {
                if let participantId = fullScreenParticipant {
                    let isLocalParticipant = participantId == 0
                    let videoEnabled = isLocalParticipant ? agoraService.isVideoEnabled : (participants.first(where: { $0.id == participantId })?.isVideoEnabled ?? true)
                    ZStack {
                        Color.black.ignoresSafeArea()
                        AgoraVideoView(uid: participantId, isLocal: isLocalParticipant, isVideoEnabled: videoEnabled)
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
            .fileImporter(
                isPresented: $showingMaterialPicker,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    do {
                        let urls = try result.get()
                        guard let selectedURL = urls.first else { return }
                        try await presentationService.presentMaterial(from: selectedURL)
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
            .sheet(isPresented: $showingPresentationSheet) {
                if let asset = presentationService.currentAsset {
                    PresentationAssetSheet(
                        asset: asset,
                        onClose: {
                            if isHost {
                                presentationService.clearPresentation()
                            }
                            showingPresentationSheet = false
                        },
                        onStop: isHost ? { presentationService.clearPresentation(); showingPresentationSheet = false } : nil
                    )
                } else {
                    Text("Presentation is not available.")
                        .padding()
                }
            }
            .sheet(isPresented: $showingBibleStudySelector) {
                BibleStudyShareSheet(
                    topics: BibleStudyService.shared.getTopicsForLiveSession(),
                    onSelect: { topic in
                        await shareBibleStudyTopic(topic)
                    },
                    onDismiss: {
                        showingBibleStudySelector = false
                    }
                )
            }
            // Do NOT auto-show sheet when currentAsset changes — only show when host shares (shareBibleStudyTopic) or user taps View (eye). Prevents double presentation.

        return interactiveLayer
    }

    private var mainContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            layeredContent

            if let countdownText = countdownDisplay {
                VStack {
                    HStack {
                        Text(countdownText)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var layeredContent: some View {
        ZStack {
            videoGridArea
                .padding(.bottom, 160)

            VStack {
                Spacer()
                controlsOverlay
            }
            .transition(.move(edge: .bottom))

            if isHost && isHostPaused {
                hostPauseOverlay
            }
        }

        if showChatOverlay {
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

        if let roomTitle = breakoutRoomTitle {
            VStack {
                HStack {
                    Text("Breakout Room: \(roomTitle)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                Spacer()
            }
            .accessibilityLabel("Breakout Room \(roomTitle)")
        }
    }
    
    // MARK: - View Components
    
    private var videoGridArea: some View {
        GeometryReader { geometry in
            Group {
                // Conference mode: Default to grid, can switch to speaker
                // Multi-participant mode: Default to speaker, can switch to grid
                let effectiveLayoutMode: LayoutMode = {
                    if layoutMode == .grid || (layoutMode == .speaker && streamMode == .conference) {
                        return layoutMode
                    } else {
                        // Multi-participant defaults to speaker view
                        return streamMode == .multiParticipant ? .speaker : layoutMode
                    }
                }()
                
                if effectiveLayoutMode == .grid {
                    gridLayout(geometry: geometry)
                } else {
                    speakerLayout(geometry: geometry)
                }
            }
        }
        .onAppear {
            // Set default layout based on stream mode when view appears
            if streamMode == .multiParticipant && layoutMode == .grid {
                // Multi-participant mode defaults to speaker view
                layoutMode = .speaker
            }
        }
    }
    
    private var controlsOverlay: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(session.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(modeIndicator)
                            .font(.caption2)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(modeColor)
                            .clipShape(Capsule())
                    }
                    
                    let displayCount = max(session.currentParticipants, sessionParticipants.count, 1)
                    HStack(spacing: 4) {
                        Text("\(displayCount) participant\(displayCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        if streamMode == .broadcast {
                            if agoraService.isBroadcaster {
                                Text("• Broadcaster")
                                    .font(.caption2)
                                    .foregroundColor(.green.opacity(0.8))
                            } else if agoraService.isAudience {
                                Text("• Viewer")
                                    .font(.caption2)
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                        } else if streamMode == .multiParticipant {
                            Text(layoutMode == .speaker ? "• Speaker View" : "• Grid View")
                                .font(.caption2)
                                .foregroundColor(.purple.opacity(0.8))
                        }
                    }
                }
                Spacer()

                if agoraService.isBroadcaster || streamMode != .broadcast {
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
            }

            controlButtons
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.85)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .blur(radius: 0)
        )
        .cornerRadius(20)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var controlButtons: some View {
        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
            HStack(spacing: 16) {
                if agoraService.isBroadcaster || streamMode != .broadcast {
                    controlButton(
                        systemName: agoraService.isVideoEnabled ? "video.fill" : "video.slash.fill",
                        background: agoraService.isVideoEnabled ? Color.blue : Color.gray,
                        size: 50
                    ) {
                        agoraService.toggleVideo()
                        if let index = participants.firstIndex(where: { $0.isLocal }) {
                            participants[index].isVideoEnabled = agoraService.isVideoEnabled
                        }
                    }

                    controlButton(
                        systemName: agoraService.isAudioEnabled ? "mic.fill" : "mic.slash.fill",
                        background: agoraService.isAudioEnabled ? Color.blue : Color.gray,
                        size: 50
                    ) {
                        agoraService.toggleAudio()
                        if let index = participants.firstIndex(where: { $0.isLocal }) {
                            participants[index].isMuted = !agoraService.isAudioEnabled
                        }
                    }

                    if isHost {
                        controlButton(
                            systemName: isHostPaused ? "play.circle.fill" : "pause.circle.fill",
                            background: isHostPaused ? Color.green : Color.orange,
                            size: 50
                        ) {
                            toggleHostPauseState()
                        }

                        controlButton(systemName: "doc.richtext", background: Color.green, size: 50) {
                            showingMaterialPicker = true
                        }

                        controlButton(systemName: "book.circle.fill", background: Color.orange, size: 50) {
                            showingBibleStudySelector = true
                        }
                    }

                    if presentationService.currentAsset != nil {
                        controlButton(systemName: "eye.circle.fill", background: Color.purple, size: 50) {
                            showingPresentationSheet = true
                        }
                    }
                } else if streamMode == .broadcast && agoraService.isAudience {
                    VStack(spacing: 6) {
                        if presentationService.currentAsset != nil {
                            controlButton(systemName: "eye.circle.fill", background: Color.purple, size: 50) {
                                showingPresentationSheet = true
                            }
                        }
                        Button(action: handleRequestToSpeakTap) {
                            HStack(spacing: 6) {
                                if requestState == .requesting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.75)
                                } else {
                                    Image(systemName: requestState == .requested ? "hand.raised.fill" : "hand.raised")
                                }

                                Text(requestState == .requested ? "Requested" : "Request")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(width: 110, height: 56)
                            .background(requestState == .requested ? Color.gray : Color.orange)
                            .clipShape(Capsule())
                        }
                        .disabled(requestState != .idle)

                        if requestState == .requested {
                            Text("Request sent")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }

                controlButton(systemName: "message.fill", background: showChatOverlay ? Color.purple : Color.gray, size: 50) {
                    showChatOverlay.toggle()
                } badge: {
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
                }

                controlButton(systemName: "phone.down.fill", background: Color.red, size: 50) {
                    leaveStream(shouldEndSessionIfHost: true)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: 66)
        .contentShape(Rectangle())
        .shadow(radius: 1, y: 1)
    }

    @ViewBuilder
    private func controlButton(
        systemName: String,
        background: Color,
        size: CGFloat = 56,
        action: @escaping () -> Void,
        badge: () -> some View = { EmptyView() }
    ) -> some View {
        Button(action: action) {
            ZStack {
                Image(systemName: systemName)
                    .font(.title2)
                    .foregroundColor(.white)

                badge()
            }
            .frame(width: size, height: size)
            .background(background)
            .clipShape(Circle())
        }
    }
    
    // MARK: - Layouts
    
    @ViewBuilder
    private func gridLayout(geometry: GeometryProxy) -> some View {
        // Use session's participant count instead of Agora's count for layout
        // This ensures the layout is correct even if Agora callbacks haven't fired yet
        let displayCount = max(session.currentParticipants, sessionParticipants.count, 1)
        let participantCount = displayCount
        
        // Conference mode: Show all participants in grid
        // Multi-participant mode: Limit visible tiles for performance (max 9 visible)
        let maxVisibleTiles: Int = streamMode == .multiParticipant ? 9 : participantCount
        
        let visibleCount = min(participantCount, maxVisibleTiles)
        let columns = visibleCount <= 1 ? 1 : visibleCount <= 4 ? 2 : 3
        let rows = Int(ceil(Double(visibleCount) / Double(columns)))
        let itemWidth = geometry.size.width / CGFloat(columns)
        let itemHeight = geometry.size.height / CGFloat(max(rows, 1))
        
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) {
                // Local video (UID 0) - only show if user is broadcaster
                if agoraService.isBroadcaster || streamMode != .broadcast {
                    videoCellView(uid: 0, isLocal: true, width: itemWidth, height: itemHeight)
                }
                
                // Remote videos - show all in conference, or limited in multi-participant
                let remoteUsersToShow: [UInt] = {
                    if streamMode == .multiParticipant {
                        // Multi-participant: Show active speakers first, then limit total
                        let activeSpeakers = agoraService.remoteUsers.filter { uid in
                            participants.first(where: { $0.id == uid })?.isSpeaking ?? false
                        }
                        let others = agoraService.remoteUsers.filter { uid in
                            !(participants.first(where: { $0.id == uid })?.isSpeaking ?? false)
                        }
                        // Prioritize active speakers, limit total
                        return Array((activeSpeakers + others).prefix(maxVisibleTiles - (agoraService.isBroadcaster || streamMode != .broadcast ? 1 : 0)))
                    } else {
                        // Conference: Show all
                        return agoraService.remoteUsers
                    }
                }()
                
                ForEach(remoteUsersToShow, id: \.self) { uid in
                    videoCellView(uid: uid, isLocal: false, width: itemWidth, height: itemHeight)
                }
                
                // Show indicator if more participants exist in multi-participant mode
                if streamMode == .multiParticipant && agoraService.remoteUsers.count > remoteUsersToShow.count {
                    let remaining = agoraService.remoteUsers.count - remoteUsersToShow.count
                    VStack {
                        Image(systemName: "person.3.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                        Text("+\(remaining)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("more")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: itemWidth, height: itemHeight)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                }
            }
            .padding(4)
        }
    }
    
    @ViewBuilder
    private func videoCellView(uid: UInt, isLocal: Bool, width: CGFloat, height: CGFloat) -> some View {
        let participant = participants.first(where: { $0.id == uid })
        let userName = participant?.name ?? (isLocal ? "You" : "User \(uid)")
        let videoEnabled = isLocal ? agoraService.isVideoEnabled : (participant?.isVideoEnabled ?? true)
        
        ZStack {
            AgoraVideoView(uid: uid, isLocal: isLocal, isVideoEnabled: videoEnabled)
                .frame(width: width, height: height)
                .clipped()
            
            // Overlay with user info
            VStack {
                // Mute indicator and full-screen button
                HStack {
                    if let participant = participant, participant.isMuted {
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
                        fullScreenParticipant = uid
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
                    if let participant = participant, participant.isSpeaking {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    Text(userName)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    // Broadcast mode: Host can promote/demote participants
                    if streamMode == .broadcast && isHost && !isLocal {
                        Menu {
                            Button(action: {
                                promoteToBroadcaster(uid: uid)
                            }) {
                                Label("Promote to Broadcaster", systemImage: "arrow.up.circle")
                            }
                            
                            Button(action: {
                                demoteToAudience(uid: uid)
                            }) {
                                Label("Demote to Viewer", systemImage: "arrow.down.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(8)
        .onTapGesture {
            // Tap to spotlight
            spotlightedParticipant = spotlightedParticipant == uid ? nil : uid
        }
    }
    
    @ViewBuilder
    private func speakerLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            // Determine main speaker
            // Multi-participant mode: Auto-focus on active speaker
            // Conference mode: Show first remote or local
            let mainSpeaker: UInt? = {
                if streamMode == .multiParticipant {
                    // Multi-participant: Find active speaker, or fallback to first remote/local
                    let activeSpeaker = agoraService.remoteUsers.first { uid in
                        participants.first(where: { $0.id == uid })?.isSpeaking ?? false
                    }
                    return activeSpeaker ?? agoraService.remoteUsers.first
                } else {
                    // Conference: Show first remote or local
                    return agoraService.remoteUsers.first
                }
            }()
            
            // Main speaker view
            if let speaker = mainSpeaker {
                let speakerParticipant = participants.first(where: { $0.id == speaker })
                AgoraVideoView(uid: speaker, isLocal: speaker == 0, isVideoEnabled: speakerParticipant?.isVideoEnabled ?? true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if agoraService.isBroadcaster || streamMode != .broadcast {
                // Show local video if user is broadcaster (or in conference/multi-participant mode)
                AgoraVideoView(uid: 0, isLocal: true, isVideoEnabled: agoraService.isVideoEnabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Broadcast mode audience: Show placeholder
                VStack {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Waiting for broadcaster...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Small videos in corner
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            // Multi-participant mode: Limit visible thumbnails for performance (max 6)
                            // Conference mode: Show all
                            let maxThumbnails = streamMode == .multiParticipant ? 6 : agoraService.remoteUsers.count + 1
                            let allVideos: [UInt] = {
                                var videos: [UInt] = []
                                // Add local video if not main speaker
                                if mainSpeaker != 0 && (agoraService.isBroadcaster || streamMode != .broadcast) {
                                    videos.append(0)
                                }
                                // Add remote videos (excluding main speaker)
                                videos.append(contentsOf: agoraService.remoteUsers.filter { $0 != mainSpeaker })
                                return videos
                            }()
                            let visibleVideos = Array(allVideos.prefix(maxThumbnails))
                            
                            ForEach(visibleVideos, id: \.self) { uid in
                                let isLocal = uid == 0
                                let videoParticipant = participants.first(where: { $0.id == uid })
                                AgoraVideoView(uid: uid, isLocal: isLocal, isVideoEnabled: videoParticipant?.isVideoEnabled ?? true)
                                    .frame(width: 120, height: 160)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(uid == mainSpeaker ? Color.green : Color.white, lineWidth: uid == mainSpeaker ? 3 : 2)
                                    )
                                    .onTapGesture {
                                        // Tap to switch main speaker (only in multi-participant mode)
                                        if streamMode == .multiParticipant {
                                            spotlightedParticipant = uid
                                        }
                                    }
                            }
                            
                            // Show indicator if more participants exist in multi-participant mode
                            if streamMode == .multiParticipant && allVideos.count > visibleVideos.count {
                                let remaining = allVideos.count - visibleVideos.count
                                VStack {
                                    Image(systemName: "person.3.fill")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("+\(remaining)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .frame(width: 120, height: 80)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .frame(maxHeight: geometry.size.height * 0.6)
                    .padding()
                }
            }
        }
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
                
                // Start the stream using Agora - use session display name (prioritizes edited session name)
                let userName = sessionDisplayName
                
                // Determine role based on stream mode
                let role: AgoraUserRole
                switch streamMode {
                case .broadcast:
                    // Broadcast mode: Only host can broadcast, others are audience
                    role = isHost ? .broadcaster : .audience
                    print("📺 [STREAM] Broadcast mode - Host: \(isHost ? "broadcaster" : "audience")")
                case .conference:
                    // Conference mode: Everyone joins as broadcaster (all can present)
                    // Standard grid view, all participants visible
                    role = .broadcaster
                    print("💬 [STREAM] Conference mode - All participants can broadcast (grid view)")
                case .multiParticipant:
                    // Multi-participant mode: Everyone joins as broadcaster with enhanced features
                    // Speaker view by default, optimized for larger groups, auto-focus on active speaker
                    role = .broadcaster
                    print("👥 [STREAM] Multi-participant mode - All participants can broadcast (speaker view, optimized for large groups)")
                }
                
                // Join Agora channel with appropriate role
                try await agoraService.joinChannel(
                    sessionId: session.id,
                    userId: userId,
                    userName: userName,
                    role: role,
                    customChannelName: customChannelName
                )
                
                isStreaming = true
                
                // Setup local video (Agora handles this internally)
                _ = agoraService.setupLocalVideo()
                
                // Update participant list
                await updateParticipantsList()
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
    
    private func updateParticipantsList() async {
        // Get data on main actor (synchronous reads) - extract only primitive values, not model objects
        let (localUserId, currentUserParticipantData, userProfileName, sessionParticipantsData, remoteUsersList, agoraAudioEnabled, agoraVideoEnabled) = await MainActor.run {
            let userId = userService.userIdentifier
            let currentParticipant = sessionParticipants.first(where: { $0.userId == userId })
            let participantData: (userId: String, userName: String)? = currentParticipant.map { 
                ($0.userId, $0.userName) 
            }
            let profileName = userProfile?.name ?? ""
            let participantsData: [(userId: String, userName: String, isMuted: Bool, isVideoEnabled: Bool, isSpeaking: Bool)] = sessionParticipants.map {
                ($0.userId, $0.userName, $0.isMuted, $0.isVideoEnabled, $0.isSpeaking)
            }
            return (
                userId,
                participantData,
                profileName,
                participantsData,
                agoraService.remoteUsers,
                agoraService.isAudioEnabled,
                agoraService.isVideoEnabled
            )
        }
        
        // Get the display name for current user - prioritize stored participant name over profile name
        var localUserName = ""
        if let currentUserParticipant = currentUserParticipantData {
            let storedName = currentUserParticipant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || storedName.contains("iPad") || storedName == UIDevice.current.name
            
            // Use stored name if it's been set and is not a device name (handles edited names)
            if !storedName.isEmpty && !isStoredNameDevice {
                localUserName = storedName
            } else {
                // Fallback to profile name if stored name is device name
                let profileName = userProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                let isProfileNameDevice = profileName.contains("iPhone") || profileName.contains("iPad")
                
                if !profileName.isEmpty && !isProfileNameDevice {
                    localUserName = profileName
                } else {
                    // Final fallback to device name
                    localUserName = await MainActor.run { userService.getDisplayName(userProfile: userProfile) }
                }
            }
        } else {
            // No participant record yet, use profile or device name
            localUserName = await MainActor.run { userService.getDisplayName(userProfile: userProfile) }
        }
        
        // Create local participant - use the determined name (prioritizes edited session name)
        var newParticipants: [ParticipantInfo] = [
            ParticipantInfo(
                id: 0, // Agora uses 0 for local user
                name: localUserName,
                isMuted: !agoraAudioEnabled,
                isVideoEnabled: agoraVideoEnabled,
                isSpeaking: false,
                isLocal: true
            )
        ]
        
        // Add remote participants - try to get names from LiveSessionParticipant records
        // Note: Agora UIDs don't directly map to userIds, so we assign participant names
        // to remote UIDs in order (excluding the local user)
        let remoteSessionParticipants = sessionParticipantsData.filter { $0.userId != localUserId }
        
        // Fetch user names from Firebase for participants with device names (async work outside MainActor.run)
        var participantNamesCache: [String: String] = await MainActor.run { userNameCache }
        for participant in remoteSessionParticipants {
            let storedName = participant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isDeviceName = storedName.contains("iPhone") || 
                              storedName.contains("iPad") || 
                              storedName.contains("iPod") ||
                              storedName == UIDevice.current.name ||
                              storedName.isEmpty
            
            if isDeviceName && participantNamesCache[participant.userId] == nil {
                // Fetch name from Firebase asynchronously
                if let firebaseName = await getUserNameFromFirebase(userId: participant.userId) {
                    participantNamesCache[participant.userId] = firebaseName
                    
                    // Update participant record with the fetched name (best practice: persist to database)
                    await MainActor.run {
                        userNameCache[participant.userId] = firebaseName
                        // Find and update the actual participant model
                        if let participantModel = sessionParticipants.first(where: { $0.userId == participant.userId }) {
                            participantModel.userName = firebaseName
                            try? modelContext.save()
                        }
                    }
                    
                    // Sync updated name to Firebase - need to get the model on main actor
                    await MainActor.run {
                        if let participantModel = sessionParticipants.first(where: { $0.userId == participant.userId }) {
                            Task {
                                await FirebaseSyncService.shared.syncSessionParticipant(participantModel)
                                print("✅ [STREAM] Updated participant \(participant.userId) name from Firebase: \(firebaseName)")
                            }
                        }
                    }
                }
            }
        }
        
        var usedParticipantNames = Set<String>()
        
        for (index, remoteUid) in remoteUsersList.enumerated() {
                // Get participant name from database if available
                var participantName: String
                let isMuted: Bool
                let isVideoEnabled: Bool
                let isSpeaking: Bool
                
                if index < remoteSessionParticipants.count {
                    let participant = remoteSessionParticipants[index]
                    // Use stored userName (should be updated from Firebase or from their profile)
                    let storedName = participant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Check if the stored name is a device name
                    let isDeviceName = storedName.contains("iPhone") || 
                                      storedName.contains("iPad") || 
                                      storedName.contains("iPod") ||
                                      storedName == UIDevice.current.name ||
                                      storedName.isEmpty
                    
                    if isDeviceName {
                        // Try to get user name from cache (Firebase lookup)
                        if let cachedName = participantNamesCache[participant.userId], !cachedName.isEmpty {
                            participantName = cachedName
                        } else {
                            participantName = storedName.isEmpty ? "Participant" : storedName
                        }
                    } else {
                        participantName = storedName.isEmpty ? "Participant" : storedName
                    }
                    
                    isMuted = participant.isMuted
                    isVideoEnabled = participant.isVideoEnabled
                    isSpeaking = participant.isSpeaking
                    usedParticipantNames.insert(participantName)
                } else {
                    // Fallback if we don't have enough participant records
                    participantName = "Participant"
                    isMuted = false
                    isVideoEnabled = true
                    isSpeaking = false
                }
                
                newParticipants.append(
                    ParticipantInfo(
                        id: remoteUid,
                        name: participantName,
                        isMuted: isMuted,
                        isVideoEnabled: isVideoEnabled,
                        isSpeaking: isSpeaking,
                        isLocal: false
                    )
                )
            }
            
            // Update participants on main actor
            await MainActor.run {
                participants = newParticipants
            }
        }
    
    private func getUserName(for uid: UInt) -> String {
        return participants.first(where: { $0.id == uid })?.name ?? (uid == 0 ? "You" : "User \(uid)")
    }
    
    /// Fetch user name from Firebase users collection
    /// Based on best practices: fetch display names from backend/profile system
    /// and update participant records to persist the name
    private func getUserNameFromFirebase(userId: String) async -> String? {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let data = userDoc.data(),
               let name = data["name"] as? String,
               !name.isEmpty {
                // Check if the name from Firebase is also a device name
                let isDeviceName = name.contains("iPhone") || name.contains("iPad") || name.contains("iPod")
                if !isDeviceName {
                    return name
                }
            }
        } catch {
            // Silently fail - Firebase might not be configured or user might not exist
            print("⚠️ [STREAM] Failed to fetch user name from Firebase for userId: \(userId), error: \(error.localizedDescription)")
        }
        #endif
        return nil
    }
    
    // MARK: - Chat Functions
    
    // Chat messages for this session
    var sessionMessages: [ChatMessage] {
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
    
    private func sendChatMessage() {
        guard !chatMessageText.isEmpty else { return }
        
        let userId = userService.userIdentifier
        // Use session display name (prioritizes edited session name)
        let userName = sessionDisplayName
        
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
            
            // Sync message to Firebase for real-time chat
            Task {
                await FirebaseSyncService.shared.syncChatMessage(message)
                print("✅ [CHAT] Synced message to Firebase: \(message.id)")
            }
        } catch {
            print("Error sending chat message: \(error)")
        }
    }
    
    private func setupMessageSubscription() {
        #if canImport(FirebaseFirestore)
        // Start listening for chat messages from Firebase
        if let listener = FirebaseSyncService.shared.startListeningToChatMessages(
            sessionId: session.id,
            onMessageReceived: { message in
                // Check if message already exists locally to prevent duplicates
                let messageId = message.id
                let existingMessageQuery = FetchDescriptor<ChatMessage>(
                    predicate: #Predicate<ChatMessage> { msg in
                        msg.id == messageId
                    }
                )
                
                Task { @MainActor in
                    if (try? modelContext.fetch(existingMessageQuery).first) != nil {
                        print("ℹ️ [CHAT] Message already exists locally: \(message.id)")
                    } else {
                        // New message from Firebase - save locally
                        modelContext.insert(message)
                        do {
                            try modelContext.save()
                            print("✅ [CHAT] Received new message from Firebase: \(message.id)")
                        } catch {
                            print("❌ [CHAT] Error saving message: \(error.localizedDescription)")
                        }
                    }
                }
            }
        ) {
            chatMessageListener = listener
            print("✅ [CHAT] Started listening to messages for session: \(session.id)")
        }
        #endif
    }
    
    private func leaveStream(shouldEndSessionIfHost: Bool = true) {
        agoraService.leaveChannel()
        isStreaming = false
        
        // If host is leaving, mark session as inactive only when intended (explicit Done tap or after stream was up 5+ sec). Avoids ending session when view disappears before stream started.
        if isHost && shouldEndSessionIfHost {
            session.isActive = false
            session.endTime = Date()
            
            // Mark all participants as inactive
            for participant in sessionParticipants {
                participant.isActive = false
                participant.leftAt = Date()
            }
            
            // Save changes
            try? modelContext.save()
            
            // Sync session state to Firebase
            Task {
                await FirebaseSyncService.shared.syncLiveSession(session)
            }
        } else if !isHost {
            // For non-hosts, just mark their own participant as inactive
            if let userParticipant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier }) {
                userParticipant.isActive = false
                userParticipant.leftAt = Date()
                session.currentParticipants = max(0, session.currentParticipants - 1)
                if userParticipant.isBroadcaster {
                    session.currentBroadcasters = max(0, session.currentBroadcasters - 1)
                }
                try? modelContext.save()
                
                // Sync participant state to Firebase
                Task {
                    await FirebaseSyncService.shared.syncSessionParticipant(userParticipant)
                    await FirebaseSyncService.shared.updateSessionParticipantCount(session.id, count: session.currentParticipants)
                }
            }
        }
        
        // Clean up chat listener
        #if canImport(FirebaseFirestore)
        if let listener = chatMessageListener as? ListenerRegistration {
            listener.remove()
            chatMessageListener = nil
        }
        #endif
        
        // Dismiss the view to return to the session detail view
        dismiss()
    }
    
    // MARK: - Multi-Participant Mode Functions
    
    /// Start tracking active speakers for multi-participant mode
    /// This enables auto-focus on the person currently speaking
    private func startActiveSpeakerTracking() {
        guard streamMode == .multiParticipant else { return }
        
        // Update participant list periodically to detect speaking status
        // Note: Since MultiParticipantStreamView is a struct, we capture self directly
        // The Timer will be invalidated when the view disappears
        activeSpeakerTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                await self.updateParticipantsList()
                
                // Auto-switch to speaker view if someone starts speaking and we're in grid view
                if self.layoutMode == .grid && self.streamMode == .multiParticipant {
                    let hasActiveSpeaker = self.participants.contains { $0.isSpeaking }
                    if hasActiveSpeaker {
                        self.layoutMode = .speaker
                        print("🎤 [MULTI-PARTICIPANT] Active speaker detected, switching to speaker view")
                    }
                }
            }
        }
        print("✅ [MULTI-PARTICIPANT] Started active speaker tracking")
    }
    
    // MARK: - Broadcast Mode Functions
    
    private func handleRequestToSpeakTap() {
        guard requestState == .idle else { return }
        requestState = .requesting

        Task { @MainActor in
            requestToSpeak()
            requestState = .requested
        }
    }

    /// Request to speak (for audience members in broadcast mode)
    private func requestToSpeak() {
        // In broadcast mode, audience members can request to be promoted to broadcaster
        // This sends a notification to the host
        print("🙋 [BROADCAST] Requesting to speak...")

        // Send a chat message to notify the host
        let message = "🙋 Requesting to speak"
        chatMessageText = message
        sendChatMessage()

        // Show feedback
        print("✅ [BROADCAST] Request sent to host via chat")
    }
    
    /// Promote audience member to broadcaster (host only, broadcast mode)
    private func promoteToBroadcaster(uid: UInt) {
        guard streamMode == .broadcast && isHost else { return }
        
        print("⬆️ [BROADCAST] Promoting user \(uid) to broadcaster")
        
        // Find the participant by Agora UID
        // Note: In Agora, users need to change their own role
        // We'll send them a chat message to notify them to promote themselves
        // In production, you'd use Agora's signaling API for this
        
        // For now, send a chat message
        if let participant = participants.first(where: { $0.id == uid }) {
            let message = "🎤 @\(participant.name) You've been promoted to broadcaster. Please enable your camera/mic."
            chatMessageText = message
            sendChatMessage()
            print("✅ [BROADCAST] Sent promotion notification to \(participant.name)")
        }
    }
    
    /// Demote broadcaster to audience (host only, broadcast mode)
    private func demoteToAudience(uid: UInt) {
        guard streamMode == .broadcast && isHost else { return }
        
        print("⬇️ [BROADCAST] Demoting user \(uid) to audience")
        
        // Find the participant by Agora UID
        // Send them a chat message to notify them to demote themselves
        if let participant = participants.first(where: { $0.id == uid }) {
            let message = "👁️ @\(participant.name) You've been moved to viewer mode."
            chatMessageText = message
            sendChatMessage()
            print("✅ [BROADCAST] Sent demotion notification to \(participant.name)")
        }
    }
}

private struct PresentationAssetSheet: View {
    let asset: PresentationService.PresentationAsset
    let onClose: () -> Void
    let onStop: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
        VStack(spacing: 0) {
            presentationHeader

            QuickLookPreview(url: asset.fileURL)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 6)
                .padding()
                .frame(maxHeight: UIScreen.main.bounds.height * 0.6)

            Spacer()
        }
        .background(Color(.systemBackground))
            .navigationTitle("Presentation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                        onClose()
                    }
                }
            }
        }
    }

    private var presentationHeader: some View {
        HStack {
            Label {
                Text(asset.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
            } icon: {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(.purple)
            }

            Spacer()

            if let onStop = onStop {
                Button {
                    onStop()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                        Text("Stop")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
            }
        }
        .padding([.top, .horizontal])
        .overlay(
            Divider()
                .padding(.top, 60),
            alignment: .bottom
        )
    }

    private var iconName: String {
        switch asset.type {
        case .pdf:
            return "doc.richtext"
        case .image:
            return "photo"
        }
    }
}

private struct BibleStudyShareSheet: View {
    let topics: [BibleStudyTopic]
    let onSelect: (BibleStudyTopic) async -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var processingTopicId: UUID?
    @State private var previewTopic: BibleStudyTopic?
    private var availableTopics: [BibleStudyTopic] {
        topics.isEmpty ? BibleStudyService.shared.getTopicsForLiveSession() : topics
    }

    private var filteredTopics: [BibleStudyTopic] {
        guard !searchText.isEmpty else { return availableTopics }
        let query = searchText.lowercased()
        return availableTopics.filter { topic in
            topic.title.lowercased().contains(query) ||
            topic.topicDescription.lowercased().contains(query) ||
            topic.keyVerses.contains(where: { $0.lowercased().contains(query) })
        }
    }

    @ViewBuilder
    private func topicSelectionButton(for topic: BibleStudyTopic) -> some View {
        Button {
            previewTopic = topic
            guard processingTopicId == nil else { return }
            processingTopicId = topic.id
            Task {
                await onSelect(topic)
                processingTopicId = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)

                if let verse = topic.keyVerses.first {
                    Text(verse)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(processingTopicId != nil && processingTopicId != topic.id)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if filteredTopics.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "book.closed")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Topics are still loading.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(filteredTopics, id: \.id) { topic in
                            topicSelectionButton(for: topic)
                        }
                    }
                }

                if let topic = previewTopic {
                    Section(header: Text("Topic Preview")) {
                        Text(topic.topicDescription)
                            .font(.body)

                        if !topic.keyVerses.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Key Verses")
                                    .font(.headline)
                                ForEach(topic.keyVerses, id: \.self) { verse in
                                    Text(verse)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if !topic.studyQuestions.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Study Questions")
                                    .font(.headline)
                                ForEach(Array(topic.studyQuestions.enumerated()), id: \.offset) { index, question in
                                    Text("• \(question)")
                                        .font(.caption2)
                                        .id(index)
                                }
                            }
                        }

                        if !topic.applicationPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Application Points")
                                    .font(.headline)
                                ForEach(Array(topic.applicationPoints.enumerated()), id: \.offset) { index, point in
                                    Text("• \(point)")
                                        .font(.caption2)
                                        .id(index)
                                }
                            }
                        }

                        Button {
                            guard processingTopicId == nil else { return }
                            processingTopicId = topic.id
                            Task {
                                await onSelect(topic)
                                processingTopicId = nil
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Share this topic")
                                Spacer()
                            }
                        }
                        .disabled(processingTopicId != nil)

                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Share Bible Study")
            .searchable(text: $searchText, prompt: "Search topics or verses")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onDismiss()
                    }
                }
            }
            .overlay {
                if processingTopicId != nil {
                    ProgressView("Preparing topic...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
            .onAppear {
                    if previewTopic == nil {
                        previewTopic = availableTopics.first
                    }
                }
                .onChange(of: searchText) { _, _ in
                    previewTopic = filteredTopics.first
                }
        }
    }
}


private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No-op
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
