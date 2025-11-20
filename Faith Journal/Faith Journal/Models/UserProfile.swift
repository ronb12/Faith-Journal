import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var email: String?
    var avatarPhotoURL: URL? // URL to saved avatar photo
    var preferredTheme: String = "default"
    var notificationsEnabled: Bool = true
    var biometricEnabled: Bool = false
    var privacyLevel: PrivacyLevel = UserProfile.PrivacyLevel.private
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    enum PrivacyLevel: String, CaseIterable, Codable {
        case `public` = "Public"
        case friends = "Friends"
        case `private` = "Private"
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