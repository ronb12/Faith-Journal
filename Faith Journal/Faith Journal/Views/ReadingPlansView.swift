//
//  ReadingPlansView.swift
//  Faith Journal
//
//  Bible reading plans feature
//
import SwiftUI
import SwiftData
import AVFoundation
import UserNotifications

// Ensure canonical types are used

// Use AppNavigation and BibleTarget from Sources/AppNavigation.swift

@available(iOS 17.0, *)
struct ReadingPlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ReadingPlan.startDate, order: .reverse)]) private var allPlans: [ReadingPlan]
    // Use regular property for singleton, not @StateObject
    private let readingPlanService = ReadingPlanService.shared
    @State private var showingCreatePlan = false
    @State private var selectedPlan: ReadingPlan?
    @State private var selectedCategory: String = "All"
    @State private var showingStatistics = false
    @State private var searchText = ""
    @State private var filterMode: PlanFilterMode = .all
    @State private var scrollToSection: String? = nil
    
    enum PlanFilterMode {
        case all
        case active
        case completed
        case streak
        case readings
    }
    
    var categories: [String] {
        ["All"] + Array(Set(readingPlanService.availablePlans.map { $0.category })).sorted()
    }
    
    var filteredPlans: [ReadingPlanTemplate] {
        var plans = readingPlanService.availablePlans
        
        if !searchText.isEmpty {
            plans = plans.filter { plan in
                plan.title.localizedCaseInsensitiveContains(searchText) ||
                plan.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if selectedCategory != "All" {
            plans = plans.filter { $0.category == selectedCategory }
        }
        
        return plans
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            NavigationStack {
                VStack(spacing: 0) {
                    // Statistics Header
                    if !allPlans.isEmpty {
                        StatisticsHeaderCard(
                            statistics: getOverallStatistics(plans: allPlans),
                            onActiveTap: {
                                filterMode = .active
                                scrollToSection = "active"
                            },
                            onCompletedTap: {
                                filterMode = .completed
                                scrollToSection = "completed"
                            },
                            onStreakTap: {
                                filterMode = .streak
                                scrollToSection = "active"
                            },
                            onReadingsTap: {
                                filterMode = .readings
                                scrollToSection = "active"
                            }
                        )
                        .padding()
                    }
                    
                    ScrollViewReader { proxy in
                        List {
                            // Available Plans
                            Section(header: HStack {
                                Text("Available Plans")
                                Spacer()
                                Menu {
                                    ForEach(categories, id: \.self) { category in
                                        Button(category) {
                                            selectedCategory = category
                                        }
                                    }
                                } label: {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                }
                            }) {
                                ForEach(filteredPlans, id: \.id) { planTemplate in
                                    NavigationLink(destination: PlanDetailView(planTemplate: planTemplate)) {
                                        EnhancedPlanRow(
                                            title: planTemplate.title,
                                            description: planTemplate.description,
                                            duration: planTemplate.duration,
                                            category: planTemplate.category,
                                            difficulty: planTemplate.difficulty
                                        )
                                    }
                                }
                            }

                            // Your Active Plans
                            if !activePlans.isEmpty && (filterMode == .all || filterMode == .active || filterMode == .streak || filterMode == .readings) {
                                Section(header: Text("Active Plans (\(activePlans.count))")) {
                                    ForEach(filteredActivePlans) { plan in
                                        NavigationLink(destination: ActivePlanDetailView(plan: plan)) {
                                            ActivePlanRow(plan: plan)
                                        }
                                    }
                                }
                                .id("active")
                            }

                            // Completed Plans
                            if !completedPlans.isEmpty && (filterMode == .all || filterMode == .completed) {
                                Section(header: Text("Completed Plans (\(completedPlans.count))")) {
                                    ForEach(completedPlans) { plan in
                                        NavigationLink(destination: ActivePlanDetailView(plan: plan)) {
                                            ActivePlanRow(plan: plan)
                                        }
                                    }
                                }
                                .id("completed")
                            }
                        }
                        .searchable(text: $searchText, prompt: "Search reading plans...")
                        .onChange(of: scrollToSection) { _, newValue in
                            if let section = newValue {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation {
                                        proxy.scrollTo(section, anchor: .top)
                                    }
                                    scrollToSection = nil
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Reading Plans")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingStatistics = true }) {
                            Image(systemName: "chart.bar.fill")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            if filterMode != .all {
                                Button(action: {
                                    filterMode = .all
                                }) {
                                    Text("Clear Filter")
                                        .font(.caption)
                                }
                            }
                            Button(action: { showingCreatePlan = true }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingCreatePlan) {
                    CreateReadingPlanView()
                }
                .sheet(isPresented: $showingStatistics) {
                    ReadingPlanStatisticsView(plans: allPlans)
                }
            }
        } else {
            Text("Reading Plans are only available on iOS 17+")
        }
    }

    var activePlans: [ReadingPlan] {
        allPlans.filter { !$0.isCompleted && !$0.isPaused }
    }
    
    var pausedPlans: [ReadingPlan] {
        allPlans.filter { $0.isPaused }
    }

    var completedPlans: [ReadingPlan] {
        allPlans.filter { $0.isCompleted }
    }
    
    var filteredActivePlans: [ReadingPlan] {
        let plans = activePlans
        
        switch filterMode {
        case .streak:
            // Show plans with active streaks, sorted by streak count
            return plans.filter { $0.streakCount > 0 }.sorted { $0.streakCount > $1.streakCount }
        case .readings:
            // Show plans sorted by total readings completed
            return plans.sorted { $0.completedReadingsCount > $1.completedReadingsCount }
        default:
            return plans
        }
    }
}

struct StatisticsHeaderCard: View {
    let statistics: ReadingPlanStatistics
    let onActiveTap: () -> Void
    let onCompletedTap: () -> Void
    let onStreakTap: () -> Void
    let onReadingsTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ReadingPlanStatCard(
                title: "Active",
                value: "\(statistics.activePlans)",
                icon: "book.fill",
                color: .blue,
                action: onActiveTap
            )
            ReadingPlanStatCard(
                title: "Completed",
                value: "\(statistics.completedPlans)",
                icon: "checkmark.circle.fill",
                color: .green,
                action: onCompletedTap
            )
            ReadingPlanStatCard(
                title: "Streak",
                value: "\(statistics.currentStreak)",
                icon: "flame.fill",
                color: .orange,
                action: onStreakTap
            )
            ReadingPlanStatCard(
                title: "Readings",
                value: "\(statistics.totalReadings)",
                icon: "text.book.closed.fill",
                color: .purple,
                action: onReadingsTap
            )
        }
    }
}

struct ReadingPlanStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
                action()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(value)
                    .font(.headline)
                    .font(.body.weight(.bold))
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EnhancedPlanRow: View {
    let title: String
    let description: String
    let duration: Int
    let category: String
    let difficulty: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                    Text(difficulty)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .foregroundColor(difficultyColor)
                        .cornerRadius(4)
                }
            }
            Text(description)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            Text("\(duration) days")
                .font(.caption)
                .foregroundColor(.purple)
        }
        .padding(.vertical, 4)
    }
    
    var difficultyColor: Color {
        switch difficulty {
        case "Beginner": return .green
        case "Intermediate": return .orange
        case "Advanced": return .red
        default: return .gray
        }
    }
}

@available(iOS 17.0, *)
struct PlanRow: View {
    let title: String
    let description: String
    let duration: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            Text("\(duration) days")
                .font(.caption)
                .foregroundColor(.purple)
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 17.0, *)
struct ActivePlanRow: View {
    let plan: ReadingPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.title)
                    .font(.headline)
                Spacer()
                if plan.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Text("Day \(plan.currentDay)/\(plan.duration)")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
            
            ProgressView(value: plan.progress)
                .tint(.purple)
            
            if !plan.isCompleted {
                Text("\(plan.daysRemaining) days remaining")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 17.0, *)
struct PlanDetailView: View {
    let planTemplate: ReadingPlanTemplate
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ReadingPlan.startDate, order: .reverse)]) private var allPlans: [ReadingPlan]
    @State private var showingStartPlan = false
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var showingDuplicateAlert = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(planTemplate.title)
                        .font(.largeTitle)
                        .font(.body.weight(.bold))
                    
                    Text(planTemplate.description)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label("\(planTemplate.duration) days", systemImage: "calendar")
                        Label("\(planTemplate.readings.count) readings", systemImage: "book")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Divider()
                
                Text("Reading Schedule")
                    .font(.headline)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(planTemplate.readings.prefix(7), id: \.day) { reading in
                            HStack {
                                Text("Day \(reading.day)")
                                    .font(.caption)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.purple)
                                    .frame(width: 60)
                                Text(reading.reference)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if planTemplate.readings.count > 7 {
                            Text("...and \(planTemplate.readings.count - 7) more days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 68)
                        }
                    }
                }
                
                Button(action: {
                    startPlan()
                }) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Start This Plan")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSaving ? Color.purple.opacity(0.6) : Color.purple)
                    .cornerRadius(12)
                }
                .disabled(isSaving)
            }
            .padding()
        }
        .navigationTitle("Plan Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Plan Already Active", isPresented: $showingDuplicateAlert) {
            Button("OK") { }
        } message: {
            Text("This reading plan is already active. You cannot add the same plan twice while it's still active.")
        }
        .alert("Plan Started!", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("You've successfully started the \"\(planTemplate.title)\" reading plan!")
        }
    }
    
    private func startPlan() {
        // Check if a plan with the same title is already active
        let activePlansWithSameTitle = allPlans.filter { existingPlan in
            existingPlan.title == planTemplate.title &&
            !existingPlan.isCompleted &&
            !existingPlan.isPaused
        }
        
        if !activePlansWithSameTitle.isEmpty {
            isSaving = false
            showingDuplicateAlert = true
            print("⚠️ [READING PLAN] Plan \"\(planTemplate.title)\" is already active")
            return
        }
        
        isSaving = true
        
        // Create the plan with proper initialization
        let plan = ReadingPlan(
            title: planTemplate.title,
            description: planTemplate.description,
            duration: planTemplate.duration,
            startDate: Date(),
            category: planTemplate.category,
            difficulty: planTemplate.difficulty,
            isCustom: false
        )
        
        // Set readings before inserting into context
        plan.readings = planTemplate.readings
        
        // Verify readings were set correctly
        guard !plan.readings.isEmpty else {
            isSaving = false
            errorMessage = "Failed to set readings for the plan. Please try again."
            showingError = true
            print("❌ Error: Readings array is empty after assignment")
            return
        }
        
        do {
            // Insert into context
            modelContext.insert(plan)
            
            // Save to persist
            try modelContext.save()
            
            print("✅ Successfully started plan: \(plan.title) with \(plan.readings.count) readings")
            
            // Sync to Firebase
            Task {
                await FirebaseSyncService.shared.syncReadingPlan(plan)
                print("✅ [FIREBASE] Reading plan synced to Firebase")
            }
            
            // Schedule reminder if needed (async, don't wait)
            if plan.reminderEnabled {
                Task {
                    let center = UNUserNotificationCenter.current()
                    let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                    if granted == true {
                        let content = UNMutableNotificationContent()
                        content.title = "📖 Time for Your Daily Reading"
                        content.body = "Don't forget to read \(plan.title) - Day \(plan.currentDay)"
                        content.sound = .default
                        
                        let calendar = Calendar.current
                        let components = calendar.dateComponents([.hour, .minute], from: plan.reminderTime)
                        var dateComponents = DateComponents()
                        dateComponents.hour = components.hour
                        dateComponents.minute = components.minute
                        
                        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                        let request = UNNotificationRequest(identifier: "readingPlan_\(plan.id.uuidString)", content: content, trigger: trigger)
                        try? await center.add(request)
                    }
                }
            }
            
            isSaving = false
            showingSuccess = true
        } catch {
            isSaving = false
            let errorMsg = "Failed to start reading plan: \(error.localizedDescription)"
            errorMessage = errorMsg
            showingError = true
            print("❌ Error starting reading plan: \(error)")
            print("   Full error: \(error)")
            
            // Try to undo the insert if save failed
            modelContext.delete(plan)
        }
    }
}

