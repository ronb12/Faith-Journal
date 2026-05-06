//
//  RecordingCaptureFeeder.swift
//  Faith Journal
//
//  Feeds camera and microphone to StreamRecordingService when recording in Agora live sessions.
//  Uses a dedicated AVCaptureSession; may not receive video if Agora already holds the camera.
//

import Foundation
import AVFoundation

@available(iOS 17.0, macOS 14.0, *)
final class RecordingCaptureFeeder: NSObject, @unchecked Sendable {
    static let shared = RecordingCaptureFeeder()
    
    private let sessionQueue = DispatchQueue(label: "RecordingCaptureFeeder.session")
    private var captureSession: AVCaptureSession?
    private var isRunning = false
    
    private override init() {
        super.init()
    }
    
    /// Start capturing and forwarding to StreamRecordingService. Call only when StreamRecordingService has already started recording.
    func start() {
        sessionQueue.async { [weak self] in
            self?.startCaptureOnQueue()
        }
    }
    
    /// Stop capturing. Call before stopping StreamRecordingService.
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            session.stopRunning()
            self.captureSession = nil
            self.isRunning = false
            print("✅ [RECORDING FEEDER] Stopped")
        }
    }
    
    private func startCaptureOnQueue() {
        guard captureSession == nil else { return }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .high
        
        #if os(iOS)
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            session.commitConfiguration()
            print("⚠️ [RECORDING FEEDER] No video device")
            return
        }
        #else
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            session.commitConfiguration()
            print("⚠️ [RECORDING FEEDER] No video device")
            return
        }
        #endif
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        var addedAudio = false
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            addedAudio = true
        } else {
            print("⚠️ [RECORDING FEEDER] No audio device")
        }
        if addedAudio {
            let audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
            }
        }
        
        session.commitConfiguration()
        self.captureSession = session
        session.startRunning()
        self.isRunning = true
        print("✅ [RECORDING FEEDER] Started")
    }
}

@available(iOS 17.0, macOS 14.0, *)
extension RecordingCaptureFeeder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output is AVCaptureVideoDataOutput {
            StreamRecordingService.shared.appendVideo(sampleBuffer: sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            StreamRecordingService.shared.appendAudio(sampleBuffer: sampleBuffer)
        }
    }
}
