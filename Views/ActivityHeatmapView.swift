//
//  ActivityHeatmapView.swift
//  Faith Journal
//
//  Activity heatmap calendar view
//

import SwiftUI
import Charts

@available(iOS 17.0, *)
struct ActivityHeatmapView: View {
    let entries: [JournalEntry]
    let prayers: [PrayerRequest]
    let moods: [MoodEntry]
    let themeManager: ThemeManager
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Year/Month Picker
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Year")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Year", selection: $selectedYear) {
                                ForEach(2020...2030, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Month", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.platformSystemBackground)
                    )
                    
                    // Heatmap
                    let activityData = getActivityData(year: selectedYear, month: selectedMonth)
                    ActivityHeatmapGrid(data: activityData, themeManager: themeManager)
                    
                    // Legend
                    HStack(spacing: 16) {
                        Text("Less")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorForLevel(level))
                                .frame(width: 20, height: 20)
                        }
                        Text("More")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("Activity Heatmap")
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
    
    private func getActivityData(year: Int, month: Int) -> [Date: Int] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else {
            return [:]
        }
        
        var activityCounts: [Date: Int] = [:]
        
        // Count entries
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            if day >= startDate && day < endDate {
                activityCounts[day, default: 0] += 1
            }
        }
        
        // Count prayers
        for prayer in prayers {
            let day = calendar.startOfDay(for: prayer.date)
            if day >= startDate && day < endDate {
                activityCounts[day, default: 0] += 1
            }
        }
        
        // Count moods
        for mood in moods {
            let day = calendar.startOfDay(for: mood.date)
            if day >= startDate && day < endDate {
                activityCounts[day, default: 0] += 1
            }
        }
        
        return activityCounts
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        let colors: [Color] = [
            Color.gray.opacity(0.2),
            Color.blue.opacity(0.4),
            Color.blue.opacity(0.6),
            Color.blue.opacity(0.8),
            Color.blue
        ]
        return colors[min(level, colors.count - 1)]
    }
}

@available(iOS 17.0, *)
struct ActivityHeatmapGrid: View {
    let data: [Date: Int]
    let themeManager: ThemeManager
    
    var body: some View {
        let calendar = Calendar.current
        let days = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        
        if let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) {
            let firstWeekday = calendar.component(.weekday, from: firstDay)
            
            VStack(spacing: 4) {
            // Weekday headers
            HStack(spacing: 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                // Empty cells for days before month starts
                ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                    Color.clear
                        .frame(height: 30)
                }
                
                // Days of month
                ForEach(1...days, id: \.self) { day in
                    if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                        let activityCount = data[calendar.startOfDay(for: date)] ?? 0
                        let level = min(activityCount, 4)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForLevel(level))
                            .frame(height: 30)
                            .overlay(
                                Text("\(day)")
                                    .font(.caption2)
                                    .foregroundColor(level > 2 ? .white : .primary)
                            )
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        } else {
            Text("Invalid date")
                .foregroundColor(.secondary)
                .padding()
        }
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        let colors: [Color] = [
            Color.gray.opacity(0.2),
            Color.blue.opacity(0.4),
            Color.blue.opacity(0.6),
            Color.blue.opacity(0.8),
            Color.blue
        ]
        return colors[min(level, colors.count - 1)]
    }
}

