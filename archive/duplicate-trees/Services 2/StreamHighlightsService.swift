//
//  StreamHighlightsService.swift
//  Faith Journal
//
//  Highlights and clips service for live streams
//

import Foundation
import SwiftData
import AVFoundation

@MainActor
@available(iOS 17.0, *)
class StreamHighlightsService: ObservableObject {
    static let shared = StreamHighlightsService()
    
    @Published var highlights: [StreamHighlight] = []
    
    struct StreamHighlight: Identifiable {
        let id = UUID()
        let sessionId: UUID
        let title: String
        let timestamp: TimeInterval // Time in stream when highlight occurred
        let duration: TimeInterval
        let thumbnailURL: URL?
        let videoURL: URL?
        let createdAt: Date
        var shareCount: Int = 0
    }
    
    private init() {}
    
    func createHighlight(
        sessionId: UUID,
        title: String,
        timestamp: TimeInterval,
        duration: TimeInterval = 60,
        thumbnailURL: URL? = nil
    ) -> StreamHighlight {
        let highlight = StreamHighlight(
            sessionId: sessionId,
            title: title,
            timestamp: timestamp,
            duration: duration,
            thumbnailURL: thumbnailURL,
            videoURL: nil,
            createdAt: Date()
        )
        
        highlights.append(highlight)
        return highlight
    }
    
    func generateClip(from recordingURL: URL, startTime: TimeInterval, duration: TimeInterval) async throws -> URL {
        let asset = AVAsset(url: recordingURL)
        let composition = AVMutableComposition()
        
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first,
              let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first else {
            throw HighlightError.failedToLoadTracks
        }
        
        let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let duration = CMTime(seconds: duration, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, duration: duration)
        
        try videoCompositionTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        try audioCompositionTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("highlight_\(UUID().uuidString).mp4")
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw HighlightError.failedToCreateExportSession
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(start: .zero, duration: duration)
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw HighlightError.exportFailed
        }
        
        return outputURL
    }
    
    func shareHighlight(_ highlight: StreamHighlight) {
        if let index = highlights.firstIndex(where: { $0.id == highlight.id }) {
            highlights[index].shareCount += 1
        }
    }
    
    func deleteHighlight(_ highlight: StreamHighlight) {
        if let videoURL = highlight.videoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        if let thumbnailURL = highlight.thumbnailURL {
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
        highlights.removeAll { $0.id == highlight.id }
    }
}

enum HighlightError: LocalizedError {
    case failedToLoadTracks
    case failedToCreateExportSession
    case exportFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadTracks:
            return "Failed to load video/audio tracks"
        case .failedToCreateExportSession:
            return "Failed to create export session"
        case .exportFailed:
            return "Failed to export highlight clip"
        }
    }
}

