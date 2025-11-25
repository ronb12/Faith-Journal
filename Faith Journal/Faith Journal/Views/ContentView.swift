import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @StateObject private var bibleVerseManager = BibleVerseOfTheDayManager()
    @StateObject private var devotionalManager = DevotionalManager()
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedTab = 0
    @State private var showingNewJournalEntry = false
    @State private var showingNewPrayerRequest = false
    @State private var showingMoodCheckin = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                bibleVerseManager: bibleVerseManager,
                devotionalManager: devotionalManager,
                selectedTab: $selectedTab,
                showingNewJournalEntry: $showingNewJournalEntry,
                showingNewPrayerRequest: $showingNewPrayerRequest,
                showingMoodCheckin: $showingMoodCheckin,
                showingAlert: $showingAlert,
                alertMessage: $alertMessage
            )
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            JournalView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Journal")
                }
                .tag(1)
            
            PrayerView()
                .tabItem {
                    Image(systemName: "hands.sparkles.fill")
                    Text("Prayer")
                }
                .tag(2)
            
            DevotionalsView(devotionalManager: devotionalManager)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Devotionals")
                }
                .tag(3)
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Statistics")
                }
                .tag(4)
            
            LiveSessionsView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Live")
                }
                .tag(5)
            
            ReadingPlansView()
                .tabItem {
                    Image(systemName: "book.closed.fill")
                    Text("Reading Plans")
                }
                .tag(6)
            
            BibleStudyView()
                .tabItem {
                    Image(systemName: "book.pages.fill")
                    Text("Bible Study")
                }
                .tag(7)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(8)
        }
        .accentColor(themeManager.colors.primary)
        .alert("Quick Action", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct HomeView: View {
    @ObservedObject var bibleVerseManager: BibleVerseOfTheDayManager
    @ObservedObject var devotionalManager: DevotionalManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var selectedTab: Int
    @Binding var showingNewJournalEntry: Bool
    @Binding var showingNewPrayerRequest: Bool
    @Binding var showingMoodCheckin: Bool
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    @Query var userProfiles: [UserProfile]
    @Query(sort: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]) var journalEntries: [JournalEntry]
    @Environment(\.modelContext) private var modelContext
    
    var userProfile: UserProfile? {
        userProfiles.first
    }
    
    var isReturningUser: Bool {
        !journalEntries.isEmpty
    }
    
    var welcomeMessage: String {
        guard let profile = userProfile, !profile.name.isEmpty else {
            return isReturningUser ? "Welcome Back!" : "Welcome to Faith Journal!"
        }
        
        if isReturningUser {
            return "Welcome Back, \(profile.name)!"
        } else {
            return "Welcome, \(profile.name)!"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Personalized Welcome Header
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(welcomeMessage)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.colors.primary)
                                
                                Text("Grow in faith, one day at a time")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Profile Avatar/Initial
                            if let profile = userProfile, !profile.name.isEmpty {
                                ProfileAvatarView(
                                    profile: profile,
                                    size: 50,
                                    themeManager: themeManager
                                )
                            }
                        }
                    }
                    .padding(.top)
                    .padding(.horizontal)
                    
                    // Bible Verse of the Day Card
                    BibleVerseCard(bibleVerseManager: bibleVerseManager)
                    
                    // Today's Devotional Preview
                    if let todaysDevotional = devotionalManager.getTodaysDevotional() {
                        TodaysDevotionalCard(devotional: todaysDevotional, devotionalManager: devotionalManager)
                    }
                    
                    // Quick Actions
                    QuickActionsView(
                        selectedTab: $selectedTab,
                        showingNewJournalEntry: $showingNewJournalEntry,
                        showingNewPrayerRequest: $showingNewPrayerRequest,
                        showingMoodCheckin: $showingMoodCheckin,
                        showingAlert: $showingAlert,
                        alertMessage: $alertMessage
                    )
                    
                    // Recent Activity
                    RecentActivityView()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

