//
//  SessionRecommendationService.swift
//  Faith Journal
//
//  Recommends sessions based on user activity
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@MainActor
class SessionRecommendationService: ObservableObject {
    static let shared = SessionRecommendationService()
    
    private init() {}
    
    func getRecommendations(
        for userId: String,
        allSessions: [LiveSession],
        userRatings: [SessionRating],
        userParticipants: [LiveSessionParticipant],
        userFavorites: [LiveSession]
    ) -> [LiveSession] {
        var recommendations: [LiveSession] = []
        var scoredSessions: [(session: LiveSession, score: Double)] = []
        
        // Get user's favorite categories
        let favoriteCategories = getUserFavoriteCategories(
            from: userParticipants,
            favorites: userFavorites
        )
        
        // Get user's favorite hosts
        let favoriteHosts = getUserFavoriteHosts(
            from: userParticipants,
            favorites: userFavorites
        )
        
        // Score sessions based on various factors
        for session in allSessions {
            guard !session.isArchived,
                  session.hostId != userId, // Don't recommend own sessions
                  !userParticipants.contains(where: { $0.sessionId == session.id }) else {
                continue
            }
            
            var score: Double = 0.0
            
            // Category match (higher weight)
            if favoriteCategories.contains(session.category) {
                score += 30.0
            }
            
            // Host match
            if favoriteHosts.contains(session.hostId) {
                score += 25.0
            }
            
            // Tag overlap
            let userTags = getUserTags(from: userParticipants, favorites: userFavorites)
            let tagOverlap = Set(session.tags).intersection(Set(userTags)).count
            score += Double(tagOverlap) * 5.0
            
            // Popularity boost
            if session.viewerCount > 10 {
                score += 10.0
            }
            
            // High rating boost
            if let averageRating = getAverageRating(for: session.id, from: userRatings),
               averageRating >= 4.0 {
                score += 15.0
            }
            
            // Scheduled/upcoming boost
            if session.isScheduled {
                score += 5.0
            }
            
            // Recent activity boost
            let daysSinceCreated = Calendar.current.dateComponents([.day], from: session.createdAt, to: Date()).day ?? 0
            if daysSinceCreated < 7 {
                score += 5.0
            }
            
            scoredSessions.append((session: session, score: score))
        }
        
        // Sort by score and return top recommendations
        recommendations = scoredSessions
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { $0.session }
        
        return recommendations
    }
    
    private func getUserFavoriteCategories(
        from participants: [LiveSessionParticipant],
        favorites: [LiveSession]
    ) -> [String] {
        var categoryCount: [String: Int] = [:]
        
        // Count categories from participated sessions
        // Note: Would need to look up sessions from participants
        
        // Count categories from favorites
        for session in favorites {
            categoryCount[session.category, default: 0] += 2 // Higher weight for favorites
        }
        
        return Array(categoryCount.keys)
    }
    
    private func getUserFavoriteHosts(
        from participants: [LiveSessionParticipant],
        favorites: [LiveSession]
    ) -> [String] {
        var hosts = Set<String>()
        
        for session in favorites {
            hosts.insert(session.hostId)
        }
        
        return Array(hosts)
    }
    
    private func getUserTags(
        from participants: [LiveSessionParticipant],
        favorites: [LiveSession]
    ) -> [String] {
        var tags = Set<String>()
        
        for session in favorites {
            tags.formUnion(session.tags)
        }
        
        return Array(tags)
    }
    
    private func getAverageRating(for sessionId: UUID, from ratings: [SessionRating]) -> Double? {
        let sessionRatings = ratings.filter { $0.sessionId == sessionId }
        guard !sessionRatings.isEmpty else { return nil }
        
        let total = sessionRatings.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(sessionRatings.count)
    }
}
