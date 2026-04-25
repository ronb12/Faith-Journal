//
//  GlobalSearchView.swift
//  Faith Journal
//
//  Global search across all content types
//

import SwiftUI
import SwiftData
#if canImport(UIKit) && !os(visionOS)
import UIKit
#endif

// MARK: - Bible reference (opens Bible tab with `AppNavigation.bibleTarget`)
enum BibleReferenceNavigationParser {
    /// Minimal parse for search rows (aligned with `ReadingPlansView.parseReference`–style strings).
    static func parse(_ reference: String) -> (String, Int, Int?, Int?)? {
        let parts = reference.split(separator: " ")
        guard parts.count >= 2, let lastPart = parts.last else { return nil }
        let book = parts.dropLast().joined(separator: " ")
        let chapVerse = String(lastPart).trimmingCharacters(in: .whitespacesAndNewlines)
        if chapVerse.contains(":") {
            let cv = chapVerse.split(separator: ":")
            guard cv.count >= 2,
                  let chapter = Int(cv[0].trimmingCharacters(in: .whitespaces)),
                  let verse = Int(cv[1].trimmingCharacters(in: .whitespaces)) else { return nil }
            return (book, chapter, nil, verse)
        }
        if chapVerse.contains("-") || chapVerse.contains("–") {
            let separator: Character = chapVerse.contains("-") ? "-" : "–"
            let rangeParts = chapVerse.split(separator: separator)
            guard rangeParts.count == 2,
                  let startChapter = Int(rangeParts[0].trimmingCharacters(in: .whitespaces)),
                  let endChapter = Int(rangeParts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
            return (book, startChapter, endChapter, nil)
        }
        if let chapter = Int(chapVerse.trimmingCharacters(in: .whitespaces)) {
            return (book, chapter, nil, nil)
        }
        return nil
    }
}

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    // Use regular property for singleton, not @StateObject
    private let bibleService = BibleService.shared

    enum SearchCategory: String, CaseIterable {
        case all = "All"
        case journal = "Journal"
        case prayers = "Prayers"
        case verses = "Bookmarked"
        case mood = "Mood"
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            GlobalSearchView17(bibleService: bibleService)
        } else {
            Text("Global search is only available on iOS 17+")
        }
    }
}

