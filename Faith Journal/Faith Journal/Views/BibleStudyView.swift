//
//  BibleStudyView.swift
//  Faith Journal
//
//  Main view for browsing and studying Bible study topics
//

import SwiftUI
import SwiftData

struct BibleStudyView: View {
    @StateObject private var studyService = BibleStudyService.shared
    @Query(sort: [SortDescriptor(\BibleStudyTopic.lastViewedDate, order: .reverse)]) var storedTopics: [BibleStudyTopic]
    @State private var searchText = ""
    @State private var selectedCategory: BibleStudyTopic.TopicCategory? = nil
    @State private var selectedTopic: BibleStudyTopic?
    @State private var filterMode: FilterMode = .all
    @State private var showingProgress = false
    @Environment(\.modelContext) private var modelContext
    
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
        NavigationView {
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
                        try? modelContext.save()
                    }
                    .padding()
                }
                
                // Topics List
                if filteredTopics.isEmpty {
                    emptyStateView
                } else {
                    topicsList
                }
            }
            .navigationTitle("Bible Study")
            .searchable(text: $searchText, prompt: "Search topics, verses, questions...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingProgress = true }) {
                        Image(systemName: "chart.bar.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
            }
            .sheet(isPresented: $showingProgress) {
                BibleStudyProgressView()
            }
            .onAppear {
                studyService.setStoredTopics(storedTopics)
            }
        }
    }
    
    private var progressStatsCard: some View {
        let stats = studyService.getProgressStats()
        
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stats.completed)/\(stats.total)")
                    .font(.title2)
                    .fontWeight(.bold)
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
                    .fontWeight(.bold)
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
                    .fontWeight(.bold)
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
        ScrollView(.horizontal, showsIndicators: false) {
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
        .background(Color(.systemGray6))
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All Categories
                BibleStudyCategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                // Individual Categories
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
        .background(Color(.systemGray6))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Topics Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try a different search, filter, or category")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var topicsList: some View {
        List {
            ForEach(Array(filteredTopics.enumerated()), id: \.element.id) { index, topic in
                TopicRow(topic: topic) {
                    selectedTopic = topic
                    studyService.markAsViewed(topic)
                    topic.lastViewedDate = Date()
                    try? modelContext.save()
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
    }
}

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
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.purple : Color(.systemGray5))
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
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.purple : Color(.systemGray5))
                )
        }
    }
}

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
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text(topic.title)
                .font(.title3)
                .fontWeight(.bold)
            
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
                        .fontWeight(.medium)
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

struct TopicRow: View {
    let topic: BibleStudyTopic
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(topic.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if topic.isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        if topic.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
                
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
                    
                    if !topic.keyVerses.isEmpty {
                        Text("\(topic.keyVerses.count) verses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !topic.studyQuestions.isEmpty {
                        Text("\(topic.studyQuestions.count) questions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastViewed = topic.lastViewedDate {
                        Text(lastViewed, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TopicDetailView: View {
    let topic: BibleStudyTopic
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var studyService = BibleStudyService.shared
    @State private var notes = ""
    @State private var showingAnswerEditor = false
    @State private var selectedQuestionIndex: Int = 0
    @State private var editingAnswer: String = ""
    @State private var showingRelatedTopics = false
    @State private var relatedTopics: [BibleStudyTopic] = []
    @State private var isEditingPrompt = false // true for discussion prompt, false for study question
    @State private var currentQuestionOrPrompt: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(topic.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: {
                                studyService.toggleFavorite(topic)
                                try? modelContext.save()
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
                                try? modelContext.save()
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
                                .fontWeight(.semibold)
                            
                            ForEach(Array(topic.keyVerses.enumerated()), id: \.offset) { index, reference in
                                VerseCard(
                                    reference: reference,
                                    text: index < topic.verseTexts.count ? topic.verseTexts[index] : ""
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
                                    .fontWeight(.semibold)
                                
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
                                    .fontWeight(.semibold)
                                
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
                                .fontWeight(.semibold)
                            
                            ForEach(Array(topic.applicationPoints.enumerated()), id: \.offset) { index, point in
                                ApplicationCard(point: point, number: index + 1)
                            }
                        }
                    }
                    
                    // Related Topics
                    if !relatedTopics.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Related Topics")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(relatedTopics, id: \.id) { relatedTopic in
                                        RelatedTopicCard(topic: relatedTopic)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Notes Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Notes")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextEditor(text: $notes)
                            .frame(height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Topic Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        topic.notes = notes
                        topic.lastViewedDate = Date()
                        try? modelContext.save()
                        dismiss()
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
                        try? modelContext.save()
                        showingAnswerEditor = false
                        isEditingPrompt = false
                    },
                    onCancel: {
                        showingAnswerEditor = false
                        isEditingPrompt = false
                    }
                )
            }
            .onAppear {
                notes = topic.notes
                studyService.markAsViewed(topic)
                relatedTopics = studyService.getRelatedTopics(for: topic)
                try? modelContext.save()
            }
            .onChange(of: notes) { _, newValue in
                topic.notes = newValue
                try? modelContext.save()
            }
        }
    }
}

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
                        .fontWeight(.semibold)
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
        NavigationView {
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
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                Spacer()
            }
            .padding()
            .navigationTitle(title == "Discussion Prompt" ? "Answer Prompt" : "Answer Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct RelatedTopicCard: View {
    let topic: BibleStudyTopic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(topic.title)
                .font(.subheadline)
                .fontWeight(.semibold)
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

struct VerseCard: View {
    let reference: String
    let text: String
    @State private var isLoading = false
    @State private var loadedText: String?
    @StateObject private var bibleService = BibleService.shared
    
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
                .foregroundColor(.purple)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if !displayText.isEmpty {
                Text(displayText)
                    .font(.body)
                    .lineSpacing(4)
            } else {
                Text("Verse text not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.1))
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
        
        Task {
            do {
                let response = try await bibleService.fetchVerse(reference: reference)
                await MainActor.run {
                    loadedText = response.text
                    isLoading = false
                }
            } catch {
                print("⚠️ Could not load verse \(reference): \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

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
                        .fontWeight(.semibold)
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

struct BibleStudyProgressView: View {
    @StateObject private var studyService = BibleStudyService.shared
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
                        .background(Color(.systemGray6))
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
                                            .fontWeight(.semibold)
                                            .foregroundColor(.purple)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
        
        // Compute stats on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let all = studyService.getAllTopics()
            let completed = all.filter { $0.isCompleted }.count
            let favorites = all.filter { $0.isFavorite }.count
            let percent = all.isEmpty ? 0.0 : Double(completed) / Double(all.count) * 100.0
            
            let stats = (total: all.count, completed: completed, favorites: favorites, percentComplete: percent)
            
            // Compute completed by category
            let categories = BibleStudyTopic.TopicCategory.allCases
            let categoryStats = categories.map { category in
                let completed = storedTopics.filter { $0.category == category && $0.isCompleted }.count
                return (category.rawValue, completed)
            }.filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.currentStats = stats
                self.completedByCategory = categoryStats
                self.isLoading = false
            }
        }
    }
}

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
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    BibleStudyView()
}
