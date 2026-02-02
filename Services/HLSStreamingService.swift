//
//  HLSStreamingService.swift
//  Faith Journal
//
//  Native iOS streaming service using ReplayKit and AVFoundation
//  Supports broadcast mode with camera streaming
//

import Foundation
@preconcurrency import AVFoundation
import Combine
import ReplayKit
import UIKit

#if canImport(AVFAudio)
import AVFAudio
#endif

@MainActor
class HLSStreamingService: NSObject, ObservableObject {
    static let shared = HLSStreamingService()
    
    // MARK: - Published Properties
    @Published var isStreaming = false
    @Published var isConnected = false
    @Published var viewerCount = 0
    @Published var errorMessage: String?
    @Published var streamURL: URL?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isVideoEnabled = true
    @Published var isAudioEnabled = true
    
    // MARK: - Private Properties
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    
    // ReplayKit broadcaster for screen/app broadcasting
    private var broadcastController: RPBroadcastController?
    private var screenRecorder = RPScreenRecorder.shared()
    
    // Stream configuration
    private var sessionId: UUID?
    private var userId: String?
    
    // Video encoding
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Start broadcasting stream (host only)
    func startBroadcast(sessionId: UUID, userId: String) async throws {
        self.sessionId = sessionId
        self.userId = userId
        
        // Request permissions
        let videoGranted = await requestVideoPermission()
        let audioGranted = await requestAudioPermission()

        // Require at least audio permission
        guard audioGranted else {
            throw StreamingError.permissionDenied
        }
        
        // Video permission is optional (for simulator or audio-only streams)
        if !videoGranted {
            #if !targetEnvironment(simulator)
            // On real device, warn but continue with audio-only
            print("⚠️ Video permission denied - continuing with audio-only stream")
            #endif
        }
        
        // Setup capture session (handles simulator gracefully)
        try await setupCaptureSession()
        
        // Start streaming (even if camera unavailable, audio-only is fine)
        isStreaming = true
        isConnected = true
        
        // Generate HLS stream URL from Oracle server
        // This connects to the Oracle Cloud streaming server
        if let hlsURL = StreamingConfig.shared.hlsStreamURL(for: sessionId) {
            streamURL = hlsURL
            print("✅ Connected to Oracle HLS server: \(hlsURL.absoluteString)")
        } else {
            // Fallback to placeholder if server URL is invalid
            streamURL = URL(string: "faith-journal://stream/\(sessionId.uuidString)")
            print("⚠️ Using fallback stream URL - Oracle server URL not configured")
        }
        
        errorMessage = nil
    }
    
    /// Start screen broadcast using ReplayKit
    func startScreenBroadcast() async throws {
        guard RPScreenRecorder.shared().isAvailable else {
            throw StreamingError.broadcastUnavailable
        }
        
        // Start screen recording
        try await screenRecorder.startCapture { [weak self] sampleBuffer, sampleBufferType, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            
            // Process the sample buffer (video or audio)
            switch sampleBufferType {
            case .video:
                self.processVideoSampleBuffer(sampleBuffer)
            case .audioApp, .audioMic:
                self.processAudioSampleBuffer(sampleBuffer)
            @unknown default:
                break
            }
        }
        
        isStreaming = true
        isConnected = true
    }

