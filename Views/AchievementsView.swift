//
//  AchievementsView.swift
//  Faith Journal
//
//  Achievements and milestones view
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct AchievementsView: View {
    @Query(sort: [SortDescriptor(\StatisticAchievement.unlockedDate, order: .reverse)]) var allAchievements: [StatisticAchievement]
    let achievementService: AchievementService
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var unlockedAchievements: [StatisticAchievement] {
        allAchievements.filter { $0.isUnlocked }
    }
    
    var lockedAchievements: [StatisticAchievement] {
        allAchievements.filter { !$0.isUnlocked }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(unlockedAchievements.count)")
                                .font(.title)
                                .font(.body.weight(.bold))
                                .foregroundColor(.yellow)
                            Text("Unlocked")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(allAchievements.count)")
                                .font(.title)
                                .font(.body.weight(.bold))
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            let percentage = Int(Double(unlockedAchievements.count) / Double(max(allAchievements.count, 1)) * 100)
                            Text("\(percentage)%")
                                .font(.title)
                                .font(.body.weight(.bold))
                                .foregroundColor(.green)
                            Text("Complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.platformSystemBackground)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    
                    // Unlocked Achievements
                    if !unlockedAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Unlocked Achievements")
                                .font(.headline)
                                .font(.body.weight(.semibold))
                                .padding(.horizontal)
                            
                            ForEach(unlockedAchievements) { achievement in
                                AchievementCard(achievement: achievement, isUnlocked: true)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Locked Achievements
                    if !lockedAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Locked Achievements")
                                .font(.headline)
                                .font(.body.weight(.semibold))
                                .padding(.horizontal)
                            
                            ForEach(lockedAchievements) { achievement in
                                AchievementCard(achievement: achievement, isUnlocked: false)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Achievements")
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
        .onAppear {
            initializeAchievements()
        }
    }
    
    private func initializeAchievements() {
        if allAchievements.isEmpty {
            let defaults = achievementService.getDefaultAchievements()
            for achievement in defaults {
                modelContext.insert(achievement)
            }
        }
    }
}

@available(iOS 17.0, *)
struct AchievementCard: View {
    let achievement: StatisticAchievement
    let isUnlocked: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Text(achievement.icon)
                    .font(.title)
                    .opacity(isUnlocked ? 1.0 : 0.5)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                
                Text(achievement.achievementDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if isUnlocked, let unlockedDate = achievement.unlockedDate {
                    Text("Unlocked: \(unlockedDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}

