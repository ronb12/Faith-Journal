import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct BibleView: View {
    // Observe singletons to get updates when their @Published properties change
    private let bibleService = BibleService.shared
    @ObservedObject private var verseManager = BibleVerseOfTheDayManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var nav: AppNavigation
    
    // Navigation state
    @State private var selectedBook: String? = nil
    @State private var selectedChapter: Int? = nil
    @State private var showingBookSelector = false
    @State private var showingChapterView = false
    @State private var showingChapterRangeView = false
    @State private var rangeStartChapter: Int? = nil
    @State private var rangeEndChapter: Int? = nil
    @State private var currentChapterInRange: Int = 1
    @State private var rangeBook: String? = nil
    
    // Store range reading progress: "Book:start-end" -> lastChapter
    @AppStorage("bibleRangeProgress") private var rangeProgressData: Data = Data()
    
    // Search state
    @State private var searchText: String = ""
    @State private var searchFilter: SearchFilter = .all
    @State private var recentSearches: [String] = []
    @FocusState private var isSearchFocused: Bool
    
    // Translation state - Use same key as Settings
    @AppStorage("selectedBibleVersion") private var selectedTranslation: String = BibleVersion.niv.rawValue
    @State private var showingTranslationPicker = false
    @State private var showingParallelView = false
    @State private var parallelTranslation: String = "KJV"
    
    // Reading experience
    @AppStorage("bibleFontSize") private var fontSize: Double = 16
    @AppStorage("bibleTheme") private var readingTheme: String = "System"
    @AppStorage("showVerseNumbers") private var showVerseNumbers: Bool = true
    @AppStorage("paragraphSpacing") private var paragraphSpacing: Int = 5 // 3, 5, 10, or 0 for no spacing
    @State private var showingSettings = false
    
    // Verse interaction
    @State private var selectedVerse: BibleVerse? = nil
    @State private var showingHighlightPicker = false
    @State private var verseToHighlight: String? = nil
    @State private var showingNoteEditor = false
    @State private var verseToNote: String? = nil
    @State private var noteText: String = ""
    
    // Organization views
    @State private var showingBookmarks = false
    @State private var showingHighlights = false
    @State private var showingNotes = false
    @State private var showingHistory = false
    
    // Chapter reading state
    @State private var chapterVerses: [(verse: BibleVerse, number: Int)] = []
    @State private var isLoadingChapter = false
    @State private var chapterError: String? = nil
    
    // Store verses per chapter for range views (e.g., Psalm 1-10)
    private struct ChapterKey: Hashable {
        let book: String
        let chapter: Int
    }
    @State private var chapterVersesMap: [ChapterKey: [(verse: BibleVerse, number: Int)]] = [:]
    @State private var chapterLoadingMap: [ChapterKey: Bool] = [:]
    @State private var chapterErrorMap: [ChapterKey: String?] = [:]
    
    // Chapter cache for faster loading
    private struct ChapterCacheKey: Hashable {
        let book: String
        let chapter: Int
        let translation: String
    }
    
    @State private var chapterCache: [ChapterCacheKey: [(verse: BibleVerse, number: Int)]] = [:]
    
    // Track in-progress requests to prevent duplicate API calls
    @State private var inProgressRequests: Set<ChapterCacheKey> = []
    
    // Queries
    @Query(sort: [SortDescriptor(\BookmarkedVerse.createdAt, order: .reverse)]) private var bookmarks: [BookmarkedVerse]
    @Query(sort: [SortDescriptor(\BibleHighlight.createdAt, order: .reverse)]) private var highlights: [BibleHighlight]
    @Query(sort: [SortDescriptor(\BibleNote.updatedAt, order: .reverse)]) private var notes: [BibleNote]
    @Query(sort: [SortDescriptor(\BibleReadingHistory.lastReadDate, order: .reverse)]) private var readingHistory: [BibleReadingHistory]
    
    // Highlight colors
    let highlightColors: [(Color, String)] = [
        (Color.yellow.opacity(0.4), "Yellow"),
        (Color.green.opacity(0.4), "Green"),
        (Color.pink.opacity(0.4), "Pink"),
        (Color.blue.opacity(0.4), "Blue"),
        (Color.orange.opacity(0.4), "Orange")
    ]
    
    // Available translations
    let translations: [(String, String)] = [
        ("NIV", "New International Version"),
        ("KJV", "King James Version"),
        ("ESV", "English Standard Version"),
        ("NLT", "New Living Translation"),
        ("NASB", "New American Standard Bible"),
        ("WEB", "World English Bible"),
        ("MSG", "The Message"),
        ("AMP", "Amplified Bible"),
        ("CSB", "Christian Standard Bible")
    ]
    
    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case oldTestament = "Old Testament"
        case newTestament = "New Testament"
        case book = "Book"
        case keyword = "Keyword"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background based on theme
                themeBackground
                    .ignoresSafeArea()
                
                if !searchText.isEmpty {
                    // Search view
                    enhancedSearchView
                } else if showingChapterView, let book = selectedBook, let chapter = selectedChapter {
                    // Chapter reading view
                    chapterReadingView(book: book, chapter: chapter)
                } else {
                    // Main Bible view
                    mainBibleView
                }
            }
            .navigationTitle("Bible")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Translation button
                    Button(action: { showingTranslationPicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "textformat")
                            Text(selectedTranslation)
                                .font(.caption)
                        }
                    }
                    
                    // Settings button
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    // Organization buttons
                    Menu {
                        Button(action: { showingBookmarks = true }) {
                            Label("Bookmarks", systemImage: "bookmark.fill")
                        }
                        Button(action: { showingHighlights = true }) {
                            Label("Highlights", systemImage: "highlighter")
                        }
                        Button(action: { showingNotes = true }) {
                            Label("Notes", systemImage: "note.text")
                        }
                        Button(action: { showingHistory = true }) {
                            Label("Reading History", systemImage: "clock.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingBookSelector) {
                bookSelectorView
            }
            .sheet(isPresented: $showingTranslationPicker) {
                translationPickerView
            }
            .sheet(isPresented: $showingSettings) {
                bibleSettingsView
            }
            .sheet(item: $selectedVerse) { verse in
                verseDetailView(verse: verse)
            }
            .sheet(isPresented: $showingHighlightPicker) {
                if let verseRef = verseToHighlight, !verseRef.isEmpty {
                    highlightPickerView(verseReference: verseRef)
                } else {
                    // Fallback view if verse reference is nil
                    NavigationStack {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("Unable to highlight verse")
                                .font(.headline)
                            Text("Please try again")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Highlight")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingHighlightPicker = false
                                    verseToHighlight = nil
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: showingHighlightPicker) { oldValue, newValue in
                if !newValue {
                    // Clear verse reference when sheet is dismissed
                    verseToHighlight = nil
                }
            }
            .sheet(isPresented: $showingNoteEditor) {
                if let verseRef = verseToNote {
                    noteEditorView(verseReference: verseRef)
                }
            }
            .sheet(isPresented: $showingBookmarks) {
                bookmarksListView
            }
            .sheet(isPresented: $showingHighlights) {
                highlightsListView
            }
            .sheet(isPresented: $showingNotes) {
                notesListView
            }
            .sheet(isPresented: $showingHistory) {
                readingHistoryView
            }
            .fullScreenCover(isPresented: $showingChapterView) {
                if let book = selectedBook, let chapter = selectedChapter {
                    chapterReadingView(book: book, chapter: chapter)
                }
            }
            .fullScreenCover(isPresented: $showingChapterRangeView) {
                if let book = selectedBook, let startChapter = rangeStartChapter, let endChapter = rangeEndChapter {
                    chapterRangeReadingView(book: book, startChapter: startChapter, endChapter: endChapter)
                }
            }
            .onChange(of: selectedTranslation) { oldValue, newValue in
                // Update Verse of the Day when version changes
                if oldValue != newValue, let version = BibleVersion(rawValue: newValue) {
                    print("📖 Bible version changed from \(oldValue) to \(newValue), updating Verse of the Day...")
                    BibleVerseOfTheDayManager.shared.updateVersion(version)
                }
                
                // Reload current chapter when version changes
                if oldValue != newValue, let book = selectedBook, let chapter = selectedChapter {
                    print("📖 Bible version changed from \(oldValue) to \(newValue), reloading chapter...")
                    // Clear cache for this chapter in old translation
                    let oldCacheKey = ChapterCacheKey(book: book, chapter: chapter, translation: oldValue)
                    chapterCache.removeValue(forKey: oldCacheKey)
                    // Reload chapter with new translation
                    loadChapter(book: book, chapter: chapter, useCache: false)
                }
            }
            .onAppear {
                loadRecentSearches()
                if verseManager.currentVerse == nil {
                    verseManager.loadRandomVerse()
                }
                
                // Check if there's a pending bible target when view appears
                if let target = nav.bibleTarget {
                    handleBibleTarget(target)
                }
            }
            .onChange(of: nav.bibleTarget) { oldValue, newValue in
                if let target = newValue {
                    handleBibleTarget(target)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func handleBibleTarget(_ target: BibleTarget) {
        // Navigate to the specified book and chapter
        selectedBook = target.book
        selectedChapter = target.chapter
        
        // If there's a range, show range view with chapter-by-chapter navigation
        if let endChapter = target.endChapter {
            // Check for saved progress in this range
            let savedChapter = getRangeProgress(book: target.book, startChapter: target.chapter, endChapter: endChapter)
            
            // Show the range view - it will load chapters one at a time
            rangeBook = target.book
            rangeStartChapter = target.chapter
            rangeEndChapter = endChapter
            currentChapterInRange = savedChapter ?? target.chapter // Resume from saved progress or start from beginning
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingChapterRangeView = true
            }
        } else {
            // Load just the single chapter
            loadChapter(book: target.book, chapter: target.chapter, useCache: true)
            // Show the single chapter view
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingChapterView = true
            }
        }
        
        // Clear the target after handling it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            nav.bibleTarget = nil
        }
    }
    
    // MARK: - Main Bible View
    
    private var mainBibleView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search bar at top
                SearchBar(text: $searchText, placeholder: "Search Bible verses...", isFocused: $isSearchFocused)
                    .padding(.horizontal)
                
                // Quick Actions
                quickActionsSection
                
                // Verse of the Day
                if let verse = verseManager.currentVerse {
                    verseOfTheDayCard(verse: verse)
                }
                
                // Popular Verses
                popularVersesSection
                
                // Continue Reading
                if let lastRead = readingHistory.first {
                    continueReadingCard(history: lastRead)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    icon: "book.fill",
                    title: "Browse Books",
                    color: .purple
                ) {
                    showingBookSelector = true
                }
                
                QuickActionButton(
                    icon: "magnifyingglass",
                    title: "Search",
                    color: .blue
                ) {
                    // Focus the search bar - search will trigger automatically when user types
                    isSearchFocused = true
                }
                
                QuickActionButton(
                    icon: "bookmark.fill",
                    title: "Bookmarks",
                    color: .yellow
                ) {
                    showingBookmarks = true
                }
                
                QuickActionButton(
                    icon: "highlighter",
                    title: "Highlights",
                    color: .green
                ) {
                    showingHighlights = true
                }
            }
        }
    }
    
    // MARK: - Verse of the Day
    
    private func verseOfTheDayCard(verse: BibleVerse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                Text("Verse of the Day")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    verseManager.loadRandomVerse()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.primary)
                }
            }
            
            Button(action: {
                selectedVerse = verse
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verse.reference)
                        .font(.title3)
                        .font(.body.weight(.bold))
                        .foregroundColor(.purple)
                    
                    Text(verse.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack {
                // Show the selected version from settings, not the verse's actual translation
                // This ensures the version text updates when user changes version in settings
                Text(verseManager.selectedVersion.rawValue)
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: {
                        toggleBookmark(verse: verse)
                    }) {
                        Image(systemName: isBookmarked(verse: verse) ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isBookmarked(verse: verse) ? .yellow : .secondary)
                    }
                    
                    Button(action: {
                        verseToHighlight = verse.reference
                        showingHighlightPicker = true
                    }) {
                        Image(systemName: "highlighter")
                            .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        verseToNote = verse.reference
                        noteText = getNote(for: verse.reference)?.noteText ?? ""
                        showingNoteEditor = true
                    }) {
                        Image(systemName: "note.text")
                            .foregroundColor(.blue)
                    }
                    
                    ShareLink(item: "\(verse.reference)\n\n\(verse.text)") {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Popular Verses
    
    private var popularVersesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular Verses")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 8) {
                ForEach(popularVerseReferences, id: \.self) { reference in
                    PopularVerseRow(
                        reference: reference,
                        bibleService: bibleService,
                        translation: selectedTranslation,
                        onTap: { verse in
                            selectedVerse = verse
                        }
                    )
                }
            }
        }
    }
    
    let popularVerseReferences = [
        "John 3:16",
        "Jeremiah 29:11",
        "Philippians 4:13",
        "Romans 8:28",
        "Proverbs 3:5-6",
        "Isaiah 40:31",
        "Joshua 1:9",
        "Psalm 23:1",
        "Matthew 6:33",
        "1 Corinthians 13:4"
    ]
    
    // MARK: - Continue Reading
    
    private func continueReadingCard(history: BibleReadingHistory) -> some View {
        Button(action: {
            selectedBook = history.book
            selectedChapter = history.chapter
            showingChapterView = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Continue Reading")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(history.book) \(history.chapter)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    if history.readingProgress > 0 {
                        ProgressView(value: history.readingProgress)
                            .tint(.purple)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Enhanced Search
    
    private var enhancedSearchView: some View {
        VStack(spacing: 0) {
            // Search bar with filters
            VStack(spacing: 12) {
                SearchBar(text: $searchText, placeholder: "Search Bible verses...", isFocused: $isSearchFocused)
                    .padding(.horizontal)
                
                // Search filters
                ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                    HStack(spacing: 8) {
                        ForEach(SearchFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                searchFilter = filter
                            }) {
                                Text(filter.rawValue)
                                    .font(.caption)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(searchFilter == filter ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        searchFilter == filter ?
                                        LinearGradient(colors: [Color.purple, Color.blue], startPoint: .leading, endPoint: .trailing) :
                                        LinearGradient(colors: [Color(.systemGray5)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Recent searches
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Searches")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                            HStack(spacing: 8) {
                                ForEach(recentSearches.prefix(5), id: \.self) { search in
                                    Button(action: {
                                        searchText = search
                                    }) {
                                        Text(search)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
            .background(Color(.systemBackground))
            
            // Search results
            BibleSearchResultsView(
                searchText: searchText,
                bibleService: bibleService,
                translation: selectedTranslation,
                filter: searchFilter,
                onVerseTap: { verse in
                    selectedVerse = verse
                }
            )
        }
    }
    
    // MARK: - Chapter Reading View
    
    private func chapterReadingView(book: String, chapter: Int) -> some View {
        NavigationStack {
            ZStack {
                themeBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Chapter header
                        chapterHeader(book: book, chapter: chapter)
                        
                        // Chapter content (placeholder - would fetch from API)
                        chapterContent(book: book, chapter: chapter)
                    }
                    .padding()
                }
            }
            .navigationTitle("\(book) \(chapter)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        showingChapterView = false
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Previous chapter
                    if chapter > 1 {
                        Button(action: {
                            selectedChapter = chapter - 1
                        }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                    
                    // Next chapter
                    if let bookInfo = BibleBooks.book(named: book), chapter < bookInfo.chapters {
                        Button(action: {
                            selectedChapter = chapter + 1
                        }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                    
                    // Settings button (Aa)
                    Button(action: {
                        showingSettings = true
                    }) {
                        Text("Aa")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .onAppear {
                saveReadingProgress(book: book, chapter: chapter)
                loadChapter(book: book, chapter: chapter)
            }
            .onChange(of: selectedChapter) { _, newChapter in
                if let newChapter = newChapter {
                    loadChapter(book: book, chapter: newChapter)
                }
            }
            .onChange(of: selectedTranslation) { oldValue, newValue in
                // Update Verse of the Day when version changes
                if oldValue != newValue, let version = BibleVersion(rawValue: newValue) {
                    BibleVerseOfTheDayManager.shared.updateVersion(version)
                }
                // Update Verse of the Day when version changes
                if oldValue != newValue, let version = BibleVersion(rawValue: newValue) {
                    BibleVerseOfTheDayManager.shared.updateVersion(version)
                }
                loadChapter(book: book, chapter: chapter)
            }
            .sheet(isPresented: $showingSettings) {
                bibleSettingsView
            }
        }
    }
    
    // MARK: - Chapter Range Reading View (for ranges like Psalm 1-10)
    // Uses single-chapter view with range-aware navigation
    
    private func chapterRangeReadingView(book: String, startChapter: Int, endChapter: Int) -> some View {
        return NavigationStack {
            ZStack {
                themeBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Range indicator
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(book) \(startChapter)-\(endChapter)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    Text("Chapter \(currentChapterInRange) of \(endChapter - startChapter + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                    if currentChapterInRange > startChapter {
                                        Text("• Resumed")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Chapter header
                        chapterHeader(book: book, chapter: currentChapterInRange)
                        
                        // Chapter content - only loads the current chapter
                        chapterContent(book: book, chapter: currentChapterInRange)
                        
                        // Navigation buttons for range
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                // Previous chapter in range
                                if currentChapterInRange > startChapter {
                                    Button(action: {
                                        currentChapterInRange -= 1
                                        // Scroll to top
                                    }) {
                                        HStack {
                                            Image(systemName: "chevron.left")
                                            Text("Previous Chapter")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.purple)
                                        .cornerRadius(12)
                                    }
                                }
                                
                                // Next chapter in range
                                if currentChapterInRange < endChapter {
                                    Button(action: {
                                        currentChapterInRange += 1
                                        // Scroll to top
                                    }) {
                                        HStack {
                                            Text("Next Chapter")
                                            Image(systemName: "chevron.right")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.purple)
                                        .cornerRadius(12)
                                    }
                                } else {
                                    // End of range
                                    Text("End of reading")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                            }
                            .padding(.horizontal)
                            Spacer()
                        }
                        .padding(.vertical)
                    }
                    .padding()
                }
            }
            .navigationTitle("\(book) \(currentChapterInRange)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        showingChapterRangeView = false
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Previous chapter button
                    if currentChapterInRange > startChapter {
                        Button(action: {
                            currentChapterInRange -= 1
                        }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                    
                    // Next chapter button
                    if currentChapterInRange < endChapter {
                        Button(action: {
                            currentChapterInRange += 1
                        }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                    
                    // Settings button
                    Button(action: {
                        showingSettings = true
                    }) {
                        Text("Aa")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .onAppear {
                // Load the current chapter (may be resumed from saved progress)
                saveReadingProgress(book: book, chapter: currentChapterInRange)
                loadChapter(book: book, chapter: currentChapterInRange, useCache: true)
            }
            .onChange(of: currentChapterInRange) { oldValue, newChapter in
                // Save range progress when user navigates to a new chapter
                saveRangeProgress(book: book, startChapter: startChapter, endChapter: endChapter, currentChapter: newChapter)
                saveReadingProgress(book: book, chapter: newChapter)
                loadChapter(book: book, chapter: newChapter, useCache: true)
            }
            .onChange(of: selectedTranslation) { oldValue, newValue in
                // Update Verse of the Day when version changes
                if oldValue != newValue, let version = BibleVersion(rawValue: newValue) {
                    BibleVerseOfTheDayManager.shared.updateVersion(version)
                }
                // Reload current chapter when translation changes
                loadChapter(book: book, chapter: currentChapterInRange, useCache: false)
            }
            .sheet(isPresented: $showingSettings) {
                bibleSettingsView
            }
        }
    }
    
    private func chapterHeader(book: String, chapter: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book)
                .font(.title)
                .font(.body.weight(.bold))
            Text("Chapter \(chapter)")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(selectedTranslation)
                .font(.caption)
                .foregroundColor(.purple)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func chapterContent(book: String, chapter: Int) -> some View {
        let chapterKey = ChapterKey(book: book, chapter: chapter)
        let verses = chapterVersesMap[chapterKey] ?? []
        let isLoading = chapterLoadingMap[chapterKey] ?? false
        let error = chapterErrorMap[chapterKey] ?? nil
        let hasTriedLoading = chapterLoadingMap[chapterKey] != nil || chapterVersesMap[chapterKey] != nil || chapterErrorMap[chapterKey] != nil
        
        return VStack(alignment: .leading, spacing: 2) {
            if !hasTriedLoading {
                // Not loaded yet - show a subtle placeholder
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Scroll to load")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading chapter...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Unable to load chapter")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadChapter(book: book, chapter: chapter, useCache: false)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if verses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No verses found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Display verses in a flowing paragraph format with tappable verse numbers
                // Group verses into paragraphs based on user preference
                if paragraphSpacing == 0 {
                    // No spacing - display all verses as one continuous paragraph
                    buildParagraphView(from: verses)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                } else {
                    // Group verses into paragraphs based on spacing preference
                    let verseGroups = verses.chunked(into: paragraphSpacing)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(verseGroups.enumerated()), id: \.offset) { paragraphIndex, verseGroup in
                            // Each paragraph flows as continuous text with inline verse numbers
                            buildParagraphView(from: verseGroup)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    private func verseRow(reference: String, verseText: String, verseNumber: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Display verse number inline with text (standard Bible format)
            HStack(alignment: .top, spacing: 6) {
                if showVerseNumbers {
                    Text("\(verseNumber)")
                        .font(.system(size: fontSize - 2))
                        .font(.body.weight(.bold))
                        .foregroundColor(.purple)
                        .baselineOffset(2) // Slightly superscript
                }
                
                Text(verseText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: fontSize))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Verse actions - only show on long press or tap, or make them smaller/less prominent
            HStack(spacing: 12) {
                Button(action: {
                    let verse = BibleVerse(reference: reference, text: verseText, translation: selectedTranslation)
                    toggleBookmark(verse: verse)
                }) {
                    Image(systemName: isBookmarked(reference: reference) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 11))
                        .foregroundColor(isBookmarked(reference: reference) ? .yellow : .secondary.opacity(0.6))
                }
                
                Button(action: {
                    verseToHighlight = reference
                    showingHighlightPicker = true
                }) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 11))
                        .foregroundColor(hasHighlight(reference: reference) ? .green : .secondary.opacity(0.6))
                }
                
                Button(action: {
                    verseToNote = reference
                    noteText = getNote(for: reference)?.noteText ?? ""
                    showingNoteEditor = true
                }) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundColor(hasNote(reference: reference) ? .blue : .secondary.opacity(0.6))
                }
                
                ShareLink(item: "\(reference)\n\n\(verseText)") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.top, 2)
            .opacity(0.7) // Make action buttons less prominent
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            highlightColor(for: reference).opacity(0.15)
        )
    }
    
    // MARK: - Book Selector
    
    private var bookSelectorView: some View {
        NavigationStack {
            List {
                Section("Old Testament") {
                    ForEach(BibleBooks.oldTestament, id: \.name) { bookInfo in
                        Button(action: {
                            selectedBook = bookInfo.name
                            selectedChapter = 1
                            showingBookSelector = false
                            showingChapterView = true
                        }) {
                            HStack {
                                Text(bookInfo.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(bookInfo.chapters) chapters")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("New Testament") {
                    ForEach(BibleBooks.newTestament, id: \.name) { bookInfo in
                        Button(action: {
                            selectedBook = bookInfo.name
                            selectedChapter = 1
                            showingBookSelector = false
                            showingChapterView = true
                        }) {
                            HStack {
                                Text(bookInfo.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(bookInfo.chapters) chapters")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingBookSelector = false
                    }
                }
            }
        }
    }
    
    // MARK: - Translation Picker
    
    private var translationPickerView: some View {
        NavigationStack {
            List {
                ForEach(translations, id: \.0) { code, name in
                    Button(action: {
                        selectedTranslation = code
                        showingTranslationPicker = false
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .foregroundColor(.primary)
                                Text(code)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedTranslation == code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingTranslationPicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Bible Settings
    
    private var bibleSettingsView: some View {
        NavigationStack {
            Form {
                Section("Reading Experience") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Font Size")
                            .font(.subheadline)
                        Slider(value: $fontSize, in: 12...24, step: 1)
                        Text("\(Int(fontSize))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Show Verse Numbers", isOn: $showVerseNumbers)
                    
                    Picker("Reading Theme", selection: $readingTheme) {
                        Text("System").tag("System")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                        Text("Sepia").tag("Sepia")
                        Text("Night").tag("Night")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paragraph Spacing")
                            .font(.subheadline)
                        Picker("Paragraph Spacing", selection: $paragraphSpacing) {
                            Text("Every 3 Verses").tag(3)
                            Text("Every 5 Verses").tag(5)
                            Text("Every 10 Verses").tag(10)
                            Text("No Spacing (Continuous)").tag(0)
                        }
                        .pickerStyle(.menu)
                        Text("Controls how verses are grouped into paragraphs for easier reading.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Translations") {
                    Picker("Primary Translation", selection: $selectedTranslation) {
                        ForEach(translations, id: \.0) { code, name in
                            Text("\(name) (\(code))").tag(code)
                        }
                    }
                    
                    Picker("Parallel Translation", selection: $parallelTranslation) {
                        ForEach(translations, id: \.0) { code, name in
                            Text("\(name) (\(code))").tag(code)
                        }
                    }
                }
            }
            .navigationTitle("Bible Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Verse Detail View
    
    private func verseDetailView(verse: BibleVerse) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(verse.reference)
                        .font(.title)
                        .font(.body.weight(.bold))
                        .foregroundColor(.purple)
                    
                    Text(verse.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                    
                    Text(verse.translation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // Actions
                    HStack(spacing: 20) {
                        Button(action: {
                            toggleBookmark(verse: verse)
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: isBookmarked(verse: verse) ? "bookmark.fill" : "bookmark")
                                    .font(.title3)
                                Text("Bookmark")
                                    .font(.caption)
                            }
                            .foregroundColor(isBookmarked(verse: verse) ? .yellow : .secondary)
                        }
                        
                        Button(action: {
                            verseToHighlight = verse.reference
                            selectedVerse = nil
                            showingHighlightPicker = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "highlighter")
                                    .font(.title3)
                                Text("Highlight")
                                    .font(.caption)
                            }
                            .foregroundColor(.green)
                        }
                        
                        Button(action: {
                            verseToNote = verse.reference
                            noteText = getNote(for: verse.reference)?.noteText ?? ""
                            selectedVerse = nil
                            showingNoteEditor = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "note.text")
                                    .font(.title3)
                                Text("Note")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                        
                        ShareLink(item: "\(verse.reference)\n\n\(verse.text)") {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                Text("Share")
                                    .font(.caption)
                            }
                            .foregroundColor(.purple)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Show note if exists
                    if let note = getNote(for: verse.reference), !note.noteText.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Note")
                                .font(.headline)
                            Text(note.noteText)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedVerse = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Highlight Picker
    
    private func highlightPickerView(verseReference: String) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Highlight Color")
                    .font(.headline)
                    .padding()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(Array(highlightColors.enumerated()), id: \.offset) { index, colorData in
                        Button(action: {
                            toggleHighlight(verseReference: verseReference, colorIndex: index)
                            showingHighlightPicker = false
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(colorData.0)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                                    )
                                Text(colorData.1)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .padding()
                
                Button(action: {
                    removeHighlight(verseReference: verseReference)
                    showingHighlightPicker = false
                }) {
                    Text("Remove Highlight")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingHighlightPicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Note Editor
    
    private func noteEditorView(verseReference: String) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(verseReference)
                    .font(.headline)
                    .foregroundColor(.purple)
                
                TextEditor(text: $noteText)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingNoteEditor = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote(verseReference: verseReference, noteText: noteText)
                        showingNoteEditor = false
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
    
    // MARK: - Organization Views
    
    private var bookmarksListView: some View {
        NavigationStack {
            List {
                if bookmarks.isEmpty {
                    Text("No bookmarked verses yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(bookmarks) { bookmark in
                        NavigationLink {
                            verseDetailView(verse: BibleVerse(
                                reference: bookmark.verseReference,
                                text: bookmark.verseText,
                                translation: bookmark.translation
                            ))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bookmark.verseReference)
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                Text(bookmark.verseText)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete(perform: deleteBookmarks)
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingBookmarks = false
                    }
                }
            }
        }
    }
    
    private var highlightsListView: some View {
        NavigationStack {
            List {
                if highlights.isEmpty {
                    Text("No highlighted verses yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(highlights) { highlight in
                        NavigationLink {
                            verseDetailView(verse: BibleVerse(
                                reference: highlight.verseReference,
                                text: highlight.verseText,
                                translation: highlight.translation
                            ))
                        } label: {
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(highlightColors[highlight.colorIndex].0)
                                    .frame(width: 4, height: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(highlight.verseReference)
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                    Text(highlight.verseText)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteHighlights)
                }
            }
            .navigationTitle("Highlights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingHighlights = false
                    }
                }
            }
        }
    }
    
    private var notesListView: some View {
        NavigationStack {
            List {
                if notes.isEmpty {
                    Text("No notes yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(notes) { note in
                        NavigationLink {
                            noteEditorView(verseReference: note.verseReference)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.verseReference)
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                Text(note.noteText)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete(perform: deleteNotes)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingNotes = false
                    }
                }
            }
        }
    }
    
    private var readingHistoryView: some View {
        NavigationStack {
            List {
                if readingHistory.isEmpty {
                    Text("No reading history yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(readingHistory) { history in
                        Button(action: {
                            selectedBook = history.book
                            selectedChapter = history.chapter
                            showingHistory = false
                            showingChapterView = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(history.book) \(history.chapter)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(history.lastReadDate, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if history.readingProgress > 0 {
                                        ProgressView(value: history.readingProgress)
                                            .tint(.purple)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onDelete(perform: deleteHistory)
                }
            }
            .navigationTitle("Reading History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingHistory = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var themeBackground: some View {
        Group {
            switch readingTheme {
            case "Light":
                Color.white
            case "Dark":
                Color.black
            case "Sepia":
                Color(red: 0.98, green: 0.95, blue: 0.90)
            case "Night":
                Color(red: 0.1, green: 0.1, blue: 0.15)
            default:
                Color(.systemGroupedBackground)
            }
        }
    }
    
    private func isBookmarked(verse: BibleVerse) -> Bool {
        bookmarks.contains { $0.verseReference == verse.reference }
    }
    
    private func isBookmarked(reference: String) -> Bool {
        bookmarks.contains { $0.verseReference == reference }
    }
    
    private func toggleBookmark(verse: BibleVerse) {
        if let existing = bookmarks.first(where: { $0.verseReference == verse.reference }) {
            let bookmarkToDelete = existing
            modelContext.delete(existing)
            try? modelContext.save()
            
            // Sync deletion to Firebase
            Task {
                await FirebaseSyncService.shared.deleteBookmarkedVerse(bookmarkToDelete)
                print("✅ [FIREBASE] Bookmark deletion synced to Firebase")
            }
        } else {
            let bookmark = BookmarkedVerse(
                verseReference: verse.reference,
                verseText: verse.text,
                translation: verse.translation
            )
            modelContext.insert(bookmark)
            try? modelContext.save()
            
            // Sync to Firebase
            Task {
                await FirebaseSyncService.shared.syncBookmarkedVerse(bookmark)
                print("✅ [FIREBASE] Bookmark synced to Firebase")
            }
        }
    }
    
    private func hasHighlight(reference: String) -> Bool {
        highlights.contains { $0.verseReference == reference }
    }
    
    private func highlightColor(for reference: String) -> Color {
        if let highlight = highlights.first(where: { $0.verseReference == reference }) {
            return highlightColors[highlight.colorIndex].0
        }
        return Color.clear
    }
    
    private func toggleHighlight(verseReference: String, colorIndex: Int) {
        if let existing = highlights.first(where: { $0.verseReference == verseReference }) {
            if existing.colorIndex == colorIndex {
                // Remove if same color
                let highlightToDelete = existing
                modelContext.delete(existing)
                try? modelContext.save()
                
                // Sync deletion to Firebase
                Task {
                    await FirebaseSyncService.shared.deleteBibleHighlight(highlightToDelete)
                    print("✅ [FIREBASE] Highlight deletion synced to Firebase")
                }
            } else {
                // Update color
                existing.colorIndex = colorIndex
                try? modelContext.save()
                
                // Sync update to Firebase
                Task {
                    await FirebaseSyncService.shared.syncBibleHighlight(existing)
                    print("✅ [FIREBASE] Highlight update synced to Firebase")
                }
            }
        } else {
            // Add new highlight - fetch verse text asynchronously
            Task {
                do {
                    let verse = try await bibleService.fetchVerse(reference: verseReference)
                    await MainActor.run {
                        let highlight = BibleHighlight(
                            verseReference: verseReference,
                            verseText: verse.text,
                            translation: verse.translation,
                            colorIndex: colorIndex
                        )
                        modelContext.insert(highlight)
                        try? modelContext.save()
                        
                        // Sync to Firebase
                        Task {
                            await FirebaseSyncService.shared.syncBibleHighlight(highlight)
                            print("✅ [FIREBASE] Highlight synced to Firebase")
                        }
                    }
                } catch {
                    // If verse fetch fails, still create highlight with reference only
                    await MainActor.run {
                        let highlight = BibleHighlight(
                            verseReference: verseReference,
                            verseText: "",
                            translation: selectedTranslation,
                            colorIndex: colorIndex
                        )
                        modelContext.insert(highlight)
                        try? modelContext.save()
                        
                        // Sync to Firebase
                        Task {
                            await FirebaseSyncService.shared.syncBibleHighlight(highlight)
                            print("✅ [FIREBASE] Highlight synced to Firebase")
                        }
                    }
                }
            }
        }
    }
    
    private func removeHighlight(verseReference: String) {
        if let existing = highlights.first(where: { $0.verseReference == verseReference }) {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }
    
    private func hasNote(reference: String) -> Bool {
        notes.contains { $0.verseReference == reference }
    }
    
    private func getNote(for reference: String) -> BibleNote? {
        notes.first { $0.verseReference == reference }
    }
    
    private func saveNote(verseReference: String, noteText: String) {
        if let existing = notes.first(where: { $0.verseReference == verseReference }) {
            existing.noteText = noteText
            existing.updatedAt = Date()
            try? modelContext.save()
            
            // Sync update to Firebase
            Task {
                await FirebaseSyncService.shared.syncBibleNote(existing)
                print("✅ [FIREBASE] Bible note update synced to Firebase")
            }
        } else {
            Task {
                if let verse = try? await bibleService.fetchVerse(reference: verseReference) {
                    let note = BibleNote(
                        verseReference: verseReference,
                        verseText: verse.text,
                        translation: verse.translation,
                        noteText: noteText
                    )
                    await MainActor.run {
                        modelContext.insert(note)
                        try? modelContext.save()
                        
                        // Sync to Firebase
                        Task {
                            await FirebaseSyncService.shared.syncBibleNote(note)
                            print("✅ [FIREBASE] Bible note synced to Firebase")
                        }
                    }
                }
            }
        }
    }
    
    private func saveReadingProgress(book: String, chapter: Int) {
        if let existing = readingHistory.first(where: { $0.book == book && $0.chapter == chapter }) {
            existing.lastReadDate = Date()
        } else {
            let history = BibleReadingHistory(book: book, chapter: chapter, translation: selectedTranslation)
            modelContext.insert(history)
        }
        try? modelContext.save()
    }
    
    // Save range reading progress (e.g., "Psalm 1-10" -> last chapter read: 4)
    private func saveRangeProgress(book: String, startChapter: Int, endChapter: Int, currentChapter: Int) {
        let rangeKey = "\(book):\(startChapter)-\(endChapter)"
        var progress: [String: Int] = [:]
        
        // Load existing progress - handle corrupted or invalid data
        if !rangeProgressData.isEmpty {
            if let existingData = try? JSONDecoder().decode([String: Int].self, from: rangeProgressData) {
                progress = existingData
            } else {
                // Data is corrupted, reset it
                rangeProgressData = Data()
            }
        }
        
        // Save current chapter (only if it's within the range)
        if currentChapter >= startChapter && currentChapter <= endChapter {
            progress[rangeKey] = currentChapter
        }
        
        // Save back to AppStorage
        if let data = try? JSONEncoder().encode(progress) {
            rangeProgressData = data
        }
    }
    
    // Get saved range reading progress
    private func getRangeProgress(book: String, startChapter: Int, endChapter: Int) -> Int? {
        let rangeKey = "\(book):\(startChapter)-\(endChapter)"
        
        // Safely decode - handle corrupted data
        guard !rangeProgressData.isEmpty else { return nil }
        
        if let progress = try? JSONDecoder().decode([String: Int].self, from: rangeProgressData),
           let savedChapter = progress[rangeKey],
           savedChapter >= startChapter && savedChapter <= endChapter {
            return savedChapter
        }
        
        return nil
    }
    
    private func loadRecentSearches() {
        // Safely load recent searches - handle case where it might be stored as String
        if let array = UserDefaults.standard.array(forKey: "bibleRecentSearches") as? [String] {
            recentSearches = array
        } else if let string = UserDefaults.standard.string(forKey: "bibleRecentSearches") {
            // If it was stored as a String (old format), convert to array
            recentSearches = [string]
            // Clean up the old format
            UserDefaults.standard.removeObject(forKey: "bibleRecentSearches")
        } else {
            recentSearches = []
        }
    }
    
    private func saveRecentSearch(_ search: String) {
        var searches = recentSearches
        searches.removeAll { $0 == search }
        searches.insert(search, at: 0)
        recentSearches = Array(searches.prefix(10))
        UserDefaults.standard.set(recentSearches, forKey: "bibleRecentSearches")
    }
    
    private func deleteBookmarks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bookmarks[index])
        }
        try? modelContext.save()
    }
    
    private func deleteHighlights(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(highlights[index])
        }
        try? modelContext.save()
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(notes[index])
        }
        try? modelContext.save()
    }
    
    private func deleteHistory(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(readingHistory[index])
        }
        try? modelContext.save()
    }
    
    // MARK: - Chapter Loading
    
    private func loadChapter(book: String, chapter: Int, useCache: Bool = true) {
        let cacheKey = ChapterCacheKey(book: book, chapter: chapter, translation: selectedTranslation)
        let chapterKey = ChapterKey(book: book, chapter: chapter)
        
        // Check cache first for instant display
        if useCache, let cachedVerses = chapterCache[cacheKey] {
            // Update both the shared state (for single chapter view) and the map (for range view)
            chapterVerses = cachedVerses
            chapterVersesMap[chapterKey] = cachedVerses
            isLoadingChapter = false
            chapterError = nil
            chapterLoadingMap[chapterKey] = false
            chapterErrorMap[chapterKey] = nil
            
            // Only refresh in background if not already in progress
            if !inProgressRequests.contains(cacheKey) {
                Task {
                    await refreshChapterInBackground(book: book, chapter: chapter, cacheKey: cacheKey)
                }
            }
            return
        }
        
        // Prevent duplicate requests for the same chapter
        // Since we're in a View context (@MainActor), state access is already thread-safe
        if inProgressRequests.contains(cacheKey) {
            print("⚠️ Request already in progress for \(book) \(chapter) (\(selectedTranslation)), skipping duplicate")
            return
        }
        
        // Mark request as in progress
        inProgressRequests.insert(cacheKey)
        print("✅ Starting request for \(book) \(chapter) (\(selectedTranslation)) - total in progress: \(inProgressRequests.count)")
        
        // Update loading state for both single and range views
        isLoadingChapter = true
        chapterError = nil
        chapterLoadingMap[chapterKey] = true
        chapterErrorMap[chapterKey] = nil
        
        // If we have cached data from a different translation, show it while loading
        // Check both the shared state and the per-chapter map
        if chapterVerses.isEmpty && chapterVersesMap[chapterKey] == nil {
            // Try to find any cached version of this chapter
            for (key, cached) in chapterCache where key.book == book && key.chapter == chapter {
                chapterVerses = cached
                chapterVersesMap[chapterKey] = cached
                break
            }
        }
        
        // Format reference for bible-api.com (e.g., "John 3" or "John 3:1-21")
        let reference = "\(book) \(chapter)"
        
        Task {
            do {
                // Use bible-api.com to fetch the chapter with selected translation
                let passage = try await fetchChapterFromAPI(reference: reference, translation: selectedTranslation)
                await MainActor.run {
                    // Store verses with their verse numbers from the API
                    chapterVerses = passage.versesWithNumbers
                    chapterVersesMap[chapterKey] = passage.versesWithNumbers
                    
                    // Cache the result
                    chapterCache[cacheKey] = passage.versesWithNumbers
                    
                    // Limit cache size to prevent memory issues (keep last 20 chapters)
                    if chapterCache.count > 20 {
                        if let oldestKey = chapterCache.keys.first {
                            chapterCache.removeValue(forKey: oldestKey)
                        }
                    }
                    
                    isLoadingChapter = false
                    chapterLoadingMap[chapterKey] = false
                    chapterErrorMap[chapterKey] = nil
                    
                    // Remove from in-progress set
                    inProgressRequests.remove(cacheKey)
                    
                    // Preload adjacent chapters in background
                    preloadAdjacentChapters(book: book, chapter: chapter)
                }
            } catch {
                await MainActor.run {
                    let errorMessage: String
                    // Provide more user-friendly error messages
                    if let bibleError = error as? BibleServiceError {
                        errorMessage = bibleError.errorDescription ?? "Unable to load chapter"
                    } else if let urlError = error as? URLError {
                        // Handle specific URL errors
                        switch urlError.code {
                        case .notConnectedToInternet, .networkConnectionLost:
                            errorMessage = "No internet connection. Please check your network and try again."
                        case .timedOut:
                            errorMessage = "Request timed out. Please try again."
                        case .cannotFindHost, .cannotConnectToHost:
                            errorMessage = "Cannot connect to Bible service. Please check your internet connection."
                        default:
                            errorMessage = "Network error: \(urlError.localizedDescription)"
                        }
                    } else if error is DecodingError {
                        errorMessage = "Unable to parse Bible text. Please try again."
                    } else {
                        let errorMsg = error.localizedDescription
                        errorMessage = errorMsg.isEmpty ? "Unable to load chapter. Please check your internet connection and try again." : errorMsg
                    }
                    
                    chapterError = errorMessage
                    chapterErrorMap[chapterKey] = errorMessage
                    isLoadingChapter = false
                    chapterLoadingMap[chapterKey] = false
                    
                    // Remove from in-progress set
                    inProgressRequests.remove(cacheKey)
                }
            }
        }
    }
    
    private func refreshChapterInBackground(book: String, chapter: Int, cacheKey: ChapterCacheKey) async {
        // Skip if already in progress
        if inProgressRequests.contains(cacheKey) {
            return
        }
        
        inProgressRequests.insert(cacheKey)
        defer {
            inProgressRequests.remove(cacheKey)
        }
        
        let reference = "\(book) \(chapter)"
        do {
            let passage = try await fetchChapterFromAPI(reference: reference, translation: selectedTranslation)
            await MainActor.run {
                // Update cache with fresh data
                chapterCache[cacheKey] = passage.versesWithNumbers
                // Only update UI if this is still the current chapter
                if chapterVerses.first?.verse.reference.contains("\(book) \(chapter):") == true {
                    chapterVerses = passage.versesWithNumbers
                }
            }
        } catch {
            // Silently fail background refresh
            print("Background refresh failed for \(book) \(chapter): \(error.localizedDescription)")
        }
    }
    
    private func preloadAdjacentChapters(book: String, chapter: Int) {
        // Preload next chapter in background (only if not already in progress)
        let nextChapter = chapter + 1
        let nextCacheKey = ChapterCacheKey(book: book, chapter: nextChapter, translation: selectedTranslation)
        let translation = selectedTranslation
        
        if chapterCache[nextCacheKey] == nil && !inProgressRequests.contains(nextCacheKey) {
            inProgressRequests.insert(nextCacheKey)
            Task.detached(priority: .background) {
                defer {
                    Task { @MainActor in
                        self.inProgressRequests.remove(nextCacheKey)
                    }
                }
                let reference = "\(book) \(nextChapter)"
                do {
                    let passage = try await self.fetchChapterFromAPI(reference: reference, translation: translation)
                    await MainActor.run {
                        self.chapterCache[nextCacheKey] = passage.versesWithNumbers
                    }
                } catch {
                    // Silently fail preload
                }
            }
        }
        
        // Preload previous chapter if it exists (only if not already in progress)
        if chapter > 1 {
            let prevChapter = chapter - 1
            let prevCacheKey = ChapterCacheKey(book: book, chapter: prevChapter, translation: selectedTranslation)
            
            if chapterCache[prevCacheKey] == nil && !inProgressRequests.contains(prevCacheKey) {
                inProgressRequests.insert(prevCacheKey)
                Task.detached(priority: .background) {
                    defer {
                        Task { @MainActor in
                            self.inProgressRequests.remove(prevCacheKey)
                        }
                    }
                    let reference = "\(book) \(prevChapter)"
                    do {
                        let passage = try await self.fetchChapterFromAPI(reference: reference, translation: translation)
                        await MainActor.run {
                            self.chapterCache[prevCacheKey] = passage.versesWithNumbers
                        }
                    } catch {
                        // Silently fail preload
                    }
                }
            }
        }
    }
    
    private func fetchChapterFromAPI(reference: String, translation: String? = nil, fallbackAttempted: Bool = false) async throws -> BibleAPIPassage {
        let translationToUse = translation ?? selectedTranslation
        let bibleVersion = BibleVersion(rawValue: translationToUse) ?? .niv
        let translationCode = bibleVersion.bibleAPIComTranslationCode
        
        // Normalize book names for API (e.g., "Psalm" -> "Psalms")
        let bookNameMap: [String: String] = [
            "Psalm": "Psalms",
            "psalm": "psalms"
        ]
        
        // Split reference into book and chapter/verse
        let parts = reference.split(separator: " ", maxSplits: 1)
        var normalizedReference = reference
        if parts.count >= 1 {
            let bookName = String(parts[0])
            if let normalizedBook = bookNameMap[bookName] {
                normalizedReference = reference.replacingOccurrences(of: bookName, with: normalizedBook)
            }
        }
        
        // Format reference for bible-api.com: "Genesis 1" -> "genesis+1"
        // Convert to lowercase and replace spaces with +
        let formattedReference = normalizedReference.lowercased().replacingOccurrences(of: " ", with: "+")
        
        // bible-api.com format: https://bible-api.com/genesis+1?translation=kjv
        let urlString = "https://bible-api.com/\(formattedReference)?translation=\(translationCode)"
        
        print("📖 Fetching Bible chapter from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw BibleServiceError.invalidURL
        }
        
        // Create URLSession configuration with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📖 HTTP Status: \(httpResponse.statusCode) for \(urlString)")
                if httpResponse.statusCode != 200 {
                    // Handle rate limiting (429) - don't fallback, just throw error
                    if httpResponse.statusCode == 429 {
                        print("⚠️ Rate limited (429) - too many requests. Please try again later.")
                        throw BibleServiceError.networkError
                    }
                    // If translation-specific request fails, try default (web) as fallback (only once)
                    if translationCode != "web" && !fallbackAttempted {
                        print("⚠️ Translation \(translationCode) failed (status: \(httpResponse.statusCode)), trying default WEB...")
                        return try await fetchChapterFromAPI(reference: reference, translation: "WEB", fallbackAttempted: true)
                    }
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    throw BibleServiceError.networkError
                }
            }
            
            // Check if the response contains an error (bible-api.com returns {"error":"..."} for invalid translations)
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = jsonObject["error"] as? String {
                print("⚠️ API Error: \(errorMessage)")
                // If translation-specific request fails, try default (web) as fallback (only once)
                if translationCode != "web" && !fallbackAttempted {
                    print("⚠️ Translation \(translationCode) not found, trying default WEB...")
                    return try await fetchChapterFromAPI(reference: reference, translation: "WEB", fallbackAttempted: true)
                }
                throw BibleServiceError.networkError
            }
            
            // Try to parse as JSON first to see the structure
            // Parse the response - bible-api.com returns a simpler structure
            let decoder = JSONDecoder()
            let apiResponse: BibleService.BibleAPIResponse = try decoder.decode(BibleService.BibleAPIResponse.self, from: data)
            print("✅ Successfully parsed \(apiResponse.verses.count) verses from \(apiResponse.reference)")
            
            // Convert API response to BiblePassage
            // The reference from API is like "Genesis 1", we need to create "Genesis 1:1", "Genesis 1:2", etc.
            let bookName = apiResponse.reference.components(separatedBy: " ").dropLast().joined(separator: " ")
            let verses = apiResponse.verses.map { apiVerse in
                // Create proper reference like "Genesis 1:1"
                let verseRef = "\(bookName) \(apiVerse.chapter):\(apiVerse.verse)"
                return BibleVerse(
                    reference: verseRef,
                    text: apiVerse.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    translation: apiResponse.translation_id?.uppercased() ?? selectedTranslation
                )
            }
            
            // Create verses with their numbers for proper display
            let versesWithNumbers = apiResponse.verses.enumerated().map { index, apiVerse in
                let verseRef = "\(bookName) \(apiVerse.chapter):\(apiVerse.verse)"
                let verse = BibleVerse(
                    reference: verseRef,
                    text: apiVerse.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    translation: apiResponse.translation_id?.uppercased() ?? selectedTranslation
                )
                return (verse: verse, number: apiVerse.verse)
            }
            
            return BibleAPIPassage(
                reference: apiResponse.reference,
                verses: verses,
                versesWithNumbers: versesWithNumbers,
                text: apiResponse.text
            )
        } catch {
            // If decoding fails, try to get error details
            // Note: data might not be in scope if network error occurred
            if case let decodingError as DecodingError = error {
                print("❌ Decoding error: \(decodingError)")
                // If it's a decoding error and we haven't tried the default translation yet, try WEB
                if translationCode != "web" {
                    print("⚠️ Decoding failed for \(translationCode), trying default WEB...")
                    return try await fetchChapterFromAPI(reference: reference, translation: "WEB")
                }
            } else if let urlError = error as? URLError {
                print("❌ URL Error: \(urlError.localizedDescription) (code: \(urlError.code.rawValue))")
            } else {
                print("❌ Error fetching chapter: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    private func extractVerseNumber(from reference: String) -> Int? {
        // Extract verse number from reference like "John 3:16" -> 16
        let components = reference.split(separator: ":")
        if components.count >= 2 {
            let versePart = String(components[1])
            // Handle verse ranges like "16-17" by taking the first number
            let verseNum = versePart.split(separator: "-").first ?? Substring(versePart)
            return Int(verseNum.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
    
    private func buildParagraphView(from verseGroup: [(verse: BibleVerse, number: Int)]) -> some View {
        // Build a flowing paragraph where verses are separated by spaces, not line breaks
        Text(buildParagraphText(from: verseGroup))
            .font(.system(size: fontSize))
            .foregroundColor(.primary)
            .lineSpacing(6) // Line spacing for readability
            .lineLimit(nil) // Allow unlimited lines for natural flow
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 4) // Add vertical padding for better paragraph separation
            .background(
                // Check if any verse in this paragraph is highlighted
                verseGroup.contains { hasHighlight(reference: $0.verse.reference) } ?
                highlightColor(for: verseGroup.first { hasHighlight(reference: $0.verse.reference) }?.verse.reference ?? "").opacity(0.15) :
                Color.clear
            )
    }
    
    private func buildParagraphText(from verseGroup: [(verse: BibleVerse, number: Int)]) -> AttributedString {
        var attributedString = AttributedString()
        
        for (index, verseData) in verseGroup.enumerated() {
            // Clean up verse text: replace newlines with spaces and normalize whitespace
            var verseText = verseData.verse.text
                .replacingOccurrences(of: "\n", with: " ") // Replace newlines with spaces
                .replacingOccurrences(of: "\r", with: " ") // Replace carriage returns
                .replacingOccurrences(of: "  ", with: " ") // Replace double spaces with single
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove trailing commas/spaces that might cause awkward breaks
            verseText = verseText.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            
            if showVerseNumbers {
                // Add verse number as inline element with better spacing
                var verseNumber = AttributedString("\(verseData.number) ")
                verseNumber.font = .system(size: fontSize - 2, weight: .bold)
                verseNumber.foregroundColor = hasHighlight(reference: verseData.verse.reference) ? .white : .purple
                verseNumber.baselineOffset = 2 // Slightly superscript for better appearance
                attributedString.append(verseNumber)
            }
            
            // Add verse text
            var text = AttributedString(verseText)
            text.font = .system(size: fontSize)
            text.foregroundColor = .primary
            attributedString.append(text)
            
            // Add space between verses (not after the last verse in the paragraph)
            // Use a single space for natural flow
            if index < verseGroup.count - 1 {
                var space = AttributedString(" ")
                space.font = .system(size: fontSize)
                attributedString.append(space)
            }
        }
        
        return attributedString
    }
    
    private func buildFlowingText(from verses: [(verse: BibleVerse, number: Int)]) -> AttributedString {
        var attributedString = AttributedString()
        
        for (index, verseData) in verses.enumerated() {
            let verseText = verseData.verse.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if showVerseNumbers {
                // Add verse number
                var verseNumber = AttributedString("\(verseData.number) ")
                verseNumber.font = .system(size: fontSize - 2, weight: .bold)
                verseNumber.foregroundColor = .purple
                attributedString.append(verseNumber)
            }
            
            // Add verse text
            var text = AttributedString(verseText)
            text.font = .system(size: fontSize)
            text.foregroundColor = .primary
            attributedString.append(text)
            
            // Add spacing after verse
            if index < verses.count - 1 {
                // Add paragraph break after every 5 verses
                let verseIndex = index + 1 // 1-based index
                if verseIndex % 5 == 0 {
                    // Add newline for paragraph break
                    var paragraphBreak = AttributedString("\n\n")
                    paragraphBreak.font = .system(size: fontSize)
                    attributedString.append(paragraphBreak)
                } else {
                    // Regular single space
                    var space = AttributedString(" ")
                    space.font = .system(size: fontSize)
                    attributedString.append(space)
                }
            }
        }
        
        return attributedString
    }
}

// MARK: - API Response Models

struct BibleAPIPassage {
    let reference: String
    let verses: [BibleVerse]
    let versesWithNumbers: [(verse: BibleVerse, number: Int)]
    let text: String
}

// MARK: - Supporting Views

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PopularVerseRow: View {
    let reference: String
    @ObservedObject var bibleService: BibleService
    let translation: String
    let onTap: (BibleVerse) -> Void
    @State private var verse: BibleVerse? = nil
    @State private var isLoading = false
    
    var body: some View {
        Button(action: {
            if let verse = verse {
                onTap(verse)
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reference)
                        .font(.subheadline)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                    if let verse = verse {
                        Text(verse.text)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .onAppear {
            loadVerse()
        }
    }
    
    private func loadVerse() {
        isLoading = true
        Task {
            do {
                let fetchedVerse = try await bibleService.fetchVerse(reference: reference)
                await MainActor.run {
                    verse = fetchedVerse
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct BibleSearchResultsView: View {
    let searchText: String
    @ObservedObject var bibleService: BibleService
    let translation: String
    let filter: BibleView.SearchFilter
    let onVerseTap: (BibleVerse) -> Void
    @State private var results: [BibleVerse] = []
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No verses found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try searching for a book, chapter, or keyword")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if results.isEmpty {
                Text("Enter a search term to find Bible verses")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { verse in
                    Button(action: {
                        onVerseTap(verse)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verse.reference)
                                .font(.headline)
                                .foregroundColor(.purple)
                            Text(verse.text)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .onAppear {
            performSearch()
        }
        .onChange(of: searchText) { _, _ in
            performSearch()
        }
        .onChange(of: translation) { _, _ in
            // Re-search when translation changes
            if !searchText.isEmpty {
                performSearch()
            }
        }
    }
    
    func performSearch() {
        guard !searchText.isEmpty else {
            results = []
            return
        }
        
        isLoading = true
        Task {
            let allVerses = bibleService.getAllLocalVerses()
            let searchLower = searchText.lowercased()
            
            // Filter by translation first (if available in local database)
            // Note: Local database may have limited translations, so we include all if translation doesn't match
            var filtered = allVerses.filter { verse in
                // Match translation if available, or include all if translation doesn't match
                verse.translation.uppercased() == translation.uppercased() || verse.translation.isEmpty || verse.translation.uppercased() == "WEB"
            }
            
            // Then filter by search text
            filtered = filtered.filter { verse in
                verse.reference.lowercased().contains(searchLower) ||
                verse.text.lowercased().contains(searchLower)
            }
            
            // Apply filter
            switch filter {
            case .oldTestament:
                filtered = filtered.filter { verse in
                    BibleBooks.oldTestament.contains { $0.name == extractBook(from: verse.reference) }
                }
            case .newTestament:
                filtered = filtered.filter { verse in
                    BibleBooks.newTestament.contains { $0.name == extractBook(from: verse.reference) }
                }
            case .book:
                filtered = filtered.filter { verse in
                    extractBook(from: verse.reference).lowercased().contains(searchLower)
                }
            default:
                break
            }
            
            await MainActor.run {
                results = Array(filtered.prefix(50))
                isLoading = false
            }
        }
    }
    
    private func extractBook(from reference: String) -> String {
        // Simple extraction - in production would be more robust
        let parts = reference.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0]) + " " + String(parts[1])
        }
        return String(parts.first ?? "")
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .focused($isFocused)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
