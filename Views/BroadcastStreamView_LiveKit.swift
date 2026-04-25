//
//  BroadcastStreamView_LiveKit.swift
//  Faith Journal
//
//  LiveKit-based streaming view for cross-location broadcasting.
//  Requires the LiveKit Swift SDK (add via SPM):
//    https://github.com/livekit/client-sdk-swift
//

import SwiftUI
import AVFoundation
import SwiftData

#if canImport(LiveKit)
import LiveKit
#endif

// MARK: - Main View

@available(iOS 16.0, *)
struct BroadcastStreamView_LiveKit: View {
    let sessionTitle: String
    let sessionCategory: String
    let sessionHostId: String
    let currentParticipants: Int

    @Environment(\.dismiss) private var dismiss
    @StateObject private var liveKitService = LiveKitService.shared

    @State private var isHost = false
    @State private var userName = "User"
    @State private var showSettings = false
    @State private var isMuted = false
    @State private var isCameraOff = false
    @State private var roomName = ""

    private var currentUserId: String {
        // Try to get from ProfileManager if available, otherwise fall back to stored value
        UserDefaults.standard.string(forKey: "currentUserId") ?? UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                videoArea
                controlsArea
            }

            if case .connecting = liveKitService.connectionState {
                connectingOverlay
            }
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .alert("Stream Error", isPresented: .constant(liveKitErrorIsPresented)) {
            Button("OK", role: .cancel) { }
            if liveKitService.errorMessage?.contains("SDK not installed") == true {
                Button("Learn More") {
                    // Instructions shown in the alert message body
                }
            }
        } message: {
            Text(liveKitService.errorMessage ?? "")
        }
        .onAppear { connect() }
        .onDisappear {
            Task { await liveKitService.disconnect() }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var videoArea: some View {
        ZStack {
#if canImport(LiveKit)
            // Real video surfaces rendered by the LiveKit SDK
            if liveKitService.isConnected {
                LiveKitVideoSurface(isHost: isHost, service: liveKitService)
            } else {
                placeholderVideo
            }
#else
            placeholderVideo
#endif
            topOverlay
        }
        .frame(maxHeight: .infinity)
    }

    private var placeholderVideo: some View {
        VStack(spacing: 16) {
            Image(systemName: isHost ? "video.circle.fill" : "person.video.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.3))

            switch liveKitService.connectionState {
            case .connected:
                Text(isHost ? "Broadcasting" : "Watching Stream")
                    .font(.headline).foregroundColor(.white)
            case .error:
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                    Text("Could not connect")
                        .font(.headline).foregroundColor(.white)
                    Text(liveKitService.errorMessage ?? "Unknown error")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            default:
                Text(sessionTitle)
                    .font(.caption).foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private var topOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionTitle)
                        .font(.headline).foregroundColor(.white)
                    Text(sessionCategory)
                        .font(.caption).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                liveBadge
            }
            .padding()
            .background(Color.black.opacity(0.5))
            Spacer()
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(liveKitService.isConnected ? Color.red : Color.gray)
                .frame(width: 8, height: 8)
            Text(liveKitService.isConnected ? "LIVE" : liveKitService.getConnectionStatus().uppercased())
                .font(.caption2.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((liveKitService.isConnected ? Color.red : Color.gray).opacity(0.25))
        .cornerRadius(6)
    }

    private var controlsArea: some View {
        VStack(spacing: 12) {
            HStack {
                Label("\(liveKitService.viewerCount) watching", systemImage: "person.fill")
                    .font(.caption).foregroundColor(.white.opacity(0.7))
                Spacer()
                if isHost {
                    Label("Host", systemImage: "crown.fill")
                        .font(.caption).foregroundColor(.yellow)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                if isHost {
                    Button(action: toggleMute) {
                        Label(isMuted ? "Unmute" : "Mute",
                              systemImage: isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.caption).foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background((isMuted ? Color.red : Color.gray).opacity(0.3))
                            .cornerRadius(6)
                    }

                    Button(action: toggleCamera) {
                        Label(isCameraOff ? "Camera On" : "Camera",
                              systemImage: isCameraOff ? "video.slash.fill" : "video.fill")
                            .font(.caption).foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background((isCameraOff ? Color.red : Color.gray).opacity(0.3))
                            .cornerRadius(6)
                    }
                }

                Spacer()

                Menu {
                    Button("Settings") { showSettings = true }
                    Button("Leave", role: .destructive) { dismiss() }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24)).foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
        }
    }

    private var connectingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Connecting…")
                    .font(.caption).foregroundColor(.white)
            }
        }
        .ignoresSafeArea()
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Session Info") {
                    LabeledContent("Title") { Text(sessionTitle) }
                    LabeledContent("Category") { Text(sessionCategory) }
                    LabeledContent("Participants") { Text("\(currentParticipants)") }
                    LabeledContent("Status") { Text(liveKitService.getConnectionStatus()) }
                }
                Section("Your Settings") {
                    TextField("Username", text: $userName)
                    Toggle("Host", isOn: $isHost)
                }
                Section {
                    Button("Leave Stream", role: .destructive) { dismiss() }
                }
            }
            .navigationTitle("Stream Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private var liveKitErrorIsPresented: Bool {
        if case .error = liveKitService.connectionState { return true }
        return false
    }