struct BibleVerseCard: View {
    @ObservedObject var bibleVerseManager: BibleVerseOfTheDayManager
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(themeManager.colors.primary)
                Text("Bible Verse of the Day")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    bibleVerseManager.refreshVerse()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(themeManager.colors.primary)
                }
            }
            
            if bibleVerseManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading verse...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if let verse = bibleVerseManager.currentVerse {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verse.reference)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.colors.primary)
                    
                    Text(verse.text)
                        .font(.body)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Spacer()
                        Text(verse.translation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            } else if let error = bibleVerseManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct TodaysDevotionalCard: View {
    let devotional: Devotional
    @ObservedObject var devotionalManager: DevotionalManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingDevotionalDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Today's Devotional")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    showingDevotionalDetail = true
                }) {
                    Text("Read")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(devotional.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(devotional.scripture)
                    .font(.subheadline)
                    .foregroundColor(themeManager.colors.primary)
                    .italic()
                
                Text(devotional.content.prefix(100) + "...")
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .sheet(isPresented: $showingDevotionalDetail) {
            DevotionalDetailView(devotional: devotional, devotionalManager: devotionalManager)
        }
    }
}

struct QuickActionsView: View {
    @Binding var selectedTab: Int
    @Binding var showingNewJournalEntry: Bool
    @Binding var showingNewPrayerRequest: Bool
    @Binding var showingMoodCheckin: Bool
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    title: "New Journal Entry",
                    icon: "square.and.pencil",
                    color: .blue
                ) {
                    selectedTab = 1 // Switch to Journal tab
                    showingNewJournalEntry = true
                }
                
                QuickActionButton(
                    title: "Add Prayer Request",
                    icon: "hands.sparkles",
                    color: .green
                ) {
                    selectedTab = 2 // Switch to Prayer tab
                    showingNewPrayerRequest = true
                }
                
                QuickActionButton(
                    title: "Read Devotional",
                    icon: "heart",
                    color: .red
                ) {
                    selectedTab = 3 // Switch to Devotionals tab
                }
                
                QuickActionButton(
                    title: "Mood Check-in",
                    icon: "face.smiling",
                    color: .orange
                ) {
                    showingMoodCheckin = true
                }
            }
        }
        .sheet(isPresented: $showingNewJournalEntry) {
            NewJournalEntryView()
        }
        .sheet(isPresented: $showingNewPrayerRequest) {
            NewPrayerRequestView()
        }
        .sheet(isPresented: $showingMoodCheckin) {
            MoodCheckinView()
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentActivityView: View {
    @Query(sort: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]) var allEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]) var allPrayers: [PrayerRequest]
    
    var recentEntries: [JournalEntry] {
        Array(allEntries.prefix(3))
    }
    
    var recentPrayers: [PrayerRequest] {
        Array(allPrayers.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            if recentEntries.isEmpty && recentPrayers.isEmpty {
                Text("No recent activity. Start journaling to see your activity here!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    // Show recent journal entries
                    ForEach(recentEntries.prefix(2)) { entry in
                        ActivityRow(
                            icon: "book",
                            title: entry.title,
                            subtitle: formatDate(entry.createdAt),
                            color: .blue
                        )
                    }
                    
                    // Show recent answered prayers
                    ForEach(recentPrayers.filter { $0.status == .answered }.prefix(2)) { prayer in
                        ActivityRow(
                            icon: "hands.sparkles",
                            title: "Prayer Answered: \(prayer.title)",
                            subtitle: formatDate(prayer.answerDate ?? prayer.createdAt),
                            color: .green
                        )
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

// Devotionals View
struct DevotionalsView: View {
    @ObservedObject var devotionalManager: DevotionalManager
    @State private var showingDevotionalDetail = false
    @State private var selectedDevotional: Devotional?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(devotionalManager.categories, id: \.self) { category in
                            CategoryButton(
                                title: category,
                                isSelected: devotionalManager.selectedCategory == category
                            ) {
                                devotionalManager.selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                // Devotionals List
                if devotionalManager.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading devotionals...")
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(devotionalManager.filteredDevotionals()) { devotional in
                                DevotionalCard(
                                    devotional: devotional,
                                    devotionalManager: devotionalManager
                                ) {
                                    selectedDevotional = devotional
                                    showingDevotionalDetail = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Devotionals")
            .sheet(isPresented: $showingDevotionalDetail) {
                if let devotional = selectedDevotional {
                    DevotionalDetailView(devotional: devotional, devotionalManager: devotionalManager)
                }
            }
        }
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? themeManager.colors.primary : Color(.systemGray5))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DevotionalCard: View {
    let devotional: Devotional
    @ObservedObject var devotionalManager: DevotionalManager
    let onTap: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(devotional.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(devotional.scripture)
                            .font(.subheadline)
                            .foregroundColor(themeManager.colors.primary)
                            .italic()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(devotional.category)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.colors.primary)
                            .cornerRadius(8)
                        
                        if devotional.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }
                }
                
                Text(devotional.content.prefix(150) + "...")
                    .font(.body)
                    .lineLimit(4)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text(devotional.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(devotional.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DevotionalDetailView: View {
    let devotional: Devotional
    @ObservedObject var devotionalManager: DevotionalManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var shareText: String {
        """
        \(devotional.title)
        
        \(devotional.scripture)
        
        \(devotional.content)
        
        - \(devotional.author)
        """
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(devotional.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(devotional.scripture)
                            .font(.title2)
                            .foregroundColor(themeManager.colors.primary)
                            .italic()
                        
                        HStack {
                            Text(devotional.author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(devotional.date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Content
                    Text(devotional.content)
                        .font(.body)
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            devotionalManager.markAsCompleted(devotional)
                        }) {
                            HStack {
                                Image(systemName: devotional.isCompleted ? "checkmark.circle.fill" : "circle")
                                Text(devotional.isCompleted ? "Completed" : "Mark as Read")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(devotional.isCompleted ? .green : themeManager.colors.primary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(devotional.isCompleted ? Color.green : themeManager.colors.primary, lineWidth: 1)
                            )
                        }
                        
                        Button(action: {
                            showingShareSheet = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Devotional")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(activityItems: [shareText])
            }
        }
    }
}

struct MoodCheckinView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMood = 3
    @State private var notes = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Mood Check-in Saved"
    @State private var isSaving = false
    
    let moods = ["😢", "😕", "😐", "🙂", "😊"]
    let moodLabels = ["Very Low", "Low", "Okay", "Good", "Great"]
    let moodIntensities = [2, 4, 6, 8, 10] // Map to 1-10 scale
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("How are you feeling today?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack(spacing: 20) {
                    ForEach(0..<moods.count, id: \.self) { index in
                        VStack {
                            Text(moods[index])
                                .font(.system(size: 40))
                                .opacity(selectedMood == index ? 1.0 : 0.5)
                            Text(moodLabels[index])
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onTapGesture {
                            selectedMood = index
                        }
                    }
                }
                
                TextField("Add notes (optional)", text: $notes)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Mood Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMoodEntry()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") {
                if alertTitle == "Mood Check-in Saved" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveMoodEntry() {
        guard !isSaving else { return }
        
        isSaving = true
        
        let moodEntry = MoodEntry(
            mood: moodLabels[selectedMood],
            intensity: moodIntensities[selectedMood],
            notes: notes.isEmpty ? nil : notes,
            tags: []
        )
        
        modelContext.insert(moodEntry)
        
        do {
            try modelContext.save()
            print("✅ Mood entry saved successfully: \(moodEntry.mood), intensity: \(moodEntry.intensity)")
            alertTitle = "Mood Check-in Saved"
            alertMessage = "Your mood check-in has been saved successfully."
            showingAlert = true
            isSaving = false
        } catch {
            print("❌ Error saving mood entry: \(error)")
            print("Error details: \(error.localizedDescription)")
            alertTitle = "Error Saving"
            alertMessage = "Failed to save your mood check-in. Please try again.\n\nError: \(error.localizedDescription)"
            showingAlert = true
            isSaving = false
            
            // Remove the entry if save failed
            modelContext.delete(moodEntry)
        }
    }
}

// Profile Avatar View Component that reacts to UserProfile changes
struct ProfileAvatarView: View {
    let profile: UserProfile
    let size: CGFloat
    let themeManager: ThemeManager
    @State private var avatarImage: UIImage?
    
    var body: some View {
        Group {
            if let avatarImage = avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themeManager.colors.primary, themeManager.colors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(profile.name.prefix(1).uppercased()))
                            .font(size > 40 ? .title3 : .headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
            }
        }
        .id(profile.avatarPhotoURL?.absoluteString ?? "no-avatar-\(profile.id)")
        .onAppear {
            loadAvatar()
        }
        .onChange(of: profile.avatarPhotoURL) { _, _ in
            loadAvatar()
        }
    }
    
    private func loadAvatar() {
        guard let avatarURL = profile.avatarPhotoURL else {
            avatarImage = nil
            return
        }
        
        // Load image asynchronously to avoid blocking UI
        Task {
            if let imageData = try? Data(contentsOf: avatarURL),
               let image = UIImage(data: imageData) {
                await MainActor.run {
                    avatarImage = image
                }
            } else {
                await MainActor.run {
                    avatarImage = nil
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [JournalEntry.self], inMemory: true)
}
