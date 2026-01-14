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
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        #if canImport(AgoraRtcKit)
        // Setup video canvas
        DispatchQueue.main.async {
            if isLocal {
                _ = AgoraService.shared.setupLocalVideo()
            } else {
                _ = AgoraService.shared.setupRemoteVideo(for: uid)
            }
        }
        #endif
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update view if needed
    }
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
                AgoraVideoView(uid: 0, isLocal: true)
                    .frame(height: geometry.size.height / CGFloat(rows))
                    .cornerRadius(8)
                
                // Remote users
                ForEach(agoraService.remoteUsers, id: \.self) { uid in
                    AgoraVideoView(uid: uid, isLocal: false)
                        .frame(height: geometry.size.height / CGFloat(rows))
                        .cornerRadius(8)
                }
            }
        }
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
