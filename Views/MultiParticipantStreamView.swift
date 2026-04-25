//
//  MultiParticipantStreamView.swift
//  Faith Journal
//
//  Live streaming with multiple participants — Agora only on iOS and macOS.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(macOS)
@available(macOS 14.0, *)
struct MultiParticipantStreamView: View {
    let session: LiveSession
    var streamMode: StreamMode = .participant
    enum StreamMode { case host, participant }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if AgoraService.shared.isAvailable {
            MultiParticipantStreamView_Agora(session: session)
        } else if JitsiService.isMeetSDKAvailable {
            MultiParticipantStreamView_Jitsi(session: session)
        } else {
            ContentUnavailableView(
                "Live session",
                systemImage: "video.slash",
                description: Text("Agora is not configured and Jitsi Meet SDK is not linked. Add an Agora App ID or add the Jitsi package to join live sessions.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
#else
@available(iOS 17.0, *)
struct MultiParticipantStreamView: View {
    let session: LiveSession
    var streamMode: StreamMode = .participant
    enum StreamMode { case host, participant }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if AgoraService.shared.isAvailable {
            MultiParticipantStreamView_Agora(session: session)
        } else if JitsiService.isMeetSDKAvailable {
            MultiParticipantStreamView_Jitsi(session: session)
        } else {
            ContentUnavailableView(
                "Live session",
                systemImage: "video.slash",
                description: Text("Agora is not configured and Jitsi Meet SDK is not linked. Add an Agora App ID or add the Jitsi package to join live sessions.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif

#if os(macOS) && !canImport(AgoraRtcKit1)
/// Placeholder when Agora SDK is not available on macOS (run repackage_agora_macos.sh to enable full live sessions).
@available(macOS 14.0, *)
struct MultiParticipantStreamView_Agora: View {
    let session: LiveSession
    var body: some View {
        ContentUnavailableView(
            "Live session",
            systemImage: "video.slash",
            description: Text("Join from the app to watch or present.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
