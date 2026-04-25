//
//  StatisticsView_Enhanced.swift
//  Faith Journal
//
//  Enhanced statistics view with all features
//

import SwiftUI
import SwiftData
import Charts

@available(iOS 17.0, *)
struct StatisticsView_Enhanced: View {
    @Query(sort: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]) var allEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]) var allPrayers: [PrayerRequest]
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) var allMoods: [MoodEntry]
    @Query(sort: [SortDescriptor(\ReadingPlan.createdAt, order: .reverse)]) var allPlans: [ReadingPlan]
    @Query(sort: [SortDescriptor(\BookmarkedVerse.createdAt, order: .reverse)]) var allBookmarks: [BookmarkedVerse]
    @Query(sort: [SortDescriptor(\BibleHighlight.createdAt, order: .reverse)]) var allHighlights: [BibleHighlight]
    @Query(sort: [SortDescriptor(\BibleNote.createdAt, order: .reverse)]) var allNotes: [BibleNote]
    @Query(sort: [SortDescriptor(\BibleStudyTopic.createdAt, order: .reverse)]) var allTopics: [BibleStudyTopic]
    @Query(sort: [SortDescriptor(\StatisticAchievement.unlockedDate, order: .reverse)]) var allAchievements: [StatisticAchievement]
    
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    // Use regular property for singleton, not @StateObject
    private let statsService = StatisticsService.shared
    // Use regular property for singleton, not @StateObject
    private let achievementService = AchievementService.shared
    
    @State private var selectedTimeframe: Timeframe = .month
    @State private var selectedTab: StatsTab = .overview
    @State private var showingMoodAnalytics = false
    @State private var showingHeatmap = false
    @State private var showingAchievements = false
    @State private var showingInsights = false
    @State private var showingExport = false
    @State private var showingComparison = false
    @State private var compareWithPrevious = false
    
    enum Timeframe: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        case all = "All Time"
    }
    
    enum StatsTab: String, CaseIterable {
        case overview = "Overview"
        case journal = "Journal"
        case prayer = "Prayer"
        case mood = "Mood"
        case reading = "Reading"
        case bible = "Bible"
    }
    
    var filteredEntries: [JournalEntry] {
        statsService.filterByTimeframe(entries: allEntries, timeframe: convertTimeframe(selectedTimeframe))
    }
    
    var filteredPrayers: [PrayerRequest] {
        statsService.filterPrayersByTimeframe(prayers: allPrayers, timeframe: convertTimeframe(selectedTimeframe))
    }
    
    var filteredMoods: [MoodEntry] {
        statsService.filterMoodsByTimeframe(entries: allMoods, timeframe: convertTimeframe(selectedTimeframe))
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            NavigationStack {
                VStack(spacing: 0) {
                    // Timeframe Picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Tab Picker
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(StatsTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            switch selectedTab {
                            case .overview:
                                OverviewTab(
                                    entries: filteredEntries,
                                    prayers: filteredPrayers,
                                    moods: filteredMoods,
                                    plans: allPlans,
                                    bookmarks: allBookmarks,
                                    highlights: allHighlights,
                                    notes: allNotes,
                                    statsService: statsService,
                                    themeManager: themeManager,
                                    compareWithPrevious: compareWithPrevious
                                )
                            case .journal:
                                JournalTab(
                                    entries: filteredEntries,
                                    allEntries: allEntries,
                                    statsService: statsService,
                                    themeManager: themeManager
                                )
                            case .prayer:
                                PrayerTab(
                                    prayers: filteredPrayers,
                                    allPrayers: allPrayers,
                                    statsService: statsService,
                                    themeManager: themeManager
                                )
                            case .mood:
                                MoodTab(
                                    moods: filteredMoods,
                                    allMoods: allMoods,
                                    statsTimeframe: convertTimeframe(selectedTimeframe),
                                    statsService: statsService,
                                    themeManager: themeManager
                                )
                            case .reading:
                                ReadingTab(
                                    plans: allPlans,
                                    topics: allTopics,
                                    statsService: statsService,
                                    themeManager: themeManager
                                )
                            case .bible:
                                BibleTab(
                                    bookmarks: allBookmarks,
                                    highlights: allHighlights,
                                    notes: allNotes,
                                    statsService: statsService,
                                    themeManager: themeManager
                                )
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .navigationTitle("Statistics")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Menu {
                            Button(action: { showingInsights = true }) {
                                Label("Insights", systemImage: "lightbulb.fill")
                            }
                            Button(action: { showingAchievements = true }) {
                                Label("Achievements", systemImage: "trophy.fill")
                            }
                            Button(action: { showingHeatmap = true }) {
                                Label("Activity Heatmap", systemImage: "calendar")
                            }
                            Button(action: { compareWithPrevious.toggle() }) {
                                Label(compareWithPrevious ? "Hide Comparison" : "Compare Periods", systemImage: "chart.bar.doc.horizontal")
                            }
                            Button(action: { showingExport = true }) {
                                Label("Export Report", systemImage: "square.and.arrow.up")
                            }
                            Button(action: { showingMoodAnalytics = true }) {
                                Label("Full Mood Report", systemImage: "chart.bar.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingMoodAnalytics) {
                    MoodAnalyticsView()
                }
                .sheet(isPresented: $showingHeatmap) {
                    ActivityHeatmapView(entries: allEntries, prayers: allPrayers, moods: allMoods, themeManager: themeManager)
                }
                .sheet(isPresented: $showingAchievements) {
                    AchievementsView(achievementService: achievementService)
                }
                .sheet(isPresented: $showingInsights) {
                    StatisticsInsightsView(
                        entries: allEntries,
                        prayers: allPrayers,
                        moods: allMoods,
                        plans: allPlans,
                        statsService: statsService
                    )
                }
                .sheet(isPresented: $showingExport) {
                    StatisticsExportView(
                        entries: allEntries,
                        prayers: allPrayers,
                        moods: allMoods,
                        plans: allPlans,
                        statsService: statsService
                    )
                }
            }
        } else {
            Text("Statistics are only available on iOS 17+")
        }
    }
    
    private func convertTimeframe(_ timeframe: Timeframe) -> StatisticsService.Timeframe {
        switch timeframe {
        case .week: return .week
        case .month: return .month
        case .year: return .year
        case .all: return .all
        }
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    let entries: [JournalEntry]
    let prayers: [PrayerRequest]
    let moods: [MoodEntry]
    let plans: [ReadingPlan]
    let bookmarks: [BookmarkedVerse]
    let highlights: [BibleHighlight]
    let notes: [BibleNote]
    let statsService: StatisticsService
    let themeManager: ThemeManager
    let compareWithPrevious: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Engagement Score
            let engagement = statsService.getOverallEngagementScore(
                entries: entries,
                prayers: prayers,
                moods: moods,
                plans: plans
            )
            
            EngagementScoreCard(score: engagement, themeManager: themeManager)
                .padding(.horizontal)
            
            // Summary Cards Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                EnhancedStatCard(
                    title: "Journal Entries",
                    value: "\(entries.count)",
                    subtitle: formatChange(entries.count, previous: getPreviousCount(entries)),
                    icon: "book.fill",
                    color: .blue,
                    themeManager: themeManager
                )
                
                EnhancedStatCard(
                    title: "Total Words",
                    value: formatNumber(statsService.getTotalWords(entries: entries)),
                    subtitle: "\(statsService.getAverageEntryLength(entries: entries)) avg/entry",
                    icon: "text.word.spacing",
                    color: .indigo,
                    themeManager: themeManager
                )
                
                EnhancedStatCard(
                    title: "Prayer Requests",
                    value: "\(prayers.count)",
                    subtitle: "\(prayers.filter { $0.isAnswered }.count) answered",
                    icon: "hands.sparkles.fill",
                    color: .green,
                    themeManager: themeManager
                )
                
                EnhancedStatCard(
                    title: "Mood Check-ins",
                    value: "\(moods.count)",
                    subtitle: moods.isEmpty ? "" : "Avg: \(String(format: "%.1f", Double(moods.reduce(0) { $0 + $1.intensity }) / Double(moods.count)))/10",
                    icon: "face.smiling.fill",
                    color: .purple,
                    themeManager: themeManager
                )
                
                EnhancedStatCard(
                    title: "Reading Plans",
                    value: "\(plans.count)",
                    subtitle: "\(plans.filter { $0.isCompleted }.count) completed",
                    icon: "book.closed.fill",
                    color: .orange,
                    themeManager: themeManager
                )
                
                EnhancedStatCard(
                    title: "Bible Bookmarks",
                    value: "\(bookmarks.count)",
                    subtitle: "\(highlights.count) highlights, \(notes.count) notes",
                    icon: "bookmark.fill",
                    color: .teal,
                    themeManager: themeManager
                )
                
                EnhancedStatCard(
                    title: "Days Streak",
                    value: "\(calculateStreak(entries: entries))",
                    subtitle: "Keep it going!",
                    icon: "flame.fill",
                    color: .red,
                    themeManager: themeManager
                )
                
                EnhancedStatCard(
                    title: "Consistency",
                    value: "\(Int(statsService.getConsistencyScore(entries: entries, timeframe: .month)))%",
                    subtitle: "This month",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .cyan,
                    themeManager: themeManager
                )
            }
            .padding(.horizontal)
            
            // Quick Insights
            let insights = statsService.generateInsights(
                entries: entries,
                prayers: prayers,
                moods: moods,
                plans: plans
            )
            
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Insights")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal)
                    
                    ForEach(Array(insights.prefix(3)), id: \.title) { insight in
                        InsightCard(insight: insight, themeManager: themeManager)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private func getPreviousCount<T>(_ items: [T]) -> Int {
        // Simplified - would need actual previous period data
        return 0
    }
    
    private func formatChange(_ current: Int, previous: Int) -> String {
        guard previous > 0 else { return "" }
        let change = current - previous
        let percent = Double(change) / Double(previous) * 100
        if change > 0 {
            return "+\(change) (+\(Int(percent))%)"
        } else if change < 0 {
            return "\(change) (\(Int(percent))%)"
        }
        return "No change"
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }
    
    private func calculateStreak(entries: [JournalEntry]) -> Int {
        guard !entries.isEmpty else { return 0 }
        var streak = 0
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())
        
        let entryDates = Set(entries.map { calendar.startOfDay(for: $0.date) })
        
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
}

// MARK: - Journal Tab

struct JournalTab: View {
    let entries: [JournalEntry]
    let allEntries: [JournalEntry]
    let statsService: StatisticsService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Journal Stats
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Words",
                    value: formatNumber(statsService.getTotalWords(entries: entries)),
                    icon: "text.word.spacing",
                    color: .blue
                )
                StatCard(
                    title: "Avg Length",
                    value: "\(statsService.getAverageEntryLength(entries: entries))",
                    icon: "ruler",
                    color: .indigo,
                    subtitle: "words"
                )
            }
            .padding(.horizontal)
            
            // Most Active Day
            let mostActiveDay = statsService.getMostActiveDay(entries: entries)
            let bestTime = statsService.getBestJournalingTime(entries: entries)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Journaling Patterns")
                    .font(.headline)
                    .font(.body.weight(.semibold))
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    PatternInfoCard(
                        title: "Most Active Day",
                        value: mostActiveDay,
                        icon: "calendar",
                        color: .blue,
                        themeManager: themeManager
                    )
                    PatternInfoCard(
                        title: "Best Time",
                        value: bestTime,
                        icon: "clock.fill",
                        color: .purple,
                        themeManager: themeManager
                    )
                }
                .padding(.horizontal)
            }
            
            // Entries Over Time Chart
            if !entries.isEmpty {
                EntriesOverTimeChart(entries: entries, themeManager: themeManager)
            }
            
            // Day of Week Distribution
            let dayDistribution = statsService.getEntriesByDayOfWeek(entries: entries)
            if !dayDistribution.isEmpty {
                DayOfWeekChart(distribution: dayDistribution, themeManager: themeManager)
            }
            
            // Entry Length Distribution
            if !entries.isEmpty {
                EntryLengthChart(entries: entries, themeManager: themeManager)
            }
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

