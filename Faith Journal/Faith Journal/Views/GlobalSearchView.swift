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
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]) private var allJournalEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]) private var allPrayerRequests: [PrayerRequest]
    @Query(sort: [SortDescriptor(\BookmarkedVerse.createdAt, order: .reverse)]) private var allBookmarkedVerses: [BookmarkedVerse]
    @StateObject private var bibleService = BibleService.shared
    
    @State private var searchText = ""
    @State private var selectedCategory: SearchCategory = .all
    
    enum SearchCategory: String, CaseIterable {
        case all = "All"
        case journal = "Journal"
        case prayers = "Prayers"
        case verses = "Verses"
    }
    
    var searchResults: SearchResults {
        guard !searchText.isEmpty else {
            return SearchResults(
                journalEntries: [],
                prayerRequests: [],
                verses: []
            )
        }
        
        let query = searchText.lowercased()
        var journalResults: [JournalEntry] = []
        var prayerResults: [PrayerRequest] = []
        var verseResults: [BookmarkedVerse] = []
        
        if selectedCategory == .all || selectedCategory == .journal {
            journalResults = allJournalEntries.filter { entry in
                entry.title.lowercased().contains(query) ||
                entry.content.lowercased().contains(query) ||
                entry.tags.contains { $0.lowercased().contains(query) }
            }
        }
        
        if selectedCategory == .all || selectedCategory == .prayers {
            prayerResults = allPrayerRequests.filter { prayer in
                prayer.title.lowercased().contains(query) ||
                prayer.details.lowercased().contains(query) ||
                (prayer.answerNotes?.lowercased().contains(query) ?? false)
            }
        }
        
        if selectedCategory == .all || selectedCategory == .verses {
            // Search bookmarked verses
            let bookmarked = allBookmarkedVerses.filter { verse in
                verse.verseReference.lowercased().contains(query) ||
                verse.verseText.lowercased().contains(query)
            }
            
            // Search local verses database
            let localVerses = bibleService.getAllLocalVerses().filter { verse in
                verse.reference.lowercased().contains(query) ||
                verse.text.lowercased().contains(query)
            }.prefix(20)
            
            var mappedVerses: [BookmarkedVerse] = []
            for verse in localVerses {
                mappedVerses.append(BookmarkedVerse(
                    verseReference: verse.reference,
                    verseText: verse.text,
                    translation: verse.translation,
                    bookmarkedBy: "",
                    bookmarkedByName: ""
                ))
            }
            
            verseResults = bookmarked + mappedVerses
        }
        
        return SearchResults(
            journalEntries: journalResults,
            prayerRequests: prayerResults,
            verses: verseResults
        )
    }
    
    var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
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
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Search across all your content")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Journal entries, prayers, verses, and more")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No results found")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Try different keywords")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var resultsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                journalEntriesSection
                prayerRequestsSection
                versesSection
            }
            .padding()
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
    
    var body: some View {
        NavigationView {
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
            .navigationBarTitleDisplayMode(.inline)
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
}

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
                    .fontWeight(.semibold)
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
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text(date, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    GlobalSearchView()
}
