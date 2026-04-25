//
//  AgoraVideoView.swift
//  Faith Journal
//
//  SwiftUI wrapper for Agora video view
//

import SwiftUI

#if canImport(AgoraRtcKit)
import AgoraRtcKit
#endif

struct AgoraVideoView: UIViewRepresentable {
    let uid: UInt // 0 for local user, other values for remote users
    let isLocal: Bool
    let isVideoEnabled: Bool // Pass video enabled state to trigger updates
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true
        
        #if canImport(AgoraRtcKit)
        // Setup video canvas with the view
        DispatchQueue.main.async {
            setupVideoCanvas(for: view)
        }
        #endif
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Re-setup video canvas when view updates to ensure it's properly configured
        #if canImport(AgoraRtcKit)
        DispatchQueue.main.async {
            // Ensure frame is set before setting up canvas
            uiView.setNeedsLayout()
            uiView.layoutIfNeeded()
            
            // Only setup video canvas if video is enabled (for local video)
            if isLocal {
                // For local video, check if video is enabled before setting up
                if isVideoEnabled {
                    setupVideoCanvas(for: uiView)
                } else {
                    // Clear the video view when disabled
                    uiView.subviews.forEach { $0.removeFromSuperview() }
                    uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
                }
            } else {
                // For remote video, always setup (remote users control their own video)
                setupVideoCanvas(for: uiView)
            }
        }
        #endif
    }
    
    #if canImport(AgoraRtcKit)
    private func setupVideoCanvas(for view: UIView) {
        if isLocal {
            AgoraService.shared.setupLocalVideo(view: view)
        } else {
            AgoraService.shared.setupRemoteVideo(for: uid, view: view)
        }
    }
    #endif
}

/// Grid view for displaying multiple video participants
struct AgoraParticipantGridView: View {
    @ObservedObject var agoraService = AgoraService.shared
    
    var body: some View {
        GeometryReader { geometry in
            let columns = calculateColumns(for: agoraService.participantCount)
            let rows = calculateRows(for: agoraService.participantCount, columns: columns)
            
            VStack(spacing: 2) {
                // Local user
                AgoraVideoView(uid: 0, isLocal: true, isVideoEnabled: agoraService.isVideoEnabled)
                    .frame(height: geometry.size.height / CGFloat(rows))
                    .cornerRadius(8)
                
                // Remote users
                ForEach(agoraService.remoteUsers, id: \.self) { uid in
                    AgoraVideoView(uid: uid, isLocal: false, isVideoEnabled: true)
                        .frame(height: geometry.size.height / CGFloat(rows))
                        .cornerRadius(8)
                }
            }
        }
        .id(agoraService.participantCount)
    }
    
    private func calculateColumns(for count: Int) -> Int {
        switch count {
        case 1...2: return 1
        case 3...4: return 2
        case 5...9: return 3
        default: return 4
        }
    }
    
    private func calculateRows(for count: Int, columns: Int) -> Int {
        return Int(ceil(Double(count) / Double(columns)))
    }
}
