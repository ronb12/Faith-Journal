//
//  StreamReactionsService.swift
//  Faith Journal
//
//  Reactions system for live streams
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
enum StreamReaction: String, CaseIterable {
    case heart = "❤️"
    case clap = "👏"
    case prayer = "🙏"
    case amen = "Amen"
    case hallelujah = "Hallelujah"
    case fire = "🔥"
    case star = "⭐"
    case thumbsUp = "👍"
    
    var displayName: String {
        switch self {
        case .heart: return "Heart"
        case .clap: return "Clap"
        case .prayer: return "Prayer"
        case .amen: return "Amen"
        case .hallelujah: return "Hallelujah"
        case .fire: return "Fire"
        case .star: return "Star"
        case .thumbsUp: return "Thumbs Up"
        }
    }
}

@available(iOS 17.0, *)
struct ReactionData: Identifiable {
    let id = UUID()
    let reaction: StreamReaction
    let userId: String
    let userName: String
    let timestamp: Date
    var position: CGPoint = .zero
}

@MainActor
@available(iOS 17.0, *)
class StreamReactionsService: ObservableObject {
    static let shared = StreamReactionsService()
    
    @Published var activeReactions: [ReactionData] = []
    @Published var reactionCounts: [StreamReaction: Int] = [:]
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func addReaction(_ reaction: StreamReaction, userId: String, userName: String) {
        let reactionData = ReactionData(
            reaction: reaction,
            userId: userId,
            userName: userName,
            timestamp: Date()
        )
        
        activeReactions.append(reactionData)
        reactionCounts[reaction, default: 0] += 1
        
        // Remove reaction after animation (3 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.activeReactions.removeAll { $0.id == reactionData.id }
        }
        
        // Update analytics
        StreamAnalyticsService.shared.recordReaction()
    }
    
    func getTopReactions(limit: Int = 3) -> [(reaction: StreamReaction, count: Int)] {
        return reactionCounts.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }
    
    func reset() {
        activeReactions.removeAll()
        reactionCounts.removeAll()
    }
}

