//
//  AgoraVideoView.swift
//  Faith Journal
//
//  SwiftUI wrapper for Agora video view (iOS: UIView, macOS: NSView)
//

import SwiftUI

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

#if os(iOS)
import UIKit

/// Container that calls setup when bounds become valid (fixes iPad where SwiftUI may not call updateUIView again after layout).
private final class LocalVideoContainerView: UIView {
    var onBoundsValid: (() -> Void)?
    private var hasSetup = false
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, !hasSetup else { return }
        hasSetup = true
        onBoundsValid?()
    }
}

struct AgoraVideoView: UIViewRepresentable {
    let uid: UInt // 0 for local user, other values for remote users
    let isLocal: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        #if canImport(AgoraRtcKit)
        if isLocal {
            let container = LocalVideoContainerView()
            container.backgroundColor = .black
            container.onBoundsValid = { [weak container] in
                guard let container = container else { return }
                Task { @MainActor in
                    AgoraService.shared.setupLocalVideo(view: container)
                }
            }
            return container
        }
        #endif
        let container = UIView()
        container.backgroundColor = .black
        #if canImport(AgoraRtcKit)
        AgoraService.shared.setupRemoteVideo(for: uid, view: container)
        #endif
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if isLocal {
            // Local video is bound in layoutSubviews via LocalVideoContainerView (reliable on iPad)
            if let container = uiView as? LocalVideoContainerView, container.bounds.width > 0, container.bounds.height > 0, !context.coordinator.localBound {
                context.coordinator.localBound = true
                AgoraService.shared.setupLocalVideo(view: container)
            }
        } else if !uiView.subviews.isEmpty {
            uiView.subviews.forEach { subview in
                subview.frame = uiView.bounds
                subview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }
        }
    }
    
    class Coordinator {
        var localBound = false
    }
}
#elseif os(macOS)
import AppKit

/// macOS container that calls setup when bounds become valid (SwiftUI may not call updateNSView with non-zero bounds in time).
private final class LocalVideoContainerViewMac: NSView {
    var onBoundsValid: (() -> Void)?
    private var hasSetup = false
    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.height > 0, !hasSetup else { return }
        hasSetup = true
        onBoundsValid?()
    }
}

struct AgoraVideoView: NSViewRepresentable {
    let uid: UInt
    let isLocal: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSView {
        #if canImport(AgoraRtcKit) || canImport(AgoraRtcKit1)
        if isLocal {
            let container = LocalVideoContainerViewMac()
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.black.cgColor
            container.onBoundsValid = { [weak container] in
                guard let container = container else { return }
                Task { @MainActor in
                    AgoraService.shared.setupLocalVideo(view: container)
                }
            }
            return container
        }
        #endif
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        
        #if canImport(AgoraRtcKit) || canImport(AgoraRtcKit1)
        if !isLocal {
            AgoraService.shared.setupRemoteVideo(for: uid, view: container)
        }
        #endif
        
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isLocal {
            if let container = nsView as? LocalVideoContainerViewMac, container.bounds.width > 0, container.bounds.height > 0, !context.coordinator.localBound {
                context.coordinator.localBound = true
                AgoraService.shared.setupLocalVideo(view: container)
            }
        } else if !nsView.subviews.isEmpty {
            nsView.subviews.forEach { subview in
                subview.frame = nsView.bounds
                subview.autoresizingMask = [.width, .height]
            }
        }
    }
    
    class Coordinator {
        var localBound = false
    }
}
#endif

/// Wrapper for a single remote participant's video (used when embedding in grids keyed by uid string)
struct AgoraRemoteVideoView: View {
    let uid: UInt
    
    var body: some View {
        AgoraVideoView(uid: uid, isLocal: false)
    }
}

/// Participant identity for grid: local (uid 0) or remote (uid)
private enum AgoraParticipantId: Hashable {
    case local
    case remote(UInt)
}

/// Grid view for displaying multiple video participants; layout adapts to 1, 2, 3, 4+ people.
/// With 5+ participants, enlarges the active speaker when `AgoraService.spotlightSubject` is set (volume indication).
struct AgoraParticipantGridView: View {
    @ObservedObject var agoraService = AgoraService.shared

