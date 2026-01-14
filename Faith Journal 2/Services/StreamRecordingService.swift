//
//  StreamRecordingService.swift
//  Faith Journal
//
//  Recording service for live streams
//

import Foundation
import AVFoundation
import SwiftData
import UIKit

@MainActor
@available(iOS 17.0, *)
class StreamRecordingService: ObservableObject {
    static let shared = StreamRecordingService()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingQuality: RecordingQuality = .hd
    @Published var savedRecordings: [StreamRecording] = []
    
    private var recordingTimer: Timer?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var recordingStartTime: Date?
    
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
    
    func startRecording(sessionId: UUID, title: String, quality: RecordingQuality = .hd) async throws {
        guard !isRecording else { return }
        
        recordingQuality = quality
        recordingStartTime = Date()
        isRecording = true
        recordingDuration = 0
        
        // Start recording timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1.0
            }
        }
        
        // Setup file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "\(sessionId.uuidString)_\(Date().timeIntervalSince1970).mp4"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        // Setup AVAssetWriter
        assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
        
        // Configure video input
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: quality.resolution.width,
            AVVideoHeightKey: quality.resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 5000000
            ]
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        
        // Configure audio input
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true
        
        if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
        }
        
        if let audioInput = audioInput, assetWriter?.canAdd(audioInput) == true {
            assetWriter?.add(audioInput)
        }
        
        guard assetWriter?.startWriting() == true else {
            throw RecordingError.failedToStart
        }
        
        print("✅ Recording started: \(fileURL.path)")
    }
    
    func stopRecording(sessionId: UUID, title: String) async throws -> StreamRecording? {
        guard isRecording else { return nil }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard let assetWriter = assetWriter,
              let fileURL = assetWriter.outputURL as URL? else {
            throw RecordingError.failedToStop
        }
        
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        await assetWriter.finishWriting()
        
        isRecording = false
        let duration = recordingDuration
        recordingDuration = 0
        
        // Get file size
        let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
        
        // Create thumbnail
        let thumbnailURL = try? await generateThumbnail(for: fileURL)
        
        let recording = StreamRecording(
            sessionId: sessionId,
            title: title,
            duration: duration,
            fileURL: fileURL,
            createdAt: Date(),
            thumbnailURL: thumbnailURL,
            fileSize: fileSize ?? 0
        )
        
        savedRecordings.append(recording)
        
        self.assetWriter = nil
        self.videoInput = nil
        self.audioInput = nil
        
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
            let thumbnail = UIImage(cgImage: cgImage)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let thumbnailURL = documentsPath.appendingPathComponent("\(UUID().uuidString).jpg")
            
            if let jpegData = thumbnail.jpegData(compressionQuality: 0.8) {
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