    private func connect() {
        isHost = sessionHostId == currentUserId
        roomName = "faith-\(sessionHostId)"
        Task {
            do {
                if isHost {
                    try await liveKitService.connectAsHost(roomName: roomName, userName: userName)
                } else {
                    try await liveKitService.connectAsViewer(roomName: roomName, userName: userName)
                }
            } catch {
                // Error state is set on liveKitService.connectionState by the service
            }
        }
    }

    private func toggleMute() {
        isMuted.toggle()
        Task {
            if isMuted {
                await liveKitService.stopPublishingAudio()
            } else {
                // Re-enable audio — requires reconnect or SDK call
#if canImport(LiveKit)
                _ = try? await liveKitService.room?.localParticipant.setMicrophone(enabled: true)
#endif
            }
        }
    }

    private func toggleCamera() {
        isCameraOff.toggle()
        Task {
            if isCameraOff {
                await liveKitService.stopPublishingCamera()
            } else {
#if canImport(LiveKit)
                _ = try? await liveKitService.room?.localParticipant.setCamera(enabled: true)
#endif
            }
        }
    }
}

// MARK: - LiveKit video surface (SDK present only)

#if canImport(LiveKit)
@available(iOS 16.0, *)
private struct LiveKitVideoSurface: View {
    let isHost: Bool
    @ObservedObject var service: LiveKitService

    var body: some View {
        if isHost, let room = service.room, let track = room.localParticipant.firstCameraVideoTrack {
            SwiftUIVideoView(track)
                .background(Color.black)
        } else {
            // Grid of remote video tracks
            let presenters = service.getVisiblePresenters()
            if presenters.isEmpty {
                Color.black
            } else {
                let layout = service.getGridLayout()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: layout.cols)) {
                    ForEach(presenters) { p in
                        RemoteVideoCell(participant: p, room: service.room)
                    }
                }
            }
        }
    }
}

@available(iOS 16.0, *)
private struct RemoteVideoCell: View {
    let participant: LiveKitService.RemoteParticipantInfo
    let room: Room?

    var body: some View {
        ZStack {
            Color.black
            Text(participant.displayName.prefix(1))
                .font(.largeTitle.bold())
                .foregroundColor(.white)
        }
        .aspectRatio(16/9, contentMode: .fit)
        .cornerRadius(8)
    }
}
#endif

// MARK: - Preview

#Preview {
    if #available(iOS 16.0, *) {
        BroadcastStreamView_LiveKit(
            sessionTitle: "Evening Prayer",
            sessionCategory: "Prayer",
            sessionHostId: "host-123",
            currentParticipants: 5
        )
    }
}
