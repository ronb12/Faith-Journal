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
    @State private var searchText = ""
    @State private var selectedCategory: BibleStudyTopic.TopicCategory? = nil
    @State private var selectedTopic: BibleStudyTopic?
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Filter
                categoryFilter
                
                // Daily Topic Card
                if let dailyTopic = studyService.dailyTopic {
                    DailyTopicCard(topic: dailyTopic)
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
            .searchable(text: $searchText, prompt: "Search topics...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { selectedCategory = nil }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(item: $selectedTopic) { topic in
                TopicDetailView(topic: topic)
            }
        }
    }
    
    private var filteredTopics: [BibleStudyTopic] {
        var topics = studyService.getAllTopics()
        
        // Filter by category
        if let category = selectedCategory {
            topics = topics.filter { $0.category == category }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            topics = topics.filter { topic in
                topic.title.lowercased().contains(query) ||
                topic.topicDescription.lowercased().contains(query) ||
                topic.category.rawValue.lowercased().contains(query)
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
            
            Text("Try a different search or category")
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
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
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
                
                Button(action: { showingDetail = true }) {
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
        .sheet(isPresented: $showingDetail) {
            TopicDetailView(topic: topic)
        }
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
                    
                    if topic.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(topic.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
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
                                studyService.toggleFavorite(topic)
                            }) {
                                Image(systemName: topic.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                                    .foregroundColor(topic.isCompleted ? .green : .secondary)
                                Text(topic.isCompleted ? "Completed" : "Mark Complete")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                    
                    // Study Questions
                    if !topic.studyQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Study Questions")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(topic.studyQuestions.enumerated()), id: \.offset) { index, question in
                                QuestionCard(question: question, number: index + 1)
                            }
                        }
                    }
                    
                    // Discussion Prompts
                    if !topic.discussionPrompts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Discussion Prompts")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(topic.discussionPrompts.enumerated()), id: \.offset) { index, prompt in
                                PromptCard(prompt: prompt, number: index + 1)
                            }
                        }
                    }
                    
                    // Application Points
                    if !topic.applicationPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Application Points")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(topic.applicationPoints.enumerated()), id: \.offset) { index, point in
                                ApplicationCard(point: point, number: index + 1)
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
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                notes = topic.notes
            }
            .onChange(of: notes) { _, newValue in
                topic.notes = newValue
                try? modelContext.save()
            }
        }
    }
}

struct VerseCard: View {
    let reference: String
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reference)
                .font(.headline)
                .foregroundColor(.purple)
            
            if !text.isEmpty {
                Text(text)
                    .font(.body)
                    .lineSpacing(4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
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

#Preview {
    BibleStudyView()
}