@available(iOS 17.0, *)
struct ActivePlanDetailView: View {
    let plan: ReadingPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Use regular property for singleton, not @StateObject
    private let bibleService = BibleService.shared
    @State private var selectedReading: DailyReading?
    @State private var showingSettings = false
    @State private var showingCalendar = false
    @State private var showingStatistics = false
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @EnvironmentObject private var nav: AppNavigation
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Progress Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(plan.title)
                        .font(.largeTitle)
                        .font(.body.weight(.bold))
                    
                    if !plan.isCompleted {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Day \(plan.currentDay) of \(plan.duration)")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(plan.progress * 100))% Complete")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: plan.progress)
                                .tint(.purple)
                        }
                    } else {
                        Text("Completed!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
                
                Divider()
                
                // Today's Reading - Prominently Displayed
                if let todayReading = plan.getTodayReading(), !plan.isCompleted {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.purple)
                                .font(.title2)
                            Text("Today's Reading")
                                .font(.title2)
                                .font(.body.weight(.bold))
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Day indicator
                            HStack {
                                Text("Day \(todayReading.day) of \(plan.duration)")
                                    .font(.subheadline)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.15))
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                if todayReading.isCompleted {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Completed")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.green)
                                }
                            }
                            
                            // Verse reference - Large and prominent
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Read:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Button(action: {
                                    if let (book, chapter, endChapter, verse) = parseReference(todayReading.reference) {
                                        // Set the bible target first
                                        nav.bibleTarget = BibleTarget(book: book, chapter: chapter, verse: verse, endChapter: endChapter)
                                        // Then navigate to More tab (where Bible is accessed)
                                        // This will trigger the onChange in MoreView to navigate to Bible
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            nav.selectedTab = 4 // More tab
                                        }
                                    }
                                }) {
                                    Text(todayReading.reference)
                                        .font(.title)
                                        .font(.body.weight(.bold))
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                            }
                            
                            // Description
                            if !todayReading.readingDescription.isEmpty {
                                Text(todayReading.readingDescription)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            
                            Divider()
                            
                            // Fetch and display verse text
                            if let verse = BibleService.shared.getAllLocalVerses().first(where: { verse in
                                verse.reference.lowercased().contains(todayReading.reference.lowercased()) ||
                                todayReading.reference.lowercased().contains(verse.reference.lowercased())
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "book.closed.fill")
                                            .foregroundColor(.purple)
                                        Text("Scripture")
                                            .font(.caption)
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                    }
                                    
                                    Text(verse.text)
                                        .font(.body)
                                        .lineSpacing(6)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.purple.opacity(0.08))
                                        .cornerRadius(12)
                                    
                                    Text("Translation: \(verse.translation)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                                .padding(.top, 8)
                            } else {
                                // Show reference even if verse not found locally
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "book.closed.fill")
                                            .foregroundColor(.purple)
                                        Text("Scripture Reference")
                                            .font(.caption)
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                    }
                                    
                                    Text("Please read: \(todayReading.reference)")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.purple.opacity(0.08))
                                        .cornerRadius(12)
                                }
                                .padding(.top, 8)
                            }
                            
                            // Mark complete button
                            Button(action: {
                                plan.markReadingComplete(todayReading.day)
                                do {
                                    try modelContext.save()
                                    
                                    // Sync to Firebase
                                    Task {
                                        await FirebaseSyncService.shared.syncReadingPlan(plan)
                                        print("✅ [FIREBASE] Reading plan update synced to Firebase")
                                    }
                                } catch {
                                    print("❌ Error marking reading complete: \(error.localizedDescription)")
                                    ErrorHandler.shared.handle(.saveFailed)
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: todayReading.isCompleted ? "checkmark.circle.fill" : "circle")
                                    Text(todayReading.isCompleted ? "Reading Completed" : "Mark as Complete")
                                    Spacer()
                                }
                                .font(.headline)
                                .foregroundColor(todayReading.isCompleted ? .green : .white)
                                .padding()
                                .background(todayReading.isCompleted ? Color.green.opacity(0.2) : Color.purple)
                                .cornerRadius(12)
                            }
                            .disabled(todayReading.isCompleted)
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                    }
                } else if plan.isCompleted {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Reading Plan Completed!")
                                .font(.title2)
                                .font(.body.weight(.bold))
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // Reading Schedule
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.purple)
                        Text("Reading Schedule")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(plan.readings, id: \.id) { reading in
                            let isToday = reading.day == plan.currentDay && !plan.isCompleted

                            HStack(spacing: 12) {
                                Image(systemName: reading.isCompleted ? "checkmark.circle.fill" : (isToday ? "circle.fill" : "circle"))
                                    .foregroundColor(reading.isCompleted ? .green : (isToday ? .purple : .secondary))
                                    .font(isToday ? .title3 : .body)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Day \(reading.day)")
                                            .font(.subheadline)
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(isToday ? .purple : .primary)

                                        if isToday {
                                            Text("TODAY")
                                                .font(.caption2)
                                                .font(.body.weight(.bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple)
                                                .cornerRadius(4)
                                        }
                                    }

                                    Button(action: {
                                        if let (book, chapter, endChapter, verse) = parseReference(reading.reference) {
                                            // Set the bible target first
                                            nav.bibleTarget = BibleTarget(book: book, chapter: chapter, verse: verse, endChapter: endChapter)
                                            // Then navigate to More tab (where Bible is accessed)
                                            // This will trigger the onChange in MoreView to navigate to Bible
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                nav.selectedTab = 4 // More tab
                                            }
                                        }
                                    }) {
                                        Text(reading.reference)
                                            .font(.subheadline)
                                            .font(.body.weight(isToday ? .semibold : .regular))
                                            .foregroundColor(.blue)
                                            .underline()
                                    }

                                    if !reading.readingDescription.isEmpty {
                                        Text(reading.readingDescription)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    if reading.isCompleted, let completedDate = reading.completedDate {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                            Text(completedDate, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        .padding(.top, 2)
                                    }
                                }

                                Spacer()
                            }
                            .padding()
                            .background(isToday ? Color.purple.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedReading = reading
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Reading Plan")
        .navigationBarTitleDisplayMode(.inline)
            .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingCalendar = true }) {
                        Label("Calendar", systemImage: "calendar")
                    }
                    Button(action: { showingStatistics = true }) {
                        Label("Statistics", systemImage: "chart.bar")
                    }
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gearshape")
                    }
                    Button(action: { showingShareSheet = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Plan", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Reading Plan", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePlan()
            }
        } message: {
            Text("Are you sure you want to delete \"\(plan.title)\"? This action cannot be undone.")
        }
        .sheet(item: $selectedReading) { reading in
            ReadingDetailView(reading: reading, plan: plan)
        }
        .sheet(isPresented: $showingCalendar) {
            ReadingPlanCalendarView(plan: plan)
        }
        .sheet(isPresented: $showingStatistics) {
            PlanStatisticsDetailView(plan: plan)
        }
        .sheet(isPresented: $showingSettings) {
            PlanSettingsView(plan: plan)
        }
        .sheet(isPresented: $showingShareSheet) {
            ReadingPlanShareSheet(activityItems: [plan.shareText])
        }
    }
    
    private func deletePlan() {
        isDeleting = true
        
        // Delete from SwiftData
        modelContext.delete(plan)
        
        do {
            try modelContext.save()
            print("✅ [READING PLAN] Deleted reading plan: \(plan.title)")
            
            // Delete from Firebase
            Task {
                await FirebaseSyncService.shared.deleteReadingPlan(plan)
                print("✅ [FIREBASE] Reading plan deleted from Firebase")
            }
            
            // Dismiss the view after deletion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dismiss()
            }
        } catch {
            print("❌ [READING PLAN] Failed to delete reading plan: \(error.localizedDescription)")
            isDeleting = false
            // Show error alert if needed
        }
    }
}

