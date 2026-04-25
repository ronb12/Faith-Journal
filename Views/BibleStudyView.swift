//
//  BibleStudyView.swift
//  Faith Journal
//
//  Main view for browsing and studying Bible study topics
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct BibleStudyView: View {
    // Use regular property for singleton, not @StateObject
    private let studyService = BibleStudyService.shared
    @Query(sort: [SortDescriptor(\BibleStudyTopic.lastViewedDate, order: .reverse)]) var storedTopics: [BibleStudyTopic]
    @State private var searchText = ""
    @State private var selectedCategory: BibleStudyTopic.TopicCategory? = nil
    @State private var selectedTopic: BibleStudyTopic?
    @State private var filterMode: FilterMode = .all
    @State private var showingProgress = false
    @Environment(\.modelContext) private var modelContext
    
    /// When in a live session, host syncs which topic is shown; participant receives day (1-365) here.
    var sessionId: UUID? = nil
    var isHost: Bool = false
    var syncedDayOfYear: Int? = nil
    
    enum FilterMode: String, CaseIterable {
        case all = "All"
        case favorites = "Favorites"
        case completed = "Completed"
        case recent = "Recent"
        
        var icon: String {
            switch self {
            case .all: return "book.fill"
            case .favorites: return "heart.fill"
            case .completed: return "checkmark.circle.fill"
            case .recent: return "clock.fill"
            }
        }
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Progress Stats Card
                        progressStatsCard
                        // Category Filter
                        categoryFilter
                        // Filter Mode (All, Favorites, Completed, Recent)
                        filterModeBar
                        // Daily Topic Card
                        if let dailyTopic = studyService.dailyTopic, filterMode == .all {
                            DailyTopicCard(topic: dailyTopic) {
                                selectedTopic = dailyTopic
                                studyService.markAsViewed(dailyTopic)
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("❌ Error saving daily topic view: \(error.localizedDescription)")
                                    ErrorHandler.shared.handle(.saveFailed)
                                }
                            }
                            .padding()
                        }
                        // Topics List - scrollable to show all 365 topics
                        if filteredTopics.isEmpty {
                            emptyStateView
                                .frame(height: 400)
                        } else {
                            topicsScrollView
                        }
                    }
                }
                .navigationTitle("Bible Study")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
                .searchable(text: $searchText, prompt: "Search topics, verses, questions...")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: { showingProgress = true }) {
                            Image(systemName: "chart.bar.fill")
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        Menu {
                            Button(action: { filterMode = .all }) {
                                Label("All Topics", systemImage: "book.fill")
                            }
                            Button(action: { filterMode = .favorites }) {
                                Label("Favorites", systemImage: "heart.fill")
                            }
                            Button(action: { filterMode = .completed }) {
                                Label("Completed", systemImage: "checkmark.circle.fill")
                            }
                            Button(action: { filterMode = .recent }) {
                                Label("Recent", systemImage: "clock.fill")
                            }
                            Divider()
                            Button(action: { selectedCategory = nil }) {
                                Label("Clear Filters", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(item: $selectedTopic) { topic in
                    TopicDetailView(topic: topic)
                        .macOSSheetFrameLarge()
                }
                .sheet(isPresented: $showingProgress) {
                    BibleStudyProgressView()
                        .macOSSheetFrameStandard()
                }
                .onChange(of: syncedDayOfYear) { _, day in
                    guard let day = day, day >= 1, day <= 365 else { return }
                    selectedTopic = studyService.getTopicForDay(day)
                }
                .onChange(of: selectedTopic) { _, topic in
                    guard isHost, let sessionId = sessionId, let topic = topic,
                          let day = studyService.topicDayOfYear(for: topic) else { return }
                    Task {
                        await FirebaseSyncService.shared.setSessionPresentation(sessionId: sessionId, type: "bibleStudy", pdfURL: nil, imageURL: nil, bibleStudyDayOfYear: day)
                    }
                }
                .onAppear {
                    studyService.setStoredTopics(storedTopics)
                }
            }
        } else {
            Text("Bible Study is only available on iOS 17+")
        }
    }
    
    private var progressStatsCard: some View {
        let stats = studyService.getProgressStats()
        
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stats.completed)/\(stats.total)")
                    .font(.title2)
                    .font(.body.weight(.bold))
                    .foregroundColor(.purple)
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stats.favorites)")
                    .font(.title2)
                    .font(.body.weight(.bold))
                    .foregroundColor(.purple)
                Text("Favorites")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(stats.percentComplete))%")
                    .font(.title2)
                    .font(.body.weight(.bold))
                    .foregroundColor(.purple)
                Text("Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showingProgress = true }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.purple)
                    .font(.headline)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
        .contentShape(Rectangle()) // Makes entire card tappable
        .onTapGesture {
            showingProgress = true
        }
    }
    
    private var filterModeBar: some View {
        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
            HStack(spacing: 12) {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    FilterModeChip(
                        mode: mode,
                        isSelected: filterMode == mode,
                        action: { filterMode = mode }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.platformSystemGray6)
    }
    
    private var filteredTopics: [BibleStudyTopic] {
        var topics: [BibleStudyTopic] = []
        
        // Apply filter mode
        switch filterMode {
        case .all:
            topics = studyService.getAllTopics()
        case .favorites:
            topics = studyService.getFavoriteTopics()
        case .completed:
            topics = studyService.getCompletedTopics()
        case .recent:
            topics = studyService.getRecentTopics()
        }
        
        // Filter by category
        if let category = selectedCategory {
            topics = topics.filter { $0.category == category }
        }
        
        // Enhanced search - includes verses, questions, application points
        if !searchText.isEmpty {
            topics = studyService.searchTopics(query: searchText).filter { topic in
                topics.contains { $0.id == topic.id || $0.title == topic.title }
            }
        }
        
        return topics
    }
    
    private var categoryFilter: some View {
        #if os(macOS)
        HStack {
            Text("Category:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Picker("Category", selection: $selectedCategory) {
                Text("All").tag(nil as BibleStudyTopic.TopicCategory?)
                ForEach(BibleStudyTopic.TopicCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category as BibleStudyTopic.TopicCategory?)
                }
            }
            .pickerStyle(.menu)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.platformSystemGray6)
        #else
        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
            HStack(spacing: 12) {
                BibleStudyCategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                ForEach(BibleStudyTopic.TopicCategory.allCases, id: \.self) { category in
                    BibleStudyCategoryChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.platformSystemGray6)
        #endif
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Topics Found")
                .font(.title2)
                .font(.body.weight(.semibold))
            
            Text("Try a different search, filter, or category")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var topicsList: some View {
        List {
            // Show count of topics
            Section {
                Text("\(filteredTopics.count) topics available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(Array(filteredTopics.enumerated()), id: \.element.id) { index, topic in
                TopicRow(topic: topic) {
                    selectedTopic = topic
                    studyService.markAsViewed(topic)
                    topic.lastViewedDate = Date()
                    do {
                        try modelContext.save()
                    } catch {
                        print("❌ Error saving topic view: \(error.localizedDescription)")
                        ErrorHandler.shared.handle(.saveFailed)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var topicsScrollView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Enhanced topic count header
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "book.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(filteredTopics.count) Topics Available")
                        .font(.subheadline)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    if filteredTopics.count == 365 {
                        Text("Complete collection for daily study")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Filtered from 365 total topics")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Badge
                if filteredTopics.count == 365 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("All")
                            .font(.caption2)
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Topics list
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredTopics.enumerated()), id: \.element.id) { index, topic in
                    Button(action: {
                        selectedTopic = topic
                        studyService.markAsViewed(topic)
                        topic.lastViewedDate = Date()
                        do {
                            try modelContext.save()
                        } catch {
                            print("❌ Error saving topic view: \(error.localizedDescription)")
                            ErrorHandler.shared.handle(.saveFailed)
                        }
                    }) {
                        TopicRow(topic: topic) {
                            selectedTopic = topic
                            studyService.markAsViewed(topic)
                            topic.lastViewedDate = Date()
                            do {
                                try modelContext.save()
                            } catch {
                                print("❌ Error saving topic view: \(error.localizedDescription)")
                                ErrorHandler.shared.handle(.saveFailed)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.platformSystemBackground)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if index < filteredTopics.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color.platformSystemBackground)
        }
    }
}

@available(iOS 17.0, *)
struct FilterModeChip: View {
    let mode: BibleStudyView.FilterMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.caption)
                Text(mode.rawValue)
                    .font(.subheadline)
                    .font(.body.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.purple : Color.platformSystemGray5)
            )
        }
    }
}

struct BibleStudyCategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .font(.body.weight(.medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.purple : Color.platformSystemGray5)
                )
        }
    }
}

