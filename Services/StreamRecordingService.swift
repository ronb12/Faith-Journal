//
//  StreamRecordingService.swift
//  Faith Journal
//
//  Recording service for live streams
//

import Foundation
import AVFoundation
import CoreVideo
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Thread-safe ref so we can pass CVPixelBuffer into a @Sendable closure.
private final class PixelBufferRef: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    init(_ b: CVPixelBuffer) { pixelBuffer = b }
}

/// Thread-safe ref so we can pass CMSampleBuffer into a @Sendable closure.
private final class SampleBufferRef: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer
    init(_ b: CMSampleBuffer) { sampleBuffer = b }
}

/// Context for the current recording; only used on recordingQueue.
private final class RecordingContext {
    let assetWriter: AVAssetWriter
    let videoInput: AVAssetWriterInput
    let videoAdaptor: AVAssetWriterInputPixelBufferAdaptor
    let audioInput: AVAssetWriterInput
    let fileURL: URL
    var hasStartedSession = false
    
    init(assetWriter: AVAssetWriter, videoInput: AVAssetWriterInput, videoAdaptor: AVAssetWriterInputPixelBufferAdaptor, audioInput: AVAssetWriterInput, fileURL: URL) {
        self.assetWriter = assetWriter
        self.videoInput = videoInput
        self.videoAdaptor = videoAdaptor
        self.audioInput = audioInput
        self.fileURL = fileURL
    }
}

@available(iOS 17.0, macOS 14.0, *)
class StreamRecordingService: ObservableObject, @unchecked Sendable {
    static let shared = StreamRecordingService()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingQuality: RecordingQuality = .hd
    @Published var savedRecordings: [StreamRecording] = []
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    private let recordingQueue = DispatchQueue(label: "StreamRecordingService.recording")
    /// Only access from recordingQueue.
    private nonisolated(unsafe) var _recordingContext: RecordingContext?
    
    enum RecordingQuality: String, CaseIterable {
        case sd = "SD (480p)"
        case hd = "HD (720p)"
        case fullHD = "Full HD (1080p)"
        
        var resolution: CGSize {
            switch self {
            case .sd: return CGSize(width: 854, height: 480)
            case .hd: return CGSize(width: 1280, height: 720)
            case .fullHD: return CGSize(width: 1920, height: 1080)
            }
        }
    }
    
    struct StreamRecording: Identifiable {
        let id = UUID()
        let sessionId: UUID
        let title: String
        let duration: TimeInterval
        let fileURL: URL
        let createdAt: Date
        let thumbnailURL: URL?
        var fileSize: Int64 = 0
    }
    
    private init() {}
    
