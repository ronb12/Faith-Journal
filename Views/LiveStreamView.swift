//
//  LiveStreamView.swift
//  Faith Journal
//
//  Full-screen live stream view.
//  Video fills the entire screen; all controls are overlaid.
//

import SwiftUI
import SwiftData
import AVFoundation

#if canImport(WebRTC)
import WebRTC
#endif

// MARK: - Main view

@available(iOS 17.0, *)
struct LiveStreamView: View {

    let session: LiveSession?

    @ObservedObject private var streamingService = UnifiedStreamingService.shared
    private let userService = LocalUserService.shared
    @Environment(\.dismiss) private var dismiss
    @Query var userProfiles: [UserProfile]
    private var userProfile: UserProfile? { userProfiles.first }

    // Stream state
    @State private var isStreaming       = false
    @State private var isHost            = false
    @State private var isScreenSharing   = false
    @State private var screenShareError  : String?

    // Host control toggles
    @State private var isMuted           = false
    @State private var isCameraOff       = false
    @State private var isCameraFront     = true

    // Overlay visibility
    @State private var controlsVisible   = true
    @State private var showChat          = false
    @State private var showReactions     = false
    @State private var showPolls         = false
    @State private var showQnA           = false
    @State private var theaterMode       = false
    @State private var showParticipants  = false

    // Error
    @State private var showingError      = false
    @State private var errorMessage      = ""

    // Chat
    @State private var chatMessages: [LiveChatMessage] = []
    @State private var chatInputText = ""
    @State private var chatListener: Any?

    // Participants (for host strip)
    @State private var participants: [ParticipantInfo] = []
    @State private var spotlightedId: String?

    struct ParticipantInfo: Identifiable {
        let id: String
        let name: String
        let isMuted: Bool
        let isVideoEnabled: Bool
        let isSpeaking: Bool
    }

