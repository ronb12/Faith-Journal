//
//  TopicPickerView.swift
//  Faith Journal
//
//  View for selecting a Bible study topic for live sessions
//

import SwiftUI

struct TopicPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTopic: BibleStudyTopic?
    @StateObject private var studyService = BibleStudyService.shared
    @State private var searchText = ""
    @State private var selectedCategory: BibleStudyTopic.TopicCategory? = nil
    
    var filteredTopics: [BibleStudyTopic] {
        var topics = studyService.getAllTopics()
        
        if let category = selectedCategory {
            topics = topics.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            topics = topics.filter { topic in
                topic.title.lowercased().contains(query) ||
                topic.topicDescription.lowercased().contains(query)
            }
        }
        
        return topics
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button(action: { selectedCategory = nil }) {
                            Text("All")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedCategory == nil ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedCategory == nil ? Color.purple : Color(.systemGray5))
                                )
                        }
                        
                        ForEach(BibleStudyTopic.TopicCategory.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
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
                
                // Topics List
                if filteredTopics.isEmpty {
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
                } else {
                    List {
                        ForEach(filteredTopics, id: \.id) { topic in
                            TopicSelectionRow(topic: topic, isSelected: selectedTopic?.id == topic.id) {
                                selectedTopic = topic
                                dismiss()
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Select Topic")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search topics...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct TopicSelectionRow: View {
    let topic: BibleStudyTopic
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(topic.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
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
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TopicPickerView(selectedTopic: .constant(nil))
}

