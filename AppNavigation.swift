import SwiftUI

@available(iOS 17.0, *)
class AppNavigation: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var bibleTarget: BibleTarget? = nil
}

struct BibleTarget: Equatable {
    let book: String
    let chapter: Int
    let verse: Int?
    let endChapter: Int? // For ranges like "Psalm 1-10"
}
