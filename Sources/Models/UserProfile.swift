import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var email: String?
    var preferredTheme: String
    var notificationsEnabled: Bool
    var biometricEnabled: Bool
    var privacyLevel: PrivacyLevel
    var createdAt: Date
    var updatedAt: Date
    
    enum PrivacyLevel: String, CaseIterable, Codable {
        case public = "Public"
        case friends = "Friends"
        case private = "Private"
    }
    
    init(name: String, email: String? = nil) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.preferredTheme = "default"
        self.notificationsEnabled = true
        self.biometricEnabled = false
        self.privacyLevel = .private
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 