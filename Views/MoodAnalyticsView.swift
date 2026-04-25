//
//  MoodAnalyticsView.swift
//  Faith Journal
//
//  Enhanced mood analytics view
//

import SwiftUI
import SwiftData
import Charts

@available(iOS 17.0, *)
struct MoodAnalyticsView: View {
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) var allMoodEntries: [MoodEntry]
    @Query(sort: [SortDescriptor(\MoodGoal.createdAt, order: .reverse)]) var allGoals: [MoodGoal]
    @Query(sort: [SortDescriptor(\MoodAchievement.unlockedDate, order: .reverse)]) var allAchievements: [MoodAchievement]
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) var journalEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.date, order: .reverse)]) var prayerRequests: [PrayerRequest]
    
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    // Use regular property for singleton, not @StateObject
    private let analyticsService = MoodAnalyticsService.shared
    // Use regular property for singleton, not @StateObject
    private let goalsService = MoodGoalsService.shared
    
    @State private var selectedTimeframe: Timeframe = .week
    @State private var selectedTab: AnalyticsTab = .overview
    @State private var showingHeatmap = false
    @State private var showingInsights = false
    @State private var showingGoals = false
    @State private var showingExport = false
    @State private var showingSettings = false
    
    enum Timeframe: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        case all = "All Time"
    }
    
    enum AnalyticsTab: String, CaseIterable {
        case overview = "Overview"
        case patterns = "Patterns"
        case correlations = "Correlations"
        case goals = "Goals"
    }
    
    var filteredEntries: [MoodEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
                return allMoodEntries
            }
            return allMoodEntries.filter { $0.date >= weekAgo }
        case .month:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else {
                return allMoodEntries
            }
            return allMoodEntries.filter { $0.date >= monthAgo }
        case .year:
            guard let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) else {
                return allMoodEntries
            }
            return allMoodEntries.filter { $0.date >= yearAgo }
        case .all:
            return allMoodEntries
        }
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            NavigationStack {
                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Timeframe Picker
                            Picker("Timeframe", selection: $selectedTimeframe) {
                                ForEach(Timeframe.allCases, id: \.self) { timeframe in
                                    Text(timeframe.rawValue).tag(timeframe)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)

                            Text("Mood data stays on this device unless you use iCloud or sync. Analytics use only check-ins already saved in Faith Journal.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            switch selectedTab {
                            case .overview:
                                MoodOverviewTab(entries: filteredEntries, timeframe: selectedTimeframe, analyticsService: analyticsService, themeManager: themeManager)
                            case .patterns:
                                PatternsTab(entries: filteredEntries, analyticsService: analyticsService, themeManager: themeManager)
                            case .correlations:
                                CorrelationsTab(entries: filteredEntries, analyticsService: analyticsService, themeManager: themeManager)
                            case .goals:
                                GoalsTab(goals: allGoals, achievements: allAchievements, entries: filteredEntries, goalsService: goalsService, themeManager: themeManager)
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .navigationTitle("Mood Analytics")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Menu {
                            Button(action: { showingInsights = true }) {
                                Label("Insights", systemImage: "lightbulb.fill")
                            }
                            Button(action: { showingGoals = true }) {
                                Label("Goals & Achievements", systemImage: "target")
                            }
                            Button(action: { showingHeatmap = true }) {
                                Label("Heatmap Calendar", systemImage: "calendar")
                            }
                            Button(action: { showingExport = true }) {
                                Label("Export Data", systemImage: "square.and.arrow.up")
                            }
                            Button(action: { showingSettings = true }) {
                                Label("Settings", systemImage: "gearshape.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingInsights) {
                    MoodInsightsView(analyticsService: analyticsService)
                        .macOSSheetFrameStandard()
                }
                .sheet(isPresented: $showingGoals) {
                    MoodGoalsView(goalsService: goalsService)
                        .macOSSheetFrameForm()
                }
                .sheet(isPresented: $showingHeatmap) {
                    MoodHeatmapView()
                        .macOSSheetFrameStandard()
                }
                .sheet(isPresented: $showingExport) {
                    MoodExportView()
                        .macOSSheetFrameStandard()
                }
                .sheet(isPresented: $showingSettings) {
                    MoodSettingsView()
                        .macOSSheetFrameStandard()
                }
            }
        } else {
            Text("Mood analytics is only available on iOS 17+")
        }
    }
}

// Include the supporting views from the enhanced file
// MARK: - Overview Tab

@available(iOS 17.0, *)
struct MoodOverviewTab: View {
    let entries: [MoodEntry]
    let timeframe: MoodAnalyticsView.Timeframe
    let analyticsService: MoodAnalyticsService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Header Stats
            HStack(spacing: 16) {
                MoodStatCard(
                    title: "Average Mood",
                    value: String(format: "%.1f", analyticsService.getAverageMood(entries: entries, timeframe: convertTimeframe(timeframe))),
                    subtitle: "out of 10",
                    color: themeManager.colors.primary
                )
                
                MoodStatCard(
                    title: "Check-ins",
                    value: "\(entries.count)",
                    subtitle: timeframe.rawValue,
                    color: .blue
                )
            }
            .padding(.horizontal)
            
            if !entries.isEmpty {
                // Mood Trend Chart
                MoodAnalyticsTrendChart(entries: entries, themeManager: themeManager)
                
                // Mood Distribution
                MoodDistributionChart(entries: entries, analyticsService: analyticsService, themeManager: themeManager)
                
                // Recent Entries
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Check-ins")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal)
                    
                    ForEach(Array(entries.prefix(5))) { entry in
                        MoodEntryRow(entry: entry)
                    }
                }
            } else {
                EmptyMoodView()
            }
        }
    }
    
    private func convertTimeframe(_ timeframe: MoodAnalyticsView.Timeframe) -> MoodAnalyticsService.Timeframe {
        switch timeframe {
        case .week: return .week
        case .month: return .month
        case .year: return .year
        case .all: return .all
        }
    }
}

