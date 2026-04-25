//
//  VideoViewRepresentable.swift
//  Faith Journal
//
//  Shared video view representable for WebRTC and AVFoundation
//

import SwiftUI
import AVFoundation
#if os(macOS)
import AppKit
#endif

#if canImport(WebRTC) && os(iOS)
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
#if os(iOS)
struct VideoPreviewLayerView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}
#else
struct VideoPreviewLayerView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        previewLayer.frame = view.bounds
        view.layer?.addSublayer(previewLayer)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = nsView.bounds
        }
    }
}
#endif

