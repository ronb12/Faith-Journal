import Foundation
import SwiftData

@Model
final class Subscription {
    var id: UUID = UUID()
    var type: SubscriptionType = Subscription.SubscriptionType.free
    var startDate: Date = Date()
    var endDate: Date?
    var isActive: Bool = true
    var autoRenew: Bool = false
    var createdAt: Date = Date()
    
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