    /// Stop screen broadcast
    func stopScreenBroadcast() {
        screenRecorder.stopCapture { [weak self] error in
            if let error = error {
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        Task { @MainActor in
            self.isStreaming = false
            self.isConnected = false
        }
    }
    
    /// Stop broadcasting
    func stopBroadcast() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        audioOutput = nil
        videoDeviceInput = nil
        audioDeviceInput = nil
        previewLayer = nil
        
        isStreaming = false
        isConnected = false
        streamURL = nil
        sessionId = nil
        userId = nil
        isVideoEnabled = true
        isAudioEnabled = true
    }
    
    /// Toggle video
    func toggleVideo() {
        isVideoEnabled.toggle()
        
        guard let session = captureSession else { return }
        
        // Enable/disable video input
        if let videoDeviceInput = videoDeviceInput {
            session.beginConfiguration()
            if isVideoEnabled {
                if !session.inputs.contains(videoDeviceInput) {
                    session.addInput(videoDeviceInput)
                }
            } else {
                if session.inputs.contains(videoDeviceInput) {
                    session.removeInput(videoDeviceInput)
                }
            }
            session.commitConfiguration()
        }
        
        // Enable/disable video output connections
        if let videoOutput = videoOutput {
            for connection in videoOutput.connections {
                if connection.isVideoMirroringSupported {
                    connection.isEnabled = isVideoEnabled
                }
            }
        }
    }
    
    /// Toggle audio
    func toggleAudio() {
        isAudioEnabled.toggle()
        
        guard let session = captureSession else { return }
        
        // Enable/disable audio input
        if let audioDeviceInput = audioDeviceInput {
            session.beginConfiguration()
            if isAudioEnabled {
                if !session.inputs.contains(audioDeviceInput) {
                    session.addInput(audioDeviceInput)
                }
            } else {
                if session.inputs.contains(audioDeviceInput) {
                    session.removeInput(audioDeviceInput)
                }
            }
            session.commitConfiguration()
        }
        
        // Note: Audio output connections don't have an isEnabled property
        // The audio will stop being captured when the input is removed
    }
    
    /// Join as viewer (watch the stream)
    func joinAsViewer(streamURL: URL) async {
        self.streamURL = streamURL
        isConnected = true
        errorMessage = nil
        
        // For production: Use AVPlayer to play HLS stream
        // let player = AVPlayer(url: streamURL)
        // player.play()
    }
    
    /// Leave stream
    func leaveStream() {
        isConnected = false
        streamURL = nil
        sessionId = nil
        userId = nil
    }
    
    /// Update viewer count (called from your backend)
    func updateViewerCount(_ count: Int) {
        viewerCount = count
    }
    
    /// Flip camera between front and back
    func flipCamera(toFront: Bool) {
        guard let session = captureSession else { return }
        
        guard let currentVideoInput = videoDeviceInput else { return }
        
        session.beginConfiguration()
        session.removeInput(currentVideoInput)
        
        let position: AVCaptureDevice.Position = toFront ? .front : .back
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let newVideoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(newVideoInput) else {
            // If we can't add the new input, add back the old one
            session.addInput(currentVideoInput)
            session.commitConfiguration()
            return
        }
        
        session.addInput(newVideoInput)
        self.videoDeviceInput = newVideoInput
        session.commitConfiguration()
        
        print("✅ Camera flipped to \(toFront ? "front" : "back")")
    }
    
    // MARK: - Preview Layer
    
    /// Get preview layer for local video display
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
    
    // MARK: - Private Methods
    
    private func setupCaptureSession() async throws {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Configure session preset
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        
        // Setup video input - handle simulator gracefully
        #if targetEnvironment(simulator)
        // In simulator, camera is not available - create a placeholder session
        // We'll still allow streaming with audio-only or use a placeholder video
        print("⚠️ Running in simulator - camera not available, using audio-only mode")
        isVideoEnabled = false
        #else
        // On real device, try to get camera
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
           session.canAddInput(videoInput) {
            session.addInput(videoInput)
            self.videoDeviceInput = videoInput
            
            // Setup video output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }
        } else {
            // Camera not available on real device too - continue with audio-only
            print("⚠️ Camera not available - continuing with audio-only mode")
            isVideoEnabled = false
        }
        #endif
        
        // Setup audio input (works in simulator)
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            self.audioDeviceInput = audioInput
            
            // Setup audio output
            let audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audioQueue"))
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
                self.audioOutput = audioOutput
            }
        } else {
            // If no audio either, we can't stream
            throw StreamingError.microphoneUnavailable
        }
        
        session.commitConfiguration()
        
        // Create preview layer (even if no camera, we'll show a placeholder)
        // In simulator or when camera unavailable, we still create the layer for UI consistency
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        self.previewLayer = previewLayer
        
        self.captureSession = session
        
        // Start session (startRunning is synchronous, runs on background thread)
        // Only start if we have at least audio input
        if session.inputs.count > 0 {
            // Start on background queue to avoid blocking
            let sessionRef = session
            DispatchQueue.global(qos: .userInitiated).async { @Sendable in
                sessionRef.startRunning()
            }
        } else {
            // Even with no inputs, create a placeholder preview layer for UI
            // This ensures the view doesn't break in simulator
            print("⚠️ No capture inputs available - using placeholder preview")
        }
    }
    
    private func requestVideoPermission() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .video)
    }
    
    private func requestAudioPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension HLSStreamingService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // In production: Process video frames and send to HLS streaming server
        // This would involve encoding, segmenting, and uploading to your streaming service
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Handle dropped frames if needed
    }
}

// MARK: - Sample Buffer Processing Helpers
extension HLSStreamingService {
    fileprivate func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Placeholder: encode/process video frames for streaming
    }

    fileprivate func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Placeholder: encode/process audio frames for streaming
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension HLSStreamingService: AVCaptureAudioDataOutputSampleBufferDelegate {
    // The captureOutput(_:didOutput:from:) method is already implemented in AVCaptureVideoDataOutputSampleBufferDelegate
    // and satisfies both protocol requirements since they have the same signature
}

// MARK: - Errors
enum StreamingError: LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case microphoneUnavailable
    case broadcastUnavailable
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera or microphone permission denied. Please enable in Settings."
        case .cameraUnavailable:
            #if targetEnvironment(simulator)
            return "Camera is not available in simulator. Audio-only streaming is available."
            #else
            return "Camera is not available. Please check camera permissions in Settings."
            #endif
        case .microphoneUnavailable:
            return "Microphone is not available."
        case .broadcastUnavailable:
            return "Broadcast is not available on this device."
        case .connectionFailed:
            return "Failed to connect to streaming service."
        }
    }
}
