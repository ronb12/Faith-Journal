//
//  WebRTCService.swift
//  Faith Journal
//
//  Lightweight stub of WebRTC service to satisfy references during compilation.
//  This provides a minimal API used by views; real implementation can be restored later.
//

import Foundation
import Combine

@MainActor
@available(iOS 17.0, *)
class WebRTCService: ObservableObject {
	static let shared = WebRTCService()

	// Basic published state
	@Published var errorMessage: String? = nil
	@Published var connectionState: String = "Disconnected"

	// Local device flags
	@Published var localVideoEnabled: Bool = false
	@Published var localAudioEnabled: Bool = true

	// Callbacks used by views
	var onRemoteVideoTrack: ((_ userId: String, _ track: Any) -> Void)?
	var onRemoteVideoTrackRemoved: ((_ userId: String) -> Void)?
	var onLocalVideoTrackReady: ((_ track: Any) -> Void)?
	var onParticipantCountChanged: ((_ count: Int) -> Void)?

	private init() {}

	// MARK: - Controls
	func toggleVideo() {
		localVideoEnabled.toggle()
	}

	func toggleAudio() {
		localAudioEnabled.toggle()
	}

	func joinSession(sessionId: UUID, userId: String, signalingService: Any) {
		// No-op stub: set connected state
		connectionState = "Connecting..."
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			self.connectionState = "Connected"
		}
	}

	func leaveSession() {
		connectionState = "Disconnected"
	}

	func addPeerConnection(for userId: String) {
		// stub
		onParticipantCountChanged?((Int.random(in: 1...4)))
	}

	func removePeerConnection(for userId: String) {
		// stub
		onParticipantCountChanged?((Int.random(in: 0...3)))
	}

	// Async offer/answer stubs
	func createOffer(for userId: String) async throws -> String {
		return ""
	}

	func createAnswer(for userId: String) async throws -> String {
		return ""
	}

	func setRemoteDescription(sdp: String, type: Any, for userId: String) async throws {
		// stub
	}

	func setRemoteIceCandidate(candidate: String, sdpMLineIndex: Int32, sdpMid: String?, for userId: String) {
		// stub
	}
}