// MARK: - Prayer Tab

struct PrayerTab: View {
    let prayers: [PrayerRequest]
    let allPrayers: [PrayerRequest]
    let statsService: StatisticsService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Prayer Stats
            let answered = prayers.filter { $0.isAnswered }.count
            let answerRate = statsService.getPrayerAnswerRate(prayers: prayers, timeframe: .all)
            let avgAnswerTime = statsService.getAverageAnswerTime(prayers: prayers)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Prayers",
                    value: "\(prayers.count)",
                    icon: "hands.sparkles.fill",
                    color: .green
                )
                StatCard(
                    title: "Answered",
                    value: "\(answered)",
                    icon: "checkmark.circle.fill",
                    color: .blue,
                    subtitle: "\(Int(answerRate))%"
                )
            }
            .padding(.horizontal)
            
            if let avgTime = avgAnswerTime {
                let days = Int(avgTime / 86400)
                StatCard(
                    title: "Avg Answer Time",
                    value: "\(days)",
                    icon: "clock.fill",
                    color: .orange,
                    subtitle: "days"
                )
                .padding(.horizontal)
            }
            
            // Prayer Status Chart
            if !prayers.isEmpty {
                PrayerStatusChart(prayers: prayers, themeManager: themeManager)
            }
            
            // Most Prayed Topics
            let topics = statsService.getMostPrayedTopics(prayers: prayers)
            if !topics.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Most Prayed Topics")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal)
                    
                    ForEach(Array(topics.enumerated()), id: \.offset) { index, topic in
                        HStack {
                            Text("#\(index + 1)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 30)
                            Text(topic.0)
                                .font(.subheadline)
                            Spacer()
                            Text("\(topic.1)")
                                .font(.headline)
                                .foregroundColor(themeManager.colors.primary)
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

// MARK: - Mood Tab

struct MoodTab: View {
    let moods: [MoodEntry]
    let allMoods: [MoodEntry]
    /// Must match the Statistics screen’s timeframe so charts and the consistency card match the range picker.
    let statsTimeframe: StatisticsService.Timeframe
    let statsService: StatisticsService
    let themeManager: ThemeManager

    /// Lowercase, for use inside sentences (empty states).
    private var statsTimeframeSubtitle: String {
        switch statsTimeframe {
        case .week: return "this week"
        case .month: return "this month"
        case .year: return "this year"
        case .all: return "all time"
        case .custom: return "this range"
        }
    }

    /// Aligned with the Statistics range picker: “This Week”, “This Month”, etc.
    private var statsTimeframeForCard: String {
        switch statsTimeframe {
        case .week: return "This week"
        case .month: return "This month"
        case .year: return "This year"
        case .all: return "All time"
        case .custom: return "Selected range"
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if allMoods.isEmpty {
                EmptyStateView(
                    icon: "face.smiling",
                    title: "No mood data yet",
                    message: "Log a mood check-in from Home or the Mood check-in to see statistics here"
                )
            } else if moods.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.clock",
                    title: "No check-ins in this period",
                    message: "You have mood history, but nothing logged for \(statsTimeframeSubtitle). Try “All Time” in the range picker above, or add new check-ins."
                )
            } else {
                let avgMood = Double(moods.reduce(0) { $0 + $1.intensity }) / Double(moods.count)
                let consistency = statsService.getMoodConsistency(entries: moods, timeframe: statsTimeframe)
                
                HStack(spacing: 16) {
                    StatCard(
                        title: "Average Mood",
                        value: String(format: "%.1f", avgMood),
                        icon: "face.smiling.fill",
                        color: .purple,
                        subtitle: "out of 10"
                    )
                    StatCard(
                        title: "Consistency",
                        value: "\(Int(consistency))%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .cyan,
                        subtitle: statsTimeframeForCard
                    )
                }
                .padding(.horizontal)
                
                // Mood Trend Chart
                let moodTrend = statsService.getMoodTrend(entries: moods, timeframe: statsTimeframe)
                if !moodTrend.isEmpty {
                    MoodTrendChart(moodTrend: moodTrend, themeManager: themeManager)
                }
            }
        }
    }
}

// MARK: - Reading Tab

struct ReadingTab: View {
    let plans: [ReadingPlan]
    let topics: [BibleStudyTopic]
    let statsService: StatisticsService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            let readingStats = statsService.getReadingPlansStats(plans: plans)
            let completedTopics = topics.filter { $0.isCompleted }.count
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Reading Plans",
                    value: "\(plans.count)",
                    icon: "book.closed.fill",
                    color: .orange,
                    subtitle: "\(readingStats.completed) completed"
                )
                StatCard(
                    title: "Total Readings",
                    value: "\(readingStats.totalReadings)",
                    icon: "text.book.closed.fill",
                    color: .blue,
                    subtitle: readingStats.formattedTotalTime
                )
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Bible Study Topics",
                    value: "\(topics.count)",
                    icon: "book.fill",
                    color: .indigo,
                    subtitle: "\(completedTopics) completed"
                )
                StatCard(
                    title: "Longest Streak",
                    value: "\(readingStats.longestStreak)",
                    icon: "flame.fill",
                    color: .red,
                    subtitle: "days"
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Bible Tab

struct BibleTab: View {
    let bookmarks: [BookmarkedVerse]
    let highlights: [BibleHighlight]
    let notes: [BibleNote]
    let statsService: StatisticsService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            let bibleStats = statsService.getBibleStats(
                bookmarks: bookmarks,
                highlights: highlights,
                notes: notes
            )
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Bookmarks",
                    value: "\(bibleStats.bookmarks)",
                    icon: "bookmark.fill",
                    color: .teal
                )
                StatCard(
                    title: "Highlights",
                    value: "\(bibleStats.highlights)",
                    icon: "highlighter",
                    color: .yellow
                )
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Notes",
                    value: "\(bibleStats.notes)",
                    icon: "note.text",
                    color: .blue
                )
                StatCard(
                    title: "Total",
                    value: "\(bibleStats.bookmarks + bibleStats.highlights + bibleStats.notes)",
                    icon: "book.fill",
                    color: .purple,
                    subtitle: "items"
                )
            }
            .padding(.horizontal)
            
            // Favorite Books
            if !bibleStats.favoriteBooks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Favorite Books")
                        .font(.headline)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal)
                    
                    ForEach(Array(bibleStats.favoriteBooks.prefix(5)), id: \.key) { book in
                        HStack {
                            Text(book.key)
                                .font(.subheadline)
                            Spacer()
                            Text("\(book.value)")
                                .font(.headline)
                                .foregroundColor(themeManager.colors.primary)
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

struct EngagementScoreCard: View {
    let score: EngagementScore
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Overall Engagement")
                    .font(.headline)
                    .font(.body.weight(.semibold))
                Spacer()
                Text("\(Int(score.overall))%")
                    .font(.title)
                    .font(.body.weight(.bold))
                    .foregroundColor(themeManager.colors.primary)
            }
            
            ProgressView(value: score.overall, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: themeManager.colors.primary))
            
            HStack(spacing: 12) {
                MiniScoreCard(title: "Journal", score: score.journaling, color: .blue)
                MiniScoreCard(title: "Prayer", score: score.prayer, color: .green)
                MiniScoreCard(title: "Mood", score: score.mood, color: .purple)
                MiniScoreCard(title: "Reading", score: score.reading, color: .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct MiniScoreCard: View {
    let title: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(Int(score))%")
                .font(.caption)
                .font(.body.weight(.semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EnhancedStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .font(.body.weight(.bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
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

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .font(.body.weight(.bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct PatternInfoCard: View {
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
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.headline)
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

struct InsightCard: View {
    let insight: StatisticInsight
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title2)
                .foregroundColor(colorForType(insight.type))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func colorForType(_ type: StatisticInsight.InsightType) -> Color {
        switch type {
        case .achievement: return .yellow
        case .pattern: return .blue
        case .positive: return .green
        case .warning: return .orange
        case .recommendation: return .purple
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text(title)
                .font(.title2)
                .font(.body.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Chart Views

struct EntriesOverTimeChart: View {
    let entries: [JournalEntry]
    let themeManager: ThemeManager
    
    var entriesPerMonth: [(month: Date, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date))!
        }
        return grouped.map { (month, entries) in
            (month: month, count: entries.count)
        }.sorted { $0.month < $1.month }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Entries Over Time")
                .font(.headline)
                .font(.body.weight(.semibold))
                .padding(.horizontal)
            
            Chart(entriesPerMonth, id: \.month) { data in
                BarMark(
                    x: .value("Month", data.month, unit: .month),
                    y: .value("Count", data.count)
                )
                .foregroundStyle(themeManager.colors.primary)
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
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal)
        }
    }
}

struct DayOfWeekChart: View {
    let distribution: [String: Int]
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity by Day of Week")
                .font(.headline)
                .font(.body.weight(.semibold))
                .padding(.horizontal)
            
            Chart(Array(distribution.sorted(by: { $0.value > $1.value })), id: \.key) { item in
                BarMark(
                    x: .value("Day", item.key),
                    y: .value("Count", item.value)
                )
                .foregroundStyle(themeManager.colors.primary)
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
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal)
        }
    }
}

struct EntryLengthChart: View {
    let entries: [JournalEntry]
    let themeManager: ThemeManager
    
    var lengthDistribution: [(range: String, count: Int)] {
        var ranges: [String: Int] = [
            "0-100": 0,
            "101-500": 0,
            "501-1000": 0,
            "1001-2000": 0,
            "2000+": 0
        ]
        
        for entry in entries {
            let wordCount = entry.content.split(separator: " ").count
            switch wordCount {
            case 0...100: ranges["0-100", default: 0] += 1
            case 101...500: ranges["101-500", default: 0] += 1
            case 501...1000: ranges["501-1000", default: 0] += 1
            case 1001...2000: ranges["1001-2000", default: 0] += 1
            default: ranges["2000+", default: 0] += 1
            }
        }
        
        return ranges.map { (range: $0.key, count: $0.value) }.sorted { $0.range < $1.range }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Entry Length Distribution")
                .font(.headline)
                .font(.body.weight(.semibold))
                .padding(.horizontal)
            
            Chart(lengthDistribution, id: \.range) { data in
                BarMark(
                    x: .value("Range", data.range),
                    y: .value("Count", data.count)
                )
                .foregroundStyle(themeManager.colors.primary)
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
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal)
        }
    }
}

struct PrayerStatusChart: View {
    let prayers: [PrayerRequest]
    let themeManager: ThemeManager
    
    var prayerStatusData: [(status: String, count: Int)] {
        [
            ("Answered", prayers.filter { $0.isAnswered }.count),
            ("Active", prayers.filter { $0.status == .active }.count),
            ("Archived", prayers.filter { $0.status == .archived }.count)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prayer Status")
                .font(.headline)
                .font(.body.weight(.semibold))
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
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal)
        }
    }
}

struct MoodTrendChart: View {
    let moodTrend: [Date: Double]
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Trend")
                .font(.headline)
                .font(.body.weight(.semibold))
                .padding(.horizontal)
            
            Chart(Array(moodTrend.sorted(by: { $0.key < $1.key })), id: \.key) { data in
                LineMark(
                    x: .value("Date", data.key, unit: .day),
                    y: .value("Mood", data.value)
                )
                .foregroundStyle(themeManager.colors.primary)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", data.key, unit: .day),
                    y: .value("Mood", data.value)
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
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day())
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
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal)
        }
    }
}

