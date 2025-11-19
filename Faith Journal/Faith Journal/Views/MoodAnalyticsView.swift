//
//  MoodAnalyticsView.swift
//  Faith Journal
//
//  Created on 11/18/25.
//

import SwiftUI
import SwiftData
import Charts

struct MoodAnalyticsView: View {
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) var allMoodEntries: [MoodEntry]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedTimeframe: Timeframe = .week
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }
    
    var filteredEntries: [MoodEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return allMoodEntries.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return allMoodEntries.filter { $0.date >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return allMoodEntries.filter { $0.date >= yearAgo }
        case .all:
            return allMoodEntries
        }
    }
    
    var averageMood: Double {
        guard !filteredEntries.isEmpty else { return 0 }
        let sum = filteredEntries.reduce(0) { $0 + Double($1.intensity) }
        return sum / Double(filteredEntries.count)
    }
    
    var moodDistribution: [String: Int] {
        var distribution: [String: Int] = [:]
        for entry in filteredEntries {
            distribution[entry.mood, default: 0] += 1
        }
        return distribution
    }
    
    var weeklyData: [(date: Date, intensity: Int)] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }
        return grouped.map { (date, entries) in
            let avgIntensity = entries.reduce(0) { $0 + $1.intensity } / entries.count
            return (date: date, intensity: avgIntensity)
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Stats
                    HStack(spacing: 16) {
                        MoodStatCard(
                            title: "Average Mood",
                            value: String(format: "%.1f", averageMood),
                            subtitle: "out of 10",
                            color: themeManager.colors.primary
                        )
                        
                        MoodStatCard(
                            title: "Check-ins",
                            value: "\(filteredEntries.count)",
                            subtitle: selectedTimeframe.rawValue,
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    // Timeframe Picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if filteredEntries.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No Mood Data")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Start tracking your mood to see analytics here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 60)
                    } else {
                        // Mood Trend Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mood Trend")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            Chart(weeklyData, id: \.date) { data in
                                LineMark(
                                    x: .value("Date", data.date, unit: .day),
                                    y: .value("Intensity", data.intensity)
                                )
                                .foregroundStyle(themeManager.colors.primary)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Date", data.date, unit: .day),
                                    y: .value("Intensity", data.intensity)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [themeManager.colors.primary.opacity(0.3), themeManager.colors.primary.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                            .frame(height: 200)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: selectedTimeframe == .week ? 1 : 7)) { value in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.month().day())
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
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
                        
                        // Mood Distribution
                        if !moodDistribution.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Mood Distribution")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal)
                                
                                Chart(Array(moodDistribution.sorted(by: { $0.value > $1.value })), id: \.key) { item in
                                    BarMark(
                                        x: .value("Count", item.value),
                                        y: .value("Mood", item.key)
                                    )
                                    .foregroundStyle(themeManager.colors.primary)
                                }
                                .frame(height: 200)
                                .chartXAxis {
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
                        
                        // Recent Mood Entries
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Check-ins")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                            
                            ForEach(Array(filteredEntries.prefix(5))) { entry in
                                MoodEntryRow(entry: entry)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Mood Analytics")
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct MoodStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct MoodEntryRow: View {
    let entry: MoodEntry
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mood)
                    .font(.headline)
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.intensity)/10")
                    .font(.headline)
                    .foregroundColor(themeManager.colors.primary)
                ProgressView(value: Double(entry.intensity), total: 10.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: themeManager.colors.primary))
                    .frame(width: 60)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal)
    }
}

#Preview {
    MoodAnalyticsView()
        .modelContainer(for: [MoodEntry.self], inMemory: true)
}

