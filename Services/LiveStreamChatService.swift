//
//  LiveStreamChatService.swift
//  Faith Journal
//
//  Real-time live stream chat (YouTube-style) using Firestore.
//  Firestore path: liveStreamChats/{sessionId}/messages/{autoId}
//  Rules and indexes: see firestore.rules, firestore.indexes.json, and firebase.json in project root.
//

import CryptoKit
import Foundation
import SwiftData

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
@available(iOS 17.0, macOS 15.0, *)
final class LiveStreamChatService: ObservableObject {
    static let shared = LiveStreamChatService()

    @Published private(set) var remoteMessages: [ChatMessage] = []
    @Published var lastError: String?

    private var activeSessionId: UUID?
    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    private var db: Firestore { Firestore.firestore() }
    #endif

    private init() {}

    #if canImport(FirebaseFirestore)
    private func messagesCollection(for sessionId: UUID) -> CollectionReference {
        db.collection("liveStreamChats").document(sessionId.uuidString).collection("messages")
    }
    #endif

    /// Begins real-time delivery of chat for this live session. Call on appear; `stop` on disappear.
    func start(sessionId: UUID) {
        #if canImport(FirebaseFirestore)
        guard activeSessionId != sessionId else { return }
        stop()
        lastError = nil
        activeSessionId = sessionId
        let ref = messagesCollection(for: sessionId)
        listener = ref
            .order(by: "createdAt", descending: false)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snap, err in
                Task { @MainActor in
                    guard let self else { return }
                    if let err {
                        self.lastError = err.localizedDescription
                        return
                    }
                    guard let documents = snap?.documents else { return }
                    self.remoteMessages = documents.compactMap { self.mapDocument($0.data(), documentId: $0.documentID) }
                }
            }
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif
        activeSessionId = nil
        remoteMessages = []
        lastError = nil
    }

    /// Pushes a message the user already saved locally. Uses the same `ChatMessage.id` in Firestore for echo deduplication.
    func sendMessage(
        sessionId: UUID,
        userId: String,
        userName: String,
        text: String,
        message: ChatMessage
    ) async {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 2000 else { return }
        if Auth.auth().currentUser == nil { return }
        let col = messagesCollection(for: sessionId)
        let payload: [String: Any] = [
            "sessionId": sessionId.uuidString,
            "userId": userId,
            "userName": userName,
            "text": trimmed,
            "messageType": "text",
            "messageUUID": message.id.uuidString,
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                col.addDocument(data: payload) { err in
                    if let err { c.resume(throwing: err) } else { c.resume() }
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    #if canImport(FirebaseFirestore)
    private static func stableUUIDForDocumentId(_ id: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data(id.utf8))
        return digest.withUnsafeBytes { raw in
            let u = raw.load(as: uuid_t.self)
            return UUID(uuid: u)
        }
    }

    private func mapDocument(_ data: [String: Any], documentId: String) -> ChatMessage? {
        guard
            let sessionIdStr = data["sessionId"] as? String,
            let sessionId = UUID(uuidString: sessionIdStr),
            let userId = data["userId"] as? String,
            let userName = data["userName"] as? String
        else { return nil }
        let text = (data["text"] as? String) ?? ""
        guard !text.isEmpty else { return nil }
        let msg = ChatMessage(
            sessionId: sessionId,
            userId: userId,
            userName: userName,
            message: text,
            messageType: .text
        )
        if let uStr = data["messageUUID"] as? String, let u = UUID(uuidString: uStr) {
            msg.id = u
        } else {
            msg.id = Self.stableUUIDForDocumentId(documentId)
        }
        if let ts = data["createdAt"] as? Timestamp {
            msg.timestamp = ts.dateValue()
        }
        return msg
    }
    #endif
}