    /// Call from capture pipeline when recording is active. Thread-safe.
    nonisolated func appendVideo(sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer), let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let bufferRef = PixelBufferRef(pixelBuffer)
        recordingQueue.async { [weak self, bufferRef] in
            guard let self = self, let c = self._recordingContext else { return }
            if !c.hasStartedSession {
                c.assetWriter.startSession(atSourceTime: pts)
                c.hasStartedSession = true
            }
            if c.videoInput.isReadyForMoreMediaData {
                _ = c.videoAdaptor.append(bufferRef.pixelBuffer, withPresentationTime: pts)
            }
        }
    }
    
    /// Call from capture pipeline when recording is active. Thread-safe.
    nonisolated func appendAudio(sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let bufferRef = SampleBufferRef(sampleBuffer)
        recordingQueue.async { [weak self, bufferRef] in
            guard let self = self, let c = self._recordingContext else { return }
            if !c.hasStartedSession {
                let pts = CMSampleBufferGetPresentationTimeStamp(bufferRef.sampleBuffer)
                c.assetWriter.startSession(atSourceTime: pts)
                c.hasStartedSession = true
            }
            if c.audioInput.isReadyForMoreMediaData {
                c.audioInput.append(bufferRef.sampleBuffer)
            }
        }
    }
    
    @MainActor
    func startRecording(sessionId: UUID, title: String, quality: RecordingQuality = .hd) async throws {
        guard !isRecording else { return }
        
        recordingQuality = quality
        recordingStartTime = Date()
        recordingDuration = 0
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "\(sessionId.uuidString)_\(Date().timeIntervalSince1970).mp4"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            recordingQueue.async { [weak self] in
                guard let self = self else { cont.resume(); return }
                do {
                    let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
                    let videoSettings: [String: Any] = [
                        AVVideoCodecKey: AVVideoCodecType.h264,
                        AVVideoWidthKey: quality.resolution.width,
                        AVVideoHeightKey: quality.resolution.height,
                        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 5000000]
                    ]
                    let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                    vInput.expectsMediaDataInRealTime = true
                    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vInput, sourcePixelBufferAttributes: [
                        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                    ])
                    let audioSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVNumberOfChannelsKey: 2,
                        AVSampleRateKey: 44100,
                        AVEncoderBitRateKey: 128000
                    ]
                    let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                    aInput.expectsMediaDataInRealTime = true
                    if writer.canAdd(vInput) { writer.add(vInput) }
                    if writer.canAdd(aInput) { writer.add(aInput) }
                    guard writer.startWriting() else {
                        DispatchQueue.main.async { cont.resume(throwing: RecordingError.failedToStart) }
                        return
                    }
                    self._recordingContext = RecordingContext(assetWriter: writer, videoInput: vInput, videoAdaptor: adaptor, audioInput: aInput, fileURL: fileURL)
                    DispatchQueue.main.async {
                        self.isRecording = true
                        self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                            Task { @MainActor in
                                self?.recordingDuration += 1.0
                            }
                        }
                        cont.resume()
                    }
                } catch {
                    DispatchQueue.main.async { cont.resume(throwing: error) }
                }
            }
        }
        print("✅ Recording started: \(fileURL.path)")
    }
    
    @MainActor
    func stopRecording(sessionId: UUID, title: String) async throws -> StreamRecording? {
        guard isRecording else { return nil }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        let duration = recordingDuration
        
        let fileURL: URL? = await withCheckedContinuation { cont in
            recordingQueue.async { [weak self] in
                guard let self = self, let ctx = self._recordingContext else {
                    DispatchQueue.main.async { cont.resume(returning: nil) }
                    return
                }
                self._recordingContext = nil
                ctx.videoInput.markAsFinished()
                ctx.audioInput.markAsFinished()
                let url = ctx.fileURL
                ctx.assetWriter.finishWriting {
                    DispatchQueue.main.async { [weak self] in
                        self?.isRecording = false
                        self?.recordingDuration = 0
                        cont.resume(returning: url)
                    }
                }
            }
        }
        
        guard let fileURL = fileURL else { return nil }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        let thumbnailURL = try? await generateThumbnail(for: fileURL)
        let recording = StreamRecording(
            sessionId: sessionId,
            title: title,
            duration: duration,
            fileURL: fileURL,
            createdAt: Date(),
            thumbnailURL: thumbnailURL,
            fileSize: fileSize
        )
        savedRecordings.append(recording)
        print("✅ Recording saved: \(fileURL.path)")
        return recording
    }
    
    private func generateThumbnail(for videoURL: URL) async throws -> URL? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let thumbnailURL = documentsPath.appendingPathComponent("\(UUID().uuidString).jpg")
            let jpegData: Data?
            #if os(iOS)
            let thumbnail = UIImage(cgImage: cgImage)
            jpegData = thumbnail.jpegData(compressionQuality: 0.8)
            #else
            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            jpegData = platformImageToJPEGData(thumbnail, quality: 0.8)
            #endif
            if let jpegData = jpegData {
                try? jpegData.write(to: thumbnailURL)
                return thumbnailURL
            }
        } catch {
            print("Failed to generate thumbnail: \(error)")
        }
        
        return nil
    }
    
    func deleteRecording(_ recording: StreamRecording) {
        try? FileManager.default.removeItem(at: recording.fileURL)
        if let thumbnailURL = recording.thumbnailURL {
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
        savedRecordings.removeAll { $0.id == recording.id }
    }
}

enum RecordingError: LocalizedError {
    case failedToStart
    case failedToStop
    
    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Failed to start recording"
        case .failedToStop:
            return "Failed to stop recording"
        }
    }
}