    var body: some View {
        if #available(iOS 17.0, *), session != nil {
            streamContent
                .ignoresSafeArea()
                .statusBarHidden(theaterMode)
                .onAppear(perform: startStreaming)
                .onDisappear(perform: cleanup)
                .onChange(of: streamingService.isVideoEnabled) { _, on in
                    if !on { isCameraOff = true }
                }
                .onChange(of: streamingService.errorMessage) { _, msg in
                    if let msg { errorMessage = msg; showingError = true }
                }
                .alert("Error", isPresented: $showingError) {
                    Button("OK", role: .cancel) { }
                } message: { Text(errorMessage) }
                .alert("Screen Sharing",
                       isPresented: Binding(get: { screenShareError != nil },
                                            set: { if !$0 { screenShareError = nil } })) {
                    Button("OK", role: .cancel) { screenShareError = nil }
                } message: { Text(screenShareError ?? "") }
                .sheet(isPresented: $showChat) { chatSheet }
                .sheet(isPresented: $showParticipants) { participantSheet }
        } else {
            ContentUnavailableView(
                "iOS 17+ Required",
                systemImage: "video.slash",
                description: Text("Live streaming requires iOS 17 or later.")
            )
        }
    }

    // MARK: - Stream content (full-screen ZStack)

    @available(iOS 17.0, *)
    private var streamContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {

                // 1 — Black canvas
                Color(red: 0.059, green: 0.059, blue: 0.059).ignoresSafeArea()

                // 2 — Main video
                mainVideo
                    .frame(width: geo.size.width, height: geo.size.height)

                // 3 — Live stream controls overlay
                LiveStreamOverlay(
                    session:          session,
                    isHost:           isHost,
                    showChatOverlay:  $showChat,
                    showingReactions: $showReactions,
                    showingPolls:     $showPolls,
                    showingQnA:       $showQnA,
                    controlsVisible:  $controlsVisible,
                    theaterMode:      $theaterMode,
                    chatMessages:     $chatMessages,
                    viewerCount:      session?.viewerCount ?? 0,
                    onReaction:       { },
                    onToggleChat:     { showChat.toggle() },
                    onToggleTheater:  { withAnimation { theaterMode.toggle() } },
                    onShare:          shareStream
                )

                // 4 — Host-only bottom control bar
                if isHost {
                    hostControlBar(geo: geo)
                }

                // 5 — PIP (non-host sees own camera; host sees nothing extra)
                if !isHost {
                    pipView(geo: geo)
                }

                // 6 — Top-left back / close button
                closeButton(geo: geo)
            }
        }
    }

    // MARK: - Main video area

    @ViewBuilder
    private var mainVideo: some View {
        if isHost, let layer = HLSStreamingService.shared.getPreviewLayer() {
            VideoPreviewLayerView(previewLayer: layer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let layer = HLSStreamingService.shared.getPreviewLayer() {
            VideoPreviewLayerView(previewLayer: layer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            waitingPlaceholder
        }
    }

    private var waitingPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
            Text(isStreaming ? "Connecting…" : "Starting stream…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            if isStreaming {
                ProgressView().tint(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Host bottom control bar

    @ViewBuilder
    private func hostControlBar(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Thin participant strip (scrollable, shown only when participants exist)
            if !participants.isEmpty {
                participantStrip
                    .padding(.bottom, 4)
            }

            // Control buttons row
            HStack(spacing: 0) {
                Spacer()

                // Mic
                hostButton(
                    icon: isMuted ? "mic.slash.fill" : "mic.fill",
                    label: isMuted ? "Unmute" : "Mute",
                    tint: isMuted ? .red : .white,
                    bg: Color.white.opacity(0.12)
                ) { toggleMute() }

                Spacer()

                // Camera on/off
                hostButton(
                    icon: isCameraOff ? "video.slash.fill" : "video.fill",
                    label: isCameraOff ? "Camera On" : "Camera Off",
                    tint: isCameraOff ? .red : .white,
                    bg: Color.white.opacity(0.12)
                ) { toggleCamera() }

                Spacer()

                // Flip camera
                hostButton(
                    icon: "arrow.triangle.2.circlepath.camera.fill",
                    label: "Flip camera",
                    tint: .white,
                    bg: Color.white.opacity(0.12)
                ) { flipCamera() }

                Spacer()

                // Screen share
                hostButton(
                    icon: isScreenSharing ? "rectangle.slash.fill" : "rectangle.on.rectangle.fill",
                    label: isScreenSharing ? "Stop sharing" : "Share screen",
                    tint: isScreenSharing ? .green : .white,
                    bg: isScreenSharing ? .green.opacity(0.2) : .white.opacity(0.12)
                ) { toggleScreenSharing() }

                Spacer()

                // Participants
                hostButton(
                    icon: "person.2.fill",
                    label: "Participants",
                    tint: .white,
                    bg: Color.white.opacity(0.12)
                ) { showParticipants = true }

                Spacer()

                // End stream
                hostButton(
                    icon: "xmark",
                    label: "End stream",
                    tint: .white,
                    bg: .red
                ) { leaveStream() }

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.bottom, geo.safeAreaInsets.bottom)
            .background(
                LinearGradient(
                    colors: [.clear, Color(red: 0.059, green: 0.059, blue: 0.059).opacity(0.96)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func hostButton(
        icon: String, label: String, tint: Color, bg: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(bg)
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .accessibilityLabel(label)
    }

    // MARK: - Participant strip

    private var participantStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(participants) { p in
                    participantChip(p)
                        .onTapGesture { spotlightedId = spotlightedId == p.id ? nil : p.id }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 72)
    }

    private func participantChip(_ p: ParticipantInfo) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(spotlightedId == p.id ? Color.orange.opacity(0.35) : Color.white.opacity(0.1))
                    .frame(width: 46, height: 46)
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 46, height: 46)

                if p.isMuted {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: -2, y: -2)
                }
            }

            Text(p.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)

            if p.isSpeaking {
                Capsule()
                    .fill(Color.green)
                    .frame(width: 20, height: 3)
            }
        }
        .frame(width: 54)
        .accessibilityLabel("\(p.name)\(p.isMuted ? ", muted" : "")\(p.isSpeaking ? ", speaking" : "")")
    }

    // MARK: - PIP (viewer)

    @ViewBuilder
    private func pipView(geo: GeometryProxy) -> some View {
        if let layer = HLSStreamingService.shared.getPreviewLayer() {
            let w = geo.size.width * 0.26
            let h = w / 9 * 16
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VideoPreviewLayerView(previewLayer: layer)
                        .frame(width: w, height: h)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
                        .padding(.trailing, 14)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 80)
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Close / back button

    private func closeButton(geo: GeometryProxy) -> some View {
        VStack {
            HStack {
                Button(action: leaveStream) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Leave stream")
                .padding(.leading, 14)
                .padding(.top, geo.safeAreaInsets.top + 8)
                Spacer()
            }
            Spacer()
        }
    }

    // MARK: - Chat sheet

    private var chatSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.059, green: 0.059, blue: 0.059).ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                if chatMessages.isEmpty {
                                    Text("No messages yet. Be the first to say something!")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 40)
                                        .multilineTextAlignment(.center)
                                } else {
                                    ForEach(chatMessages) { msg in
                                        chatRow(msg).id(msg.id)
                                    }
                                }
                            }
                            .padding()
                        }
                        .onChange(of: chatMessages.count) { _, _ in
                            if let last = chatMessages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.1))

                    HStack(spacing: 10) {
                        TextField("Say something…", text: $chatInputText)
                            .foregroundStyle(.white)
                            .tint(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                            .submitLabel(.send)
                            .onSubmit { sendChatMessage() }

                        Button(action: sendChatMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(chatInputText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.gray.opacity(0.5)
                                    : Color(red: 1, green: 0, blue: 0))
                                .clipShape(Circle())
                        }
                        .disabled(chatInputText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel("Send message")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.129, green: 0.129, blue: 0.129))
                }
            }
            .navigationTitle("Live Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showChat = false }.foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func chatRow(_ msg: LiveChatMessage) -> some View {
        if msg.isSuperChat, let amount = msg.superChatAmount {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "dollarsign.circle.fill").font(.caption2).foregroundStyle(.yellow)
                    Text("\(msg.username) · \(amount)").font(.caption.weight(.semibold)).foregroundStyle(.yellow)
                }
                Text(msg.text).font(.body).foregroundStyle(.white)
            }
            .padding(10)
            .background(Color(red: 0.18, green: 0.10, blue: 0))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.45), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(chatNameColor(for: msg.username))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(String(msg.username.prefix(1)).uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(msg.username)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(chatNameColor(for: msg.username))
                    Text(msg.text)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func chatNameColor(for username: String) -> Color {
        let colors: [Color] = [
            Color(red: 0.12, green: 0.71, blue: 0.96),
            Color(red: 0.30, green: 0.85, blue: 0.56),
            Color(red: 0.96, green: 0.71, blue: 0.12),
            Color(red: 0.96, green: 0.45, blue: 0.12),
            Color(red: 0.71, green: 0.40, blue: 0.96),
            Color(red: 0.96, green: 0.26, blue: 0.45),
        ]
        return colors[abs(username.hashValue) % colors.count]
    }

    // MARK: - Participant sheet

    private var participantSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.059, green: 0.059, blue: 0.059).ignoresSafeArea()
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3),
                        spacing: 20
                    ) {
                        ForEach(participants) { p in
                            VStack(spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 80, height: 80)
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 34))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .frame(width: 80, height: 80)
                                    if p.isMuted {
                                        Image(systemName: "mic.slash.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                            .padding(4)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 4, y: -4)
                                    }
                                }
                                Text(p.name)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if p.isSpeaking {
                                    Text("Speaking")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.green)
                                }
                            }
                            .accessibilityLabel("\(p.name)\(p.isMuted ? ", muted" : "")")
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Participants (\(participants.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showParticipants = false }.foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Connection status (used externally)

    private func connectionStatusText() -> String {
        if streamingService.isConnected { return "Connected" }
        if isStreaming { return "Connecting…" }
        if let err = streamingService.errorMessage { return err }
        return "Disconnected"
    }

    // MARK: - Actions

    private func toggleMute() {
        isMuted.toggle()
        Task { @MainActor in streamingService.toggleAudio() }
    }

    private func toggleCamera() {
        isCameraOff.toggle()
        Task { @MainActor in streamingService.toggleVideo() }
    }

    private func flipCamera() {
        isCameraFront.toggle()
        HLSStreamingService.shared.flipCamera(toFront: isCameraFront)
    }

    private func toggleScreenSharing() {
        Task {
            if isScreenSharing {
                HLSStreamingService.shared.stopScreenBroadcast()
                isScreenSharing = false
            } else {
                do {
                    screenShareError = nil
                    try await HLSStreamingService.shared.startScreenBroadcast()
                    isScreenSharing = true
                } catch {
                    screenShareError = error.localizedDescription
                }
            }
        }
    }

    private func shareStream() {
        guard let session else { return }
        #if os(iOS)
        let text = "Join me on Faith Journal Live: \(session.title)"
        let vc   = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(vc, animated: true)
        #endif
    }

    private func startStreaming() {
        guard let session else { return }
        let userId = userService.userIdentifier
        startChatListener()
        Task {
            await requestPermissions()
            do {
                let name = userService.getProfileDisplayName(userProfile: userProfile)
                try await streamingService.startStream(
                    sessionId: session.id, userId: userId, userName: name, isBroadcastMode: false
                )
                isStreaming = true
            } catch {
                errorMessage = "Failed to start streaming: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func startChatListener() {
        guard let session else { return }
        chatListener = FirebaseSyncService.shared.startListeningToChatMessages(sessionId: session.id) { chatMessage in
            Task { @MainActor in
                let liveMsg = LiveChatMessage(
                    username: chatMessage.userName,
                    text: chatMessage.message,
                    isSuperChat: false,
                    superChatAmount: nil
                )
                withAnimation(.easeIn(duration: 0.18)) {
                    self.chatMessages.append(liveMsg)
                    if self.chatMessages.count > 60 { self.chatMessages.removeFirst() }
                }
            }
        }
    }

    private func sendChatMessage() {
        let text = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session else { return }
        chatInputText = ""
        let displayName = userService.getProfileDisplayName(userProfile: userProfile)
        Task {
            let msg = ChatMessage(
                sessionId: session.id,
                userId: userService.userIdentifier,
                userName: displayName,
                message: text
            )
            await FirebaseSyncService.shared.syncChatMessage(msg)
        }
    }

    private func requestPermissions() async {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
    }

    private func leaveStream() {
        Task {
            streamingService.stopStream()
            isStreaming = false
        }
        dismiss()
    }

    private func cleanup() {
        FirebaseSyncService.shared.removeChatMessageListener(chatListener)
        chatListener = nil
        if isScreenSharing {
            HLSStreamingService.shared.stopScreenBroadcast()
            isScreenSharing = false
        }
        leaveStream()
    }
}

// MARK: - Connection status badge (reusable)

struct ConnectionStatusView: View {
    let state: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dotColor).frame(width: 7, height: 7)
            Text(state).font(.caption).foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.black.opacity(0.5))
        .clipShape(Capsule())
    }

    private var dotColor: Color {
        switch state {
        case "Connected":    return .green
        case "Connecting…":  return .yellow
        default:             return .gray
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    NavigationView {
        MultiParticipantStreamView(session: LiveSession(
            title: "Evening Prayer",
            description: "Join us",
            hostId: "host-1",
            category: "Prayer"
        ))
    }
}