// MARK: - Patterns Tab

@available(iOS 17.0, *)
struct PatternsTab: View {
    let entries: [MoodEntry]
    let analyticsService: MoodAnalyticsService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            let (bestDay, worstDay) = analyticsService.getBestWorstDays(entries: entries)
            let (bestTime, worstTime) = analyticsService.getBestWorstTimes(entries: entries)
            let streaks = analyticsService.getMoodStreaks(entries: entries)
            let volatility = analyticsService.getMoodVolatility(entries: entries, timeframe: .month)
            
            // Best/Worst Days
            HStack(spacing: 16) {
                PatternCard(
                    title: "Best Day",
                    value: bestDay,
                    icon: "calendar.badge.plus",
                    color: .green,
                    themeManager: themeManager
                )
                PatternCard(
                    title: "Worst Day",
                    value: worstDay,
                    icon: "calendar.badge.minus",
                    color: .red,
                    themeManager: themeManager
                )
            }
            .padding(.horizontal)
            
            // Best/Worst Times
            HStack(spacing: 16) {
                PatternCard(
                    title: "Best Time",
                    value: bestTime,
                    icon: "clock.fill",
                    color: .blue,
                    themeManager: themeManager
                )
                PatternCard(
                    title: "Worst Time",
                    value: worstTime,
                    icon: "clock.badge.xmark",
                    color: .orange,
                    themeManager: themeManager
                )
            }
            .padding(.horizontal)
            
            // Streaks
            VStack(alignment: .leading, spacing: 12) {
                Text("Streaks")
                    .font(.headline)
                    .font(.body.weight(.semibold))
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    StreakCard(
                        title: "Current",
                        value: "\(streaks.currentStreak)",
                        subtitle: "days",
                        color: themeManager.colors.primary,
                        themeManager: themeManager
                    )
                    StreakCard(
                        title: "Longest Positive",
                        value: "\(streaks.positiveStreak)",
                        subtitle: "days",
                        color: .green,
                        themeManager: themeManager
                    )
                }
                .padding(.horizontal)
            }
            
            // Volatility
            VStack(alignment: .leading, spacing: 12) {
                Text("Mood Consistency")
                    .font(.headline)
                    .font(.body.weight(.semibold))
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Volatility Score")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.2f", volatility))
                            .font(.headline)
                            .foregroundColor(themeManager.colors.primary)
                    }
                    .padding(.horizontal)
                    
                    Text(volatility < 2.0 ? "Very Consistent" : volatility < 3.0 ? "Moderately Consistent" : "Variable")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.platformSystemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Goals Tab

@available(iOS 17.0, *)
struct GoalsTab: View {
    let goals: [MoodGoal]
    let achievements: [MoodAchievement]
    let entries: [MoodEntry]
    let goalsService: MoodGoalsService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Active Goals
            if !goals.filter({ !$0.isCompleted }).isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Goals")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal)
                    