@available(iOS 17.0, *)
struct GlobalSearchView17: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var nav: AppNavigation
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]) private var allJournalEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]) private var allPrayerRequests: [PrayerRequest]
    @Query(sort: [SortDescriptor(\BookmarkedVerse.createdAt, order: .reverse)]) private var allBookmarkedVerses: [BookmarkedVerse]
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) private var allMoodEntries: [MoodEntry]
    @ObservedObject var bibleService: BibleService
    @State private var searchText = ""
    @State private var selectedCategory: GlobalSearchView.SearchCategory = .all
    
    // Detect if running on iPad
    private var isIPad: Bool {
        PlatformDevice.isPadOrMac
    }

    struct SearchResults {
        let journalEntries: [JournalEntry]
        let prayerRequests: [PrayerRequest]
        let verses: [BookmarkedVerse]
        let moodEntries: [MoodEntry]

        var isEmpty: Bool {
            journalEntries.isEmpty && prayerRequests.isEmpty && verses.isEmpty && moodEntries.isEmpty
        }
    }

    var searchResults: SearchResults {
        // Trim and normalize search text
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSearchEmpty = trimmedSearchText.isEmpty
        
        // Filter journal entries
        let journalEntries = allJournalEntries.filter { entry in
            // Check if category matches
            guard selectedCategory == .all || selectedCategory == .journal else { return false }
            
            // If search is empty, don't show anything (user needs to type)
            guard !isSearchEmpty else { return false }
            
            // Search in title and content
            return entry.title.localizedCaseInsensitiveContains(trimmedSearchText) ||
                   entry.content.localizedCaseInsensitiveContains(trimmedSearchText)
        }
        
        // Filter prayer requests
        let prayerRequests = allPrayerRequests.filter { prayer in
            // Check if category matches
            guard selectedCategory == .all || selectedCategory == .prayers else { return false }
            
            // If search is empty, don't show anything
            guard !isSearchEmpty else { return false }
            
            // Search in title, details, and tags
            return prayer.title.localizedCaseInsensitiveContains(trimmedSearchText) ||
                   prayer.details.localizedCaseInsensitiveContains(trimmedSearchText) ||
                   prayer.tags.contains { $0.localizedCaseInsensitiveContains(trimmedSearchText) }
        }
        
        // Filter verses (bookmarked)
        let verses = allBookmarkedVerses.filter { verse in
            // Check if category matches
            guard selectedCategory == .all || selectedCategory == .verses else { return false }
            
            // If search is empty, don't show anything
            guard !isSearchEmpty else { return false }
            
            // Search in reference and text
            return verse.verseReference.localizedCaseInsensitiveContains(trimmedSearchText) ||
                   verse.verseText.localizedCaseInsensitiveContains(trimmedSearchText)
        }
        
        let moodEntries = allMoodEntries.filter { entry in
            guard selectedCategory == .all || selectedCategory == .mood else { return false }
            guard !isSearchEmpty else { return false }
            let inNotes = (entry.notes ?? "").localizedCaseInsensitiveContains(trimmedSearchText)
            let inMood = entry.mood.localizedCaseInsensitiveContains(trimmedSearchText)
            let inEmoji = entry.emoji.localizedCaseInsensitiveContains(trimmedSearchText)
            let inCategory = entry.moodCategory.localizedCaseInsensitiveContains(trimmedSearchText)
            let inTags = entry.tags.contains { $0.localizedCaseInsensitiveContains(trimmedSearchText) }
            let inActivities = entry.activities.contains { $0.localizedCaseInsensitiveContains(trimmedSearchText) }
            return inMood || inNotes || inEmoji || inCategory || inTags || inActivities
        }
        
        return SearchResults(journalEntries: journalEntries, prayerRequests: prayerRequests, verses: verses, moodEntries: moodEntries)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilter

                if searchText.isEmpty {
                    emptyStateView
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    resultsContent
                }
            }
            .navigationTitle("Search")
            #if os(iOS)
            .navigationBarTitleDisplayMode(isIPad ? .large : .inline)
            #endif
            .searchable(text: $searchText, prompt: "Search journal, prayers, bookmarked verses, mood…")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
            HStack(spacing: 12) {
                ForEach(GlobalSearchView.SearchCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category.rawValue)
                            .font(.subheadline)
                            .font(.body.weight(.medium))
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == category ? Color.purple : Color.platformSystemGray5)
                            )
                    }
                }
            }
            .padding(.horizontal, isIPad ? 40 : 16)
        }
        .padding(.vertical, 8)
        .background(Color.platformSystemGray6)
    }

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.primary)
            Text("Search across your content")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Journal, prayers, bookmarked Bible verses, mood check-ins, and more")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.primary)
            Text("No results found")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Try different keywords")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var resultsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !searchResults.journalEntries.isEmpty || !searchResults.prayerRequests.isEmpty || !searchResults.verses.isEmpty
                    || !searchResults.moodEntries.isEmpty {
                    journalEntriesSection
                    prayerRequestsSection
                    versesSection
                    moodEntriesSection
                } else {
                    noResultsView
                }
            }
            .padding(isIPad ? 40 : 16)
        }
    }

    @ViewBuilder
    var journalEntriesSection: some View {
        if !searchResults.journalEntries.isEmpty {
            SearchSection(
                title: "Journal Entries (\(searchResults.journalEntries.count))",
                icon: "book.fill",
                color: .blue
            ) {
                ForEach(searchResults.journalEntries) { entry in
                    journalEntryRow(entry: entry)
                }
            }
        }
    }

    @ViewBuilder
    func journalEntryRow(entry: JournalEntry) -> some View {
        NavigationLink(destination: JournalEntryDetailView(entry: entry)) {
            SearchResultRow(
                title: entry.title,
                subtitle: truncateText(entry.content, maxLength: 100),
                date: entry.createdAt
            )
        }
    }

    @ViewBuilder
    var prayerRequestsSection: some View {
        if !searchResults.prayerRequests.isEmpty {
            SearchSection(
                title: "Prayer Requests (\(searchResults.prayerRequests.count))",
                icon: "hands.sparkles.fill",
                color: .green
            ) {
                ForEach(searchResults.prayerRequests) { prayer in
                    prayerRequestRow(prayer: prayer)
                }
            }
        }
    }

    @ViewBuilder
    func prayerRequestRow(prayer: PrayerRequest) -> some View {
        NavigationLink(destination: PrayerRequestDetailView(request: prayer)) {
            SearchResultRow(
                title: prayer.title,
                subtitle: truncateText(prayer.details, maxLength: 100),
                date: prayer.createdAt
            )
        }
    }

    func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count > maxLength {
            return String(text.prefix(maxLength)) + "..."
        }
        return text
    }

    @ViewBuilder
    var versesSection: some View {
        if !searchResults.verses.isEmpty {
            SearchSection(
                title: "Bookmarked Verses (\(searchResults.verses.count))",
                icon: "book.closed.fill",
                color: .purple
            ) {
                ForEach(searchResults.verses.indices, id: \.self) { index in
                    verseRow(verse: searchResults.verses[index])
                }
            }
        }
    }

    @ViewBuilder
    func verseRow(verse: BookmarkedVerse) -> some View {
        Button {
            if let p = BibleReferenceNavigationParser.parse(verse.verseReference) {
                let (book, ch, endCh, v) = p
                #if canImport(UIKit) && !os(visionOS)
                let haptic = UIImpactFeedbackGenerator(style: .light)
                haptic.prepare()
                haptic.impactOccurred()
                #endif
                nav.bibleTarget = BibleTarget(book: book, chapter: ch, verse: v, endChapter: endCh)
                nav.selectedTab = 4
                FaithJournalLog.search.info("Open Bible from search: \(verse.verseReference)")
                dismiss()
            }
        } label: {
            SearchResultRow(
                title: verse.verseReference,
                subtitle: verse.verseText,
                date: verse.createdAt
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var moodEntriesSection: some View {
        if !searchResults.moodEntries.isEmpty {
            SearchSection(
                title: "Mood (\(searchResults.moodEntries.count))",
                icon: "face.smiling",
                color: .pink
            ) {
                ForEach(searchResults.moodEntries, id: \.id) { entry in
                    NavigationLink {
                        MoodEntrySearchDetailView(entry: entry)
                    } label: {
                        SearchResultRow(
                            title: "\(entry.emoji) \(entry.mood)",
                            subtitle: moodSearchSubtitle(entry),
                            date: entry.date
                        )
                    }
                }
            }
        }
    }

    private func moodSearchSubtitle(_ entry: MoodEntry) -> String {
        if let n = entry.notes, !n.isEmpty { return truncateText(n, maxLength: 100) }
        return "Intensity \(entry.intensity)/10"
    }
}

@available(iOS 17.0, *)
struct MoodEntrySearchDetailView: View {
    let entry: MoodEntry

    var body: some View {
        ScrollView {
            MoodEntryRow(entry: entry)
                .padding()
        }
        .navigationTitle("Mood check-in")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct SearchSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .font(.body.weight(.semibold))
            }
            
            content
        }
    }
}

struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Text(date, style: .relative)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.platformSystemGray6)
        )
    }
}