@available(iOS 17.0, *)
struct DailyTopicCard: View {
    let topic: BibleStudyTopic
    let onTap: () -> Void
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                Text("Today's Topic")
                    .font(.headline)
                    .font(.body.weight(.semibold))
                Spacer()
            }
            
            Text(topic.title)
                .font(.title3)
                .font(.body.weight(.bold))
            
            Text(topic.topicDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(topic.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(5)
                
                Spacer()
                
                Button(action: {
                    onTap()
                    showingDetail = true
                }) {
                    Text("Study Now")
                        .font(.subheadline)
                        .font(.body.weight(.medium))
                        .foregroundColor(.purple)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}
// ...existing code...

@available(iOS 17.0, *)
struct TopicDetailView: View {
    let topic: BibleStudyTopic
    /// When true, shown as the live-session Bible study presentation (same screen as main Bible Study).
    var isPresentationMode: Bool = false
    /// Host-only: called when "Stop presenting" is tapped.
    var onStopPresenting: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Use regular property for singleton, not @StateObject
    private let studyService = BibleStudyService.shared
    @State private var notes = ""
    @State private var showingAnswerEditor = false
    @State private var selectedQuestionIndex: Int = 0
    @State private var editingAnswer: String = ""
    @State private var showingRelatedTopics = false
    @State private var relatedTopics: [BibleStudyTopic] = []
    @State private var isEditingPrompt = false // true for discussion prompt, false for study question
    @State private var currentQuestionOrPrompt: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(topic.title)
                                .font(.largeTitle)
                                .font(.body.weight(.bold))
                            
                            Spacer()
                            
                            Button(action: {
                                studyService.toggleFavorite(topic)
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("❌ Error toggling favorite: \(error.localizedDescription)")
                                    ErrorHandler.shared.handle(.saveFailed)
                                }
                            }) {
                                Image(systemName: topic.isFavorite ? "heart.fill" : "heart")
                                    .foregroundColor(topic.isFavorite ? .red : .secondary)
                                    .font(.title2)
                            }
                        }
                        
                        Text(topic.topicDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(topic.category.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Button(action: {
                                studyService.toggleCompletion(topic)
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("❌ Error toggling completion: \(error.localizedDescription)")
                                    ErrorHandler.shared.handle(.saveFailed)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: topic.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                                        .foregroundColor(topic.isCompleted ? .green : .secondary)
                                    Text(topic.isCompleted ? "Completed" : "Mark Complete")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.bottom)
                    
                    Divider()
                    
                    // Key Verses
                    if !topic.keyVerses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Key Verses")
                                .font(.headline)
                                .font(.body.weight(.semibold))
                            
                            ForEach(Array(topic.keyVerses.enumerated()), id: \.offset) { index, reference in
                                VerseCard(
                                    reference: reference,
                                    text: index < topic.verseTexts.count ? topic.verseTexts[index] : "",
                                    isPresentationMode: isPresentationMode
                                )
                            }
                        }
                    }
                    
                    // Study Questions with Answers
                    if !topic.studyQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Study Questions")
                                    .font(.headline)
                                    .font(.body.weight(.semibold))
                                
                                Spacer()
                                
                                Text("\(topic.studyQuestions.filter { !studyService.getQuestionAnswer(topic, questionIndex: topic.studyQuestions.firstIndex(of: $0) ?? 0).isEmpty }.count)/\(topic.studyQuestions.count) answered")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            ForEach(Array(topic.studyQuestions.enumerated()), id: \.offset) { index, question in
                                QuestionAnswerCard(
                                    question: question,
                                    number: index + 1,
                                    answer: studyService.getQuestionAnswer(topic, questionIndex: index),
                                    onTap: {
                                        selectedQuestionIndex = index
                                        editingAnswer = studyService.getQuestionAnswer(topic, questionIndex: index)
                                        isEditingPrompt = false
                                        showingAnswerEditor = true
                                    }
                                )
                            }
                        }
                    }
                    
                    // Discussion Prompts with Answers
                    if !topic.discussionPrompts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Discussion Prompts")
                                    .font(.headline)
                                    .font(.body.weight(.semibold))
                                
                                Spacer()
                                
                                Text("\(topic.discussionPrompts.filter { !studyService.getDiscussionAnswer(topic, promptIndex: topic.discussionPrompts.firstIndex(of: $0) ?? 0).isEmpty }.count)/\(topic.discussionPrompts.count) answered")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            ForEach(Array(topic.discussionPrompts.enumerated()), id: \.offset) { index, prompt in
                                DiscussionPromptAnswerCard(
                                    prompt: prompt,
                                    number: index + 1,
                                    answer: studyService.getDiscussionAnswer(topic, promptIndex: index),
                                    onTap: {
                                        selectedQuestionIndex = index
                                        editingAnswer = studyService.getDiscussionAnswer(topic, promptIndex: index)
                                        showingAnswerEditor = true
                                        isEditingPrompt = true
                                    }
                                )
                            }
                        }
                    }
                    
                    // Application Points (Key Takeaways)
                    if !topic.applicationPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Key Takeaways")
                                .font(.headline)
                                .font(.body.weight(.semibold))
                            
                            ForEach(Array(topic.applicationPoints.enumerated()), id: \.offset) { index, point in
                                ApplicationCard(point: point, number: index + 1)
                            }
                        }
                    }
                    
                    // Related Topics
                    if !relatedTopics.isEmpty {
                        #if os(macOS)
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(relatedTopics, id: \.id) { relatedTopic in
                                    RelatedTopicCard(topic: relatedTopic)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.top, 4)
                        } label: {
                            Text("Related Topics (\(relatedTopics.count))")
                                .font(.headline)
                                .font(.body.weight(.semibold))
                        }
                        #else
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Related Topics")
                                .font(.headline)
                                .font(.body.weight(.semibold))
                            
                            ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                                HStack(spacing: 12) {
                                    ForEach(relatedTopics, id: \.id) { relatedTopic in
                                        RelatedTopicCard(topic: relatedTopic)
                                    }
                                }
                            }
                        }
                        #endif
                    }
                    
                    // Notes Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Notes")
                            .font(.headline)
                            .font(.body.weight(.semibold))
                        
                        TextEditor(text: $notes)
                            .frame(height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Topic Study")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .preferredColorScheme(isPresentationMode ? .light : nil)
            .toolbar {
                if isPresentationMode, let onStop = onStopPresenting {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Stop presenting") {
                            onStop()
                        }
                        .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(isPresentationMode ? "Close" : "Done") {
                        if isPresentationMode {
                            // In live session overlay, dismiss() does nothing; close via callback.
                            onStopPresenting?()
                        } else {
                            topic.notes = notes
                            topic.lastViewedDate = Date()
                            do {
                                try modelContext.save()
                            } catch {
                                print("❌ Error saving topic notes: \(error.localizedDescription)")
                                ErrorHandler.shared.handle(.saveFailed)
                            }
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAnswerEditor) {
                QuestionAnswerEditorView(
                    question: isEditingPrompt ? topic.discussionPrompts[selectedQuestionIndex] : topic.studyQuestions[selectedQuestionIndex],
                    answer: $editingAnswer,
                    title: isEditingPrompt ? "Discussion Prompt" : "Study Question",
                    onSave: {
                        if isEditingPrompt {
                            studyService.updateDiscussionAnswer(topic, promptIndex: selectedQuestionIndex, answer: editingAnswer)
                        } else {
                            studyService.updateQuestionAnswer(topic, questionIndex: selectedQuestionIndex, answer: editingAnswer)
                        }
                        topic.lastViewedDate = Date()
                        do {
                            try modelContext.save()
                            showingAnswerEditor = false
                            isEditingPrompt = false
                        } catch {
                            print("❌ Error saving question answer: \(error.localizedDescription)")
                            ErrorHandler.shared.handle(.saveFailed)
                        }
                    },
                    onCancel: {
                        showingAnswerEditor = false
                        isEditingPrompt = false
                    }
                )
                .macOSSheetFrameLarge()
            }
            .onAppear {
                notes = topic.notes
                studyService.markAsViewed(topic)
                relatedTopics = studyService.getRelatedTopics(for: topic)
                do {
                    try modelContext.save()
                } catch {
                    print("❌ Error saving topic view on appear: \(error.localizedDescription)")
                    ErrorHandler.shared.handle(.saveFailed)
                }
            }
            .onChange(of: notes) { _, newValue in
                topic.notes = newValue
                do {
                    try modelContext.save()
                } catch {
                    print("❌ Error auto-saving notes: \(error.localizedDescription)")
                    ErrorHandler.shared.handle(.saveFailed)
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct QuestionAnswerCard: View {
    let question: String
    let number: Int
    let answer: String
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number).")
                    .font(.headline)
                    .foregroundColor(.purple)
                    .frame(width: 30)
                
                Text(question)
                    .font(.body)
            }
            
            if !answer.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    Text("Your Answer:")
                        .font(.caption)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text(answer)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            } else {
                Button(action: onTap) {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.caption)
                        Text("Tap to answer")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
}

@available(iOS 17.0, *)
struct QuestionAnswerEditorView: View {
    let question: String
    @Binding var answer: String
    var title: String = "Study Question"
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var backgroundColor: Color {
        title == "Discussion Prompt" ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1)
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(question)
                    .font(.body)
                    .padding()
                    .background(backgroundColor)
                    .cornerRadius(8)
                
                Text("Your Response")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $answer)
                    .frame(minHeight: 200, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
            .navigationTitle(title == "Discussion Prompt" ? "Answer Prompt" : "Answer Question")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .automatic) {
                    Button("Save", action: onSave)
                        .font(.body.weight(.semibold))
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct RelatedTopicCard: View {
    let topic: BibleStudyTopic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(topic.title)
                .font(.subheadline)
                .font(.body.weight(.semibold))
                .lineLimit(2)
            
            Text(topic.category.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 180)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}

@available(iOS 17.0, *)
struct VerseCard: View {
    let reference: String
    let text: String
    var isPresentationMode: Bool = false
    @State private var isLoading = false
    @State private var loadedText: String?
    // Use regular property for singleton, not @StateObject
    private let bibleService: BibleService = BibleService.shared
    
    var displayText: String {
        if let loaded = loadedText {
            return loaded
        }
        if !text.isEmpty {
            return text
        }
        return ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reference)
                .font(.headline)
                .foregroundColor(isPresentationMode ? .primary : .purple)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if !displayText.isEmpty {
                Text(displayText)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundColor(isPresentationMode ? .primary : nil)
            } else {
                Text("Verse text not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isPresentationMode ? Color.platformSystemGray6 : Color.purple.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            // If text is empty, try to fetch it
            if text.isEmpty && loadedText == nil {
                loadVerseText()
            }
        }
    }
    
    private func loadVerseText() {
        guard !isLoading else { return }
        isLoading = true
        
        Task { @MainActor in
            // First try to find in local verses database
            let service = self.bibleService
            let localVerses = service.getAllLocalVerses()
            if let localVerse = localVerses.first(where: { verse in
                // Try to match the reference - be flexible with matching
                verse.reference.lowercased().contains(reference.lowercased()) ||
                reference.lowercased().contains(verse.reference.lowercased()) ||
                // Try matching just the verse number part (remove spaces for comparison)
                reference.lowercased().replacingOccurrences(of: " ", with: "").contains(verse.reference.lowercased().replacingOccurrences(of: " ", with: ""))
            }) {
                self.loadedText = localVerse.text
                self.isLoading = false
                return
            }
            
            // If not found locally, try to fetch from API
            do {
                let response = try await service.fetchVerse(reference: reference)
                self.loadedText = response.text
                self.isLoading = false
            } catch {
                print("⚠️ Could not load verse \(reference): \(error.localizedDescription)")
                self.isLoading = false
                // Verse text not available will be shown
            }
        }
    }
}

@available(iOS 17.0, *)
struct QuestionCard: View {
    let question: String
    let number: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.headline)
                .foregroundColor(.purple)
                .frame(width: 30)
            
            Text(question)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

@available(iOS 17.0, *)
struct DiscussionPromptAnswerCard: View {
    let prompt: String
    let number: Int
    let answer: String
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number).")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .frame(width: 30)
                
                Text(prompt)
                    .font(.body)
            }
            
            if !answer.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    Text("Your Response:")
                        .font(.caption)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text(answer)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
            } else {
                Button(action: onTap) {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.caption)
                        Text("Tap to respond")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
}

@available(iOS 17.0, *)
struct PromptCard: View {
    let prompt: String
    let number: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.headline)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            Text(prompt)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

@available(iOS 17.0, *)
struct ApplicationCard: View {
    let point: String
    let number: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.headline)
                .foregroundColor(.green)
                .frame(width: 30)
            
            Text(point)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

@available(iOS 17.0, *)
struct BibleStudyProgressView: View {
    // Use regular property for singleton, not @StateObject
    private let studyService = BibleStudyService.shared
    @Query(sort: [SortDescriptor(\BibleStudyTopic.createdAt, order: .reverse)]) var storedTopics: [BibleStudyTopic]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var currentStats: (total: Int, completed: Int, favorites: Int, percentComplete: Double) = (0, 0, 0, 0.0)
    @State private var completedByCategory: [(String, Int)] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView("Loading statistics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else {
                    VStack(spacing: 24) {
                        // Summary Cards
                        HStack(spacing: 16) {
                            BibleStudyStatCard(
                                title: "Total Topics",
                                value: "\(currentStats.total)",
                                icon: "book.fill",
                                color: .purple
                            )
                            
                            BibleStudyStatCard(
                                title: "Completed",
                                value: "\(currentStats.completed)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            BibleStudyStatCard(
                                title: "Favorites",
                                value: "\(currentStats.favorites)",
                                icon: "heart.fill",
                                color: .red
                            )
                        }
                        .padding(.horizontal)
                        
                        // Progress Bar
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Overall Progress")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(currentStats.percentComplete))%")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                            }
                            
                            ProgressView(value: currentStats.percentComplete, total: 100.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                        }
                        .padding()
                        .background(Color.platformSystemGray6)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Completed by Category
                        if !completedByCategory.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Completed by Category")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(completedByCategory, id: \.0) { category, count in
                                    HStack {
                                        Text(category)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(count)")
                                            .font(.subheadline)
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(.purple)
                                    }
                                    .padding()
                                    .background(Color.platformSystemGray6)
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Study Progress")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadStats()
            }
        }
    }
    
    private func loadStats() {
        isLoading = true
        
        // Update stored topics in service (only once)
        studyService.setStoredTopics(storedTopics)
        
        // Get topics on main actor (since BibleStudyService is @MainActor)
        Task { @MainActor in
            let all = studyService.getAllTopics()
            let allTopicsCopy = all  // Create a copy to use off the main actor
            let storedTopicsCopy = storedTopics  // Capture storedTopics for use off main actor
            
            // Compute stats on background thread
            Task.detached(priority: .userInitiated) {
                let completed = allTopicsCopy.filter { $0.isCompleted }.count
                let favorites = allTopicsCopy.filter { $0.isFavorite }.count
                let percent = allTopicsCopy.isEmpty ? 0.0 : Double(completed) / Double(allTopicsCopy.count) * 100.0
                
                let stats = (total: allTopicsCopy.count, completed: completed, favorites: favorites, percentComplete: percent)
                
                // Compute completed by category
                let categories = BibleStudyTopic.TopicCategory.allCases
                let categoryStats = categories.map { category in
                    let completed = storedTopicsCopy.filter { $0.category == category && $0.isCompleted }.count
                    return (category.rawValue, completed)
                }.filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }
                
                // Update UI on main thread
                await Task { @MainActor in
                    self.currentStats = stats
                    self.completedByCategory = categoryStats
                    self.isLoading = false
                }.value
            }
        }
    }
}

