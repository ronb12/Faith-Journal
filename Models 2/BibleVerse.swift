import Foundation

struct BibleVerse: Codable, Identifiable, Hashable {
    let id: UUID
    let reference: String
    let text: String
    let translation: String
    
    init(id: UUID = UUID(), reference: String, text: String, translation: String) {
        self.id = id
        self.reference = reference
        self.text = text
        self.translation = translation
    }
}
