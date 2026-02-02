//
//  StreamAnalyticsService.swift
//  Faith Journal
//
//  Analytics and insights for live streams
//

import Foundation
import SwiftData

@MainActor
@available(iOS 17.0, *)
class StreamAnalyticsService: ObservableObject {
    static let shared = StreamAnalyticsService()
    
    @Published var currentViewerCount = 0
    @Published var peakViewerCount = 0
    @Published var averageWatchTime: TimeInterval = 0
    @Published var engagementRate: Double = 0.0
    @Published var bitrate: Double = 0.0
    @Published var frameRate: Double = 0.0
    @Published var latency: TimeInterval = 0
    @Published var resolution: String = "720p"
    
    private var viewerCountHistory: [Date: Int] = [:]
    private var watchTimeData: [TimeInterval] = []
    private var reactionCount = 0
    private var messageCount = 0
    
    private init() {}
    
    func updateViewerCount(_ count: Int) {
        currentViewerCount = count
        if count > peakViewerCount {
            peakViewerCount = count
        }
        viewerCountHistory[Date()] = count
    }
    
    func recordWatchTime(_ duration: TimeInterval) {
        watchTimeData.append(duration)
        averageWatchTime = watchTimeData.reduce(0, +) / Double(watchTimeData.count)
    }
    
    func recordReaction() {
        reactionCount += 1
        updateEngagementRate()
    }
    
    func recordMessage() {
        messageCount += 1
        updateEngagementRate()
    }
    
    private func updateEngagementRate() {
        let totalEngagements = Double(reactionCount + messageCount)
        let totalViewers = Double(max(currentViewerCount, 1))
        engagementRate = (totalEngagements / totalViewers) * 100.0
    }
    
    func updateStreamMetrics(bitrate: Double, frameRate: Double, latency: TimeInterval, resolution: String) {
        self.bitrate = bitrate
        self.frameRate = frameRate
        self.latency = latency
        self.resolution = resolution
    }
    
    func getViewerTrend() -> [Int] {
        let sortedHistory = viewerCountHistory.sorted { $0.key < $1.key }
        return Array(sortedHistory.map { $0.value }.suffix(10))
    }
    
    func reset() {
        currentViewerCount = 0
        peakViewerCount = 0
        averageWatchTime = 0
        engagementRate = 0.0
        viewerCountHistory.removeAll()
        watchTimeData.removeAll()
        reactionCount = 0
        messageCount = 0
    }
    
    // MARK: - Advanced Analytics
    
    func calculateRetentionRate() -> Double {
        guard !viewerCountHistory.isEmpty else { return 0.0 }
        let sortedHistory = viewerCountHistory.sorted { $0.key < $1.key }
        guard let initial = sortedHistory.first?.value,
              let current = sortedHistory.last?.value,
              initial > 0 else { return 0.0 }
        return (Double(current) / Double(initial)) * 100.0
    }
    
    func calculateAverageSessionDuration() -> TimeInterval {
        guard !watchTimeData.isEmpty else { return 0 }
        return watchTimeData.reduce(0, +) / Double(watchTimeData.count)
    }
    
    func getPeakEngagementTime() -> Date? {
        guard !viewerCountHistory.isEmpty else { return nil }
        return viewerCountHistory.max(by: { $0.value < $1.value })?.key
    }
    
    func calculateMessageEngagement() -> Double {
        guard currentViewerCount > 0 else { return 0.0 }
        return (Double(messageCount) / Double(currentViewerCount)) * 100.0
    }
    
    func calculateReactionEngagement() -> Double {
        guard currentViewerCount > 0 else { return 0.0 }
        return (Double(reactionCount) / Double(currentViewerCount)) * 100.0
    }
}