@available(iOS 17.0, *)
struct BibleStudyStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .font(.body.weight(.bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.platformSystemBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}


@available(iOS 17.0, *)
struct TopicRow: View {
    let topic: BibleStudyTopic
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Text(topic.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if topic.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                if topic.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bible Game Constants
private let kBasePointsPerCorrect = 100
private let kStreakBonusPerLevel = 25
private let kSpeedBonusMax = 50
private let kTimerSecondsPerQuestion = 15
private let kHighScoreKey = "BibleStudyGameHighScore"
private let kTotalGamesKey = "BibleStudyGameTotalGames"
private let kTotalCorrectKey = "BibleStudyGameTotalCorrect"
private let kAchievementsKey = "BibleStudyGameAchievements"
private let kDailyChallengeDateKey = "BibleStudyGameDailyChallengeDate"
private let kDailyChallengeCompletedKey = "BibleStudyGameDailyChallengeCompleted"

private enum GameTopicFilter: String, CaseIterable {
    case all = "All Topics"
    case today = "Today's Topic"
    case category = "By Category"
}

private enum GameQuestionKind: String {
    case verseToTopic, topicToVerse, completeVerse, topicQuestion
}

// MARK: - Bible Study Game

@available(iOS 17.0, *)
struct BibleStudyGameView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var questions: [GameQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var selectedOption: String?
    @State private var score: Int = 0
    @State private var points: Int = 0
    @State private var currentStreak: Int = 0
    @State private var bestStreak: Int = 0
    @State private var isComplete: Bool = false
    @State private var hasStartedGame: Bool = false
    @State private var roundLength: Int = 20
    @State private var topicFilter: GameTopicFilter = .all
    @State private var selectedCategory: BibleStudyTopic.TopicCategory = .faith
    @State private var isTimed: Bool = false
    @State private var isDailyChallenge: Bool = false
    @State private var lifelineUsed: Bool = false
    @State private var hiddenOptions: Set<String> = []
    @State private var timeRemaining: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var speedBonusThisQuestion: Int = 0
    @State private var newAchievementsThisGame: [String] = []
    @State private var filterProducesQuestions: Bool = true

    private var highScore: Int { UserDefaults.standard.integer(forKey: kHighScoreKey) }
    private var totalGamesPlayed: Int { UserDefaults.standard.integer(forKey: kTotalGamesKey) }
    private var totalCorrectAllTime: Int { UserDefaults.standard.integer(forKey: kTotalCorrectKey) }
    private var currentQuestion: GameQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }
    private var visibleOptions: [String] {
        guard let q = currentQuestion else { return [] }
        if hiddenOptions.isEmpty { return q.options }
        return q.options.filter { !hiddenOptions.contains($0) }
    }

    private var dailyChallengeCompletedToday: Bool {
        let last = UserDefaults.standard.double(forKey: kDailyChallengeDateKey)
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        return last == today && UserDefaults.standard.bool(forKey: kDailyChallengeCompletedKey)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if !hasStartedGame {
                    gameSetupView
                } else if questions.isEmpty {
                    VStack(spacing: 12) {
                        Text("Not enough questions for this filter")
                            .font(.headline)
                        Text("There aren’t enough study topics with key verses and wrong-answer options for a full round. Try “All Topics”, a different category, a shorter round, or turn off Daily Challenge if today’s set is too thin.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(themeManager.colors.textSecondary)
                    }
                    .padding()
                    Spacer()
                    Button("Back to Setup") { hasStartedGame = false }
                        .buttonStyle(.bordered)
                } else if isComplete {
                    resultsView
                } else if let question = currentQuestion {
                    VStack(alignment: .leading, spacing: 16) {
                        ProgressView(value: Double(currentIndex + 1), total: Double(questions.count))
                            .tint(themeManager.colors.primary)
                        Text("Question \(currentIndex + 1) of \(questions.count)")
                            .font(.subheadline)
                            .foregroundColor(themeManager.colors.textSecondary)
                        Text(question.prompt)
                            .font(.headline)
                        if let verseText = question.verseText, !verseText.isEmpty {
                            Text("“\(verseText)”")
                                .font(.body)
                                .foregroundColor(themeManager.colors.textSecondary)
                                .italic()
                        }

                        ForEach(visibleOptions, id: \.self) { option in
                            Button {
                                selectOption(option)
                            } label: {
                                HStack {
                                    Text(option)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if let selected = selectedOption, selected == option {
                                        Image(systemName: option == question.correctAnswer ? "checkmark.circle.fill" : "x.circle.fill")
                                            .foregroundColor(option == question.correctAnswer ? themeManager.colors.primary : .red)
                                    }
                                }
                                .padding()
                                .background(optionBackground(option, correct: question.correctAnswer))
                                .cornerRadius(12)
                            }
                            .disabled(selectedOption != nil)
                            .buttonStyle(.plain)
                        }
                        if !lifelineUsed && selectedOption == nil && visibleOptions.count >= 3 {
                            Button { useLifeline5050() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb.fill")
                                    Text("50/50 – remove two wrong answers").font(.caption)
                                }
                                .foregroundColor(themeManager.colors.primary)
                            }
                            .buttonStyle(.plain)
                        }
                        if let selected = selectedOption {
                            Text(selected.isEmpty ? "Time's up!" : (selected == question.correctAnswer ? "Correct! \(question.correctAnswer)" : "Correct Answer: \(question.correctAnswer)"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(selected.isEmpty ? .red : (selected == question.correctAnswer ? themeManager.colors.primary : .red))
                            if speedBonusThisQuestion > 0 {
                                Text("+\(speedBonusThisQuestion) speed bonus").font(.caption).foregroundColor(themeManager.colors.primary)
                            }
                            Text(question.explanation)
                                .font(.caption)
                                .foregroundColor(themeManager.colors.textSecondary)
                        }
                    }
                    Spacer()
                    Button(action: goToNextQuestion) {
                        Text(currentIndex == questions.count - 1 ? "Finish Game" : "Next Question")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(selectedOption == nil)
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.colors.primary)
                }
            }
            .padding()
            .navigationTitle(isDailyChallenge ? "Daily Challenge" : "Bible Game")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onDisappear {
                timerTask?.cancel()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        timerTask?.cancel()
                        dismiss()
                    }
                }
                if hasStartedGame && !questions.isEmpty && !isComplete {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill").font(.caption)
                                Text("\(points)").font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(themeManager.colors.primary)
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill").font(.caption)
                                Text("\(currentStreak)").font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(currentStreak >= 3 ? .orange : themeManager.colors.textSecondary)
                            if isTimed {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill").font(.caption)
                                    Text("\(timeRemaining)s").font(.subheadline.weight(.semibold))
                                        .foregroundColor(timeRemaining <= 5 ? .red : themeManager.colors.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var gameSetupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isDailyChallenge, dailyChallengeCompletedToday {
                    Label("You already finished today’s Daily Challenge. Come back tomorrow for a new set.", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundColor(themeManager.colors.textSecondary)
                }
                if !filterProducesQuestions, !dailyChallengeCompletedToday {
                    Text("This combination can’t build a full round. Choose more topics, a different filter, or fewer questions.")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                Text("Round length")
                    .font(.subheadline.weight(.semibold))
                Picker("Questions", selection: $roundLength) {
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("30").tag(30)
                    Text("50").tag(50)
                }
                .pickerStyle(.segmented)
                Text("Topics")
                    .font(.subheadline.weight(.semibold))
                Picker("Filter", selection: $topicFilter) {
                    ForEach([GameTopicFilter.all, .today, .category], id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.menu)
                if topicFilter == .category {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(BibleStudyTopic.TopicCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Toggle(isOn: $isTimed) {
                    Label("Timed (bonus for quick answers)", systemImage: "clock.fill")
                }
                Toggle(isOn: $isDailyChallenge) {
                    Label("Today's Daily Challenge", systemImage: "calendar.badge.clock")
                }
                if isDailyChallenge {
                    Text("Same questions for everyone today. Play once and compare!")
                        .font(.caption)
                        .foregroundColor(themeManager.colors.textSecondary)
                }
                Button(action: startGame) {
                    Text("Start Game")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.colors.primary)
                .padding(.top, 8)
                .disabled(
                    (isDailyChallenge && dailyChallengeCompletedToday)
                    || !filterProducesQuestions
                )
            }
            .padding(.vertical, 8)
        }
        .onAppear(perform: refreshFilterProducesQuestions)
        .onChange(of: roundLength) { _, _ in refreshFilterProducesQuestions() }
        .onChange(of: topicFilter) { _, _ in refreshFilterProducesQuestions() }
        .onChange(of: selectedCategory) { _, _ in refreshFilterProducesQuestions() }
        .onChange(of: isDailyChallenge) { _, _ in refreshFilterProducesQuestions() }
    }

    private func refreshFilterProducesQuestions() {
        var topics: [BibleStudyTopic]
        switch topicFilter {
        case .all:
            topics = BibleStudyService.shared.getAllTopics()
        case .today:
            let daily = BibleStudyService.shared.getDailyTopic()
            topics = BibleStudyService.shared.getAllTopics().filter { $0.id == daily.id || daily.relatedTopics.contains($0.title) }
            if topics.isEmpty { topics = [daily] }
        case .category:
            topics = BibleStudyService.shared.getTopics(for: selectedCategory)
        }
        let count = min(roundLength, 50)
        let daySeed: UInt64? = isDailyChallenge
            ? UInt64(Calendar.current.component(.day, from: Date())) + UInt64(Calendar.current.component(.year, from: Date())) * 1000
            : nil
        filterProducesQuestions = !Self.generateQuestions(from: topics, count: count, dailySeed: daySeed).isEmpty
    }

    private func startGame() {
        if isDailyChallenge, dailyChallengeCompletedToday { return }
        var topics: [BibleStudyTopic]
        switch topicFilter {
        case .all:
            topics = BibleStudyService.shared.getAllTopics()
        case .today:
            let daily = BibleStudyService.shared.getDailyTopic()
            topics = BibleStudyService.shared.getAllTopics().filter { $0.id == daily.id || daily.relatedTopics.contains($0.title) }
            if topics.isEmpty { topics = [daily] }
        case .category:
            topics = BibleStudyService.shared.getTopics(for: selectedCategory)
        }
        let count = min(roundLength, 50)
        let daySeed: UInt64? = isDailyChallenge ? UInt64(Calendar.current.component(.day, from: Date())) + UInt64(Calendar.current.component(.year, from: Date())) * 1000 : nil
        questions = Self.generateQuestions(from: topics, count: count, dailySeed: daySeed)
        currentIndex = 0
        selectedOption = nil
        score = 0
        points = 0
        currentStreak = 0
        bestStreak = 0
        isComplete = questions.isEmpty
        hasStartedGame = true
        lifelineUsed = false
        hiddenOptions = []
        newAchievementsThisGame = []
        speedBonusThisQuestion = 0
        if isTimed {
            timeRemaining = kTimerSecondsPerQuestion
            startTimer()
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                timeRemaining -= 1
            }
            if timeRemaining == 0, selectedOption == nil {
                selectedOption = ""
            }
        }
    }

    private func useLifeline5050() {
        guard let question = currentQuestion, !lifelineUsed else { return }
        let wrong = question.options.filter { $0 != question.correctAnswer }
        let toHide = wrong.shuffled().prefix(2)
        hiddenOptions = Set(toHide)
        lifelineUsed = true
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    @ViewBuilder
    private var resultsView: some View {
        let percentage = questions.isEmpty ? 0 : Int((Double(score) / Double(questions.count)) * 100)
        let letterGrade = Self.letterGrade(for: percentage)
        let message = Self.encouragingMessage(percentage: percentage, score: score, total: questions.count)
        ScrollView {
        VStack(spacing: 24) {
            Text("Game Complete!")
                .font(.title2)
                .fontWeight(.semibold)
            Text(letterGrade)
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(themeManager.colors.primary)
            Text("\(score)/\(questions.count) correct • \(points) pts")
                .font(.title3)
                .foregroundColor(themeManager.colors.textSecondary)
            if bestStreak >= 3 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(.orange)
                    Text("Best streak: \(bestStreak)")
                        .font(.subheadline)
                        .foregroundColor(themeManager.colors.textSecondary)
                }
            }
            if points >= highScore && points > 0 {
                Text("New high score!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.colors.primary)
            } else if highScore > 0 {
                Text("High score: \(highScore) pts")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            Text(message)
                .font(.subheadline)
                .foregroundColor(themeManager.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Divider()
            Text("Scoreboard")
                .font(.title2)
                .fontWeight(.semibold)
            VStack(spacing: 14) {
                HStack {
                    Text("Total games played")
                    Spacer()
                    Text("\(totalGamesPlayed)")
                        .fontWeight(.semibold)
                }
                .font(.body)
                HStack {
                    Text("All-time correct answers")
                    Spacer()
                    Text("\(totalCorrectAllTime)")
                        .fontWeight(.semibold)
                }
                .font(.body)
                HStack {
                    Text("High score")
                    Spacer()
                    Text("\(highScore) pts")
                        .font(.body.weight(.semibold))
                        .foregroundColor(themeManager.colors.primary)
                }
                .font(.body)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            if !newAchievementsThisGame.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Achievements unlocked")
                        .font(.headline)
                    ForEach(newAchievementsThisGame, id: \.self) { id in
                        HStack(spacing: 8) {
                            Image(systemName: BibleStudyGameAchievement.icon(for: id))
                                .foregroundColor(themeManager.colors.primary)
                            Text(BibleStudyGameAchievement.title(for: id))
                                .font(.subheadline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(themeManager.colors.primary.opacity(0.1))
                .cornerRadius(12)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("All achievements")
                    .font(.headline)
                ForEach(BibleStudyGameAchievement.allIds, id: \.self) { id in
                    HStack(spacing: 8) {
                        Image(systemName: BibleStudyGameAchievement.isUnlocked(id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(BibleStudyGameAchievement.isUnlocked(id) ? themeManager.colors.primary : .secondary)
                        Text(BibleStudyGameAchievement.title(for: id))
                            .font(.subheadline)
                            .foregroundColor(BibleStudyGameAchievement.isUnlocked(id) ? .primary : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            Spacer()
            Button("Play Again") {
                hasStartedGame = false
                questions = []
                newAchievementsThisGame = []
            }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.colors.primary)
            Spacer()
        }
        .padding(.vertical, 16)
        }
    }

    private func selectOption(_ option: String) {
        guard selectedOption == nil, let question = currentQuestion else { return }
        timerTask?.cancel()
        let correct = option == question.correctAnswer
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(correct ? .success : .error)
        #endif
        selectedOption = option
        if correct {
            score += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            var pts = kBasePointsPerCorrect + (currentStreak - 1) * kStreakBonusPerLevel
            if isTimed && timeRemaining > 0 {
                speedBonusThisQuestion = min(kSpeedBonusMax, timeRemaining * 3)
                pts += speedBonusThisQuestion
            }
            points += pts
        } else {
            currentStreak = 0
        }
    }

    private func goToNextQuestion() {
        guard selectedOption != nil else { return }
        timerTask?.cancel()
        if !isTimed { timeRemaining = 0 }
        selectedOption = nil
        hiddenOptions = []
        speedBonusThisQuestion = 0
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            if isTimed {
                timeRemaining = kTimerSecondsPerQuestion
                startTimer()
            }
        } else {
            saveGameStats()
            newAchievementsThisGame = BibleStudyGameAchievement.checkNewAchievements(
                score: score, total: questions.count, points: points, bestStreak: bestStreak,
                totalGames: totalGamesPlayed + 1, totalCorrect: totalCorrectAllTime + score
            )
            if isDailyChallenge {
                UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970, forKey: kDailyChallengeDateKey)
                UserDefaults.standard.set(true, forKey: kDailyChallengeCompletedKey)
            }
            isComplete = true
        }
    }

    private func saveGameStats() {
        if points > highScore { UserDefaults.standard.set(points, forKey: kHighScoreKey) }
        UserDefaults.standard.set(totalGamesPlayed + 1, forKey: kTotalGamesKey)
        UserDefaults.standard.set(totalCorrectAllTime + score, forKey: kTotalCorrectKey)
    }

    private func resetGame() {
        let topics = BibleStudyService.shared.getAllTopics()
        questions = Self.generateQuestions(from: topics)
        currentIndex = 0
        selectedOption = nil
        score = 0
        points = 0
        currentStreak = 0
        bestStreak = 0
        isComplete = questions.isEmpty
    }

    private func optionBackground(_ option: String, correct: String) -> Color {
        guard let selected = selectedOption else { return Color.platformSystemGray6 }
        if option == selected {
            return option == correct ? themeManager.colors.primary.opacity(0.2) : Color.red.opacity(0.2)
        }
        if option == correct { return themeManager.colors.primary.opacity(0.15) }
        return Color.platformSystemGray6
    }

    private static func letterGrade(for percentage: Int) -> String {
        switch percentage {
        case 90...100: return "A"
        case 80..<90:  return "B"
        case 70..<80:  return "C"
        case 60..<70:  return "D"
        default:       return percentage == 0 ? "—" : "F"
        }
    }

    private static func encouragingMessage(percentage: Int, score: Int, total: Int) -> String {
        switch percentage {
        case 95...100: return "Outstanding! You really know your Scripture. 🌟"
        case 85..<95:  return "Excellent work! Keep studying and growing."
        case 75..<85:  return "Great job! You're building a solid foundation."
        case 60..<75:  return "Good effort! Review the topics and try again."
        case 1..<60:   return "Keep exploring! Each round helps you learn."
        default:       return "No questions available. Try again in a bit."
        }
    }

    private static func generateQuestions(from topics: [BibleStudyTopic], count: Int = 30, dailySeed: UInt64? = nil) -> [GameQuestion] {
        let candidates = topics.filter { !$0.keyVerses.isEmpty }
        var questions: [GameQuestion] = []
        var rng = dailySeed ?? UInt64(arc4random())
        func shuffleOrder<T>(_ a: [T]) -> [T] {
            var b = a
            for i in 0..<(b.count - 1) {
                rng = rng &* 6364136223846793005 &+ 1442695040888963407
                let j = i + Int(rng % UInt64(b.count - i))
                b.swapAt(i, j)
            }
            return b
        }
        let shuffledTopics = shuffleOrder(candidates)

        for topic in shuffledTopics {
            guard questions.count < count else { break }
            let verses = topic.keyVerses.compactMap { v -> String? in
                let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }
            guard let correct = verses.isEmpty ? nil : verses[Int(rng % UInt64(verses.count))] else { continue }

            var decoys = Set<String>()
            let otherVerses = candidates.filter { $0.id != topic.id }
                .flatMap { $0.keyVerses }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0 != correct }

            for verse in shuffleOrder(otherVerses) where decoys.count < 3 {
                decoys.insert(verse)
            }

            guard decoys.count >= 3 else { continue }
            let options = shuffleOrder([correct] + Array(decoys))
            let explanation = topic.topicDescription.isEmpty ? "Category: \(topic.category.rawValue)." : topic.topicDescription
            let verseText = topic.verseTexts.first
            let prompt = "Which verse reference ties to “\(topic.title)”?"

            questions.append(GameQuestion(
                prompt: prompt,
                options: options,
                correctAnswer: correct,
                explanation: explanation,
                verseText: verseText
            ))
        }

        if questions.count < count {
            for topic in shuffleOrder(candidates) where questions.count < count {
                guard let verse = topic.keyVerses.first?.trimmingCharacters(in: .whitespacesAndNewlines), !verse.isEmpty else { continue }
                var decoys = Set<String>()
                for t in shuffleOrder(candidates) where t.id != topic.id && decoys.count < 3 {
                    decoys.insert(t.title)
                }
                guard decoys.count >= 3 else { continue }
                let options = shuffleOrder([topic.title] + Array(decoys))
                questions.append(GameQuestion(
                    prompt: "Which topic does the verse \"" + verse + "\" support?",
                    options: options,
                    correctAnswer: topic.title,
                    explanation: topic.topicDescription.isEmpty ? topic.category.rawValue : topic.topicDescription,
                    verseText: nil
                ))
            }
        }

        return Array(questions.prefix(count))
    }

    private struct GameQuestion: Identifiable {
        let id = UUID()
        let prompt: String
        let options: [String]
        let correctAnswer: String
        let explanation: String
        let verseText: String?
    }
}

// MARK: - Bible Game Achievements
private enum BibleStudyGameAchievement {
    static let allIds = ["first_10", "perfect", "streak_5", "streak_10", "games_10", "games_100", "daily", "high_score"]
    static func isUnlocked(_ id: String) -> Bool {
        let achieved = (UserDefaults.standard.stringArray(forKey: kAchievementsKey) ?? []).contains(id)
        if id == "daily" {
            let last = UserDefaults.standard.double(forKey: kDailyChallengeDateKey)
            let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
            return last == today && UserDefaults.standard.bool(forKey: kDailyChallengeCompletedKey)
        }
        return achieved
    }
    static func icon(for id: String) -> String {
        switch id {
        case "first_10": return "star.fill"
        case "perfect": return "crown.fill"
        case "streak_5": return "flame.fill"
        case "streak_10": return "flame.circle.fill"
        case "games_10": return "gamecontroller.fill"
        case "games_100": return "trophy.fill"
        case "daily": return "calendar.badge.clock"
        case "high_score": return "medal.fill"
        default: return "star.fill"
        }
    }
    static func title(for id: String) -> String {
        switch id {
        case "first_10": return "First Steps – 10 correct in a game"
        case "perfect": return "Perfect Round – 100% correct"
        case "streak_5": return "On Fire – 5 in a row"
        case "streak_10": return "Unstoppable – 10 in a row"
        case "games_10": return "Dedicated – 10 games played"
        case "games_100": return "Century – 100 games played"
        case "daily": return "Daily Challenge completed today"
        case "high_score": return "New high score"
        default: return id
        }
    }
    static func checkNewAchievements(score: Int, total: Int, points: Int, bestStreak: Int, totalGames: Int, totalCorrect: Int) -> [String] {
        var newIds: [String] = []
        let current = UserDefaults.standard.stringArray(forKey: kAchievementsKey) ?? []
        let highScore = UserDefaults.standard.integer(forKey: kHighScoreKey)
        if score >= 10 && !current.contains("first_10") { newIds.append("first_10") }
        if total > 0 && score == total && !current.contains("perfect") { newIds.append("perfect") }
        if bestStreak >= 5 && !current.contains("streak_5") { newIds.append("streak_5") }
        if bestStreak >= 10 && !current.contains("streak_10") { newIds.append("streak_10") }
        if totalGames >= 10 && !current.contains("games_10") { newIds.append("games_10") }
        if totalGames >= 100 && !current.contains("games_100") { newIds.append("games_100") }
        if points >= highScore && points > 0 && !current.contains("high_score") { newIds.append("high_score") }
        var updated = current
        for id in newIds where id != "daily" { updated.append(id) }
        UserDefaults.standard.set(updated, forKey: kAchievementsKey)
        return newIds
    }
}
