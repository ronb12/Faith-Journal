//
//  StatisticsView.swift
//  Faith Journal
//
//  Created on 11/18/25.
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query(sort: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]) var allEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]) var allPrayers: [PrayerRequest]
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) var allMoods: [MoodEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showingMoodAnalytics = false
    
    var answeredPrayers: Int {
        allPrayers.filter { $0.status == .answered }.count
    }
    
    var activePrayers: Int {
        allPrayers.filter { $0.status == .active }.count
    }
    
    var entriesWithMedia: Int {
        allEntries.filter { !$0.photoURLs.isEmpty || $0.audioURL != nil || $0.drawingData != nil }.count
    }
    
    var journalingStreak: Int {
        guard !allEntries.isEmpty else { return 0 }
        var streak = 0
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())
        
        let entryDates = Set(allEntries.map { calendar.startOfDay(for: $0.date) })
        
        while entryDates.contains(currentDate) {
            streak += 1
            if let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                currentDate = calendar.startOfDay(for: previousDate)
            } else {
                break
            }
        }
        
        return streak
    }
    
    var mostUsedTags: [(String, Int)] {
        var tagCounts: [String: Int] = [:]
        for entry in allEntries {
            for tag in entry.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        for prayer in allPrayers {
            for tag in prayer.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return Array(tagCounts.sorted(by: { $0.value > $1.value }).prefix(5))
    }
    
    var entriesPerMonth: [(month: Date, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allEntries) { entry in
            calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date))!
        }
        return grouped.map { (month, entries) in
            (month: month, count: entries.count)
        }.sorted { $0.month < $1.month }
    }
    
    var prayerStatusData: [(status: String, count: Int)] {
        [
            ("Answered", answeredPrayers),
            ("Active", activePrayers),
            ("Archived", allPrayers.filter { $0.status == .archived }.count)
        ]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary Cards
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Journal Entries",
                                value: "\(allEntries.count)",
                                icon: "book.fill",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "Prayer Requests",
                                value: "\(allPrayers.count)",
                                icon: "hands.sparkles.fill",
                                color: .green
                            )
                        }
                        
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Days Streak",
                                value: "\(journalingStreak)",
                                icon: "flame.fill",
                                color: .orange
                            )
                            
                            StatCard(
                                title: "Mood Check-ins",
                                value: "\(allMoods.count)",
                                icon: "face.smiling.fill",
                                color: .purple
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Entries Over Time Chart
                    if !entriesPerMonth.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Journal Entries Over Time")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            Chart(entriesPerMonth, id: \.month) { data in
                                BarMark(
                                    x: .value("Month", data.month, unit: .month),
                                    y: .value("Count", data.count)
                                )
                                .foregroundStyle(.blue)
                                .cornerRadius(4)
                            }
                            .frame(height: 200)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .month)) { value in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                                }
                            }
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisValueLabel()
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Prayer Status Chart
                    if !allPrayers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Prayer Requests Status")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            Chart(prayerStatusData, id: \.status) { data in
                                BarMark(
                                    x: .value("Status", data.status),
                                    y: .value("Count", data.count)
                                )
                                .foregroundStyle(by: .value("Status", data.status))
                                .cornerRadius(4)
                            }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisGridLine()
                                    AxisValueLabel()
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Additional Stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Additional Statistics")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            StatRow(
                                title: "Answered Prayers",
                                value: "\(answeredPrayers)",
                                subtitle: "\(allPrayers.isEmpty ? 0 : (answeredPrayers * 100 / allPrayers.count))% of total"
                            )
                            
                            StatRow(
                                title: "Entries with Media",
                                value: "\(entriesWithMedia)",
                                subtitle: "\(allEntries.isEmpty ? 0 : (entriesWithMedia * 100 / allEntries.count))% of entries"
                            )
                            
                            if !allMoods.isEmpty {
                                let avgMood = allMoods.reduce(0) { $0 + $1.intensity } / allMoods.count
                                Button(action: { showingMoodAnalytics = true }) {
                                    StatRow(
                                        title: "Average Mood",
                                        value: String(format: "%.1f/10", Double(avgMood)),
                                        subtitle: "Tap to view detailed analytics"
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Most Used Tags
                    if !mostUsedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Most Used Tags")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(Array(mostUsedTags.enumerated()), id: \.offset) { index, tag in
                                    HStack {
                                        Text("#\(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 30)
                                        
                                        Text(tag.0)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        Text("\(tag.1)")
                                            .font(.subheadline)
                                            .foregroundColor(.purple)
                                            .fontWeight(.semibold)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistics")
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showingMoodAnalytics) {
                MoodAnalyticsView()
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            Spacer()
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.purple)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [JournalEntry.self, PrayerRequest.self, MoodEntry.self], inMemory: true)
}

