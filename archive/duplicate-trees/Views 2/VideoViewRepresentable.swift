//
//  VideoViewRepresentable.swift
//  Faith Journal
//
//  Shared video view representable for WebRTC and AVFoundation
//

import SwiftUI
import AVFoundation

#if canImport(WebRTC)
import WebRTC

struct VideoViewRepresentable: UIViewRepresentable {
    let view: RTCEAGLVideoView
    
    func makeUIView(context: Context) -> RTCEAGLVideoView {
        return view
    }
    
    func updateUIView(_ uiView: RTCEAGLVideoView, context: Context) {
        // No updates needed
    }
}
#endif

// MARK: - AVFoundation Preview Layer View
struct VideoPreviewLayerView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}

