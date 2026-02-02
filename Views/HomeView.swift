import SwiftUI
import SwiftData

// MARK: - Activity Item Types

@available(iOS 17.0, *)
enum ActivityItem: Identifiable {
    case journal(JournalEntry)
    case mood(MoodEntry)

    var id: UUID {
        switch self {
        case .journal(let entry): return entry.id
        case .mood(let entry): return entry.id
        }
    }

    var date: Date {
        switch self {
        case .journal(let entry): return entry.createdAt
        case .mood(let entry): return entry.date
        }
    }

    var title: String {
        switch self {
        case .journal(let entry): return entry.title
        case .mood(let entry): return "Mood Check-in: \(entry.mood)"
        }
    }

    var subtitle: String {
        switch self {
        case .journal(let entry): return entry.createdAt.relativeFormatted()
        case .mood(let entry): return entry.date.relativeFormatted()
        }
    }

    var icon: String {
        switch self {
        case .journal: return "book.fill"
        case .mood: return "face.smiling"
        }
    }

    var color: Color {
        switch self {
        case .journal: return .blue
        case .mood: return .green
        }
    }
}

// MARK: - Date Extensions

extension Date {
    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

@available(iOS 17.0, *)
@available(iOS 17.0, *)
struct HomeView: View {
    @Binding var selectedTab: Int
    @Binding var showingNewJournalEntry: Bool
    @Binding var showingNewPrayerRequest: Bool
    @Binding var showingMoodCheckin: Bool
    @Binding var showingAlert: Bool
    @Binding var alertMessage: String
    
    // Observe singletons to get updates when their @Published properties change
    @ObservedObject private var verseManager = BibleVerseOfTheDayManager.shared
    private let devotionalManager = DevotionalManager.shared
    // Observe ProfileManager to get Firebase profile updates
    @ObservedObject private var profileManager = ProfileManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    // State for avatar image to handle async loading
    @State private var avatarImage: UIImage?
    
