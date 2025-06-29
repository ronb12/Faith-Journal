import Foundation
import SwiftData

@Model
final class Devotional {
    var id: UUID
    var title: String
    var content: String
    var author: String
    var date: Date
    var category: String
    var tags: [String]
    var isFavorite: Bool
    var isCompleted: Bool
    var completionDate: Date?
    var notes: String?
    var createdAt: Date
    
    init(title: String, content: String, author: String, category: String, tags: [String] = []) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.author = author
        self.date = Date()
        self.category = category
        self.tags = tags
        self.isFavorite = false
        self.isCompleted = false
        self.createdAt = Date()
    }
} 