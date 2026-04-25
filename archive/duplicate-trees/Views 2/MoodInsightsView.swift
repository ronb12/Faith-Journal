//
//  MoodInsightsView.swift
//  Faith Journal
//
//  Mood insights and recommendations view
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct MoodInsightsView: View {
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) var allMoodEntries: [MoodEntry]
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) var journalEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.date, order: .reverse)]) var prayerRequests: [PrayerRequest]
    
    let analyticsService: MoodAnalyticsService
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    let insights = analyticsService.generateInsights(
                        entries: allMoodEntries,
                        journalEntries: journalEntries,
                        prayerRequests: prayerRequests
                    )
                    
                    if insights.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "lightbulb")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No Insights Yet")
                                .font(.title2)
                                .font(.body.weight(.semibold))
                            Text("Keep tracking your mood to receive personalized insights")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 60)
                    } else {
                        ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                            MoodInsightCard(insight: insight, themeManager: themeManager)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Mood Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

@available(iOS 17.0, *)
struct MoodInsightCard: View {
    let insight: MoodInsight
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForType(insight.type))
                    .font(.title2)
                    .foregroundColor(colorForType(insight.type))
                Text(insight.title)
                    .font(.headline)
                Spacer()
                if insight.priority == .high {
                    Text("High Priority")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
            }
            
            Text(insight.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !insight.suggestedActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Actions:")
                        .font(.caption)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(insight.suggestedActions, id: \.self) { action in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(themeManager.colors.primary)
                                .font(.caption)
                            Text(action)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            if let scripture = insight.scriptureReference {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(themeManager.colors.primary)
                    Text(scripture)
                        .font(.caption)
                        .italic()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeManager.colors.primary.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private func iconForType(_ type: MoodInsight.InsightType) -> String {
        switch type {
        case .positive: return "arrow.up.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .pattern: return "chart.line.uptrend.xyaxis"
        case .achievement: return "trophy.fill"
        case .encouragement: return "heart.fill"
        }
    }
    
    private func colorForType(_ type: MoodInsight.InsightType) -> Color {
        switch type {
        case .positive: return .green
        case .warning: return .orange
        case .pattern: return .blue
        case .achievement: return .yellow
        case .encouragement: return .pink
        }
    }
}
