import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var email: String?
    var avatarPhotoURL: String?
    var preferredTheme: String?
    var notificationsEnabled: Bool = true
    var biometricEnabled: Bool = false
    var privacyLevel: String = "Private"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(name: String, email: String? = nil) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}