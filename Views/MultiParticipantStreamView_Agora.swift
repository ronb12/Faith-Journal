//
//  MultiParticipantStreamView_Agora.swift
//  Faith Journal
//
//  Agora-backed live session view for iOS, iPad, and macOS.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS)
import QuickLook
import AVFoundation
#endif
#if os(macOS)
import AVFoundation
#endif
#if os(macOS)
#if canImport(AgoraRtcKit1)
import AgoraRtcKit1
#elseif canImport(AgoraRtcKit)
import AgoraRtcKit
#endif
#else
#if canImport(AgoraRtcKit)
import AgoraRtcKit
#endif
#endif

#if os(iOS) || os(macOS)
@available(iOS 17.0, macOS 14.0, *)
struct MultiParticipantStreamView_Agora: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    private var userProfile: UserProfile? { userProfiles.first }
    private let userService = LocalUserService.shared

    @State private var hasJoined = false
    @State private var joinError: String?
    @State private var joinTimedOut = false
    @ObservedObject private var agoraService = AgoraService.shared
    @ObservedObject private var presentationService = PresentationService.shared
    @State private var showingPresentationSheet = false
    @State private var showingBibleStudySelector = false
    @State private var showingBibleSheet = false
    /// When true, Bible is shown in the same full-screen path as Bible Study (overlay + PIP) instead of a plain sheet. Audience still uses the sheet.
    @State private var isPresentingBibleOverlay = false
    @State private var showingMaterialPicker = false
    @State private var presentationListener: Any?
    /// When set, presentation sheet shows the same screen as Bible Study (TopicDetailView).
    @State private var presentedBibleStudyTopic: BibleStudyTopic?
    /// Participant-only: asset loaded from host's shared URL so the sheet can show it reliably.
    @State private var participantPresentationAsset: PresentationService.PresentationAsset?
    @State private var presentationLoadFailed = false
    @State private var showingPresentationError = false
    @State private var presentationError: String?
    @State private var showingEndSessionConfirmation = false
    /// Participant only: when true, overlay is hidden until next presentation update.
    @State private var participantClosedOverlay = false
    /// Recording & replay: set by Create form; host starts recording when joining.
    @AppStorage("recordNextSession") private var recordNextSession = false
    @AppStorage("uploadReplayToCloud") private var uploadReplayToCloud = false
    /// True after we've started recording this session (so we don't start twice).
    @State private var hasStartedRecordingThisSession = false
    /// User chose Jitsi after an Agora failure (same session; only used when Jitsi SDK is linked).
    @State private var useJitsiInstead = false
    /// Host toggles “open floor” in Firebase so broadcast audience can present.
    @State private var broadcastOpenFloor = false
    @State private var floorListener: Any?
    /// Full session chat (same Firebase-backed UI as session detail).
    @State private var showingLiveChat = false
    /// On-video chat overlay (YouTube-style): floating messages + inline input.
    @State private var showChatOverlay = true
    @State private var chatInputText: String = ""
    @State private var liveChatMessages: [LiveChatMessage] = []
    @State private var chatListener: Any?

    private var isHost: Bool { userService.userIdentifier == session.hostId }
    private var displayName: String {
        userService.getProfileDisplayName(userProfile: userProfile)
    }
    /// In broadcast mode only host can publish; in conference/multiParticipant everyone can.
    private var role: AgoraUserRole {
        if session.typedStreamMode == .broadcast { return isHost ? .broadcaster : .audience }
        return .broadcaster
    }

    /// Keeps the floating chat row above `liveSessionBottomBar` so it does not cover mic/camera/end icons.
    private var liveSessionBottomBarClearance: CGFloat {
        #if os(iOS)
        return 108
        #else
        return 64
        #endif
    }

    var body: some View {
        #if (os(iOS) && canImport(AgoraRtcKit)) || (os(macOS) && canImport(AgoraRtcKit1))
        agoraBody
        #else
        ContentUnavailableView("Agora", systemImage: "video.slash", description: Text("Agora is available on iOS, iPad, and macOS when the SDK is linked."))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        #endif
    }

    #if (os(iOS) && canImport(AgoraRtcKit)) || (os(macOS) && canImport(AgoraRtcKit1))
    private var agoraBody: some View {
        NavigationStack {
            agoraStackContent
        }
        .toolbar { agoraToolbarContent }
        .alert("End session?", isPresented: $showingEndSessionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End for everyone") { endSessionAndDismiss(archive: false) }
            Button("End and archive", role: .destructive) { endSessionAndDismiss(archive: true) }
        } message: {
            Text("End the live session for all participants. Choose \"End and archive\" to move it to the Archived section.")
        }
        .fileImporter(isPresented: $showingMaterialPicker, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
            // Dismiss the picker immediately so Close/Cancel works (binding can lag on some platforms).
            Task { @MainActor in
                showingMaterialPicker = false
            }
            Task {
                presentationError = nil
                isPresentingBibleOverlay = false
                do {
                    let urls = try result.get()
                    guard let selectedURL = urls.first else { return }
                    try await presentationService.presentMaterial(from: selectedURL)
                    let syncError = await syncPresentationToFirebase()
                    if let syncError = syncError {
                        presentationError = syncError
                        showingPresentationError = true
                    }
                    // Overlay shows the presentation; don't open sheet or it would show twice
                } catch {
                    // User cancelled or other error – only show alert for real errors, not cancellation
                    let nsErr = error as NSError
                    let isCancellation = nsErr.domain == NSCocoaErrorDomain && nsErr.code == NSUserCancelledError
                    if !isCancellation {
                        presentationError = error.localizedDescription
                        showingPresentationError = true
                    }
                }
            }
        }
        .alert("Presentation", isPresented: $showingPresentationError) {
            Button("OK") { showingPresentationError = false }
        } message: {
            Text(presentationError ?? "Something went wrong.")
        }
        .sheet(isPresented: $showingPresentationSheet) {
            if let topic = presentedBibleStudyTopic {
                TopicDetailView(
                    topic: topic,
                    isPresentationMode: true,
                    onStopPresenting: isHost ? {
                        presentedBibleStudyTopic = nil
                        presentationService.clearPresentation()
                        Task { await clearPresentationInFirebase() }
                        showingPresentationSheet = false
                    } : nil
                )
                #if os(iOS)
                .presentationDetents([.large])
                .presentationBackground(.regularMaterial)
                #endif
            } else if isPresentingBibleOverlay, role == .broadcaster {
                NavigationStack {
                    BibleView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    isPresentingBibleOverlay = false
                                    showingPresentationSheet = false
                                }
                            }
                        }
                }
                #if os(iOS)
                .presentationDetents([.large])
                .presentationBackground(.regularMaterial)
                #endif
            } else if let asset = participantPresentationAsset ?? presentationService.currentAsset {
                PresentationAssetSheetAgora(
                    asset: asset,
                    onStop: isHost ? {
                        presentationService.clearPresentation()
                        Task { await clearPresentationInFirebase() }
                        showingPresentationSheet = false
                    } : nil
                )
            } else {
                Text("Presentation is not available.")
                    .padding()
            }
        }
        .sheet(isPresented: $showingBibleStudySelector) {
            BibleStudyShareSheetAgora(
                topics: BibleStudyService.shared.getTopicsForLiveSession(),
                onSelect: { topic in
                    await shareBibleStudyTopic(topic)
                },
                onDismiss: { showingBibleStudySelector = false }
            )
        }
        .sheet(isPresented: $showingBibleSheet) {
            NavigationStack {
                BibleView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingBibleSheet = false }
                        }
                    }
            }
            #if os(iOS)
            .presentationDetents([.large])
            #endif
        }
        .sheet(isPresented: $showingLiveChat) {
            LiveSessionChatView(session: session, canSend: agoraService.isConnected)
            #if os(iOS)
                .presentationDetents([.large])
            #endif
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black.opacity(0.85), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .onAppear {
            guard !hasJoined else { return }
            if session.isArchived {
                joinError = "This session has been archived and can no longer be joined."
                return
            }
            hasJoined = true
            joinTimedOut = false
            #if os(iOS)
            requestCameraAndMicIfNeeded()
            #elseif os(macOS)
            requestCameraAndMicIfNeededMac()
            #endif
            startPresentationListener()
            startFloorListener()
            startChatListener()
            Task { await joinChannel() }
            Task {
                try? await Task.sleep(for: .seconds(15))
                await MainActor.run {
                    if !agoraService.isConnected && joinError == nil && agoraService.errorMessage == nil {
                        joinTimedOut = true
                    }
                }
            }
        }
        .onChange(of: agoraService.isConnected) { _, connected in
            if connected, isHost, recordNextSession, !hasStartedRecordingThisSession {
                hasStartedRecordingThisSession = true
                recordNextSession = false
                Task {
                    do {
                        try await StreamRecordingService.shared.startRecording(sessionId: session.id, title: session.title, quality: .hd)
                        RecordingCaptureFeeder.shared.start()
                    } catch {
                        print("⚠️ [AGORA RECORDING] Failed to start: \(error.localizedDescription)")
                    }
                }
            }
        }
        .onDisappear {
            if hasJoined {
                if isHost && StreamRecordingService.shared.isRecording {
                    Task {
                        await stopRecordingAndSave()
                        await MainActor.run { agoraService.leaveChannel() }
                    }
                } else {
                    agoraService.leaveChannel()
                }
            }
            FirebaseSyncService.shared.removePresentationListener(presentationListener)
            presentationListener = nil
            FirebaseSyncService.shared.removePresentationListener(floorListener)
            floorListener = nil
            FirebaseSyncService.shared.removeChatMessageListener(chatListener)
            chatListener = nil
        }
        .onChange(of: presentedBibleStudyTopic) { _, _ in participantClosedOverlay = false }
        .onChange(of: participantPresentationAsset) { _, _ in participantClosedOverlay = false }
        .onChange(of: isPresentingBibleOverlay) { oldValue, newValue in
            participantClosedOverlay = false
            if oldValue == true && newValue == false, isHost, role == .broadcaster {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    AgoraService.shared.invalidateLocalVideoBinding()
                }
            }
        }
        #if canImport(JitsiMeetSDK)
        .fullScreenCover(isPresented: $useJitsiInstead) {
            MultiParticipantStreamView_Jitsi(session: session)
        }
        #endif
    }

    @ViewBuilder
    private var agoraStackContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if agoraService.isConnected {
                AgoraParticipantGridView(
                    presentationHidesLocal: isHost && shouldShowPresentationOverlay,
                    presentationHidesRemoteUid: (!isHost && shouldShowPresentationOverlay) ? presenterRemoteVideoUidForPIP : nil
                )
            } else if let err = joinError ?? agoraService.errorMessage {
                errorOverlay(err)
            } else {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5).tint(.white)
                    Text(joinTimedOut ? "Taking longer than expected" : "Joining session...").foregroundColor(.white)
                    if joinTimedOut {
                        Button("Try again") {
                            joinTimedOut = false
                            joinError = nil
                            agoraService.errorMessage = nil
                            Task { await joinChannel() }
                        }
                        .buttonStyle(.borderedProminent).tint(.white).foregroundColor(.black)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #if os(iOS) || os(macOS)
            if agoraService.isConnected {
                VStack {
                    if session.typedStreamMode == .broadcast, role == .audience, broadcastOpenFloor {
                        HStack(spacing: 12) {
                            Image(systemName: "person.wave.2.fill").foregroundColor(.yellow)
                            Text("The host opened the floor — you can go on camera.")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Button("Present now") {
                                agoraService.promoteToPresenter()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                    Spacer()
                    liveSessionBottomBar
                }
                .allowsHitTesting(true)
                .zIndex(50)
            }
            #endif
            if agoraService.isConnected, showChatOverlay {
                AgoraLiveChatOverlay(
                    messages: $liveChatMessages,
                    inputText: $chatInputText,
                    bottomChromeInset: liveSessionBottomBarClearance,
                    canSend: agoraService.isConnected,
                    onSend: sendChatMessage
                )
                .zIndex(120)
            }
            // Presentation overlay on top so host and participants see shared material; host always sees own presentation
            if shouldShowPresentationOverlay {
                presentationOverlayContent
                    .zIndex(200)
            }
        }
    }
    
    /// True when presentation overlay should be visible: participants (unless they closed it) or host with any active content
    private var shouldShowPresentationOverlay: Bool {
        let hostHasContent = isHost && (presentationService.currentAsset != nil || presentedBibleStudyTopic != nil)
        /// Same layout as Bible Study: full-screen + presenter PIP. Sheet-only path never set this, so the camera tile was missing.
        let broadcasterBible = role == .broadcaster && isPresentingBibleOverlay
        return hostHasContent || broadcasterBible || (hasActivePresentation && !participantClosedOverlay)
    }

    /// For participants: which remote `uid` is the host (or best guess) for a small PIP of the presenter's face on top of slides/Bible.
    private var presenterRemoteVideoUidForPIP: UInt? {
        let r = agoraService.remoteUsers
        if r.isEmpty { return nil }
        if r.count == 1 { return r[0] }
        if case .remote(let u) = agoraService.spotlightSubject, r.contains(u) { return u }
        return r.sorted().first
    }

    private var shouldShowPresenterFacePIP: Bool {
        shouldShowPresentationOverlay
            && agoraService.isConnected
            && (role == .broadcaster || presenterRemoteVideoUidForPIP != nil)
    }

    @ToolbarContentBuilder
    private var agoraToolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .principal) {
            Text(streamModeLabel).font(.subheadline).foregroundColor(.white.opacity(0.9))
        }
        if role == .broadcaster {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingMaterialPicker = true } label: { Image(systemName: "doc.richtext") }
                    .disabled(!agoraService.isConnected)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingBibleStudySelector = true } label: { Image(systemName: "book.circle.fill") }
                    .accessibilityLabel("Bible Study")
                    .disabled(!agoraService.isConnected)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { openBibleForCurrentRole() } label: { Image(systemName: "text.book.closed") }
                    .accessibilityLabel("Bible")
                    .disabled(!agoraService.isConnected)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showChatOverlay.toggle() } label: { Image(systemName: showChatOverlay ? "bubble.left.fill" : "bubble.left") }
                    .accessibilityLabel(showChatOverlay ? "Hide chat overlay" : "Show chat overlay")
            }
            if hasActivePresentation {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingPresentationSheet = true } label: { Image(systemName: "eye.circle.fill") }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { agoraService.toggleAudio() } label: { Image(systemName: agoraService.isAudioEnabled ? "mic" : "mic.slash") }
                    .disabled(!agoraService.isConnected)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { agoraService.toggleVideo() } label: { Image(systemName: agoraService.isVideoEnabled ? "video" : "video.slash") }
                    .disabled(!agoraService.isConnected)
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { openBibleForCurrentRole() } label: { Image(systemName: "text.book.closed") }
                    .accessibilityLabel("Bible")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showChatOverlay.toggle() } label: { Image(systemName: showChatOverlay ? "bubble.left.fill" : "bubble.left") }
                    .accessibilityLabel(showChatOverlay ? "Hide chat overlay" : "Show chat overlay")
            }
            if hasActivePresentation {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingPresentationSheet = true } label: { Image(systemName: "eye.circle.fill") }
                }
            }
        }
        if isHost {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive, action: { showingEndSessionConfirmation = true }) {
                    Image(systemName: "stop.circle.fill")
                    Text("End session")
                }
                .font(.subheadline.weight(.medium))
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") { leaveAndDismiss() }
        }
        #else
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { leaveAndDismiss() }
        }
        ToolbarItem(placement: .principal) {
            Text(streamModeLabel).font(.subheadline).foregroundColor(.white.opacity(0.9))
        }
        if role == .broadcaster {
            ToolbarItem(placement: .automatic) {
                Button { showingMaterialPicker = true } label: { Image(systemName: "doc.richtext") }
                    .disabled(!agoraService.isConnected)
            }
            ToolbarItem(placement: .automatic) {
                Button { showingBibleStudySelector = true } label: { Image(systemName: "book.circle.fill") }
                    .accessibilityLabel("Bible Study")
                    .disabled(!agoraService.isConnected)
            }
            ToolbarItem(placement: .automatic) {
                Button { openBibleForCurrentRole() } label: { Image(systemName: "text.book.closed") }
                    .accessibilityLabel("Bible")
                    .disabled(!agoraService.isConnected)
            }
            ToolbarItem(placement: .automatic) {
                Button { showChatOverlay.toggle() } label: { Image(systemName: showChatOverlay ? "bubble.left.fill" : "bubble.left") }
                    .accessibilityLabel(showChatOverlay ? "Hide chat overlay" : "Show chat overlay")
            }
            if hasActivePresentation {
                ToolbarItem(placement: .automatic) {
                    Button { showingPresentationSheet = true } label: { Image(systemName: "eye.circle.fill") }
                }
            }
            ToolbarItem(placement: .automatic) {
                Button { agoraService.toggleAudio() } label: { Image(systemName: agoraService.isAudioEnabled ? "mic" : "mic.slash") }
                    .disabled(!agoraService.isConnected)
            }
            ToolbarItem(placement: .automatic) {
                Button { agoraService.toggleVideo() } label: { Image(systemName: agoraService.isVideoEnabled ? "video" : "video.slash") }
                    .disabled(!agoraService.isConnected)
            }
        } else {
            ToolbarItem(placement: .automatic) {
                Button { openBibleForCurrentRole() } label: { Image(systemName: "text.book.closed") }
                    .accessibilityLabel("Bible")
            }
            ToolbarItem(placement: .automatic) {
                Button { showChatOverlay.toggle() } label: { Image(systemName: showChatOverlay ? "bubble.left.fill" : "bubble.left") }
                    .accessibilityLabel(showChatOverlay ? "Hide chat overlay" : "Show chat overlay")
            }
            if presentedBibleStudyTopic != nil || presentationService.currentAsset != nil {
                ToolbarItem(placement: .automatic) {
                    Button { showingPresentationSheet = true } label: { Image(systemName: "eye.circle.fill") }
                }
            }
        }
        if isHost {
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive, action: { showingEndSessionConfirmation = true }) {
                    Image(systemName: "stop.circle.fill")
                    Text("End session")
                }
                .font(.subheadline.weight(.medium))
            }
        }
        #endif
    }

    #if os(iOS)
    private func requestCameraAndMicIfNeeded() {
        Task {
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraStatus == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
            }
            let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            if micStatus == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
        }
    }
    #elseif os(macOS)
    private func requestCameraAndMicIfNeededMac() {
        Task {
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraStatus == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
            }
            let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            if micStatus == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
        }
    }
    #endif

    /// Apply host's presentation state (used by listener and by initial fetch for participants).
    private func applyPresentationUpdate(type: String?, pdfURL: String?, imageURL: String?, bibleStudyDayOfYear: Int?) {
        Task { @MainActor in
            if type == nil || type == "none" {
                PresentationService.shared.clearPresentation()
                presentedBibleStudyTopic = nil
                participantPresentationAsset = nil
                presentationLoadFailed = false
                isPresentingBibleOverlay = false
                showingPresentationSheet = false
                return
            }
            if type == "bibleStudy", let day = bibleStudyDayOfYear, day >= 1, day <= 365 {
                presentedBibleStudyTopic = BibleStudyService.shared.getTopicForDay(day)
                participantPresentationAsset = nil
                return
            }
            if let urlString = pdfURL, !urlString.isEmpty {
                let title = (type == "bibleStudy" && bibleStudyDayOfYear != nil)
                    ? (BibleStudyService.shared.getTopicForDay(bibleStudyDayOfYear!).title)
                    : "Presentation"
                do {
                    try await PresentationService.shared.presentFromRemoteURL(urlString, title: title)
                    participantPresentationAsset = PresentationService.shared.currentAsset
                    presentedBibleStudyTopic = nil
                    presentationLoadFailed = false
                } catch {
                    print("⚠️ [PRESENTATION] Participant failed to load PDF: \(error.localizedDescription)")
                    participantPresentationAsset = nil
                    presentationLoadFailed = true
                }
            } else if let urlString = imageURL, !urlString.isEmpty {
                do {
                    try await PresentationService.shared.presentFromRemoteURL(urlString, title: "Image")
                    participantPresentationAsset = PresentationService.shared.currentAsset
                    presentedBibleStudyTopic = nil
                    presentationLoadFailed = false
                } catch {
                    print("⚠️ [PRESENTATION] Participant failed to load image: \(error.localizedDescription)")
                    participantPresentationAsset = nil
                    presentationLoadFailed = true
                }
            }
        }
    }

    private func startFloorListener() {
        let sid = session.id
        floorListener = FirebaseSyncService.shared.startListeningBroadcastOpenFloor(sessionId: sid) { open in
            let wasOpen = self.broadcastOpenFloor
            self.broadcastOpenFloor = open
            if wasOpen && !open,
               self.session.typedStreamMode == .broadcast,
               !self.isHost,
               self.agoraService.currentRole == .broadcaster {
                self.agoraService.demoteToAudience()
            }
        }
    }

    private func startPresentationListener() {
        let sid = session.id
        presentationListener = FirebaseSyncService.shared.startListeningToSessionPresentation(sessionId: sid) { type, pdfURL, imageURL, bibleStudyDayOfYear in
            self.applyPresentationUpdate(type: type, pdfURL: pdfURL, imageURL: imageURL, bibleStudyDayOfYear: bibleStudyDayOfYear)
        }
        // Participants: fetch current presentation once so we show host's slide even if listener fires before they joined
        if !isHost {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                let (type, pdfURL, imageURL, day) = await FirebaseSyncService.shared.fetchCurrentSessionPresentation(sessionId: sid)
                applyPresentationUpdate(type: type, pdfURL: pdfURL, imageURL: imageURL, bibleStudyDayOfYear: day)
            }
        }
    }

    /// Returns an error message if sync failed (e.g. Storage not configured); nil on success.
    private func syncPresentationToFirebase() async -> String? {
        guard isHost, let asset = presentationService.currentAsset else { return nil }
        do {
            let data = try Data(contentsOf: asset.fileURL)
            let ext = asset.fileURL.pathExtension
            let contentType = ext == "pdf" ? "application/pdf" : "image/jpeg"
            let urlString = try await FirebaseSyncService.shared.uploadPresentationData(
                sessionId: session.id,
                data: data,
                contentType: contentType,
                fileExtension: ext.isEmpty ? "pdf" : ext
            )
            if asset.type == .pdf {
                await FirebaseSyncService.shared.setSessionPresentation(sessionId: session.id, type: "pdf", pdfURL: urlString)
            } else {
                await FirebaseSyncService.shared.setSessionPresentation(sessionId: session.id, type: "image", imageURL: urlString)
            }
            return nil
        } catch {
            print("⚠️ [PRESENTATION] Sync to Firebase failed: \(error.localizedDescription)")
            return "Upload failed: \(error.localizedDescription). Participants won't see the file until it's uploaded. Check that Firebase Storage is enabled."
        }
    }

    private func clearPresentationInFirebase() async {
        guard isHost else { return }
        await FirebaseSyncService.shared.setSessionPresentation(sessionId: session.id, type: "none")
    }

    private func shareBibleStudyTopic(_ topic: BibleStudyTopic) async {
        isPresentingBibleOverlay = false
        // Show in overlay only (everyone sees at same time); don't open sheet or topic would show twice
        presentedBibleStudyTopic = topic
        showingBibleStudySelector = false

        guard isHost else { return }
        do {
            try await presentationService.presentBibleStudy(topic: topic)
            guard let day = BibleStudyService.shared.topicDayOfYear(for: topic) else { return }
            if let asset = presentationService.currentAsset {
                let data = try Data(contentsOf: asset.fileURL)
                let urlString = try await FirebaseSyncService.shared.uploadPresentationData(
                    sessionId: session.id,
                    data: data,
                    contentType: "application/pdf",
                    fileExtension: "pdf"
                )
                await FirebaseSyncService.shared.setSessionPresentation(
                    sessionId: session.id,
                    type: "bibleStudy",
                    pdfURL: urlString,
                    bibleStudyDayOfYear: day
                )
            } else {
                await FirebaseSyncService.shared.setSessionPresentation(
                    sessionId: session.id,
                    type: "bibleStudy",
                    pdfURL: nil,
                    imageURL: nil,
                    bibleStudyDayOfYear: day
                )
            }
            // Host sees TopicDetailView only; clear PDF so sheet never shows PDF viewer
            presentationService.clearPresentation()
        } catch {
            // Still sync topic for participants (day of year) even if PDF failed
            if let day = BibleStudyService.shared.topicDayOfYear(for: topic) {
                await FirebaseSyncService.shared.setSessionPresentation(
                    sessionId: session.id,
                    type: "bibleStudy",
                    pdfURL: nil,
                    imageURL: nil,
                    bibleStudyDayOfYear: day
                )
            }
        }
    }

    private var streamModeLabel: String {
        switch session.typedStreamMode {
        case .broadcast:        return "Broadcast"
        case .multiParticipant: return "Multi-Participant"
        case .conference:       return "Conference"
        }
    }

    private func startChatListener() {
        guard chatListener == nil else { return }
        let sid = session.id
        chatListener = FirebaseSyncService.shared.startListeningToChatMessages(sessionId: sid) { chatMessage in
            DispatchQueue.main.async {
                let live = LiveChatMessage(
                    username: chatMessage.userName.isEmpty ? "Participant" : chatMessage.userName,
                    text: chatMessage.message,
                    isSuperChat: false,
                    superChatAmount: nil
                )
                liveChatMessages.append(live)
                if liveChatMessages.count > 60 {
                    liveChatMessages.removeFirst(max(0, liveChatMessages.count - 60))
                }
            }
        }
    }

    private func sendChatMessage() {
        let text = chatInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatInputText = ""

        let msg = ChatMessage(
            sessionId: session.id,
            userId: userService.userIdentifier,
            userName: displayName.isEmpty ? "Participant" : displayName,
            message: text,
            messageType: .text
        )
        modelContext.insert(msg)
        try? modelContext.save()
        Task { await FirebaseSyncService.shared.syncChatMessage(msg) }
    }

    /// True when host or participant has presentation content (Bible study or PDF/image) so everyone sees it.
    private var hasActivePresentation: Bool {
        presentedBibleStudyTopic != nil
            || presentationService.currentAsset != nil
            || participantPresentationAsset != nil
            || presentationLoadFailed
            || (role == .broadcaster && isPresentingBibleOverlay)
    }

    #if os(iOS)
    /// One-line label under an icon: avoids wrapping when many controls share the bottom bar.
    @ViewBuilder
    private func liveSessionBottomControlCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsTightening(true)
            .multilineTextAlignment(.center)
    }

    /// Bottom bar so live session features (present, Bible, mic, video, end, Done) are always visible on iOS.
    private var liveSessionBottomBar: some View {
        HStack(alignment: .center, spacing: 10) {
            if role == .broadcaster {
                Button { showingMaterialPicker = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.richtext").font(.title2)
                        liveSessionBottomControlCaption("Present")
                    }
                    .foregroundColor(.white)
                }
                .disabled(!agoraService.isConnected)
                Button { showingBibleStudySelector = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "book.circle.fill").font(.title2)
                        liveSessionBottomControlCaption("Study")
                    }
                    .foregroundColor(.white)
                }
                .disabled(!agoraService.isConnected)
            }
            Button { openBibleForCurrentRole() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "text.book.closed").font(.title2)
                    liveSessionBottomControlCaption("Bible")
                }
                .foregroundColor(.white)
            }
            .disabled(!agoraService.isConnected)
            Button { showChatOverlay.toggle() } label: {
                VStack(spacing: 4) {
                    Image(systemName: showChatOverlay ? "bubble.left.fill" : "bubble.left").font(.title2)
                    liveSessionBottomControlCaption(showChatOverlay ? "Chat On" : "Chat Off")
                }
                .foregroundColor(.white)
            }
            if hasActivePresentation {
                Button { showingPresentationSheet = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "eye.circle.fill").font(.title2)
                        liveSessionBottomControlCaption("View")
                    }
                    .foregroundColor(.white)
                }
            }
            if role == .broadcaster {
                Button { agoraService.toggleAudio() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: agoraService.isAudioEnabled ? "mic.fill" : "mic.slash").font(.title2)
                        liveSessionBottomControlCaption(agoraService.isAudioEnabled ? "Mic" : "Mute")
                    }
                    .foregroundColor(.white)
                }
                .disabled(!agoraService.isConnected)
                Button { agoraService.toggleVideo() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: agoraService.isVideoEnabled ? "video.fill" : "video.slash").font(.title2)
                        liveSessionBottomControlCaption(agoraService.isVideoEnabled ? "Video" : "Off")
                    }
                    .foregroundColor(.white)
                }
                .disabled(!agoraService.isConnected)
                if isHost {
                    Button(role: .destructive) { showingEndSessionConfirmation = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill").font(.title2)
                            liveSessionBottomControlCaption("End")
                        }
                        .foregroundColor(.red)
                    }
                    if session.typedStreamMode == .broadcast {
                        Menu {
                            Button {
                                Task { await FirebaseSyncService.shared.setBroadcastOpenFloor(sessionId: session.id, open: true) }
                            } label: {
                                Label("Open floor (audience can present)", systemImage: "person.3.fill")
                            }
                            Button {
                                Task { await FirebaseSyncService.shared.setBroadcastOpenFloor(sessionId: session.id, open: false) }
                            } label: {
                                Label("Close floor", systemImage: "person.fill.xmark")
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: broadcastOpenFloor ? "person.3.fill" : "person.3").font(.title2)
                                liveSessionBottomControlCaption("Floor")
                            }
                            .foregroundColor(broadcastOpenFloor ? .green : .white)
                        }
                    }
                }
            }
            Spacer(minLength: 4)
            Button { leaveAndDismiss() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                    liveSessionBottomControlCaption("Done")
                }
                .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.75))
        .padding(.bottom, 8)
    }
    #elseif os(macOS)
    /// Bottom bar for macOS so Present, Bible, View presentation, mic, video are visible and clickable.
    private var liveSessionBottomBar: some View {
        HStack(spacing: 20) {
            if role == .broadcaster {
                Button { showingMaterialPicker = true } label: {
                    Label("Present", systemImage: "doc.richtext")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!agoraService.isConnected)
                Button { showingBibleStudySelector = true } label: {
                    Label("Bible Study", systemImage: "book.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!agoraService.isConnected)
            }
            Button { openBibleForCurrentRole() } label: {
                Label("Bible", systemImage: "text.book.closed")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!agoraService.isConnected)
            Button { showChatOverlay.toggle() } label: {
                Label(showChatOverlay ? "Chat On" : "Chat Off", systemImage: showChatOverlay ? "bubble.left.fill" : "bubble.left")
            }
            .buttonStyle(.borderedProminent)
            if hasActivePresentation {
                Button { showingPresentationSheet = true } label: {
                    Label("View presentation", systemImage: "eye.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            if role == .broadcaster {
                Button { agoraService.toggleAudio() } label: {
                    Label(agoraService.isAudioEnabled ? "Mic on" : "Mute", systemImage: agoraService.isAudioEnabled ? "mic.fill" : "mic.slash")
                }
                .buttonStyle(.bordered)
                .disabled(!agoraService.isConnected)
                Button { agoraService.toggleVideo() } label: {
                    Label(agoraService.isVideoEnabled ? "Video on" : "Video off", systemImage: agoraService.isVideoEnabled ? "video.fill" : "video.slash")
                }
                .buttonStyle(.bordered)
                .disabled(!agoraService.isConnected)
                if isHost {
                    Button(role: .destructive) { showingEndSessionConfirmation = true } label: {
                        Label("End session", systemImage: "stop.circle.fill")
                    }
                    if session.typedStreamMode == .broadcast {
                        Menu {
                            Button {
                                Task { await FirebaseSyncService.shared.setBroadcastOpenFloor(sessionId: session.id, open: true) }
                            } label: {
                                Label("Open floor (audience can present)", systemImage: "person.3.fill")
                            }
                            Button {
                                Task { await FirebaseSyncService.shared.setBroadcastOpenFloor(sessionId: session.id, open: false) }
                            } label: {
                                Label("Close floor", systemImage: "person.fill.xmark")
                            }
                        } label: {
                            Label("Floor", systemImage: broadcastOpenFloor ? "person.3.fill" : "person.3")
                        }
                        .foregroundColor(broadcastOpenFloor ? .green : .primary)
                    }
                }
            }
            Spacer()
            Button { leaveAndDismiss() } label: {
                Label("Done", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Material.regular)
    }
    #endif

    private func openBibleForCurrentRole() {
        if role == .broadcaster { isPresentingBibleOverlay = true }
        else { showingBibleSheet = true }
    }

    /// Full-screen overlay so everyone sees the same presentation at the same time.
    @ViewBuilder
    private var presentationOverlayContent: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if isPresentingBibleOverlay, role == .broadcaster {
                    NavigationStack {
                        BibleView()
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close") { isPresentingBibleOverlay = false }
                                }
                            }
                    }
                    .preferredColorScheme(.light)
                    #if os(iOS)
                    .background(Color(UIColor.systemBackground))
                    #elseif os(macOS)
                    .background(Color(NSColor.windowBackgroundColor))
                    #endif
                } else if let topic = presentedBibleStudyTopic {
                    TopicDetailView(
                        topic: topic,
                        isPresentationMode: true,
                        onStopPresenting: isHost ? {
                            presentedBibleStudyTopic = nil
                            presentationService.clearPresentation()
                            Task { await clearPresentationInFirebase() }
                            showingPresentationSheet = false
                        } : {
                            participantClosedOverlay = true
                        }
                    )
                    .preferredColorScheme(.light)
                    #if os(iOS)
                    .background(Color(UIColor.systemBackground))
                    #elseif os(macOS)
                    .background(Color(NSColor.windowBackgroundColor))
                    #endif
                } else if let asset = participantPresentationAsset ?? presentationService.currentAsset {
                    PresentationAssetSheetAgora(
                        asset: asset,
                        onStop: isHost ? {
                            presentationService.clearPresentation()
                            Task { await clearPresentationInFirebase() }
                            showingPresentationSheet = false
                        } : {
                            participantClosedOverlay = true
                        }
                    )
                } else if presentationLoadFailed {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.richtext.badge.ellipsis")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Host is presenting")
                            .font(.headline)
                        Text("Content could not be loaded. Ask the host to try again or check your connection.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if shouldShowPresenterFacePIP { presenterFacePIP.padding(.trailing, 10).padding(.top, 8) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    /// Small camera tile so you still see the presenter’s face while slides / Bible study fill the screen.
    @ViewBuilder
    private var presenterFacePIP: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if role == .broadcaster {
                ZStack(alignment: .bottomLeading) {
                    if agoraService.isVideoEnabled {
                        AgoraVideoView(uid: 0, isLocal: true)
                            .id("pip-local-broadcaster")
                    } else {
                        ZStack {
                            Color(white: 0.2)
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    Text("You")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
            } else if let uid = presenterRemoteVideoUidForPIP {
                ZStack(alignment: .bottomLeading) {
                    AgoraVideoView(uid: uid, isLocal: false)
                    Text(session.hostName.isEmpty ? "Host" : session.hostName)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
            }
        }
        .frame(width: 120, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }

    private func errorOverlay(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
                Text("Connection failed").font(.headline).foregroundColor(.white)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Try again") {
                    joinError = nil
                    agoraService.errorMessage = nil
                    Task { await joinChannel() }
                }
                .buttonStyle(.borderedProminent).tint(.white).foregroundColor(.black)
                Button("Done") { leaveAndDismiss() }
                    .buttonStyle(.bordered).tint(.white)
                #if canImport(JitsiMeetSDK)
                if JitsiService.isMeetSDKAvailable {
                    Button("Use Jitsi Meet instead") {
                        agoraService.leaveChannel()
                        useJitsiInstead = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.cyan)
                    .foregroundColor(.white)
                }
                #endif
            }
            .padding(24)
        }
    }

    private func joinChannel() async {
        joinError = nil
        agoraService.errorMessage = nil
        guard AgoraService.shared.isAvailable else {
            joinError = "Agora is not configured. Add your App ID in AgoraService."
            return
        }
        let identity = userService.userIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identity.isEmpty else {
            joinError = "Sign in to join the session."
            return
        }
        do {
            try await AgoraService.shared.joinChannel(
                sessionId: session.id,
                userId: identity,
                userName: displayName,
                role: role,
                token: nil
            )
        } catch {
            joinError = error.localizedDescription
        }
    }

    private func leaveAndDismiss() {
        isPresentingBibleOverlay = false
        if isHost && StreamRecordingService.shared.isRecording {
            Task {
                await stopRecordingAndSave()
                await MainActor.run {
                    agoraService.leaveChannel()
                    dismiss()
                }
            }
        } else {
            agoraService.leaveChannel()
            dismiss()
        }
    }

    /// End the session for everyone (host only), optionally archive, sync to Firebase, then leave and dismiss.
    private func endSessionAndDismiss(archive: Bool) {
        guard isHost else { return }
        session.isActive = false
        session.endTime = Date()
        if archive { session.isArchived = true }
        if StreamRecordingService.shared.isRecording {
            Task {
                await stopRecordingAndSave()
                await MainActor.run {
                    agoraService.leaveChannel()
                    dismiss()
                }
                try? modelContext.save()
                await FirebaseSyncService.shared.syncLiveSessionPublic(session)
            }
        } else {
            agoraService.leaveChannel()
            dismiss()
            Task {
                try? modelContext.save()
                await FirebaseSyncService.shared.syncLiveSessionPublic(session)
            }
        }
    }

    /// Stop recording feeder and StreamRecordingService; upload to cloud or save local URL to session.
    private func stopRecordingAndSave() async {
        RecordingCaptureFeeder.shared.stop()
        guard StreamRecordingService.shared.isRecording else { return }
        guard let rec = try? await StreamRecordingService.shared.stopRecording(sessionId: session.id, title: session.title) else { return }
        let fileURL = rec.fileURL
        if uploadReplayToCloud {
            let sessionId = session.id
            do {
                let urlString = try await FirebaseSyncService.shared.uploadRecording(sessionId: sessionId, fileURL: fileURL)
                await MainActor.run {
                    FirebaseSyncService.shared.saveRecordingURL(sessionId: sessionId, urlString: urlString)
                }
            } catch {
                print("⚠️ [AGORA RECORDING] Upload failed: \(error.localizedDescription)")
                await MainActor.run {
                    session.recordingURL = fileURL.absoluteString
                    try? modelContext.save()
                }
            }
        } else {
            await MainActor.run {
                session.recordingURL = fileURL.absoluteString
                try? modelContext.save()
            }
        }
        await FirebaseSyncService.shared.syncLiveSessionPublic(session)
    }
    #endif // (os(iOS) || os(macOS)) && canImport(AgoraRtcKit)
}
#endif

// MARK: - On-video chat overlay (Agora)

#if os(iOS) || os(macOS)
@available(iOS 17.0, macOS 14.0, *)
private struct AgoraLiveChatOverlay: View {
    @Binding var messages: [LiveChatMessage]
    @Binding var inputText: String
    /// Reserve space above the home indicator for the session bottom bar (icons).
    var bottomChromeInset: CGFloat = 0
    let canSend: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(messages.suffix(5)) { msg in
                        HStack(alignment: .top, spacing: 8) {
                            Text(msg.username + ":")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(nameColor(for: msg))
                                .lineLimit(1)
                            Text(msg.text)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .frame(maxWidth: min(geo.size.width * 0.78, 420), alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)

                HStack(spacing: 10) {
                    TextField("Chat…", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .disabled(!canSend)
                        .submitLabel(.send)
                        .onSubmit { if canSend { onSend() } }

                    Button(action: onSend) {
                        Image(systemName: "paperplane.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(width: 38, height: 38)
                            .background(canSend && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white : Color.white.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .disabled(!canSend || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, max(10, geo.safeAreaInsets.bottom + 8 + bottomChromeInset))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func nameColor(for msg: LiveChatMessage) -> Color {
        let palette: [Color] = [
            Color(red: 0.12, green: 0.71, blue: 0.96),
            Color(red: 0.30, green: 0.85, blue: 0.56),
            Color(red: 0.96, green: 0.71, blue: 0.12),
            Color(red: 0.96, green: 0.45, blue: 0.12),
            Color(red: 0.71, green: 0.40, blue: 0.96),
            Color(red: 0.96, green: 0.26, blue: 0.45),
        ]
        return palette[msg.colorIndex % palette.count]
    }
}
#endif

// MARK: - Presentation sheets (used by MultiParticipantStreamView_Agora)

#if os(iOS)
private struct QuickLookPreviewAgora: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController()
        c.dataSource = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
#endif

private struct PresentationAssetSheetAgora: View {
    let asset: PresentationService.PresentationAsset
    let onStop: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Label(asset.title, systemImage: asset.type == .pdf ? "doc.richtext" : "photo")
                        .font(.headline)
                    Spacer()
                    if let onStop = onStop {
                        Button("Stop") {
                            onStop()
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding()
                #if os(iOS)
                QuickLookPreviewAgora(url: asset.fileURL)
                    .padding()
                #else
                Text("Open: \(asset.fileURL.lastPathComponent)")
                    .padding()
                #endif
                Spacer()
            }
            .navigationTitle("Presentation")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onStop?()
                    }
                }
            }
        }
    }
}

private struct BibleStudyShareSheetAgora: View {
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
        let q = searchText.lowercased()
        return availableTopics.filter {
            $0.title.lowercased().contains(q) ||
            $0.topicDescription.lowercased().contains(q) ||
            $0.keyVerses.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        let daily = BibleStudyService.shared.getDailyTopic()
                        previewTopic = daily
                        guard processingTopicId == nil else { return }
                        processingTopicId = daily.id
                        Task {
                            await onSelect(daily)
                            processingTopicId = nil
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Today's Bible Study")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(BibleStudyService.shared.getDailyTopic().title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if processingTopicId == BibleStudyService.shared.getDailyTopic().id {
                                ProgressView()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(processingTopicId != nil)
                }

                Section(header: Text("All topics")) {
                    if filteredTopics.isEmpty {
                        Text("No topics match your search.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredTopics, id: \.id) { topic in
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
                    }
                }

                if let topic = previewTopic {
                    Section(header: Text("Topic preview")) {
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
                                ForEach(Array(topic.studyQuestions.enumerated()), id: \.offset) { _, question in
                                    Text("• \(question)")
                                        .font(.caption)
                                }
                            }
                        }

                        if !topic.applicationPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Application Points")
                                    .font(.headline)
                                ForEach(Array(topic.applicationPoints.enumerated()), id: \.offset) { _, point in
                                    Text("• \(point)")
                                        .font(.caption)
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
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .searchable(text: $searchText, prompt: "Search topics or verses")
            .navigationTitle("Present Bible Study")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
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
            .overlay {
                if processingTopicId != nil {
                    VStack {
                        Spacer()
                        ProgressView("Preparing topic...")
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                        Spacer()
                    }
                }
            }
        }
    }
}