                    ForEach(goals.filter { !$0.isCompleted }) { goal in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(goal.title)
                                .font(.headline)
                            Text(goal.goalDescription)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.platformSystemBackground)
                        )
                        .padding(.horizontal)
                    }
                }
            }
            
            // Completed Goals
            if !goals.filter({ $0.isCompleted }).isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Completed Goals")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal)
                    
                    ForEach(goals.filter { $0.isCompleted }) { goal in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(goal.title)
                                .font(.headline)
                            Text(goal.goalDescription)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.platformSystemBackground)
                        )
                        .padding(.horizontal)
                    }
                }
            }
            
            // Achievements
            VStack(alignment: .leading, spacing: 12) {
                Text("Achievements")
                    .font(.headline)
                    .font(.body.weight(.semibold))
                    .padding(.horizontal)
                
                if achievements.filter({ $0.isUnlocked }).isEmpty {
                    Text("Unlock achievements by tracking your mood consistently!")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                        ForEach(achievements.filter { $0.isUnlocked }) { achievement in
                            VStack(spacing: 8) {
                                Text(achievement.icon)
                                    .font(.system(size: 40))
                                Text(achievement.title)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.platformSystemBackground)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Locked Achievements
                if !achievements.filter({ !$0.isUnlocked }).isEmpty {
                    Text("Locked Achievements")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal)
                        .padding(.top)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                        ForEach(achievements.filter { !$0.isUnlocked }) { achievement in
                            VStack(spacing: 8) {
                                Text(achievement.icon)
                                    .font(.system(size: 40))
                                    .opacity(0.5)
                                Text(achievement.title)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .opacity(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.platformSystemBackground)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Correlations Tab

@available(iOS 17.0, *)
struct CorrelationsTab: View {
    let entries: [MoodEntry]
    let analyticsService: MoodAnalyticsService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Activity Correlation
            let activityCorr = analyticsService.getActivityCorrelation(entries: entries)
            if !activityCorr.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Activity Impact")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal)
                    
                    ForEach(Array(activityCorr.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { item in
                        HStack {
                            Text(item.key)
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f/10", item.value))
                                .font(.headline)
                                .foregroundColor(themeManager.colors.primary)
                            ProgressView(value: item.value, total: 10.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: themeManager.colors.primary))
                                .frame(width: 100)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.platformSystemGray6)
                        )
                        .padding(.horizontal)
                    }
                }
            }
            
            // Weather Correlation
            let weatherCorr = analyticsService.getWeatherCorrelation(entries: entries)
            if !weatherCorr.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weather Impact")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal)
                    
                    ForEach(Array(weatherCorr.sorted(by: { $0.value > $1.value })), id: \.key) { item in
                        HStack {
                            Text(item.key)
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f/10", item.value))
                                .font(.headline)
                                .foregroundColor(themeManager.colors.primary)
                            ProgressView(value: item.value, total: 10.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: themeManager.colors.primary))
                                .frame(width: 100)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.platformSystemGray6)
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

@available(iOS 17.0, *)
struct PatternCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            Text(value)
                .font(.title2)
                .font(.body.weight(.bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

@available(iOS 17.0, *)
struct StreakCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title)
                    .font(.body.weight(.bold))
                    .foregroundColor(color)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct EmptyMoodView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("No Mood Data")
                .font(.title2)
                .font(.body.weight(.semibold))
            Text("Start tracking your mood to see analytics here")
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Chart Views

@available(iOS 17.0, *)
struct MoodAnalyticsTrendChart: View {
    let entries: [MoodEntry]
    let themeManager: ThemeManager
    
    var weeklyData: [(date: Date, intensity: Int)] {
        let grouped = Dictionary(grouping: entries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }
        return grouped.map { (date, entries) in
            let avgIntensity = entries.reduce(0) { $0 + $1.intensity } / entries.count
            return (date: date, intensity: avgIntensity)
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Trend")
                .font(.headline)
                .font(.body.weight(.semibold))
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
                AxisMarks(values: .stride(by: .day, count: 1)) { value in
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
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal)
        }
    }
}

@available(iOS 17.0, *)
struct MoodDistributionChart: View {
    let entries: [MoodEntry]
    let analyticsService: MoodAnalyticsService
    let themeManager: ThemeManager
    
    var moodDistribution: [String: Int] {
        analyticsService.getMoodDistribution(entries: entries, timeframe: .all)
    }
    
    var body: some View {
        if !moodDistribution.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mood Distribution")
                    .font(.headline)
                    .font(.body.weight(.semibold))
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
                        .fill(Color.platformSystemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Reusable Components

@available(iOS 17.0, *)
struct MoodStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            Text(value)
                .font(.title2)
                .font(.body.weight(.bold))
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

@available(iOS 17.0, *)
struct MoodEntryRow: View {
    let entry: MoodEntry
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.emoji)
                        .font(.title3)
                    Text(entry.mood)
                        .font(.headline)
                }
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.primary)
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.primary)
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
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal)
    }
}