    /// When the full-screen presentation overlay is up, the presenter is shown in a PIP; omit them from the grid so Agora has a single canvas for that user.
    var presentationHidesLocal: Bool = false
    var presentationHidesRemoteUid: UInt? = nil
    
    /// All participants to show: local first, then remotes (order stable for layout).
    private var participantIds: [AgoraParticipantId] {
        [.local] + agoraService.remoteUsers.map { .remote($0) }
    }

    private var displayParticipantIds: [AgoraParticipantId] {
        participantIds.filter { id in
            if presentationHidesLocal, case .local = id { return false }
            if let u = presentationHidesRemoteUid, case .remote(u) = id { return false }
            return true
        }
    }
    
    private var spotlightEligible: Bool {
        agoraService.participantCount >= 5
    }
    
    /// IDs for the smaller strip when spotlighting one speaker.
    private var idsForCompactGrid: [AgoraParticipantId] {
        guard spotlightEligible else { return displayParticipantIds }
        switch agoraService.spotlightSubject {
        case .local:
            return displayParticipantIds.filter {
                if case .local = $0 { return false }
                return true
            }
        case .remote(let uid):
            return displayParticipantIds.filter {
                if case .remote(uid) = $0 { return false }
                return true
            }
        case .none:
            return displayParticipantIds
        }
    }

    /// While showing presenter PIP on the presentation overlay, skip the large "Speaking" row so the face only appears in PIP.
    private var usePresentationSimplifiedLayout: Bool {
        presentationHidesLocal || presentationHidesRemoteUid != nil
    }
    
    var body: some View {
        GeometryReader { geometry in
            let displayCount = max(1, displayParticipantIds.count)
            let count = usePresentationSimplifiedLayout ? displayCount : max(1, agoraService.participantCount)
            let fullColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount(for: count))
            let compactColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount(for: max(1, idsForCompactGrid.count)))
            let showSpotlight = !usePresentationSimplifiedLayout && spotlightEligible && agoraService.spotlightSubject != .none
            
            if showSpotlight {
                VStack(spacing: 6) {
                    spotlightLargeTile()
                        .frame(height: max(160, geometry.size.height * 0.52))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    LazyVGrid(columns: compactColumns, spacing: 4) {
                        ForEach(idsForCompactGrid, id: \.self) { id in
                            participantView(for: id)
                                .aspectRatio(1, contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                .clipped()
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: fullColumns, spacing: 4) {
                    ForEach(displayParticipantIds, id: \.self) { id in
                        participantView(for: id)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // `participantCount` avoids spotlight churn. `localVideoSurfaceEpoch` bumps only when the host moves local
        // preview (PIP ↔ grid) so surfaces rebind — e.g. after closing Bible overlay.
        .id("\(agoraService.participantCount)-\(agoraService.localVideoSurfaceEpoch)")
    }
    
    @ViewBuilder
    private func spotlightLargeTile() -> some View {
        switch agoraService.spotlightSubject {
        case .local:
            participantView(for: .local)
                .overlay(alignment: .topLeading) {
                    spotlightLabel
                }
        case .remote(let uid):
            participantView(for: .remote(uid))
                .overlay(alignment: .topLeading) {
                    spotlightLabel
                }
        case .none:
            EmptyView()
        }
    }
    
    private var spotlightLabel: some View {
        Text("Speaking")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(8)
    }
    
    @ViewBuilder
    private func participantView(for id: AgoraParticipantId) -> some View {
        switch id {
        case .local:
            AgoraVideoView(uid: 0, isLocal: true)
        case .remote(let uid):
            AgoraVideoView(uid: uid, isLocal: false)
        }
    }
    
    /// Columns so tiles fill the space: 1→1, 2→2, 3→3, 4→2, 5–6→3, 7+→4.
    private func columnCount(for participantCount: Int) -> Int {
        switch participantCount {
        case 1: return 1
        case 2: return 2
        case 3: return 3
        case 4: return 2
        case 5, 6: return 3
        default: return min(4, participantCount)
        }
    }
}
