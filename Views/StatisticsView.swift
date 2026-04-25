//
//  StatisticsView.swift
//  Faith Journal
//
//  Enhanced statistics view with all features
//

import SwiftUI
import SwiftData
import Charts

@available(iOS 17.0, macOS 14.0, *)
struct StatisticsView: View {
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
    
    private var tabPickerView: some View {
        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
            HStack(spacing: 12) {
                ForEach(StatsTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .font(.body.weight(.medium))
                            .foregroundColor(selectedTab == tab ? .white : Color.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTab == tab ? themeManager.colors.primary : Color.platformSystemGray6)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    var body: some View {
        if #available(iOS 17.0, macOS 14.0, *) {
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
                    
                    tabPickerView
                    
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
                        .macOSSheetFrameForm()
                }
                .sheet(isPresented: $showingHeatmap) {
                    ActivityHeatmapView(entries: allEntries, prayers: allPrayers, moods: allMoods, themeManager: themeManager)
                        .macOSSheetFrameStandard()
                }
                .sheet(isPresented: $showingAchievements) {
                    AchievementsView(achievementService: achievementService)
                        .macOSSheetFrameStandard()
                }
                .sheet(isPresented: $showingInsights) {
                    StatisticsInsightsView(
                        entries: allEntries,
                        prayers: allPrayers,
                        moods: allMoods,
                        plans: allPlans,
                        statsService: statsService
                    )
                    .macOSSheetFrameForm()
                }
                .sheet(isPresented: $showingExport) {
                    StatisticsExportView(
                        entries: allEntries,
                        prayers: allPrayers,
                        moods: allMoods,
                        plans: allPlans,
                        statsService: statsService
                    )
                    .macOSSheetFrameStandard()
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
