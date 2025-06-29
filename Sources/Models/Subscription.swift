import Foundation
import SwiftData

@Model
final class Subscription {
    var id: UUID
    var type: SubscriptionType
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var autoRenew: Bool
    var createdAt: Date
    
    enum SubscriptionType: String, CaseIterable, Codable {
        case free = "Free"
        case premium = "Premium"
        case family = "Family"
    }
    
    init(type: SubscriptionType = .free) {
        self.id = UUID()
        self.type = type
        self.startDate = Date()
        self.isActive = true
        self.autoRenew = false
        self.createdAt = Date()
    }
} 