// Enhanced reference parser used by the reading plans view.
// Accepts formats like:
// - "John 3:16" (book, chapter, verse)
// - "John 3" (book, chapter)
// - "Psalm 1-10" (book, start chapter, end chapter)
// - "Psalm 1" (book, chapter)
// Returns: (book, startChapter, endChapter?, verse?)
fileprivate func parseReference(_ reference: String) -> (String, Int, Int?, Int?)? {
    let parts = reference.split(separator: " ")
    guard parts.count >= 2, let lastPart = parts.last else { return nil }

    let book = parts.dropLast().joined(separator: " ")
    let chapVerse = String(lastPart).trimmingCharacters(in: .whitespacesAndNewlines)

    // Handle verse reference like "3:16"
    if chapVerse.contains(":") {
        let cv = chapVerse.split(separator: ":")
        guard cv.count >= 2,
              let chapter = Int(cv[0].trimmingCharacters(in: .whitespaces)),
              let verse = Int(cv[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return (book, chapter, nil, verse)
    }
    // Handle chapter range like "1-10" or "1–10" (en dash or hyphen)
    else if chapVerse.contains("-") || chapVerse.contains("–") {
        let separator = chapVerse.contains("-") ? "-" : "–"
        let rangeParts = chapVerse.split(separator: Character(separator))
        guard rangeParts.count == 2,
              let startChapter = Int(rangeParts[0].trimmingCharacters(in: .whitespaces)),
              let endChapter = Int(rangeParts[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        // Return the range
        return (book, startChapter, endChapter, nil)
    }
    // Handle single chapter like "1"
    else {
        if let chapter = Int(chapVerse.trimmingCharacters(in: .whitespaces)) {
            return (book, chapter, nil, nil)
        }
    }
    return nil
}

@available(iOS 17.0, *)
struct ReadingDetailView: View {
    let reading: DailyReading
    let plan: ReadingPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Use regular property for singleton, not @StateObject
    private let bibleService = BibleService.shared
    @State private var audioService = InlineSpeechSynthesizer()
    @State private var verse: BibleVerse?
    @State private var isPlaying = false
    
    var isPlayingBinding: Binding<Bool> {
        Binding(
            get: { audioService.isSpeaking },
            set: { _ in }
        )
    }
    @State private var showingStudyTools = false
    @State private var reflection = ""
    @State private var notes = ""
    @State private var startTime: Date?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Day \(reading.day)")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.15))
                                .cornerRadius(6)
                            Spacer()
                            if !reading.isCompleted {
                                Button(action: { showingStudyTools = true }) {
                                    Image(systemName: "book.fill")
                                    Text("Study Tools")
                                }
                                .font(.caption)
                                .foregroundColor(.purple)
                            }
                        }
                        
                        Text(reading.reference)
                            .font(.title2)
                            .font(.body.weight(.bold))
                        
                        Text(reading.readingDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Audio Playback
                    if verse != nil {
                        HStack {
                            Button(action: toggleAudio) {
                                HStack {
                                    Image(systemName: audioService.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                                    Text(audioService.isSpeaking ? "Pause" : "Play Audio")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(10)
                            }
                            Spacer()
                        }
                    }
                    
                    if let verse = verse {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(verse.reference)
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            Text(verse.text)
                                .font(.body)
                                .lineSpacing(6)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text("Translation: \(verse.translation)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Looking up verse...")
                            .foregroundColor(.secondary)
                            .onAppear {
                                loadVerse()
                            }
                    }
                    
                    // Study Questions
                    if !reading.studyQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Study Questions")
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            ForEach(reading.studyQuestions, id: \.self) { question in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(.purple)
                                    Text(question)
                                        .font(.body)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(12)
                    }
                    
                    // Reflection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reflection")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        TextEditor(text: $reflection)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(12)
                    
                    if !reading.isCompleted {
                        Button(action: {
                            markComplete()
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark as Complete")
                                Spacer()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                    } else {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Completed")
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Daily Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { 
                        saveReflection()
                        dismiss() 
                    }
                }
            }
            .sheet(isPresented: $showingStudyTools) {
                StudyToolsView(reading: reading, reflection: $reflection, notes: $notes)
            }
            .onAppear {
                reflection = reading.reflection
                notes = reading.notes
                startTime = Date()
            }
        }
    }
    
    private func loadVerse() {
        verse = BibleService.shared.getAllLocalVerses().first { verse in
            verse.reference.lowercased().contains(reading.reference.lowercased())
        }
    }
    
    private func toggleAudio() {
        guard let verse = verse else { return }
        
        if audioService.isSpeaking {
            audioService.stop()
        } else {
            audioService.speak(verse.text)
        }
    }
    
    private func markComplete() {
        let readingTime = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        // Update reading with reflection and notes before marking complete
        var updatedReadings = plan.readings
        if let index = updatedReadings.firstIndex(where: { $0.day == reading.day }) {
            updatedReadings[index].reflection = reflection
            updatedReadings[index].notes = notes
            plan.readings = updatedReadings
        }
        
        plan.markReadingComplete(reading.day, readingTime: readingTime)
        
        do {
            try modelContext.save()
            
            // Sync to Firebase
            Task {
                await FirebaseSyncService.shared.syncReadingPlan(plan)
                print("✅ [FIREBASE] Reading plan update synced to Firebase")
            }
            
            dismiss()
        } catch {
            print("❌ Error marking reading complete: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.saveFailed)
        }
    }
    
    private func saveReflection() {
        var updatedReadings = plan.readings
        if let index = updatedReadings.firstIndex(where: { $0.day == reading.day }) {
            updatedReadings[index].reflection = reflection
            updatedReadings[index].notes = notes
            plan.readings = updatedReadings
            try? modelContext.save()
            
            // Sync to Firebase
            Task {
                await FirebaseSyncService.shared.syncReadingPlan(plan)
                print("✅ [FIREBASE] Reading plan reflection/notes synced to Firebase")
            }
        }
    }
}

// MARK: - Study Tools View
@available(iOS 17.0, *)
struct StudyToolsView: View {
    let reading: DailyReading
    @Binding var reflection: String
    @Binding var notes: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedQuestion: String?
    
    var studyQuestions: [String] {
        reading.studyQuestions.isEmpty ? generateDefaultQuestions() : reading.studyQuestions
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Study Questions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Study Questions")
                            .font(.title2)
                            .font(.body.weight(.bold))
                        
                        ForEach(studyQuestions, id: \.self) { question in
                            Button(action: {
                                selectedQuestion = question
                            }) {
                                HStack {
                                    Text(question)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    
                    // Reflection Prompts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reflection Prompts")
                            .font(.title2)
                            .font(.body.weight(.bold))
                        
                        Text("What stood out to you in this reading?")
                            .font(.body)
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                        
                        Text("How can you apply this to your life today?")
                            .font(.body)
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding()
                    
                    // Notes Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                        
                        TextEditor(text: $notes)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }
            .navigationTitle("Study Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func generateDefaultQuestions() -> [String] {
        return [
            "What is the main message of this passage?",
            "What does this teach us about God?",
            "How does this apply to my life?",
            "What questions does this raise?",
            "What action can I take based on this reading?"
        ]
    }
}

@available(iOS 17.0, *)
struct CreateReadingPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ReadingPlan.startDate, order: .reverse)]) private var allPlans: [ReadingPlan]
    @State private var title = ""
    @State private var description = ""
    @State private var duration = 30
    @State private var category = "General"
    @State private var difficulty = "Beginner"
    @State private var readings: [DailyReading] = []
    @State private var showingAddReading = false
    @State private var newReadingReference = ""
    @State private var newReadingDescription = ""
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var showingDuplicateAlert = false
    @State private var errorMessage = ""
    @State private var isCreating = false
    
    let categories = ["General", "Devotional", "Overview", "Gospels", "Wisdom", "Complete Bible", "Chronological", "Old Testament", "New Testament", "Topical", "Character Study", "Seasonal"]
    let difficulties = ["Beginner", "Intermediate", "Advanced"]
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                scrollContent
            }
            .navigationTitle("Create Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddReading) {
                AddReadingView(
                    day: readings.count + 1,
                    onAdd: { reference, description in
                        readings.append(DailyReading(day: readings.count + 1, reference: reference, description: description))
                        updateDayNumbers()
                    }
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Plan Already Active", isPresented: $showingDuplicateAlert) {
                Button("OK") { }
            } message: {
                Text("This reading plan is already active. You cannot add the same plan twice while it's still active.")
            }
            .alert("Plan Created!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your custom reading plan \"\(title)\" has been created successfully!")
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard
                planDetailsCard
                readingsCard
                createButton
            }
            .padding()
        }
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.purple)
                Text("Create Custom Plan")
                    .font(.title2)
                    .font(.body.weight(.bold))
            }
            Text("Build your own personalized Bible reading plan")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }
    
    private var planDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan Details")
                .font(.headline)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 12) {
                TextField("Plan Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                
                TextField("Description (optional)", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                HStack {
                    Text("Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Stepper("\(duration) days", value: $duration, in: 7...365)
                }
                
                HStack {
                    Text("Category")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text("Difficulty")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(difficulties, id: \.self) { diff in
                            Text(diff).tag(diff)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding()
        .background(cardBackground)
    }
    
    private var readingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Readings")
                    .font(.headline)
                    .foregroundColor(.purple)
                Spacer()
                Text("\(readings.count)")
                    .font(.headline)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(8)
            }
            
            if readings.isEmpty {
                emptyReadingsView
            } else {
                readingsList
            }
            
            addReadingButton
        }
        .padding()
        .background(cardBackground)
    }
    
    private var emptyReadingsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No readings added yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Tap 'Add Reading' to get started")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var readingsList: some View {
        VStack(spacing: 8) {
            ForEach(readings.sorted(by: { $0.day < $1.day }), id: \.id) { reading in
                readingRow(reading)
            }
        }
    }
    
    private func readingRow(_ reading: DailyReading) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Day \(reading.day)")
                        .font(.subheadline)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.purple)
                    Spacer()
                    Button(action: {
                        if let index = readings.firstIndex(where: { $0.id == reading.id }) {
                            readings.remove(at: index)
                            updateDayNumbers()
                        }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                Text(reading.reference)
                    .font(.body)
                    .foregroundColor(.blue)
                if !reading.readingDescription.isEmpty {
                    Text(reading.readingDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var addReadingButton: some View {
        Button(action: {
            showingAddReading = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Reading")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }
    
    private var createButton: some View {
        Button(action: {
            createPlan()
        }) {
            HStack {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Create Plan")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(createButtonBackground)
            .cornerRadius(12)
            .shadow(color: createButtonShadow, radius: 8, x: 0, y: 4)
        }
        .disabled(title.isEmpty || readings.isEmpty || isCreating)
        .padding(.bottom)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var createButtonBackground: some View {
        Group {
            if title.isEmpty || readings.isEmpty {
                Color.gray
            } else {
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }
    
    private var createButtonShadow: Color {
        (title.isEmpty || readings.isEmpty) ? .clear : .purple.opacity(0.3)
    }
    
    private func updateDayNumbers() {
        for (index, _) in readings.enumerated() {
            readings[index] = DailyReading(day: index + 1, reference: readings[index].reference, description: readings[index].readingDescription)
        }
    }
    
    private func createPlan() {
        guard !title.isEmpty, !readings.isEmpty else {
            errorMessage = "Please fill in all required fields and add at least one reading."
            showingError = true
            return
        }
        
        // Check if a plan with the same title is already active
        let activePlansWithSameTitle = allPlans.filter { existingPlan in
            existingPlan.title == title &&
            !existingPlan.isCompleted &&
            !existingPlan.isPaused
        }
        
        if !activePlansWithSameTitle.isEmpty {
            isCreating = false
            showingDuplicateAlert = true
            print("⚠️ [READING PLAN] Plan \"\(title)\" is already active")
            return
        }
        
        isCreating = true
        
        // Use actual readings count or duration, whichever is smaller
        let finalReadings = Array(readings.prefix(duration))
        let actualDuration = max(finalReadings.count, duration)
        
        let plan = ReadingPlan(
            title: title,
            description: description,
            duration: actualDuration,
            startDate: Date(),
            category: category,
            difficulty: difficulty,
            isCustom: true
        )
        
        plan.readings = finalReadings
        
        do {
            modelContext.insert(plan)
            try modelContext.save()
            
            // Sync to Firebase
            Task {
                await FirebaseSyncService.shared.syncReadingPlan(plan)
                print("✅ [FIREBASE] Reading plan synced to Firebase")
            }
            
            isCreating = false
            showingSuccess = true
        } catch {
            isCreating = false
            errorMessage = "Failed to create plan: \(error.localizedDescription)"
            showingError = true
            modelContext.delete(plan)
        }
    }
}

struct AddReadingView: View {
    let day: Int
    let onAdd: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reference = ""
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reading Details")) {
                    Text("Day \(day)")
                        .font(.headline)
                    TextField("Bible Reference (e.g., John 3:16)", text: $reference)
                    TextField("Description (optional)", text: $description)
                        .lineLimit(4)
                }
            }
            .navigationTitle("Add Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(reference, description)
                        dismiss()
                    }
                    .disabled(reference.isEmpty)
                }
            }
        }
    }
}

// Reading Plan Service
struct ReadingPlanTemplate: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let duration: Int
    let readings: [DailyReading]
    let category: String
    let difficulty: String
    
    init(title: String, description: String, duration: Int, readings: [DailyReading], category: String = "General", difficulty: String = "Beginner") {
        self.title = title
        self.description = description
        self.duration = duration
        self.readings = readings
        self.category = category
        self.difficulty = difficulty
    }
}

@available(iOS 17.0, *)
class ReadingPlanService: ObservableObject {
    static let shared = ReadingPlanService()
    
    let availablePlans: [ReadingPlanTemplate]
    
    private init() {
        availablePlans = [
            // Beginner Plans
            ReadingPlanTemplate(
                title: "7-Day Psalms",
                description: "Explore the book of Psalms over 7 days",
                duration: 7,
                readings: Self.create7DayPsalmsPlan(),
                category: "Devotional",
                difficulty: "Beginner"
            ),
            ReadingPlanTemplate(
                title: "30-Day New Testament Overview",
                description: "Read through key passages from the New Testament in 30 days",
                duration: 30,
                readings: Self.create30DayNewTestamentPlan(),
                category: "Overview",
                difficulty: "Beginner"
            ),
            ReadingPlanTemplate(
                title: "Gospel of John - 21 Days",
                description: "Read through the Gospel of John chapter by chapter",
                duration: 21,
                readings: Self.createJohnGospelPlan(),
                category: "Gospels",
                difficulty: "Beginner"
            ),
            ReadingPlanTemplate(
                title: "Proverbs - 31 Days",
                description: "Read one chapter of Proverbs each day for 31 days",
                duration: 31,
                readings: Self.createProverbsPlan(),
                category: "Wisdom",
                difficulty: "Beginner"
            ),
            
            // Intermediate Plans
            ReadingPlanTemplate(
                title: "Bible in 90 Days",
                description: "Read through the entire Bible in 90 days",
                duration: 90,
                readings: Self.create90DayBiblePlan(),
                category: "Complete Bible",
                difficulty: "Intermediate"
            ),
            ReadingPlanTemplate(
                title: "Bible in 1 Year",
                description: "Read through the entire Bible in 365 days",
                duration: 365,
                readings: Self.create365DayBiblePlan(),
                category: "Complete Bible",
                difficulty: "Intermediate"
            ),
            ReadingPlanTemplate(
                title: "Chronological Bible - 365 Days",
                description: "Read the Bible in chronological order over one year",
                duration: 365,
                readings: Self.createChronologicalPlan(),
                category: "Chronological",
                difficulty: "Intermediate"
            ),
            ReadingPlanTemplate(
                title: "Old Testament in 60 Days",
                description: "Read through the Old Testament in 60 days",
                duration: 60,
                readings: Self.createOldTestamentPlan(),
                category: "Old Testament",
                difficulty: "Intermediate"
            ),
            ReadingPlanTemplate(
                title: "New Testament in 30 Days",
                description: "Read through the entire New Testament in 30 days",
                duration: 30,
                readings: Self.createNewTestamentPlan(),
                category: "New Testament",
                difficulty: "Intermediate"
            ),
            
            // Topical Plans
            ReadingPlanTemplate(
                title: "Prayer & Faith - 14 Days",
                description: "Explore verses about prayer and faith",
                duration: 14,
                readings: Self.createPrayerFaithPlan(),
                category: "Topical",
                difficulty: "Beginner"
            ),
            ReadingPlanTemplate(
                title: "Love & Relationships - 14 Days",
                description: "Study what the Bible says about love and relationships",
                duration: 14,
                readings: Self.createLoveRelationshipsPlan(),
                category: "Topical",
                difficulty: "Beginner"
            ),
            ReadingPlanTemplate(
                title: "Hope & Encouragement - 14 Days",
                description: "Find hope and encouragement in God's Word",
                duration: 14,
                readings: Self.createHopeEncouragementPlan(),
                category: "Topical",
                difficulty: "Beginner"
            ),
            
            // Character Studies
            ReadingPlanTemplate(
                title: "Life of David - 14 Days",
                description: "Study the life and faith of King David",
                duration: 14,
                readings: Self.createDavidPlan(),
                category: "Character Study",
                difficulty: "Intermediate"
            ),
            ReadingPlanTemplate(
                title: "Life of Paul - 14 Days",
                description: "Follow the journey of the Apostle Paul",
                duration: 14,
                readings: Self.createPaulPlan(),
                category: "Character Study",
                difficulty: "Intermediate"
            ),
            
            // Seasonal Plans
            ReadingPlanTemplate(
                title: "Advent - 25 Days",
                description: "Prepare your heart for Christmas with daily readings",
                duration: 25,
                readings: Self.createAdventPlan(),
                category: "Seasonal",
                difficulty: "Beginner"
            ),
            ReadingPlanTemplate(
                title: "Lent - 40 Days",
                description: "Journey through Lent with daily Scripture readings",
                duration: 40,
                readings: Self.createLentPlan(),
                category: "Seasonal",
                difficulty: "Beginner"
            )
        ]
    }
    
    private static func create30DayNewTestamentPlan() -> [DailyReading] {
        let readings = [
            DailyReading(day: 1, reference: "Matthew 1-3", description: "The Birth of Jesus"),
            DailyReading(day: 2, reference: "Matthew 5-7", description: "The Sermon on the Mount"),
            DailyReading(day: 3, reference: "Matthew 28", description: "The Great Commission"),
            DailyReading(day: 4, reference: "Mark 1-2", description: "Jesus Begins His Ministry"),
            DailyReading(day: 5, reference: "Mark 16", description: "The Resurrection"),
            DailyReading(day: 6, reference: "Luke 1-2", description: "The Birth Narratives"),
            DailyReading(day: 7, reference: "Luke 15", description: "Parables of Lost Things"),
            DailyReading(day: 8, reference: "Luke 23-24", description: "The Crucifixion and Resurrection"),
            DailyReading(day: 9, reference: "John 1", description: "In the Beginning"),
            DailyReading(day: 10, reference: "John 3", description: "Born Again"),
            DailyReading(day: 11, reference: "John 14-15", description: "The Farewell Discourse"),
            DailyReading(day: 12, reference: "John 20-21", description: "The Resurrection Appearances"),
            DailyReading(day: 13, reference: "Acts 1-2", description: "The Ascension and Pentecost"),
            DailyReading(day: 14, reference: "Acts 9", description: "The Conversion of Saul"),
            DailyReading(day: 15, reference: "Acts 16-17", description: "Paul's Missionary Journeys"),
            DailyReading(day: 16, reference: "Romans 1-2", description: "The Gospel of God"),
            DailyReading(day: 17, reference: "Romans 8", description: "Life in the Spirit"),
            DailyReading(day: 18, reference: "Romans 12", description: "Living Sacrifices"),
            DailyReading(day: 19, reference: "1 Corinthians 13", description: "The Love Chapter"),
            DailyReading(day: 20, reference: "1 Corinthians 15", description: "The Resurrection Chapter"),
            DailyReading(day: 21, reference: "Galatians 5", description: "Freedom in Christ"),
            DailyReading(day: 22, reference: "Ephesians 2", description: "Saved by Grace"),
            DailyReading(day: 23, reference: "Ephesians 6", description: "The Armor of God"),
            DailyReading(day: 24, reference: "Philippians 4", description: "Rejoice in the Lord"),
            DailyReading(day: 25, reference: "Colossians 3", description: "Set Your Hearts Above"),
            DailyReading(day: 26, reference: "1 Thessalonians 4-5", description: "The Second Coming"),
            DailyReading(day: 27, reference: "1 Timothy 4", description: "A Good Servant"),
            DailyReading(day: 28, reference: "Hebrews 11", description: "Faith Hall of Fame"),
            DailyReading(day: 29, reference: "James 1", description: "Trials and Temptations"),
            DailyReading(day: 30, reference: "Revelation 21-22", description: "The New Jerusalem")
        ]
        return readings
    }
    
    private static func create90DayBiblePlan() -> [DailyReading] {
        // 90-day Bible reading plan covering all 66 books
        let readings: [DailyReading] = [
            // Days 1-12: Genesis
            DailyReading(day: 1, reference: "Genesis 1-8", description: "Creation, the Fall, and the Flood"),
            DailyReading(day: 2, reference: "Genesis 9-16", description: "Noah's Covenant, Tower of Babel, Abraham's Call"),
            DailyReading(day: 3, reference: "Genesis 17-24", description: "Covenant with Abraham, Sodom and Gomorrah, Isaac's Birth"),
            DailyReading(day: 4, reference: "Genesis 25-33", description: "Jacob and Esau, Jacob's Journey"),
            DailyReading(day: 5, reference: "Genesis 34-41", description: "Dinah, Jacob Returns, Joseph in Egypt"),
            DailyReading(day: 6, reference: "Genesis 42-50", description: "Joseph Reunited with Family"),
            
            // Days 7-9: Exodus
            DailyReading(day: 7, reference: "Exodus 1-13", description: "Moses' Birth, The Exodus from Egypt"),
            DailyReading(day: 8, reference: "Exodus 14-24", description: "Crossing the Red Sea, The Ten Commandments"),
            DailyReading(day: 9, reference: "Exodus 25-40", description: "The Tabernacle and God's Presence"),
            
            // Days 10-11: Leviticus
            DailyReading(day: 10, reference: "Leviticus 1-15", description: "Laws for Offerings and Purity"),
            DailyReading(day: 11, reference: "Leviticus 16-27", description: "Day of Atonement, Holy Living"),
            
            // Days 12-13: Numbers
            DailyReading(day: 12, reference: "Numbers 1-14", description: "Census, Spies, Rebellion"),
            DailyReading(day: 13, reference: "Numbers 15-36", description: "Wandering in the Wilderness"),
            
            // Days 14-16: Deuteronomy
            DailyReading(day: 14, reference: "Deuteronomy 1-11", description: "Moses Recounts Israel's History"),
            DailyReading(day: 15, reference: "Deuteronomy 12-26", description: "Laws and Instructions"),
            DailyReading(day: 16, reference: "Deuteronomy 27-34", description: "Blessings, Curses, Moses' Death"),
            
            // Days 17-20: Joshua through Judges
            DailyReading(day: 17, reference: "Joshua 1-12", description: "Conquest of the Promised Land"),
            DailyReading(day: 18, reference: "Joshua 13-24", description: "Division of the Land"),
            DailyReading(day: 19, reference: "Judges 1-12", description: "Judges Lead Israel"),
            DailyReading(day: 20, reference: "Judges 13-21", description: "Samson and Civil War"),
            
            // Days 21-23: Ruth and 1 Samuel
            DailyReading(day: 21, reference: "Ruth 1-4", description: "Ruth's Faithfulness and Redemption"),
            DailyReading(day: 22, reference: "1 Samuel 1-15", description: "Samuel, Saul Anointed as King"),
            DailyReading(day: 23, reference: "1 Samuel 16-31", description: "David Anointed, Saul's Downfall"),
            
            // Days 24-26: 2 Samuel and 1 Kings
            DailyReading(day: 24, reference: "2 Samuel 1-12", description: "David's Reign, David and Bathsheba"),
            DailyReading(day: 25, reference: "2 Samuel 13-24", description: "David's Family Troubles"),
            DailyReading(day: 26, reference: "1 Kings 1-11", description: "Solomon's Wisdom and Temple"),
            
            // Days 27-28: 1 Kings and 2 Kings
            DailyReading(day: 27, reference: "1 Kings 12-22", description: "Kingdom Divides, Prophets"),
            DailyReading(day: 28, reference: "2 Kings 1-17", description: "Elisha, Israel Falls to Assyria"),
            
            // Days 29-30: 2 Kings and 1 Chronicles
            DailyReading(day: 29, reference: "2 Kings 18-25", description: "Judah Falls to Babylon"),
            DailyReading(day: 30, reference: "1 Chronicles 1-17", description: "Genealogies, David's Reign"),
            
            // Days 31-32: 1 & 2 Chronicles
            DailyReading(day: 31, reference: "1 Chronicles 18-29", description: "David Prepares for Temple"),
            DailyReading(day: 32, reference: "2 Chronicles 1-18", description: "Solomon's Temple, Divided Kingdom"),
            
            // Days 33-34: 2 Chronicles, Ezra, Nehemiah
            DailyReading(day: 33, reference: "2 Chronicles 19-36", description: "Kings of Judah, Exile"),
            DailyReading(day: 34, reference: "Ezra 1-10", description: "Return from Exile, Rebuilding Temple"),
            
            // Days 35-36: Nehemiah and Esther
            DailyReading(day: 35, reference: "Nehemiah 1-13", description: "Rebuilding the Wall of Jerusalem"),
            DailyReading(day: 36, reference: "Esther 1-10", description: "Esther Saves Her People"),
            
            // Days 37-39: Job
            DailyReading(day: 37, reference: "Job 1-14", description: "Job's Suffering and Questions"),
            DailyReading(day: 38, reference: "Job 15-31", description: "Job's Friends Speak"),
            DailyReading(day: 39, reference: "Job 32-42", description: "God Answers Job"),
            
            // Days 40-44: Psalms
            DailyReading(day: 40, reference: "Psalms 1-18", description: "Psalms of Worship and Trust"),
            DailyReading(day: 41, reference: "Psalms 19-35", description: "Psalms of Praise and Lament"),
            DailyReading(day: 42, reference: "Psalms 36-52", description: "Psalms of Confidence in God"),
            DailyReading(day: 43, reference: "Psalms 53-72", description: "Psalms of Deliverance"),
            DailyReading(day: 44, reference: "Psalms 73-89", description: "Psalms of God's Faithfulness"),
            
            // Days 45-47: Psalms, Proverbs
            DailyReading(day: 45, reference: "Psalms 90-106", description: "Psalms of God's Sovereignty"),
            DailyReading(day: 46, reference: "Psalms 107-119", description: "Psalms of Thanksgiving and Law"),
            DailyReading(day: 47, reference: "Psalms 120-150", description: "Songs of Ascent, Final Praise"),
            
            // Days 48-51: Proverbs
            DailyReading(day: 48, reference: "Proverbs 1-8", description: "Wisdom and Understanding"),
            DailyReading(day: 49, reference: "Proverbs 9-16", description: "Wise Living and Folly"),
            DailyReading(day: 50, reference: "Proverbs 17-24", description: "Sayings of the Wise"),
            DailyReading(day: 51, reference: "Proverbs 25-31", description: "More Proverbs, The Excellent Wife"),
            
            // Days 52-53: Ecclesiastes and Song of Songs
            DailyReading(day: 52, reference: "Ecclesiastes 1-12", description: "The Meaning of Life Under the Sun"),
            DailyReading(day: 53, reference: "Song of Songs 1-8", description: "Love Song of Solomon"),
            
            // Days 54-58: Isaiah
            DailyReading(day: 54, reference: "Isaiah 1-12", description: "Judgment and Hope for Israel"),
            DailyReading(day: 55, reference: "Isaiah 13-27", description: "Prophecies Against Nations"),
            DailyReading(day: 56, reference: "Isaiah 28-39", description: "Warnings to Judah"),
            DailyReading(day: 57, reference: "Isaiah 40-52", description: "Comfort and the Coming Messiah"),
            DailyReading(day: 58, reference: "Isaiah 53-66", description: "Suffering Servant, New Heavens and Earth"),
            
            // Days 59-62: Jeremiah
            DailyReading(day: 59, reference: "Jeremiah 1-15", description: "Jeremiah's Call and Early Prophecies"),
            DailyReading(day: 60, reference: "Jeremiah 16-29", description: "Judgment and Restoration Promised"),
            DailyReading(day: 61, reference: "Jeremiah 30-45", description: "New Covenant, Fall of Jerusalem"),
            DailyReading(day: 62, reference: "Jeremiah 46-52", description: "Prophecies Against Nations"),
            
            // Days 63-64: Lamentations and Ezekiel
            DailyReading(day: 63, reference: "Lamentations 1-5", description: "Mourning Over Jerusalem's Destruction"),
            DailyReading(day: 64, reference: "Ezekiel 1-16", description: "Ezekiel's Vision, Judgment on Israel"),
            
            // Days 65-67: Ezekiel
            DailyReading(day: 65, reference: "Ezekiel 17-32", description: "Prophecies of Judgment"),
            DailyReading(day: 66, reference: "Ezekiel 33-39", description: "Watchman, Dry Bones, Restoration"),
            DailyReading(day: 67, reference: "Ezekiel 40-48", description: "Vision of New Temple"),
            
            // Days 68-70: Daniel and Minor Prophets
            DailyReading(day: 68, reference: "Daniel 1-6", description: "Daniel in Babylon, Fiery Furnace"),
            DailyReading(day: 69, reference: "Daniel 7-12", description: "Daniel's Visions and Prophecies"),
            DailyReading(day: 70, reference: "Hosea 1-14, Joel 1-3", description: "Hosea's Marriage, Joel's Prophecy"),
            
            // Days 71-73: Minor Prophets
            DailyReading(day: 71, reference: "Amos 1-9, Obadiah 1", description: "Amos and Obadiah's Prophecies"),
            DailyReading(day: 72, reference: "Jonah 1-4, Micah 1-7", description: "Jonah and the Great Fish, Micah"),
            DailyReading(day: 73, reference: "Nahum 1-3, Habakkuk 1-3, Zephaniah 1-3", description: "Prophecies of Judgment and Hope"),
            
            // Days 74-75: Haggai, Zechariah, Malachi
            DailyReading(day: 74, reference: "Haggai 1-2, Zechariah 1-8", description: "Rebuilding the Temple"),
            DailyReading(day: 75, reference: "Zechariah 9-14, Malachi 1-4", description: "Messianic Prophecies, Final Message"),
            
            // Days 76-78: Matthew
            DailyReading(day: 76, reference: "Matthew 1-9", description: "Birth of Jesus, Early Ministry"),
            DailyReading(day: 77, reference: "Matthew 10-18", description: "Sermon on the Mount, Miracles"),
            DailyReading(day: 78, reference: "Matthew 19-28", description: "Teaching, Crucifixion, Resurrection"),
            
            // Days 79-80: Mark
            DailyReading(day: 79, reference: "Mark 1-9", description: "Jesus' Ministry Begins"),
            DailyReading(day: 80, reference: "Mark 10-16", description: "Teaching, Death, and Resurrection"),
            
            // Days 81-82: Luke
            DailyReading(day: 81, reference: "Luke 1-12", description: "Birth Narratives, Early Ministry"),
            DailyReading(day: 82, reference: "Luke 13-24", description: "Teaching, Parables, Resurrection"),
            
            // Days 83-84: John
            DailyReading(day: 83, reference: "John 1-12", description: "In the Beginning, Jesus' Signs"),
            DailyReading(day: 84, reference: "John 13-21", description: "Last Supper, Crucifixion, Resurrection"),
            
            // Days 85-86: Acts
            DailyReading(day: 85, reference: "Acts 1-14", description: "Early Church, Peter's Ministry"),
            DailyReading(day: 86, reference: "Acts 15-28", description: "Paul's Missionary Journeys"),
            
            // Days 87-88: Romans and 1 Corinthians
            DailyReading(day: 87, reference: "Romans 1-16", description: "The Gospel and Righteousness by Faith"),
            DailyReading(day: 88, reference: "1 Corinthians 1-16", description: "Church Issues and Love Chapter"),
            
            // Days 89-90: Remaining Epistles and Revelation
            DailyReading(day: 89, reference: "2 Corinthians 1-13, Galatians 1-6, Ephesians 1-6", description: "Paul's Letters to Churches"),
            DailyReading(day: 90, reference: "Philippians 1-4, Colossians 1-4, 1 Thessalonians 1-5, 2 Thessalonians 1-3, 1 Timothy 1-6, 2 Timothy 1-4, Titus 1-3, Philemon 1, Hebrews 1-13, James 1-5, 1 Peter 1-5, 2 Peter 1-3, 1 John 1-5, 2 John 1, 3 John 1, Jude 1, Revelation 1-22", description: "Remaining Epistles and Revelation - The Final Victory!")
        ]
        return readings
    }
    
    private static func create7DayPsalmsPlan() -> [DailyReading] {
        return [
            DailyReading(day: 1, reference: "Psalm 1-10", description: "Blessings of the Righteous"),
            DailyReading(day: 2, reference: "Psalm 23-25", description: "The Lord is My Shepherd"),
            DailyReading(day: 3, reference: "Psalm 27-30", description: "Trust in the Lord"),
            DailyReading(day: 4, reference: "Psalm 37-40", description: "Wait on the Lord"),
            DailyReading(day: 5, reference: "Psalm 46-50", description: "God is Our Refuge"),
            DailyReading(day: 6, reference: "Psalm 91-100", description: "God's Protection and Praise"),
            DailyReading(day: 7, reference: "Psalm 103-107", description: "Praise the Lord")
        ]
    }
    
    private static func createJohnGospelPlan() -> [DailyReading] {
        var readings: [DailyReading] = []
        for chapter in 1...21 {
            readings.append(DailyReading(day: chapter, reference: "John \(chapter)", description: "Gospel of John Chapter \(chapter)"))
        }
        return readings
    }
    
    private static func createProverbsPlan() -> [DailyReading] {
        var readings: [DailyReading] = []
        for chapter in 1...31 {
            readings.append(DailyReading(day: chapter, reference: "Proverbs \(chapter)", description: "Wisdom from Proverbs Chapter \(chapter)"))
        }
        return readings
    }
    
    // MARK: - Additional Plan Templates
    
    private static func create365DayBiblePlan() -> [DailyReading] {
        // Simplified 365-day plan - in production, this would have all 66 books properly distributed
        var readings: [DailyReading] = []
        var day = 1
        
        // Old Testament (approximately 240 days)
        let oldTestamentBooks = [
            ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36), ("Deuteronomy", 34),
            ("Joshua", 24), ("Judges", 21), ("Ruth", 4), ("1 Samuel", 31), ("2 Samuel", 24),
            ("1 Kings", 22), ("2 Kings", 25), ("1 Chronicles", 29), ("2 Chronicles", 36), ("Ezra", 10),
            ("Nehemiah", 13), ("Esther", 10), ("Job", 42), ("Psalm", 150), ("Proverbs", 31),
            ("Ecclesiastes", 12), ("Song of Solomon", 8), ("Isaiah", 66), ("Jeremiah", 52), ("Lamentations", 5),
            ("Ezekiel", 48), ("Daniel", 12), ("Hosea", 14), ("Joel", 3), ("Amos", 9),
            ("Obadiah", 1), ("Jonah", 4), ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3),
            ("Zephaniah", 3), ("Haggai", 2), ("Zechariah", 14), ("Malachi", 4)
        ]
        
        for (book, chapters) in oldTestamentBooks {
            if chapters <= 5 {
                readings.append(DailyReading(day: day, reference: "\(book) 1-\(chapters)", description: "\(book)"))
                day += 1
            } else {
                let chunks = (chapters + 4) / 5 // Divide into ~5 chapter chunks
                for i in 0..<chunks {
                    let start = i * 5 + 1
                    let end = min((i + 1) * 5, chapters)
                    readings.append(DailyReading(day: day, reference: "\(book) \(start)-\(end)", description: "\(book) Chapters \(start)-\(end)"))
                    day += 1
                }
            }
        }
        
        // New Testament (approximately 125 days)
        let newTestamentBooks = [
            ("Matthew", 28), ("Mark", 16), ("Luke", 24), ("John", 21), ("Acts", 28),
            ("Romans", 16), ("1 Corinthians", 16), ("2 Corinthians", 13), ("Galatians", 6), ("Ephesians", 6),
            ("Philippians", 4), ("Colossians", 4), ("1 Thessalonians", 5), ("2 Thessalonians", 3), ("1 Timothy", 6),
            ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1), ("Hebrews", 13), ("James", 5),
            ("1 Peter", 5), ("2 Peter", 3), ("1 John", 5), ("2 John", 1), ("3 John", 1),
            ("Jude", 1), ("Revelation", 22)
        ]
        
        for (book, chapters) in newTestamentBooks {
            if chapters <= 5 {
                readings.append(DailyReading(day: day, reference: "\(book) 1-\(chapters)", description: "\(book)"))
                day += 1
            } else {
                let chunks = (chapters + 4) / 5
                for i in 0..<chunks {
                    let start = i * 5 + 1
                    let end = min((i + 1) * 5, chapters)
                    readings.append(DailyReading(day: day, reference: "\(book) \(start)-\(end)", description: "\(book) Chapters \(start)-\(end)"))
                    day += 1
                }
            }
        }
        
        // Fill remaining days if needed
        while day <= 365 {
            readings.append(DailyReading(day: day, reference: "Psalm \(((day - 1) % 150) + 1)", description: "Daily Psalm"))
            day += 1
        }
        
        return readings.prefix(365).map { $0 }
    }
    
    private static func createChronologicalPlan() -> [DailyReading] {
        // Simplified chronological plan
        var readings: [DailyReading] = []
        var day = 1
        
        // Key chronological events
        let chronologicalReadings = [
            ("Genesis 1-11", "Creation to Tower of Babel"),
            ("Job 1-42", "Job (chronologically early)"),
            ("Genesis 12-50", "Abraham to Joseph"),
            ("Exodus 1-40", "Exodus and Law"),
            ("Leviticus 1-27", "Laws and Offerings"),
            ("Numbers 1-36", "Wilderness Journey"),
            ("Deuteronomy 1-34", "Moses' Final Words"),
            ("Joshua 1-24", "Conquest of Canaan"),
            ("Judges 1-21", "Period of Judges"),
            ("Ruth 1-4", "Ruth's Story"),
            ("1 Samuel 1-31", "Samuel and Saul"),
            ("2 Samuel 1-24", "David's Reign"),
            ("1 Kings 1-11", "Solomon"),
            ("Psalms 1-150", "Psalms (scattered throughout)"),
            ("Proverbs 1-31", "Proverbs"),
            ("Ecclesiastes 1-12", "Ecclesiastes"),
            ("Song of Solomon 1-8", "Song of Songs"),
            ("1 Kings 12-22", "Divided Kingdom"),
            ("2 Kings 1-25", "Kings of Israel and Judah"),
            ("1 Chronicles 1-29", "Chronicles - Genealogies"),
            ("2 Chronicles 1-36", "Chronicles - History"),
            ("Isaiah 1-66", "Isaiah"),
            ("Jeremiah 1-52", "Jeremiah"),
            ("Lamentations 1-5", "Lamentations"),
            ("Ezekiel 1-48", "Ezekiel"),
            ("Daniel 1-12", "Daniel"),
            ("Hosea 1-14", "Hosea"),
            ("Joel 1-3", "Joel"),
            ("Amos 1-9", "Amos"),
            ("Obadiah 1", "Obadiah"),
            ("Jonah 1-4", "Jonah"),
            ("Micah 1-7", "Micah"),
            ("Nahum 1-3", "Nahum"),
            ("Habakkuk 1-3", "Habakkuk"),
            ("Zephaniah 1-3", "Zephaniah"),
            ("Haggai 1-2", "Haggai"),
            ("Zechariah 1-14", "Zechariah"),
            ("Malachi 1-4", "Malachi"),
            ("Esther 1-10", "Esther"),
            ("Ezra 1-10", "Ezra"),
            ("Nehemiah 1-13", "Nehemiah"),
            ("Matthew 1-28", "Gospel of Matthew"),
            ("Mark 1-16", "Gospel of Mark"),
            ("Luke 1-24", "Gospel of Luke"),
            ("John 1-21", "Gospel of John"),
            ("Acts 1-28", "Acts of the Apostles"),
            ("Romans 1-16", "Romans"),
            ("1 Corinthians 1-16", "1 Corinthians"),
            ("2 Corinthians 1-13", "2 Corinthians"),
            ("Galatians 1-6", "Galatians"),
            ("Ephesians 1-6", "Ephesians"),
            ("Philippians 1-4", "Philippians"),
            ("Colossians 1-4", "Colossians"),
            ("1 Thessalonians 1-5", "1 Thessalonians"),
            ("2 Thessalonians 1-3", "2 Thessalonians"),
            ("1 Timothy 1-6", "1 Timothy"),
            ("2 Timothy 1-4", "2 Timothy"),
            ("Titus 1-3", "Titus"),
            ("Philemon 1", "Philemon"),
            ("Hebrews 1-13", "Hebrews"),
            ("James 1-5", "James"),
            ("1 Peter 1-5", "1 Peter"),
            ("2 Peter 1-3", "2 Peter"),
            ("1 John 1-5", "1 John"),
            ("2 John 1", "2 John"),
            ("3 John 1", "3 John"),
            ("Jude 1", "Jude"),
            ("Revelation 1-22", "Revelation")
        ]
        
        // Distribute readings across 365 days
        let totalReadings = chronologicalReadings.count
        let readingsPerDay = max(1, 365 / totalReadings)
        
        for (index, (reference, description)) in chronologicalReadings.enumerated() {
            let startDay = index * readingsPerDay + 1
            readings.append(DailyReading(day: startDay, reference: reference, description: description))
        }
        
        // Fill remaining days
        while day <= 365 {
            if !readings.contains(where: { $0.day == day }) {
                readings.append(DailyReading(day: day, reference: "Psalm \(((day - 1) % 150) + 1)", description: "Daily Psalm"))
            }
            day += 1
        }
        
        return readings.sorted { $0.day < $1.day }.prefix(365).map { $0 }
    }
    
    private static func createOldTestamentPlan() -> [DailyReading] {
        var readings: [DailyReading] = []
        var day = 1
        
        let oldTestamentBooks = [
            ("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36), ("Deuteronomy", 34),
            ("Joshua", 24), ("Judges", 21), ("Ruth", 4), ("1 Samuel", 31), ("2 Samuel", 24),
            ("1 Kings", 22), ("2 Kings", 25), ("1 Chronicles", 29), ("2 Chronicles", 36), ("Ezra", 10),
            ("Nehemiah", 13), ("Esther", 10), ("Job", 42), ("Psalm", 150), ("Proverbs", 31),
            ("Ecclesiastes", 12), ("Song of Solomon", 8), ("Isaiah", 66), ("Jeremiah", 52), ("Lamentations", 5),
            ("Ezekiel", 48), ("Daniel", 12), ("Hosea", 14), ("Joel", 3), ("Amos", 9),
            ("Obadiah", 1), ("Jonah", 4), ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3),
            ("Zephaniah", 3), ("Haggai", 2), ("Zechariah", 14), ("Malachi", 4)
        ]
        
        for (book, chapters) in oldTestamentBooks {
            if chapters <= 3 {
                readings.append(DailyReading(day: day, reference: "\(book) 1-\(chapters)", description: "\(book)"))
                day += 1
            } else {
                let chunks = (chapters + 2) / 3
                for i in 0..<chunks {
                    let start = i * 3 + 1
                    let end = min((i + 1) * 3, chapters)
                    readings.append(DailyReading(day: day, reference: "\(book) \(start)-\(end)", description: "\(book) Chapters \(start)-\(end)"))
                    day += 1
                }
            }
        }
        
        return readings
    }
    
    private static func createNewTestamentPlan() -> [DailyReading] {
        var readings: [DailyReading] = []
        var day = 1
        
        let newTestamentBooks = [
            ("Matthew", 28), ("Mark", 16), ("Luke", 24), ("John", 21), ("Acts", 28),
            ("Romans", 16), ("1 Corinthians", 16), ("2 Corinthians", 13), ("Galatians", 6), ("Ephesians", 6),
            ("Philippians", 4), ("Colossians", 4), ("1 Thessalonians", 5), ("2 Thessalonians", 3), ("1 Timothy", 6),
            ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1), ("Hebrews", 13), ("James", 5),
            ("1 Peter", 5), ("2 Peter", 3), ("1 John", 5), ("2 John", 1), ("3 John", 1),
            ("Jude", 1), ("Revelation", 22)
        ]
        
        for (book, chapters) in newTestamentBooks {
            if chapters <= 3 {
                readings.append(DailyReading(day: day, reference: "\(book) 1-\(chapters)", description: "\(book)"))
                day += 1
            } else {
                let chunks = (chapters + 2) / 3
                for i in 0..<chunks {
                    let start = i * 3 + 1
                    let end = min((i + 1) * 3, chapters)
                    readings.append(DailyReading(day: day, reference: "\(book) \(start)-\(end)", description: "\(book) Chapters \(start)-\(end)"))
                    day += 1
                }
            }
        }
        
        return readings
    }
    
    private static func createPrayerFaithPlan() -> [DailyReading] {
        return [
            DailyReading(day: 1, reference: "Matthew 6:5-15", description: "The Lord's Prayer"),
            DailyReading(day: 2, reference: "Philippians 4:6-7", description: "Prayer and Peace"),
            DailyReading(day: 3, reference: "James 5:13-18", description: "The Prayer of Faith"),
            DailyReading(day: 4, reference: "1 Thessalonians 5:16-18", description: "Pray Continually"),
            DailyReading(day: 5, reference: "Hebrews 11:1-6", description: "What is Faith?"),
            DailyReading(day: 6, reference: "Mark 11:22-25", description: "Have Faith in God"),
            DailyReading(day: 7, reference: "Ephesians 6:18", description: "Pray in the Spirit"),
            DailyReading(day: 8, reference: "Romans 10:17", description: "Faith Comes by Hearing"),
            DailyReading(day: 9, reference: "Luke 18:1-8", description: "The Persistent Widow"),
            DailyReading(day: 10, reference: "Matthew 21:21-22", description: "Prayer and Faith"),
            DailyReading(day: 11, reference: "1 John 5:14-15", description: "Confidence in Prayer"),
            DailyReading(day: 12, reference: "Matthew 7:7-11", description: "Ask, Seek, Knock"),
            DailyReading(day: 13, reference: "2 Corinthians 5:7", description: "Walk by Faith"),
            DailyReading(day: 14, reference: "Romans 8:26-27", description: "The Spirit Helps Us Pray")
        ]
    }
    
    private static func createLoveRelationshipsPlan() -> [DailyReading] {
        return [
            DailyReading(day: 1, reference: "1 Corinthians 13:1-13", description: "The Love Chapter"),
            DailyReading(day: 2, reference: "John 15:12-17", description: "Love One Another"),
            DailyReading(day: 3, reference: "Ephesians 5:22-33", description: "Marriage and Love"),
            DailyReading(day: 4, reference: "1 John 4:7-21", description: "God is Love"),
            DailyReading(day: 5, reference: "Romans 12:9-21", description: "Genuine Love"),
            DailyReading(day: 6, reference: "Proverbs 31:10-31", description: "A Wife of Noble Character"),
            DailyReading(day: 7, reference: "Song of Solomon 2:1-17", description: "Love Song"),
            DailyReading(day: 8, reference: "Colossians 3:12-14", description: "Clothe Yourselves with Love"),
            DailyReading(day: 9, reference: "1 Peter 4:8", description: "Love Covers a Multitude of Sins"),
            DailyReading(day: 10, reference: "Mark 12:28-34", description: "The Greatest Commandment"),
            DailyReading(day: 11, reference: "Galatians 5:22-23", description: "Fruit of the Spirit"),
            DailyReading(day: 12, reference: "Proverbs 17:17", description: "A Friend Loves at All Times"),
            DailyReading(day: 13, reference: "Ephesians 4:2-3", description: "Bear with One Another in Love"),
            DailyReading(day: 14, reference: "1 John 3:16-18", description: "Love in Action")
        ]
    }
    
    private static func createHopeEncouragementPlan() -> [DailyReading] {
        return [
            DailyReading(day: 1, reference: "Romans 15:13", description: "God of Hope"),
            DailyReading(day: 2, reference: "Jeremiah 29:11", description: "Plans to Prosper You"),
            DailyReading(day: 3, reference: "Isaiah 40:31", description: "Those Who Hope in the Lord"),
            DailyReading(day: 4, reference: "Psalm 23:1-6", description: "The Lord is My Shepherd"),
            DailyReading(day: 5, reference: "Philippians 4:13", description: "I Can Do All Things"),
            DailyReading(day: 6, reference: "Joshua 1:9", description: "Be Strong and Courageous"),
            DailyReading(day: 7, reference: "2 Corinthians 4:16-18", description: "Light and Momentary Troubles"),
            DailyReading(day: 8, reference: "Psalm 46:1-3", description: "God is Our Refuge"),
            DailyReading(day: 9, reference: "Romans 8:28", description: "All Things Work Together"),
            DailyReading(day: 10, reference: "Isaiah 41:10", description: "Do Not Fear"),
            DailyReading(day: 11, reference: "Psalm 34:17-18", description: "The Lord is Close"),
            DailyReading(day: 12, reference: "Matthew 11:28-30", description: "Come to Me"),
            DailyReading(day: 13, reference: "1 Peter 5:7", description: "Cast All Your Anxiety"),
            DailyReading(day: 14, reference: "Revelation 21:1-5", description: "A New Heaven and Earth")
        ]
    }
    
    private static func createDavidPlan() -> [DailyReading] {
        return [
            DailyReading(day: 1, reference: "1 Samuel 16:1-13", description: "David Anointed"),
            DailyReading(day: 2, reference: "1 Samuel 17:1-58", description: "David and Goliath"),
            DailyReading(day: 3, reference: "1 Samuel 18:1-16", description: "David and Jonathan"),
            DailyReading(day: 4, reference: "1 Samuel 24:1-22", description: "David Spares Saul"),
            DailyReading(day: 5, reference: "2 Samuel 5:1-10", description: "David Becomes King"),
            DailyReading(day: 6, reference: "2 Samuel 7:1-17", description: "God's Covenant with David"),
            DailyReading(day: 7, reference: "2 Samuel 11:1-27", description: "David and Bathsheba"),
            DailyReading(day: 8, reference: "2 Samuel 12:1-25", description: "Nathan Rebukes David"),
            DailyReading(day: 9, reference: "Psalm 51:1-19", description: "David's Repentance"),
            DailyReading(day: 10, reference: "Psalm 23:1-6", description: "The Lord is My Shepherd"),
            DailyReading(day: 11, reference: "Psalm 27:1-14", description: "The Lord is My Light"),
            DailyReading(day: 12, reference: "Psalm 32:1-11", description: "Blessed is the One"),
            DailyReading(day: 13, reference: "1 Chronicles 29:10-20", description: "David's Prayer"),
            DailyReading(day: 14, reference: "Acts 13:22", description: "A Man After God's Heart")
        ]
    }
    
    private static func createPaulPlan() -> [DailyReading] {
        return [
            DailyReading(day: 1, reference: "Acts 9:1-19", description: "Saul's Conversion"),
            DailyReading(day: 2, reference: "Acts 13:1-12", description: "Paul's First Missionary Journey"),
            DailyReading(day: 3, reference: "Acts 16:16-40", description: "Paul in Philippi"),
            DailyReading(day: 4, reference: "Acts 17:16-34", description: "Paul in Athens"),
            DailyReading(day: 5, reference: "Acts 20:17-38", description: "Paul's Farewell to Ephesus"),
            DailyReading(day: 6, reference: "Acts 27:1-44", description: "Paul's Shipwreck"),
            DailyReading(day: 7, reference: "Romans 1:1-17", description: "Paul's Introduction"),
            DailyReading(day: 8, reference: "1 Corinthians 9:1-27", description: "Paul's Rights as an Apostle"),
            DailyReading(day: 9, reference: "2 Corinthians 11:16-33", description: "Paul's Sufferings"),
            DailyReading(day: 10, reference: "Galatians 1:11-24", description: "Paul Called by God"),
            DailyReading(day: 11, reference: "Philippians 1:12-26", description: "Paul in Chains"),
            DailyReading(day: 12, reference: "Philippians 3:1-14", description: "Paul's Testimony"),
            DailyReading(day: 13, reference: "2 Timothy 4:1-8", description: "Paul's Final Charge"),
            DailyReading(day: 14, reference: "2 Timothy 4:9-22", description: "Paul's Final Words")
        ]
    }
    
    private static func createAdventPlan() -> [DailyReading] {
        var readings: [DailyReading] = []
        let adventReadings = [
            ("Isaiah 9:2-7", "The People Walking in Darkness"),
            ("Micah 5:2-5", "A Ruler from Bethlehem"),
            ("Isaiah 7:14", "The Virgin Will Conceive"),
            ("Isaiah 11:1-10", "The Branch from Jesse"),
            ("Jeremiah 23:5-6", "The Righteous Branch"),
            ("Malachi 3:1-4", "The Messenger of the Covenant"),
            ("Luke 1:5-25", "Zechariah and Elizabeth"),
            ("Luke 1:26-38", "The Annunciation"),
            ("Luke 1:39-56", "Mary Visits Elizabeth"),
            ("Luke 1:57-80", "The Birth of John"),
            ("Matthew 1:18-25", "The Birth of Jesus"),
            ("Luke 2:1-7", "The Birth in Bethlehem"),
            ("Luke 2:8-20", "The Shepherds"),
            ("Matthew 2:1-12", "The Magi"),
            ("Luke 2:21-40", "Simeon and Anna"),
            ("John 1:1-18", "The Word Became Flesh"),
            ("Isaiah 52:7-10", "How Beautiful Are the Feet"),
            ("Isaiah 40:1-11", "Comfort, Comfort My People"),
            ("Zechariah 9:9-10", "Rejoice, Daughter of Zion"),
            ("Isaiah 61:1-3", "The Year of the Lord's Favor"),
            ("Luke 2:41-52", "Jesus in the Temple"),
            ("Matthew 2:13-23", "The Flight to Egypt"),
            ("Revelation 21:1-7", "A New Heaven and Earth"),
            ("Revelation 22:1-5", "The River of Life"),
            ("John 3:16-21", "For God So Loved the World")
        ]
        
        for (index, (reference, description)) in adventReadings.enumerated() {
            readings.append(DailyReading(day: index + 1, reference: reference, description: description))
        }
        
        return readings
    }
    
    private static func createLentPlan() -> [DailyReading] {
        var readings: [DailyReading] = []
        // Key passages for Lent focusing on Jesus' journey to the cross
        let lentReadings = [
            ("Matthew 4:1-11", "Jesus Tempted in the Wilderness"),
            ("Mark 1:9-15", "Jesus' Baptism and Temptation"),
            ("Luke 4:1-13", "The Temptation of Jesus"),
            ("John 3:1-21", "Nicodemus and New Birth"),
            ("Matthew 5:1-12", "The Beatitudes"),
            ("Matthew 6:1-18", "Giving, Prayer, Fasting"),
            ("Mark 8:27-38", "Peter's Confession and Taking Up Cross"),
            ("Luke 9:23-27", "The Cost of Discipleship"),
            ("John 12:1-8", "Jesus Anointed at Bethany"),
            ("Matthew 21:1-11", "The Triumphal Entry"),
            ("Mark 11:15-19", "Jesus Clears the Temple"),
            ("Luke 19:41-44", "Jesus Weeps Over Jerusalem"),
            ("John 13:1-17", "Jesus Washes Disciples' Feet"),
            ("Matthew 26:17-30", "The Last Supper"),
            ("Mark 14:32-42", "Gethsemane"),
            ("Luke 22:39-46", "Jesus Prays on the Mount of Olives"),
            ("John 18:1-11", "Jesus Arrested"),
            ("Matthew 26:57-68", "Jesus Before the Sanhedrin"),
            ("Mark 15:1-15", "Jesus Before Pilate"),
            ("Luke 23:13-25", "Jesus Sentenced to Death"),
            ("John 19:1-16", "Jesus Sentenced to Be Crucified"),
            ("Matthew 27:27-44", "The Crucifixion"),
            ("Mark 15:33-39", "The Death of Jesus"),
            ("Luke 23:44-49", "Jesus' Death"),
            ("John 19:17-30", "The Crucifixion"),
            ("Matthew 27:57-66", "The Burial"),
            ("Mark 16:1-8", "The Resurrection"),
            ("Luke 24:1-12", "The Empty Tomb"),
            ("John 20:1-18", "Jesus Appears to Mary"),
            ("Matthew 28:1-10", "The Resurrection"),
            ("Mark 16:9-20", "Jesus Appears to Disciples"),
            ("Luke 24:13-35", "On the Road to Emmaus"),
            ("John 20:19-31", "Jesus Appears to Disciples"),
            ("Luke 24:36-53", "Jesus Appears and Ascends"),
            ("John 21:1-14", "Jesus and the Miraculous Catch"),
            ("Matthew 28:16-20", "The Great Commission"),
            ("Acts 1:1-11", "Jesus Ascends to Heaven"),
            ("1 Corinthians 15:1-11", "The Resurrection of Christ"),
            ("Romans 6:1-14", "Dead to Sin, Alive in Christ"),
            ("Colossians 2:13-15", "Made Alive with Christ")
        ]
        
        for (index, (reference, description)) in lentReadings.enumerated() {
            readings.append(DailyReading(day: index + 1, reference: reference, description: description))
        }
        
        return readings
    }
}

