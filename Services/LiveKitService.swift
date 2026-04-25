//
//  LiveKitService.swift
//  Faith Journal
//
//  LiveKit WebRTC integration for cross-location streaming.
//  Add the LiveKit Swift SDK via SPM to enable real video:
//    https://github.com/livekit/client-sdk-swift
//  Until then, connect/publish calls throw LiveKitError.sdkNotInstalled.
//

import Foundation
import AVFoundation
import Combine
import CryptoKit

#if canImport(LiveKit)
import LiveKit
#endif

@available(iOS 17.0, *)
@MainActor
class LiveKitService: NSObject, ObservableObject {
    static let shared = LiveKitService()

    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var isPublishing = false
    @Published var isSubscribing = false
    @Published var remoteParticipants: [RemoteParticipantInfo] = []
    @Published var errorMessage: String?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var viewerCount = 0
    @Published var activePresenters: [RemoteParticipantInfo] = []
    @Published var presentationMode: PresentationMode = .singlePresenter

    // MARK: - Private Properties
#if canImport(LiveKit)
    private(set) var room: Room?
#endif
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Types

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    enum PresentationMode {
        case singlePresenter
        case multiPresenter
    }

    struct RemoteParticipantInfo: Identifiable {
        let id: String
        let name: String
        let displayName: String
        let isAudioEnabled: Bool
        let isVideoEnabled: Bool
    }

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    func setPresentationMode(_ mode: PresentationMode) {
        presentationMode = mode
    }

    // MARK: - Connection Management

    /// Connect to LiveKit server as host/presenter.
    func connectAsHost(roomName: String, userName: String) async throws {
        connectionState = .connecting

        let serverURL = StreamingConfig.getServerURL()
        guard !serverURL.isEmpty, serverURL.hasPrefix("wss://") || serverURL.hasPrefix("ws://") else {
            let msg = "Invalid LiveKit server URL: \(serverURL). Check StreamingConfig / LiveKitSecret.plist."
            errorMessage = msg
            connectionState = .error(msg)
            throw LiveKitError.invalidServerURL
        }

        let token = try generateToken(roomName: roomName, identity: userName, isPublisher: true)

#if canImport(LiveKit)
        let lkRoom = Room()
        try await lkRoom.connect(url: serverURL, token: token)
        self.room = lkRoom

        try await lkRoom.localParticipant.setCamera(enabled: true)
        try await lkRoom.localParticipant.setMicrophone(enabled: true)

        isPublishing = true
        isConnected = true
        connectionState = .connected
        errorMessage = nil
        print("🎬 [LIVEKIT] Connected as host to \(serverURL), room '\(roomName)'")
#else
        let msg = "LiveKit SDK not installed. Add https://github.com/livekit/client-sdk-swift via Xcode → File → Add Package Dependencies."
        errorMessage = msg
        connectionState = .error(msg)
        throw LiveKitError.sdkNotInstalled
#endif
    }

    /// Connect to LiveKit server as viewer (subscribe only).
    func connectAsViewer(roomName: String, userName: String) async throws {
        connectionState = .connecting

        let serverURL = StreamingConfig.getServerURL()
        guard !serverURL.isEmpty, serverURL.hasPrefix("wss://") || serverURL.hasPrefix("ws://") else {
            let msg = "Invalid LiveKit server URL: \(serverURL). Check StreamingConfig / LiveKitSecret.plist."
            errorMessage = msg
            connectionState = .error(msg)
            throw LiveKitError.invalidServerURL
        }

        let token = try generateToken(roomName: roomName, identity: userName, isPublisher: false)

#if canImport(LiveKit)
        let lkRoom = Room()
        try await lkRoom.connect(url: serverURL, token: token)
        self.room = lkRoom

        isSubscribing = true
        isConnected = true
        connectionState = .connected
        errorMessage = nil
        print("👁️ [LIVEKIT] Connected as viewer to \(serverURL), room '\(roomName)'")
#else
        let msg = "LiveKit SDK not installed. Add https://github.com/livekit/client-sdk-swift via Xcode → File → Add Package Dependencies."
        errorMessage = msg
        connectionState = .error(msg)
        throw LiveKitError.sdkNotInstalled
#endif
    }

