//
//  GlobalSearchView.swift
//  Faith Journal
//
//  Global search across all content types
//

import SwiftUI
import SwiftData

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    // Use regular property for singleton, not @StateObject
    private let bibleService = BibleService.shared

    enum SearchCategory: String, CaseIterable {
        case all = "All"
        case journal = "Journal"
        case prayers = "Prayers"
        case verses = "Verses"
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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]) private var allJournalEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]) private var allPrayerRequests: [PrayerRequest]
    @Query(sort: [SortDescriptor(\BookmarkedVerse.createdAt, order: .reverse)]) private var allBookmarkedVerses: [BookmarkedVerse]
    @ObservedObject var bibleService: BibleService
    @State private var searchText = ""
    @State private var selectedCategory: GlobalSearchView.SearchCategory = .all
    
    // Detect if running on iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    struct SearchResults {
        let journalEntries: [JournalEntry]
        let prayerRequests: [PrayerRequest]
        let verses: [BookmarkedVerse]

        var isEmpty: Bool {
            journalEntries.isEmpty && prayerRequests.isEmpty && verses.isEmpty
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
        
        // Filter verses
        let verses = allBookmarkedVerses.filter { verse in
            // Check if category matches
            guard selectedCategory == .all || selectedCategory == .verses else { return false }
            
            // If search is empty, don't show anything
            guard !isSearchEmpty else { return false }
            
            // Search in reference and text
            return verse.verseReference.localizedCaseInsensitiveContains(trimmedSearchText) ||
                   verse.verseText.localizedCaseInsensitiveContains(trimmedSearchText)
        }
        
        return SearchResults(journalEntries: journalEntries, prayerRequests: prayerRequests, verses: verses)
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
            .navigationBarTitleDisplayMode(isIPad ? .large : .inline)
            .searchable(text: $searchText, prompt: "Search journal, prayers, verses...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                                    .fill(selectedCategory == category ? Color.purple : Color(.systemGray5))
                            )
                    }
                }
            }
            .padding(.horizontal, isIPad ? 40 : 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.primary)
            Text("Search across all your content")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Journal entries, prayers, verses, and more")
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
                if !searchResults.journalEntries.isEmpty || !searchResults.prayerRequests.isEmpty || !searchResults.verses.isEmpty {
                    journalEntriesSection
                    prayerRequestsSection
                    versesSection
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
                title: "Verses (\(searchResults.verses.count))",
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
        SearchResultRow(
            title: verse.verseReference,
            subtitle: verse.verseText,
            date: verse.createdAt
        )
    }
}

@available(iOS 17.0, *)
struct SearchResults {
    let journalEntries: [JournalEntry]
    let prayerRequests: [PrayerRequest]
    let verses: [BookmarkedVerse]
    
    var isEmpty: Bool {
        journalEntries.isEmpty && prayerRequests.isEmpty && verses.isEmpty
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
                .fill(Color(.systemGray6))
        )
    }
}