// MARK: - Statistics View
@available(iOS 17.0, *)
struct ReadingPlanStatisticsView: View {
    let plans: [ReadingPlan]
    @Environment(\.dismiss) private var dismiss
    
    var statistics: ReadingPlanStatistics {
        getOverallStatistics(plans: plans)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall Stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Overall Statistics")
                            .font(.title2)
                            .font(.body.weight(.bold))
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatisticCard(title: "Total Plans", value: "\(statistics.totalPlans)", icon: "book.fill", color: .blue)
                            StatisticCard(title: "Completed", value: "\(statistics.completedPlans)", icon: "checkmark.circle.fill", color: .green)
                            StatisticCard(title: "Active", value: "\(statistics.activePlans)", icon: "bookmark.fill", color: .orange)
                            StatisticCard(title: "Total Readings", value: "\(statistics.totalReadings)", icon: "text.book.closed.fill", color: .purple)
                            StatisticCard(title: "Reading Time", value: statistics.formattedTotalTime, icon: "clock.fill", color: .indigo)
                            StatisticCard(title: "Current Streak", value: "\(statistics.currentStreak) days", icon: "flame.fill", color: .red)
                            StatisticCard(title: "Longest Streak", value: "\(statistics.longestStreak) days", icon: "star.fill", color: .yellow)
                            StatisticCard(title: "Completion Rate", value: "\(Int(statistics.averageCompletionRate * 100))%", icon: "chart.pie.fill", color: .teal)
                        }
                    }
                    .padding()
                    
                    // Favorite Books
                    if !plans.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Favorite Books")
                                .font(.title2)
                                .font(.body.weight(.bold))
                            
                            let favoriteBooks = getFavoriteBooks(plans: plans)
                            ForEach(Array(favoriteBooks.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { bookEntry in
                                HStack {
                                    Text(bookEntry.key)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(bookEntry.value) readings")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .font(.body.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Calendar View
@available(iOS 17.0, *)
struct ReadingPlanCalendarView: View {
    let plan: ReadingPlan
    @State private var selectedDate = Date()
    
    var calendarData: [Date: Bool] {
        plan.getCalendarData()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reading Calendar")
                .font(.title2)
                .font(.body.weight(.bold))
            
            // Simple calendar grid
            let calendar = Calendar.current
            let today = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let daysInMonth = calendar.range(of: .day, in: .month, for: today)!.count
            let firstWeekday = calendar.component(.weekday, from: startOfMonth)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Day headers
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                
                // Empty cells for days before month starts
                ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                    Color.clear
                }
                
                // Days of month
                ForEach(1...daysInMonth, id: \.self) { day in
                    if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                        let dayStart = calendar.startOfDay(for: date)
                        let isCompleted = calendarData[dayStart] ?? false
                        let isToday = calendar.isDate(date, inSameDayAs: today)
                        
                        ZStack {
                            Circle()
                                .fill(isCompleted ? Color.green : (isToday ? Color.purple.opacity(0.3) : Color.clear))
                                .frame(width: 32, height: 32)
                            
                            Text("\(day)")
                                .font(.caption)
                                .font(.body.weight(isToday ? .bold : .regular))
                                .foregroundColor(isCompleted ? .white : (isToday ? .purple : .primary))
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Plan Settings View
@available(iOS 17.0, *)
struct PlanSettingsView: View {
    let plan: ReadingPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var reminderEnabled = false
    @State private var reminderTime = Date()
    @State private var catchUpMode = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminders")) {
                    Toggle("Enable Reminders", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section(header: Text("Reading Options")) {
                    Toggle("Catch-Up Mode", isOn: $catchUpMode)
                    Text("When enabled, you can catch up on missed readings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Plan Management")) {
                    if plan.isPaused {
                        Button("Resume Plan") {
                            plan.resume()
                            try? modelContext.save()
                            dismiss()
                        }
                    } else {
                        Button("Pause Plan") {
                            plan.pause()
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Plan Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        plan.reminderEnabled = reminderEnabled
                        plan.reminderTime = reminderTime
                        plan.catchUpModeEnabled = catchUpMode
                        
                        // Reminder functionality - will be implemented when service is available
                        // For now, just save the reminder settings
                        if reminderEnabled {
                            // Schedule reminder
                            Task {
                                let center = UNUserNotificationCenter.current()
                                let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                                if granted == true {
                                    let content = UNMutableNotificationContent()
                                    content.title = "📖 Time for Your Daily Reading"
                                    content.body = "Don't forget to read \(plan.title) - Day \(plan.currentDay)"
                                    content.sound = .default
                                    
                                    let calendar = Calendar.current
                                    let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
                                    var dateComponents = DateComponents()
                                    dateComponents.hour = components.hour
                                    dateComponents.minute = components.minute
                                    
                                    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                        let request = UNNotificationRequest(identifier: "readingPlan_\(plan.id.uuidString)", content: content, trigger: trigger)
                        try? await center.add(request)
                                }
                            }
                        } else {
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["readingPlan_\(plan.id.uuidString)"])
                        }
                        
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                reminderEnabled = plan.reminderEnabled
                reminderTime = plan.reminderTime
                catchUpMode = plan.catchUpModeEnabled
            }
        }
    }
}

// MARK: - Plan Statistics Detail View
@available(iOS 17.0, *)
struct PlanStatisticsDetailView: View {
    let plan: ReadingPlan
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress Stats
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Progress")
                            .font(.title2)
                            .font(.body.weight(.bold))
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatisticCard(title: "Completed", value: "\(plan.completedReadingsCount)", icon: "checkmark.circle.fill", color: .green)
                            StatisticCard(title: "Remaining", value: "\(plan.daysRemaining)", icon: "clock.fill", color: .orange)
                            StatisticCard(title: "Streak", value: "\(plan.streakCount) days", icon: "flame.fill", color: .red)
                            StatisticCard(title: "Progress", value: "\(Int(plan.progress * 100))%", icon: "chart.pie.fill", color: .purple)
                        }
                    }
                    .padding()
                    
                    // Reading Patterns
                    let patterns = getReadingPatterns(plan: plan)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reading Patterns")
                            .font(.title2)
                            .font(.body.weight(.bold))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preferred Time: \(patterns.preferredTimeOfDay)")
                            Text("Preferred Day: \(patterns.preferredDayOfWeek)")
                            Text("Average Reading Time: \(formatTime(plan.averageReadingTime))")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        return "\(minutes) min"
    }
}

// MARK: - Reading Plan Share Sheet
struct ReadingPlanShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ReadingPlan Extensions
@available(iOS 17.0, *)
extension ReadingPlan {
    var shareText: String {
        """
        📖 \(title)
        
        Progress: \(Int(progress * 100))% Complete
        Current Streak: \(streakCount) days
        Days Remaining: \(daysRemaining)
        
        Keep up the great work! 💪
        """
    }
}

// MARK: - Type Definitions
// ReadingPlanStatistics and ReadingPatterns are defined in ReadingPlanStatisticsService.swift
// Import them from there to avoid duplicate definitions

// MARK: - Inline Services (temporary until files are added to project)
@MainActor
class InlineSpeechSynthesizer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String, rate: Float = 0.5) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension InlineSpeechSynthesizer {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

// MARK: - Inline Statistics Functions
@available(iOS 17.0, *)
func getOverallStatistics(plans: [ReadingPlan]) -> ReadingPlanStatistics {
    let totalPlans = plans.count
    let completedPlans = plans.filter { $0.isCompleted }.count
    let activePlans = plans.filter { !$0.isCompleted && !$0.isPaused }.count
    let totalReadings = plans.reduce(0) { $0 + $1.completedReadingsCount }
    let totalTime = plans.reduce(0) { $0 + $1.totalReadingTime }
    let longestStreak = plans.map { $0.longestStreak }.max() ?? 0
    let currentStreak = plans.map { $0.streakCount }.max() ?? 0
    
    return ReadingPlanStatistics(
        totalPlans: totalPlans,
        completedPlans: completedPlans,
        activePlans: activePlans,
        totalReadings: totalReadings,
        totalReadingTime: totalTime,
        longestStreak: longestStreak,
        currentStreak: currentStreak,
        averageCompletionRate: totalPlans > 0 ? Double(completedPlans) / Double(totalPlans) : 0
    )
}

@available(iOS 17.0, *)
func getFavoriteBooks(plans: [ReadingPlan]) -> [String: Int] {
    var bookCounts: [String: Int] = [:]
    
    for plan in plans {
        for reading in plan.readings where reading.isCompleted {
            let book = reading.reference.components(separatedBy: " ").first ?? ""
            bookCounts[book, default: 0] += 1
        }
    }
    
    return bookCounts.sorted { $0.value > $1.value }
        .reduce(into: [String: Int]()) { $0[$1.key] = $1.value }
}

@available(iOS 17.0, *)
func getReadingPatterns(plan: ReadingPlan) -> ReadingPatterns {
    let calendar = Calendar.current
    var timeOfDayCounts: [String: Int] = ["Morning": 0, "Afternoon": 0, "Evening": 0, "Night": 0]
    var dayOfWeekCounts: [String: Int] = [:]
    
    for reading in plan.readings where reading.isCompleted {
        guard let completedDate = reading.completedDate else { continue }
        let hour = calendar.component(.hour, from: completedDate)
        let weekday = calendar.component(.weekday, from: completedDate)
        
        switch hour {
        case 5..<12: timeOfDayCounts["Morning", default: 0] += 1
        case 12..<17: timeOfDayCounts["Afternoon", default: 0] += 1
        case 17..<21: timeOfDayCounts["Evening", default: 0] += 1
        default: timeOfDayCounts["Night", default: 0] += 1
        }
        
        let weekdayName = calendar.weekdaySymbols[weekday - 1]
        dayOfWeekCounts[weekdayName, default: 0] += 1
    }
    
    return ReadingPatterns(
        preferredTimeOfDay: timeOfDayCounts.max(by: { $0.value < $1.value })?.key ?? "Morning",
        preferredDayOfWeek: dayOfWeekCounts.max(by: { $0.value < $1.value })?.key ?? "Sunday",
        timeOfDayDistribution: timeOfDayCounts,
        dayOfWeekDistribution: dayOfWeekCounts
    )
}

