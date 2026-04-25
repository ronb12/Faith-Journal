//
//  BroadcastStreamView.swift
//  Faith Journal
//
//  Broadcast mode: One presenter streams, others watch (like Facebook Live)
//  Now using LiveKit WebRTC for cross-location streaming
//

import SwiftUI
import AVFoundation

/// Wrapper that routes to the LiveKit-based broadcast experience

struct BroadcastStreamView: View {
    let session: Any?

    var body: some View {
        if #available(iOS 17.0, *), let session = session as? LiveSession {
            BroadcastStreamView_LiveKit(
                sessionTitle: session.title,
                sessionCategory: session.category,
                sessionHostId: session.hostId,
                currentParticipants: session.currentParticipants
            )
        } else {
            Text("Broadcasting is only available on iOS 17+")
        }
    }
}

