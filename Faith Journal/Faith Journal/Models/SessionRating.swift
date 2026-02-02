//
//  SessionRating.swift
//  Faith Journal
//
//  Post-session feedback and ratings
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class SessionRating {
    var id: UUID = UUID()
    var sessionId: UUID
    var userId: String = ""
    var userName: String = ""
    var rating: Int = 5 // 1-5 stars
    var review: String = ""
    var createdAt: Date = Date()
    
    init(sessionId: UUID, userId: String, userName: String, rating: Int, review: String = "") {
        self.id = UUID()
        self.sessionId = sessionId
        self.userId = userId
        self.userName = userName
        self.rating = max(1, min(5, rating)) // Clamp between 1-5
        self.review = review
        self.createdAt = Date()
    }
}
