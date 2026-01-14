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
}