    /// Disconnect from the room and reset state.
    func disconnect() async {
#if canImport(LiveKit)
        await room?.disconnect()
        room = nil
#endif
        isConnected = false
        isPublishing = false
        isSubscribing = false
        connectionState = .disconnected
        remoteParticipants = []
        activePresenters = []
        viewerCount = 0
        errorMessage = nil
    }

    // MARK: - Publishing

    func stopPublishingCamera() async {
#if canImport(LiveKit)
        _ = try? await room?.localParticipant.setCamera(enabled: false)
#endif
        isPublishing = false
    }

    func stopPublishingAudio() async {
#if canImport(LiveKit)
        _ = try? await room?.localParticipant.setMicrophone(enabled: false)
#endif
    }

    // MARK: - Participant helpers

    private func handleRemoteParticipantJoined(_ participant: RemoteParticipantInfo) {
        remoteParticipants.append(participant)
        viewerCount += 1
        if participant.isVideoEnabled {
            activePresenters.append(participant)
        }
    }

    private func handleRemoteParticipantLeft(id: String) {
        remoteParticipants.removeAll { $0.id == id }
        activePresenters.removeAll { $0.id == id }
        viewerCount = max(0, viewerCount - 1)
    }

    // MARK: - Grid layout

    func getGridLayout() -> (cols: Int, rows: Int) {
        switch activePresenters.count {
        case 0, 1: return (1, 1)
        case 2:    return (2, 1)
        case 3, 4: return (2, 2)
        case 5, 6: return (3, 2)
        case 7...9: return (3, 3)
        default:   return (4, 3)
        }
    }

    func getVisiblePresenters() -> [RemoteParticipantInfo] {
        switch presentationMode {
        case .singlePresenter: return Array(activePresenters.prefix(1))
        case .multiPresenter:  return activePresenters
        }
    }

    // MARK: - Status

    func getConnectionStatus() -> String {
        switch connectionState {
        case .disconnected:    return "Disconnected"
        case .connecting:      return "Connecting…"
        case .connected:       return "Connected"
        case .error(let msg):  return "Error: \(msg)"
        }
    }

    // MARK: - Token Generation (LiveKit JWT, signed client-side with CryptoKit)
    // In production prefer a server-side token endpoint so the API secret stays off the device.

    private func generateToken(roomName: String, identity: String, isPublisher: Bool) throws -> String {
        let config = StreamingConfig.shared
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiSecret = config.apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiKey.isEmpty else { throw LiveKitError.tokenGenerationFailed }
        guard !apiSecret.isEmpty, apiSecret != "devsecret" else { throw LiveKitError.tokenGenerationFailed }

        let now = Int(Date().timeIntervalSince1970)
        let exp = now + 3600

        let header  = #"{"alg":"HS256","typ":"JWT"}"#
        let grants  = isPublisher
            ? #"{"room":"\#(roomName)","roomJoin":true,"canPublish":true,"canSubscribe":true}"#
            : #"{"room":"\#(roomName)","roomJoin":true,"canPublish":false,"canSubscribe":true}"#
        let payload = """
        {"sub":"\(identity)","iss":"\(apiKey)","exp":\(exp),"nbf":\(now),"jti":"\(UUID().uuidString)","video":\(grants)}
        """

        let headerB64  = Data(header.utf8).base64URLEncoded()
        let payloadB64 = Data(payload.utf8).base64URLEncoded()
        let message    = "\(headerB64).\(payloadB64)"

        let key       = SymmetricKey(data: Data(apiSecret.utf8))
        let sig       = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        let sigB64    = Data(sig).base64URLEncoded()

        return "\(message).\(sigB64)"
    }

    // MARK: - Permissions

    private func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }
}

// MARK: - Data + base64url

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Errors

enum LiveKitError: LocalizedError {
    case sdkNotInstalled
    case invalidServerURL
    case permissionDenied(String)
    case connectionFailed(String)
    case tokenGenerationFailed

    var errorDescription: String? {
        switch self {
        case .sdkNotInstalled:
            return "LiveKit SDK not installed. In Xcode: File → Add Package Dependencies → https://github.com/livekit/client-sdk-swift"
        case .invalidServerURL:
            return "Invalid LiveKit server URL. Check LiveKitSecret.plist."
        case .permissionDenied(let resource):
            return "Permission denied for \(resource)."
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .tokenGenerationFailed:
            return "Token generation failed. Check LIVEKIT_API_KEY / LIVEKIT_API_SECRET in LiveKitSecret.plist."
        }
    }
}