    @Query(sort: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]) private var allJournalEntries: [JournalEntry]
    @Query(sort: [SortDescriptor(\PrayerRequest.createdAt, order: .reverse)]) private var allPrayerRequests: [PrayerRequest]
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) private var allMoodEntries: [MoodEntry]
    
    var recentEntries: [JournalEntry] {
        Array(allJournalEntries.prefix(3))
    }

    var recentMoodEntries: [MoodEntry] {
        Array(allMoodEntries.prefix(3))
    }

    var combinedRecentActivity: [ActivityItem] {
        let journalItems = recentEntries.map { ActivityItem.journal($0) }
        let moodItems = recentMoodEntries.map { ActivityItem.mood($0) }
        let allItems = journalItems + moodItems
        return allItems.sorted(by: { $0.date > $1.date }).prefix(6).map { $0 }
    }
    
    var todayDevotional: Devotional? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return devotionalManager.devotionals.first { devotional in
            calendar.isDate(devotional.date, inSameDayAs: today)
        } ?? devotionalManager.devotionals.first
    }

    // Detect if running on iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea(.all, edges: .all)
                
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // Welcome Header
                        welcomeHeader
                        
                        // Bible Verse of the Day
                        bibleVerseCard
                        
                        // Today's Devotional
                        if let devotional = todayDevotional {
                            devotionalCard(devotional: devotional)
                        }
                        
                        // Quick Actions - Always show
                        QuickActionsView(
                            showingNewJournalEntry: $showingNewJournalEntry,
                            showingNewPrayerRequest: $showingNewPrayerRequest,
                            showingMoodCheckin: $showingMoodCheckin,
                            selectedTab: $selectedTab
                        )
                        
                        // Recent Activity - Show journal entries and mood check-ins
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Activity")
                                .font(.headline)
                                .foregroundColor(.primary)
                            if !combinedRecentActivity.isEmpty {
                                ForEach(combinedRecentActivity) { activity in
                                    HStack(spacing: 12) {
                                        Image(systemName: activity.icon)
                                            .foregroundColor(activity.color)
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(activity.title)
                                                .font(.subheadline)
                                                .font(.body.weight(.semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                            Text(activity.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            } else {
                                Text("No recent activity yet. Start your faith journey by creating a journal entry or checking in on your mood!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, isIPad ? 40 : 16)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(isIPad ? .large : .inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
            }
            .onAppear {
                // Only load verse if it's nil - don't override existing verse
                if verseManager.currentVerse == nil {
                    verseManager.loadTodaysVerse()
                }
                if devotionalManager.devotionals.isEmpty {
                    devotionalManager.loadDevotionals()
                }
                // Load profile from Firebase (if not already loaded)
                Task {
                    await profileManager.loadProfile()
                }
                // Load avatar image
                loadAvatarImage()
            }
            .onChange(of: profileManager.profileImageURL) { _, _ in
                // Reload avatar when profile photo URL changes
                loadAvatarImage()
            }
            .onChange(of: profileManager.userName) { _, _ in
                // Reload avatar when profile name changes (in case image needs to update)
                loadAvatarImage()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .all)
    }
    
    // MARK: - View Components
    
    // Computed property for display name (uses Firebase ProfileManager)
    private var displayName: String {
        if !profileManager.userName.isEmpty {
            return profileManager.userName
        }
        return "Friend"
    }
    
    // Computed property for profile initial
    private var profileInitial: String {
        String(displayName.prefix(1)).uppercased()
    }
    
    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome Back, \(displayName)!")
                    .font(.title2)
                    .font(.body.weight(.bold))
                    .foregroundColor(.purple)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Grow in faith, one day at a time")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            Spacer()
            // Profile avatar - shows photo if available, otherwise shows initial
            if let avatarImage = avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(profileInitial)
                            .font(.title3)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func loadAvatarImage() {
        guard let avatarURLString = profileManager.profileImageURL else {
            // No avatar URL, clear the image
            avatarImage = nil
            return
        }
        
        // Load image from Firebase Storage URL asynchronously
        Task {
            do {
                if let image = try await profileManager.loadProfileImage(from: avatarURLString) {
                    await MainActor.run {
                        avatarImage = image
                    }
                } else {
                    await MainActor.run {
                        avatarImage = nil
                    }
                }
            } catch {
                // If image can't be loaded, clear it
                await MainActor.run {
                    avatarImage = nil
                }
                print("⚠️ [HomeView] Could not load avatar image from Firebase: \(error.localizedDescription)")
            }
        }
    }
    
    private var bibleVerseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.purple)
                Text("Bible Verse of the Day")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    verseManager.loadRandomVerse()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.primary)
                }
            }
            
            if verseManager.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading verse...")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if let verse = verseManager.currentVerse {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verse.reference)
                        .font(.subheadline)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.purple)
                    Text(verse.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Spacer()
                    // Show the selected version from settings, not the verse's actual translation
                    // This ensures the icon/text updates when user changes version in settings
                    Text(verseManager.selectedVersion.rawValue)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading verse...")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onChange(of: verseManager.selectedVersion) { oldVersion, newVersion in
            // When version changes, reload the verse to get the new translation
            print("🔄 [HomeView] Version changed from \(oldVersion.rawValue) to \(newVersion.rawValue), reloading verse")
            verseManager.loadTodaysVerse()
        }
        .onChange(of: verseManager.useAPI) { oldValue, newValue in
            // When API mode changes, reload the verse
            if oldValue != newValue {
                print("🔄 [HomeView] API mode changed to \(newValue), reloading verse")
                verseManager.loadTodaysVerse()
            }
        }
    }
    
    private func devotionalCard(devotional: Devotional) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.purple)
                Text("Today's Devotional")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(devotional.title)
                    .font(.title3)
                    .font(.body.weight(.bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Text(devotional.scripture)
                    .font(.subheadline)
                    .foregroundColor(.purple)
                Text(devotional.content)
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack {
                Spacer()
                Button(action: {
                    selectedTab = 3 // Navigate to Devotionals tab
                }) {
                    Text("Read")
                        .font(.subheadline)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func QuickActionsView(
        showingNewJournalEntry: Binding<Bool>,
        showingNewPrayerRequest: Binding<Bool>,
        showingMoodCheckin: Binding<Bool>,
        selectedTab: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.primary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                QuickActionCard(
                    title: "New Journal Entry",
                    icon: "square.and.pencil",
                    color: .blue
                ) { showingNewJournalEntry.wrappedValue = true }
                QuickActionCard(
                    title: "Add Prayer Request",
                    icon: "hands.sparkles.fill",
                    color: .green
                ) { showingNewPrayerRequest.wrappedValue = true }
                QuickActionCard(
                    title: "Read Devotional",
                    icon: "heart",
                    color: .red
                ) { selectedTab.wrappedValue = 3 }
                QuickActionCard(
                    title: "Mood Check-in",
                    icon: "face.smiling",
                    color: .orange
                ) { showingMoodCheckin.wrappedValue = true }
            }
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .padding()
            .background(color)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        HomeView(
            selectedTab: .constant(0),
            showingNewJournalEntry: .constant(false),
            showingNewPrayerRequest: .constant(false),
            showingMoodCheckin: .constant(false),
            showingAlert: .constant(false),
            alertMessage: .constant("")
        )
        .modelContainer(for: [JournalEntry.self, PrayerRequest.self, MoodEntry.self], inMemory: true)
    }
}
