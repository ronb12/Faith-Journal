//
//  PromptPickerView.swift
//  Faith Journal
//
//  Prompt picker view for browsing prompts by category
//

import SwiftUI

struct PromptPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var promptManager = PromptManager.shared
    @Binding var selectedPrompt: JournalPrompt?
    @Binding var selectedCategory: JournalPrompt.PromptCategory?
    @State private var searchText = ""
    
    var filteredCategories: [JournalPrompt.PromptCategory] {
        if searchText.isEmpty {
            return JournalPrompt.PromptCategory.allCases
        }
        return JournalPrompt.PromptCategory.allCases.filter { category in
            category.rawValue.localizedCaseInsensitiveContains(searchText) ||
            promptManager.getPrompts(for: category).contains { prompt in
                prompt.promptText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search prompts...", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                if selectedCategory == nil {
                    // Category list
                    List {
                        ForEach(filteredCategories, id: \.self) { category in
                            NavigationLink(destination: PromptsListView(category: category, selectedPrompt: $selectedPrompt, dismissParent: { dismiss() })) {
                                HStack {
                                    Image(systemName: iconForCategory(category))
                                        .foregroundColor(.purple)
                                        .frame(width: 24)
                                    Text(category.rawValue)
                                    Spacer()
                                    Text("\(promptManager.getPrompts(for: category).count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Journal Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func iconForCategory(_ category: JournalPrompt.PromptCategory) -> String {
        switch category {
        case .gratitude: return "heart.fill"
        case .prayer: return "hands.sparkles.fill"
        case .scripture: return "book.fill"
        case .growth: return "chart.line.uptrend.xyaxis"
        case .challenges: return "exclamationmark.triangle.fill"
        case .reflection: return "brain.head.profile"
        case .relationships: return "person.2.fill"
        case .service: return "hand.raised.fill"
        case .morning: return "sunrise.fill"
        case .evening: return "moon.fill"
        case .general: return "sparkles"
        }
    }
}

struct PromptsListView: View {
    let category: JournalPrompt.PromptCategory
    @Binding var selectedPrompt: JournalPrompt?
    let dismissParent: () -> Void
    @StateObject private var promptManager = PromptManager.shared
    
    var prompts: [JournalPrompt] {
        promptManager.getPrompts(for: category)
    }
    
    var body: some View {
        List {
            ForEach(prompts.indices, id: \.self) { index in
                let prompt = prompts[index]
                Button(action: {
                    selectedPrompt = prompt
                    dismissParent()
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(prompt.promptText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

