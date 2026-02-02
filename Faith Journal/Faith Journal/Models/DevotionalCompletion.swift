import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class DevotionalCompletion {
    var id: UUID
    var devotionalId: UUID
    var devotionalDate: Date
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(devotionalId: UUID, devotionalDate: Date, isCompleted: Bool = false) {
        self.id = UUID()
        self.devotionalId = devotionalId
        self.devotionalDate = devotionalDate
        self.isCompleted = isCompleted
        self.completedAt = isCompleted ? Date() : nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
