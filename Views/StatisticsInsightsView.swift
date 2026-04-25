//
//  StatisticsInsightsView.swift
//  Faith Journal
//
//  Personalized insights and recommendations view
//

import SwiftUI

@available(iOS 17.0, *)
struct StatisticsInsightsView: View {
    let entries: [JournalEntry]
    let prayers: [PrayerRequest]
    let moods: [MoodEntry]
    let plans: [ReadingPlan]
    let statsService: StatisticsService
    
    @Environment(\.dismiss) private var dismiss
    
    var insights: [StatisticInsight] {
        statsService.generateInsights(
            entries: entries,
            prayers: prayers,
            moods: moods,
            plans: plans
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if insights.isEmpty {
                        EmptyStateView(
                            icon: "lightbulb",
                            title: "No Insights Yet",
                            message: "Keep using the app to generate personalized insights"
                        )
                    } else {
                        ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                            InsightCard(insight: insight, themeManager: ThemeManager.shared)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
}

