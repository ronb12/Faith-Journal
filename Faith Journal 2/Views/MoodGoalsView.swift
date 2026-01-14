//
//  MoodGoalsView.swift
//  Faith Journal
//
//  Mood goals and achievements view
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct MoodGoalsView: View {
    @Query(sort: [SortDescriptor(\MoodGoal.createdAt, order: .reverse)]) var allGoals: [MoodGoal]
    @Query(sort: [SortDescriptor(\MoodAchievement.unlockedDate, order: .reverse)]) var allAchievements: [MoodAchievement]
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) var allMoodEntries: [MoodEntry]
    
    let goalsService: MoodGoalsService
    
    @MainActor
    init(goalsService: MoodGoalsService? = nil) {
        self.goalsService = goalsService ?? MoodGoalsService.shared
    }
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingNewGoal = false
    @State private var newGoalTitle = ""
    @State private var newGoalDescription = ""
    @State private var newGoalTarget = 7
    @State private var newGoalDate: Date?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Create Goal Button
                    Button(action: { showingNewGoal = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New Goal")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.colors.primary)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Active Goals
                    if !allGoals.filter({ !$0.isCompleted }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Goals")
                                .font(.headline)
                                .font(.body.weight(.semibold))
                                .padding(.horizontal)
                            
                            ForEach(allGoals.filter { !$0.isCompleted }) { goal in
                                GoalCard(goal: goal, themeManager: themeManager)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Completed Goals
                    if !allGoals.filter({ $0.isCompleted }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Completed Goals")
                                .font(.headline)
                                .font(.body.weight(.semibold))
                                .padding(.horizontal)
                            
                            ForEach(allGoals.filter { $0.isCompleted }) { goal in
                                GoalCard(goal: goal, themeManager: themeManager)
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
                        
                        if allAchievements.filter({ $0.isUnlocked }).isEmpty {
                            Text("Unlock achievements by tracking your mood consistently!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                                ForEach(allAchievements.filter { $0.isUnlocked }) { achievement in
                                    MoodAchievementCard(achievement: achievement, themeManager: themeManager)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Locked Achievements
                        if !allAchievements.filter({ !$0.isUnlocked }).isEmpty {
                            Text("Locked Achievements")
                                .font(.headline)
                                .font(.body.weight(.semibold))
                                .padding(.horizontal)
                                .padding(.top)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                                ForEach(allAchievements.filter { !$0.isUnlocked }) { achievement in
                                    MoodAchievementCard(achievement: achievement, themeManager: themeManager, isLocked: true)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Goals & Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewGoal) {
                CreateGoalView(
                    title: $newGoalTitle,
                    description: $newGoalDescription,
                    target: $newGoalTarget,
                    targetDate: $newGoalDate,
                    onSave: {
                        let goal = MoodGoal(
                            title: newGoalTitle,
                            description: newGoalDescription,  // This will be stored in goalDescription
                            targetMood: newGoalTarget,
                            targetDate: newGoalDate
                        )
                        modelContext.insert(goal)
                        try? modelContext.save()
                        newGoalTitle = ""
                        newGoalDescription = ""
                        newGoalTarget = 7
                        newGoalDate = nil
                        showingNewGoal = false
                    }
                )
            }
            .onAppear {
                // Update goal progress
                for goal in allGoals {
                    goalsService.updateGoalProgress(goal: goal, entries: allMoodEntries)
                }
                
                // Check for new achievements
                let unlocked = goalsService.checkAchievements(entries: allMoodEntries, achievements: allAchievements)
                if !unlocked.isEmpty {
                    try? modelContext.save()
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct CreateGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var title: String
    @Binding var description: String
    @Binding var target: Int
    @Binding var targetDate: Date?
    let onSave: () -> Void
    @State private var hasTargetDate = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Goal Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Goal Details")
                            .font(.headline)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Enter goal title", text: $title)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Enter goal description (optional)", text: $description, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .lineLimit(3...6)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    // Target Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Target")
                            .font(.headline)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Target Mood")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(target)/10")
                                    .font(.title3)
                                    .font(.body.weight(.bold))
                                    .foregroundColor(themeManager.colors.primary)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(target) },
                                set: { target = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(themeManager.colors.primary)
                            
                            HStack {
                                Text("1")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("10")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        
                        Toggle(isOn: $hasTargetDate) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Set Target Date")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Optional deadline for your goal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(themeManager.colors.primary)
                        
                        if hasTargetDate {
                            DatePicker("Target Date", selection: Binding(
                                get: { targetDate ?? Date() },
                                set: { targetDate = $0 }
                            ), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct GoalCard: View {
    let goal: MoodGoal
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(goal.title)
                    .font(.headline)
                Spacer()
                if goal.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(goal.goalDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ProgressView(value: goal.progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: themeManager.colors.primary))
            
            HStack {
                Text("\(Int(goal.progress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let targetDate = goal.targetDate {
                    Text("Target: \(targetDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

@available(iOS 17.0, *)
struct MoodAchievementCard: View {
    let achievement: MoodAchievement
    let themeManager: ThemeManager
    var isLocked: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(achievement.icon)
                .font(.system(size: 40))
                .opacity(isLocked ? 0.3 : 1.0)
            Text(achievement.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .opacity(isLocked ? 0.5 : 1.0)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}
