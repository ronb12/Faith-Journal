//
//  WatchConnectivityManager.swift
//  Faith Journal Watch App
//
//  Created on 2025-01-09.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var receivedMessage: [String: Any] = [:]

    private var session: WCSession?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()

            isPaired = session?.isPaired ?? false
            isReachable = session?.isReachable ?? false
        }
    }

    func sendMessage(_ message: [String: Any]) {
        guard let session = session, session.isReachable else {
            print("WatchConnectivity: Session not reachable")
            return
        }

        session.sendMessage(message, replyHandler: nil) { error in
            print("WatchConnectivity: Failed to send message: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
        }

        if let error = error {
            print("WatchConnectivity: Activation failed: \(error.localizedDescription)")
        } else {
            print("WatchConnectivity: Session activated with state: \(activationState.rawValue)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        print("WatchConnectivity: Reachability changed to: \(session.isReachable)")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.receivedMessage = message
        }
        print("WatchConnectivity: Received message: \(message)")
    }
}