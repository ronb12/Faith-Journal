//
//  MoodHeatmapView.swift
//  Faith Journal
//
//  Mood heatmap calendar view
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct MoodHeatmapView: View {
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) var allMoodEntries: [MoodEntry]
    @ObservedObject private var themeManager = ThemeManager.shared
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
                            .fill(Color(.systemBackground))
                    )
                    
                    // Heatmap Grid
                    let calendar = Calendar.current
                    let firstDay = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1))!
                    let range = calendar.range(of: .day, in: .month, for: firstDay)!
                    let daysInMonth = range.count
                    let firstWeekday = calendar.component(.weekday, from: firstDay)
                    
                    VStack(spacing: 4) {
                        // Weekday headers
                        HStack(spacing: 0) {
                            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                                Text(day)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Calendar grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                            // Empty cells for days before month starts
                            ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                            }
                            
                            // Days of month
                            ForEach(1...daysInMonth, id: \.self) { day in
                                let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: day))!
                                let dayStart = calendar.startOfDay(for: date)
                                let entriesForDay = allMoodEntries.filter { entry in
                                    calendar.isDate(calendar.startOfDay(for: entry.date), inSameDayAs: dayStart)
                                }
                                
                                let avgIntensity = entriesForDay.isEmpty ? 0 : entriesForDay.reduce(0) { $0 + $1.intensity } / entriesForDay.count
                                
                                DayCell(day: day, intensity: avgIntensity, hasEntry: !entriesForDay.isEmpty, themeManager: themeManager)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Legend
                    HStack {
                        Text("Less")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ForEach(0..<5) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(intensityColor(Double(index) * 2.0 + 1.0, themeManager: themeManager))
                                .frame(width: 20, height: 20)
                        }
                        Text("More")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("Mood Heatmap")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func intensityColor(_ intensity: Double, themeManager: ThemeManager) -> Color {
        if intensity == 0 {
            return Color(.systemGray5)
        } else if intensity < 4 {
            return Color.red.opacity(0.3)
        } else if intensity < 6 {
            return Color.orange.opacity(0.5)
        } else if intensity < 8 {
            return Color.yellow.opacity(0.7)
        } else {
            return themeManager.colors.primary.opacity(0.9)
        }
    }
}

@available(iOS 17.0, *)
struct DayCell: View {
    let day: Int
    let intensity: Int
    let hasEntry: Bool
    let themeManager: ThemeManager
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(hasEntry ? intensityColor(Double(intensity), themeManager: themeManager) : Color(.systemGray5))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Text("\(day)")
                    .font(.caption2)
                    .foregroundColor(hasEntry && intensity >= 5 ? .white : .primary)
            )
    }
    
    private func intensityColor(_ intensity: Double, themeManager: ThemeManager) -> Color {
        if intensity < 4 {
            return Color.red.opacity(0.3)
        } else if intensity < 6 {
            return Color.orange.opacity(0.5)
        } else if intensity < 8 {
            return Color.yellow.opacity(0.7)
        } else {
            return themeManager.colors.primary.opacity(0.9)
        }
    }
}
