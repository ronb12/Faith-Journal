//
//  LiveSessionsView.swift
//  Faith Journal
//
//  Created on 11/18/25.
//

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

@available(iOS 17.0, *)
struct LiveSessionsView: View {
    @Query(sort: [SortDescriptor(\LiveSession.startTime, order: .reverse)]) var allSessions: [LiveSession]
    @Query(sort: [SortDescriptor(\LiveSessionParticipant.joinedAt, order: .reverse)]) var allParticipants: [LiveSessionParticipant]
    @Query(sort: [SortDescriptor(\SessionInvitation.createdAt, order: .reverse)]) var allInvitations: [SessionInvitation]
    @Environment(\.modelContext) private var modelContext
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    // CloudKitPublicSyncService removed - use Firebase for sync in the future
    // @State private var syncService: CloudKitPublicSyncService?
    @State private var showingCreateSession = false
    @State private var selectedSession: LiveSession?
    @State private var showingSessionDetail = false
    @State private var showingInvitations = false
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    @State private var selectedFilter: SessionFilter = .liveNow
    @State private var selectedSort: SessionSort = .recentlyStarted
    @State private var isLoadingPublicSessions = false
    @State private var publicSessions: [LiveSession] = []
    
    enum SessionFilter: String, CaseIterable {
        case liveNow = "Live Now"
        case upcoming = "Upcoming"
        case past = "Past"
        case mySessions = "My Sessions"
        case favorites = "Favorites"
        case archived = "Archived"
    }
    
    enum SessionSort: String, CaseIterable {
        case recentlyStarted = "Recently Started"
        case mostPopular = "Most Popular"
        case mostParticipants = "Most Participants"
        case alphabetical = "Alphabetical"
    }
    
    // Combine local and public sessions, removing duplicates
    var allSessionsCombined: [LiveSession] {
        var combined = allSessions
        // Add public sessions that aren't already in local
        let localIds = Set(combined.map { $0.id })
        for publicSession in publicSessions {
            if !localIds.contains(publicSession.id) {
                combined.append(publicSession)
            }
        }
        // Remove duplicates by ID, keeping most recent
        var unique: [LiveSession] = []
        var seenIds: Set<UUID> = []
        for session in combined.sorted(by: { $0.startTime > $1.startTime }) {
            if !seenIds.contains(session.id) {
                unique.append(session)
                seenIds.insert(session.id)
            }
        }
        return unique
    }
    
    var liveNowSessions: [LiveSession] {
        allSessionsCombined.filter { $0.isActive && !$0.isScheduled }
    }
    
    var upcomingSessions: [LiveSession] {
        allSessionsCombined.filter { $0.isScheduled }
    }
    
    var pastSessions: [LiveSession] {
        allSessionsCombined.filter { !$0.isActive && !$0.isScheduled && !$0.isArchived }
    }
    
    var mySessions: [LiveSession] {
        let userId = userService.userIdentifier
        return allSessionsCombined.filter { $0.hostId == userId && !$0.isArchived }
    }
    
    var favoriteSessions: [LiveSession] {
        allSessionsCombined.filter { $0.isFavorite && !$0.isArchived }
    }
    
    var archivedSessions: [LiveSession] {
        allSessionsCombined.filter { $0.isArchived }
    }
    
    var allActiveSessions: [LiveSession] {
        switch selectedFilter {
        case .liveNow:
            return liveNowSessions
        case .upcoming:
            return upcomingSessions
        case .past:
            return pastSessions
        case .mySessions:
            return mySessions
        case .favorites:
            return favoriteSessions
        case .archived:
            return archivedSessions
        }
    }
    
    var categories: [String] {
        var cats = Set(allActiveSessions.map { $0.category })
        cats.insert("All")
        return Array(cats).sorted()
    }
    
    var filteredSessions: [LiveSession] {
        var filtered = allActiveSessions
        
        if !searchText.isEmpty {
            filtered = filtered.filter { session in
                session.title.localizedCaseInsensitiveContains(searchText) ||
                session.details.localizedCaseInsensitiveContains(searchText) ||
                session.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                session.hostName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Apply sorting
        switch selectedSort {
        case .recentlyStarted:
            filtered = filtered.sorted(by: { $0.startTime > $1.startTime })
        case .mostPopular:
            filtered = filtered.sorted(by: { $0.viewerCount > $1.viewerCount })
        case .mostParticipants:
            filtered = filtered.sorted(by: { $0.currentParticipants > $1.currentParticipants })
        case .alphabetical:
            filtered = filtered.sorted(by: { $0.title < $1.title })
        }
        
        return filtered
    }
    
    var pendingInvitationCount: Int {
        // Safely access userIdentifier with fallback
        let userId = userService.userIdentifier
        return allInvitations.filter { invitation in
            (invitation.invitedUserId == userId || invitation.invitedEmail != nil) &&
            invitation.status == .pending &&
            !invitation.isExpired
        }.count
    }
    
    var body: some View {
        if #available(iOS 17.0, *) {
            NavigationStack {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search sessions...", text: $searchText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Filter Picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SessionFilter.allCases, id: \.self) { filter in
                                SessionFilterChip(
                                    title: filter.rawValue,
                                    isSelected: selectedFilter == filter,
                                    count: filterCount(for: filter)
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    
                    // Category Filter
                    if !categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { category in
                                    CategoryChip(
                                        title: category,
                                        isSelected: selectedCategory == category,
                                        color: Color.purple
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                    }
                    
                    // Sort Picker
                    HStack {
                        Text("Sort:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Sort", selection: $selectedSort) {
                            ForEach(SessionSort.allCases, id: \.self) { sort in
                                Text(sort.rawValue).tag(sort)
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    
                    if filteredSessions.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            if isLoadingPublicSessions {
                                ProgressView()
                                    .padding()
                            } else {
                                Text(filteredSessions.isEmpty ? "No Live Sessions" : "No Active Sessions")
                                    .font(.title2.weight(.semibold))
                                
                                Text(filteredSessions.isEmpty ? "Create your first live prayer or study session" : "Check back later for active sessions")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Button(action: { showingCreateSession = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create Session")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Live Now Section (if applicable)
                                if selectedFilter == .liveNow && !liveNowSessions.isEmpty {
                                    SectionHeader(title: "🔴 Live Now", count: liveNowSessions.count)
                                    
                                    ForEach(liveNowSessions.prefix(3)) { session in
                                        EnhancedLiveSessionCard(session: session) {
                                            selectedSession = session
                                            showingSessionDetail = true
                                        }
                                    }
                                    
                                    if liveNowSessions.count > 3 {
                                        Button("View All Live Sessions") {
                                            // Show all live sessions
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.purple)
                                        .padding(.vertical, 8)
                                    }
                                }
                                
                                // Main Session List
                                ForEach(filteredSessions) { session in
                                    EnhancedLiveSessionCard(session: session) {
                                        selectedSession = session
                                        showingSessionDetail = true
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
                .navigationTitle("Live Sessions")
                .navigationViewStyle(.stack) // Force full-width layout on iPad
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingInvitations = true }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "envelope.fill")
                                    .font(.body.weight(.semibold))
                                
                                if pendingInvitationCount > 0 {
                                    Text("\(pendingInvitationCount)")
                                        .font(.caption2)
                                        .font(.body.weight(.bold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingCreateSession = true }) {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                .sheet(isPresented: $showingInvitations) {
                    InvitationsView()
                }
                .sheet(isPresented: $showingCreateSession) {
                    CreateLiveSessionView()
                }
                .sheet(item: $selectedSession) { session in
                    LiveSessionDetailView(session: session)
                }
                .onAppear {
                    // Ensure CloudKit services are initialized before use
                    // Note: App works fully without CloudKit - this is optional for multi-user features
                    Task { @MainActor in
                        // CloudKitPublicSyncService removed - use Firebase for sync
                        // Sync service initialization removed
                        // Give services a moment to initialize
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        loadPublicSessions()
                        setupSubscriptions()
                    }
                }
                .refreshable {
                    await refreshPublicSessions()
                }
            }
        } else {
            Text("Live Sessions are only available on iOS 17+")
        }
    }
    
    private func loadPublicSessions() {
        isLoadingPublicSessions = true
        Task { @MainActor in
            // Wait a bit for CloudKit to initialize if needed
            if !userService.isAuthenticated {
                // CloudKit might still be initializing - wait and recheck
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                // Re-check authentication after delay
                await userService.checkAuthentication()
            }
            
            // CloudKitPublicSyncService removed - use Firebase for sync
            // Only fetch public sessions if authenticated
            if userService.isAuthenticated {
                // let sessions = // CloudKitPublicSyncService removed - use Firebase for sync
                // try await sync.fetchPublicSessions()
                // publicSessions = sessions
                publicSessions = [] // Firebase sync to be implemented
            } else {
                // Not authenticated or sync service unavailable - just use local sessions
                publicSessions = []
            }
            isLoadingPublicSessions = false
        }
    }
    
    private func refreshPublicSessions() async {
        // CloudKitPublicSyncService removed - use Firebase for sync
        guard await MainActor.run(body: { userService.isAuthenticated }) else { return }
        // CloudKitPublicSyncService removed - use Firebase for sync
        // let sync = await MainActor.run(body: { syncService })
        
        // CloudKitPublicSyncService removed - use Firebase for sync
        // let sessions = try await sync.fetchPublicSessions()
        await MainActor.run {
            self.publicSessions = [] // Firebase sync to be implemented
        }
    }
    
    private func setupSubscriptions() {
        Task { @MainActor in
            // Wait a bit for CloudKit to initialize if needed
            if !userService.isAuthenticated {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                // Re-check authentication after delay
                await userService.checkAuthentication()
            }
            
            // CloudKitPublicSyncService removed - use Firebase for sync
            guard userService.isAuthenticated else {
                print("User not authenticated - skipping subscriptions")
                return
            }
            // CloudKitPublicSyncService removed - use Firebase for sync
            // let sync = syncService
            // try await sync.subscribeToSessions()
        }
    }
    
    private func filterCount(for filter: SessionFilter) -> Int {
        switch filter {
        case .liveNow:
            return liveNowSessions.count
        case .upcoming:
            return upcomingSessions.count
        case .past:
            return pastSessions.count
        case .mySessions:
            return mySessions.count
        case .favorites:
            return favoriteSessions.count
        case .archived:
            return archivedSessions.count
        }
    }
}

// MARK: - Enhanced Components

struct SectionHeader: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .font(.body.weight(.bold))
            Text("(\(count))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct SessionFilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.purple : Color(.systemGray5))
            )
        }
    }
}

@available(iOS 17.0, *)
struct EnhancedLiveSessionCard: View {
    let session: LiveSession
    let onTap: () -> Void
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    @State private var isFavorite = false
    
    var isHost: Bool {
        session.hostId == userService.userIdentifier
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Thumbnail/Preview Area
                ZStack(alignment: .topTrailing) {
                    // Thumbnail placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 180)
                        .overlay(
                            VStack {
                                Image(systemName: session.category == "Prayer" ? "hands.sparkles.fill" : "book.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        )
                    
                    // Status badges
                    HStack {
                        if session.isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(.caption2)
                                    .font(.body.weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        } else if session.endTime != nil {
                            // Show ENDED badge for ended sessions
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                Text("ENDED")
                                    .font(.caption2)
                                    .font(.body.weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(8)
                        }
                        
                        if session.viewerCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                Text("\(session.viewerCount)")
                            }
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        // Favorite button
                        Button(action: {
                            isFavorite.toggle()
                            session.isFavorite = isFavorite
                        }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : .white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(8)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            HStack(spacing: 8) {
                                // Host info
                                HStack(spacing: 4) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.caption)
                                    Text(session.hostName.isEmpty ? "Host" : session.hostName)
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                                
                                // Category
                                Text(session.category)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(8)
                            }
                        }
                        
                        Spacer()
                        
                        // Status indicator
                        if !session.isActive && session.endTime != nil {
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                    Text("Ended")
                                        .font(.caption)
                                        .font(.body.weight(.semibold))
                                }
                                .foregroundColor(.secondary)
                                
                                if let endTime = session.endTime {
                                    Text(endTime, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else if session.isActive && !isHost {
                            // Quick Join Button (if live)
                            Button(action: onTap) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Text(session.details)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Stats
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text("\(session.currentParticipants)/\(session.maxParticipants)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        if session.isActive {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                Text(session.formattedDuration)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        } else if let endTime = session.endTime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.badge.checkmark.fill")
                                Text("Ended \(endTime, style: .relative)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        // Connection quality
                        HStack(spacing: 4) {
                            Circle()
                                .fill(qualityColor)
                                .frame(width: 6, height: 6)
                            Text(session.connectionQuality)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Tags
                        if !session.tags.isEmpty {
                            ForEach(session.tags.prefix(2), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            isFavorite = session.isFavorite
        }
    }
    
    private var qualityColor: Color {
        switch session.connectionQuality {
        case "Good":
            return .green
        case "Fair":
            return .yellow
        case "Poor":
            return .red
        default:
            return .gray
        }
    }
}

@available(iOS 17.0, *)
struct LiveSessionCard: View {
    let session: LiveSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title)
                            .font(.headline)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text(session.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text("\(session.currentParticipants)/\(session.maxParticipants)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        if session.isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Live")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Text(session.details)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    if !session.tags.isEmpty {
                        ForEach(session.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    Text(session.startTime, style: .relative)
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

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .font(.body.weight(.medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? color : Color(.systemGray5))
                )
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

@available(iOS 17.0, *)
struct CreateLiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var userProfiles: [UserProfile]
    @ObservedObject private var themeManager = ThemeManager.shared
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    private var userProfile: UserProfile? { userProfiles.first }
    // Use regular property for singleton, not @StateObject
    // CloudKitPublicSyncService removed - use Firebase for sync in the future
    // private let syncService = CloudKitPublicSyncService.shared
    // Note: SessionNotificationService.swift needs to be added to Xcode project
    // private let notificationService = SessionNotificationService.shared
    @State private var title = ""
    @State private var details = ""
    @State private var category = "Prayer"
    @State private var maxParticipants = 10
    @State private var tags = ""
    @State private var selectedTags: Set<String> = []
    @State private var manualTagInput = ""
    @State private var isPrivate = false
    @State private var scheduledDate: Date?
    @State private var enableReminders = true
    @State private var reminderMinutes: Int = 5
    @State private var addToCalendar = false
    
    let categories = ["Prayer", "Bible Study", "Devotional", "Testimony", "Fellowship", "Other"]
    let predefinedTags = ["Prayer", "Bible Study", "Fellowship", "Worship", "Testimony", "Encouragement", "Healing", "Praise", "Intercession", "Community"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - use adaptive color for dark mode support
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        headerSection
                        
                        // Session Details Card
                        sessionDetailsCard
                        
                        // Category Selection Card
                        categoryCard
                        
                        // Settings Cards
                        participantsCard
                        
                        if scheduledDate != nil || enableReminders {
                            scheduleCard
                        }
                        
                        if enableReminders {
                            remindersCard
                        }
                        
                        // Privacy & Tags Card
                        privacyAndTagsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Live Session")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Initialize selectedTags from tags string if it exists
                if !tags.isEmpty {
                    let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    selectedTags = Set(tagArray)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                        .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { createSession() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Create")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            title.isEmpty || details.isEmpty ?
                            LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            themeManager.colors.primaryGradient
                        )
                        .cornerRadius(12)
                    }
                    .disabled(title.isEmpty || details.isEmpty)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.primaryGradient)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "video.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            Text("Start a Live Session")
                .font(.title2)
                .font(.body.weight(.bold))
                .foregroundColor(.primary)
            
            Text("Connect with others in real-time")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
    
    private var sessionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Session Details")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                TextField("Enter session title", text: $title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                
                ZStack(alignment: .topLeading) {
                    if details.isEmpty {
                        Text("Describe your session...")
                            .foregroundColor(Color(.placeholderText))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                        .foregroundColor(.primary)
                        .padding(4)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(12)
                        .scrollContentBackground(.hidden)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Category")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { cat in
                        CategoryChip(
                            title: cat,
                            isSelected: category == cat,
                            color: themeManager.colors.primary
                        ) {
                            category = cat
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Participants")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            HStack {
                Text("Max Participants")
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        if maxParticipants > 2 {
                            maxParticipants -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(maxParticipants > 2 ? themeManager.colors.primary : .gray)
                            .font(.title3)
                    }
                    .disabled(maxParticipants <= 2)
                    
                    Text("\(maxParticipants)")
                        .font(.title2)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(minWidth: 40)
                    
                    Button(action: {
                        if maxParticipants < 50 {
                            maxParticipants += 1
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(maxParticipants < 50 ? themeManager.colors.primary : .gray)
                            .font(.title3)
                    }
                    .disabled(maxParticipants >= 50)
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Schedule")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { scheduledDate != nil },
                    set: { if $0 { scheduledDate = Date().addingTimeInterval(3600) } else { scheduledDate = nil } }
                )) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(themeManager.colors.primary)
                        Text("Schedule Session")
                            .foregroundColor(.primary)
                    }
                }
                .tint(themeManager.colors.primary)
                
                if scheduledDate != nil {
                    DatePicker("Start Time", selection: Binding(
                        get: { scheduledDate ?? Date() },
                        set: { scheduledDate = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Reminders")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                Toggle(isOn: $enableReminders) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(themeManager.colors.primary)
                        Text("Enable Reminders")
                            .foregroundColor(.primary)
                    }
                }
                .tint(themeManager.colors.primary)
                
                if enableReminders {
                    Picker("Remind Me", selection: $reminderMinutes) {
                        Text("5 minutes before").tag(5)
                        Text("15 minutes before").tag(15)
                        Text("30 minutes before").tag(30)
                        Text("1 hour before").tag(60)
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                    
                    Toggle(isOn: $addToCalendar) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundColor(themeManager.colors.primary)
                            Text("Add to Calendar")
                                .foregroundColor(.primary)
                        }
                    }
                    .tint(themeManager.colors.primary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var privacyAndTagsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Privacy & Tags")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                Toggle(isOn: $isPrivate) {
                    HStack {
                        Image(systemName: isPrivate ? "lock.fill" : "lock.open.fill")
                            .foregroundColor(themeManager.colors.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private Session")
                                .foregroundColor(.primary)
                            Text(isPrivate ? "Only invited users can join" : "Anyone with the link can join")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(themeManager.colors.primary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.subheadline)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                    
                    // Predefined tags selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(predefinedTags, id: \.self) { tag in
                                Button(action: {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                    updateTagsString()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Text(tag)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedTags.contains(tag) ?
                                        themeManager.colors.primary.opacity(0.2) :
                                        Color(.tertiarySystemFill)
                                    )
                                    .foregroundColor(
                                        selectedTags.contains(tag) ?
                                        themeManager.colors.primary :
                                        .primary
                                    )
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Manual tag entry
                    HStack(spacing: 8) {
                        TextField("Add custom tag...", text: $manualTagInput)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(12)
                            .onSubmit {
                                addManualTag()
                            }
                        
                        Button(action: {
                            addManualTag()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(themeManager.colors.primary)
                        }
                        .disabled(manualTagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    // Display selected tags
                    if !selectedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Selected Tags:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Wrap tags in a flexible layout
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 8) {
                                ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text("#\(tag)")
                                            .font(.caption)
                                        Button(action: {
                                            selectedTags.remove(tag)
                                            updateTagsString()
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeManager.colors.primary.opacity(0.15))
                                    .foregroundColor(themeManager.colors.primary)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func addManualTag() {
        let trimmedTag = manualTagInput.trimmingCharacters(in: .whitespaces)
        if !trimmedTag.isEmpty && !selectedTags.contains(trimmedTag) {
            selectedTags.insert(trimmedTag)
            manualTagInput = ""
            updateTagsString()
        }
    }
    
    private func updateTagsString() {
        tags = Array(selectedTags).sorted().joined(separator: ", ")
    }
    
    private func createSession() {
        let tagArray = Array(selectedTags)
        // Use CloudKit user ID for multi-user support
        let userId = userService.userIdentifier
        let userName = userService.getDisplayName(userProfile: userProfile)
        
        let session = LiveSession(
            title: title,
            description: details,
            hostId: userId,
            category: category,
            maxParticipants: maxParticipants,
            tags: tagArray
        )
        session.isPrivate = isPrivate
        session.hostName = userName
        if let scheduled = scheduledDate {
            session.scheduledStartTime = scheduled
            session.isActive = false // Scheduled sessions are not active until start time
        }
        
        modelContext.insert(session)
        
        // Create participant entry for host
        let participant = LiveSessionParticipant(
            sessionId: session.id,
            userId: userId,
            userName: userName,
            isHost: true
        )
        modelContext.insert(participant)
        
        do {
            try modelContext.save()
            
            // CloudKitPublicSyncService removed - use Firebase for sync
            if !isPrivate && userService.isAuthenticated {
                // Task {
                //     // Sync session to Firebase
                //     // // CloudKitPublicSyncService removed - use Firebase for sync
                    // try await sync.syncSessionToPublic(session)
                //     // // CloudKitPublicSyncService removed - use Firebase for sync
                    // try await sync.syncParticipantToPublic(participant)
                // }
            }
            
            // Schedule notifications and calendar event
            // Note: Uncomment when SessionNotificationService.swift is added to Xcode project
            /*
            if let scheduled = scheduledDate {
                if enableReminders {
                    await notificationService.scheduleSessionStartingSoon(session: session, minutesBefore: reminderMinutes)
                }
                
                if addToCalendar {
                    do {
                        try await notificationService.addSessionToCalendar(session: session)
                    } catch {
                        print("Error adding to calendar: \(error)")
                    }
                }
            }
            */
            
            dismiss()
        } catch {
            print("Error creating session: \(error)")
        }
    }
}

@available(iOS 17.0, *)
struct LiveSessionDetailView: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var participants: [LiveSessionParticipant]
    @Query var invitations: [SessionInvitation]
    @Query var userProfiles: [UserProfile]
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    private var userProfile: UserProfile? { userProfiles.first }
    // CloudKitPublicSyncService removed - use Firebase for sync in the future
    // @State private var syncService: CloudKitPublicSyncService?
    @State private var showingChat = false
    @State private var hasJoined = false
    @State private var showingShareSheet = false
    @State private var showingInviteUsers = false
    @State private var showingInviteCode = false
    @State private var showingLiveStream = false
    @State private var showingBroadcastStream = false
    @State private var showingMultiParticipantStream = false
    @State private var streamMode: StreamMode = .broadcast
    @State private var showingHostProfile = false
    @State private var showingAgenda = false
    @State private var showingAnalytics = false
    @State private var showingRecording = false
    @State private var showingDeleteConfirmation = false
    @State private var showingArchiveConfirmation = false
    @Query var messages: [ChatMessage]
    
    enum StreamMode {
        case broadcast
        case conference
        case multiParticipant
    }
    
    var shareText: String {
        """
        Join me for a live session: \(session.title)
        
        \(session.details)
        
        Category: \(session.category)
        Participants: \(session.currentParticipants)/\(session.maxParticipants)
        """
    }
    
    var sessionParticipants: [LiveSessionParticipant] {
        participants.filter { $0.sessionId == session.id && $0.isActive }
    }
    
    var canJoin: Bool {
        session.isActive && session.currentParticipants < session.maxParticipants
    }
    
    var isHost: Bool {
        // Safely check if current user is host
        let userId = userService.userIdentifier
        return session.hostId == userId
    }
    
    var sessionInvitations: [SessionInvitation] {
        invitations.filter { $0.sessionId == session.id }
    }
    
    var primaryInviteCode: String? {
        sessionInvitations.first(where: { $0.status == .pending })?.inviteCode ??
        sessionInvitations.first?.inviteCode
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(session.category)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            if session.isActive {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Live")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else if session.isScheduled, let timeUntil = session.timeUntilStart {
                                CountdownTimerView(timeUntil: timeUntil)
                            }
                        }
                        
                        Text(session.title)
                            .font(.title)
                            .font(.body.weight(.bold))
                        
                        Text(session.details)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        // Host Profile
                        Button(action: { showingHostProfile = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.hostName.isEmpty ? "Host" : session.hostName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if !session.hostBio.isEmpty {
                                        Text(session.hostBio)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Agenda (if available)
                    if !session.agenda.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Agenda")
                                    .font(.headline)
                                Spacer()
                                Button(action: { showingAgenda = true }) {
                                    Text("View Full")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                            }
                            
                            Text(session.agenda)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Related Resources
                    if !session.relatedResources.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Resources")
                                .font(.headline)
                            
                            ForEach(session.relatedResources.prefix(3), id: \.self) { resource in
                                HStack {
                                    Image(systemName: "book.fill")
                                        .foregroundColor(.purple)
                                    Text(resource)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Participants with enhanced features
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Participants (\(sessionParticipants.count)/\(session.maxParticipants))")
                                .font(.headline)
                            
                            Spacer()
                            
                            // Connection quality indicator (during stream)
                            if session.isActive {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(connectionQualityColor)
                                        .frame(width: 8, height: 8)
                                    Text(session.connectionQuality)
                                        .font(.caption)
                                }
                            }
                            
                            // Stream stats (during stream)
                            if session.isActive && session.viewerCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.fill")
                                    Text("\(session.viewerCount)")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                        
                        if sessionParticipants.isEmpty {
                            Text("No participants yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(sessionParticipants) { participant in
                                        EnhancedParticipantBadge(
                                            participant: participant,
                                            isHost: isHost,
                                            onRaiseHand: { raiseHand() },
                                            onMute: { muteParticipant(participant) },
                                            onRemove: { removeParticipant(participant) },
                                            onPromote: { promoteToCoHost(participant) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    
                    // Chat Preview (during stream)
                    if session.isActive && hasJoined {
                        let recentMessages = messages.filter { $0.sessionId == session.id }.suffix(3)
                        if !recentMessages.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Recent Messages")
                                        .font(.headline)
                                    Spacer()
                                    Button(action: { showingChat = true }) {
                                        Text("View All")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                }
                                
                                ForEach(Array(recentMessages), id: \.id) { message in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(.purple)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(message.userName)
                                                .font(.caption)
                                                .font(.body.weight(.semibold))
                                            Text(message.message)
                                                .font(.subheadline)
                                                .lineLimit(2)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(message.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Tags
                    if !session.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(session.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Invitation Code (if host or private session)
                    if isHost || session.isPrivate {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Invitation Code")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if isHost {
                                    Button(action: { showingInviteCode = true }) {
                                        Image(systemName: "qrcode")
                                            .foregroundColor(.purple)
                                    }
                                }
                            }
                            
                            if let code = primaryInviteCode {
                                HStack {
                                    Text(code)
                                        .font(.title2)
                                        .font(.body.weight(.bold))
                                        .foregroundColor(.purple)
                                        .fontDesign(.monospaced)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        UIPasteboard.general.string = code
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.title3)
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                            } else if isHost {
                                Button(action: { showingInviteCode = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                        Text("Generate Invitation Code")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Host Actions
                        if isHost {
                            // Host Controls Section
                            if hasJoined && session.isActive {
                                VStack(spacing: 8) {
                                    HStack(spacing: 12) {
                                        Button(action: lockSession) {
                                            HStack(spacing: 4) {
                                                Image(systemName: session.isLocked ? "lock.fill" : "lock.open.fill")
                                                Text(session.isLocked ? "Unlock" : "Lock")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(session.isLocked ? Color.red : Color.orange)
                                            .cornerRadius(8)
                                        }
                                        
                                        Button(action: { showingAnalytics = true }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "chart.bar.fill")
                                                Text("Analytics")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.purple)
                                            .cornerRadius(8)
                                        }
                                        
                                        Button(action: endSessionForAll) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "stop.circle.fill")
                                                Text("End All")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.red)
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            
                            // Start Live Stream Button
                            if hasJoined {
                                VStack(spacing: 8) {
                                    Button(action: { startLiveStream() }) {
                                        HStack {
                                            Image(systemName: "video.fill")
                                            Text("Start Live Stream")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.red, Color.orange]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                    }
                                    
                                    // Stream Mode Picker
                                    Picker("Stream Mode", selection: $streamMode) {
                                        Text("Broadcast").tag(StreamMode.broadcast)
                                        Text("Conference").tag(StreamMode.conference)
                                        Text("Multi-Participant").tag(StreamMode.multiParticipant)
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                            
                            Button(action: { showingInviteUsers = true }) {
                                HStack {
                                    Image(systemName: "person.2.badge.plus")
                                    Text("Invite Users")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            if hasJoined {
                                Button(action: { showingChat = true }) {
                                    HStack {
                                        Image(systemName: "message.fill")
                                        Text("Open Chat")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(12)
                                }
                            }
                        } else {
                            // Non-host Actions
                            if canJoin && !hasJoined {
                                Button(action: joinSession) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                        Text("Join Session")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(12)
                                }
                            } else if hasJoined {
                                // Join Live Stream Button
                                Button(action: { joinLiveStream() }) {
                                    HStack {
                                        Image(systemName: "video.fill")
                                        Text("Join Live Stream")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                
                                Button(action: { showingChat = true }) {
                                    HStack {
                                        Image(systemName: "message.fill")
                                        Text("Open Chat")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        // Social Sharing
                        VStack(spacing: 8) {
                            Button(action: shareSession) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Session")
                                }
                                .font(.subheadline)
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            HStack(spacing: 12) {
                                // Share to social media
                                Button(action: { shareToSocialMedia(platform: "twitter") }) {
                                    HStack {
                                        Image(systemName: "at")
                                        Text("Twitter")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                }
                                
                                Button(action: { shareToSocialMedia(platform: "facebook") }) {
                                    HStack {
                                        Image(systemName: "f.circle.fill")
                                        Text("Facebook")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: { shareToSocialMedia(platform: "instagram") }) {
                                    HStack {
                                        Image(systemName: "camera.fill")
                                        Text("Instagram")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.purple, Color.pink]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(8)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    
                    // Post-Stream Features
                    if !session.isActive && session.endTime != nil {
                        VStack(alignment: .leading, spacing: 16) {
                            // Enhanced Ended Status Banner
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Session Ended")
                                        .font(.headline)
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.primary)
                                    
                                    if let endTime = session.endTime {
                                        Text("Ended \(endTime, style: .relative)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Text("Duration: \(session.formattedDuration)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            .padding(.bottom, 8)
                            
                            // Original "Session Ended" text removed - now in banner above
                            
                            // Recording availability
                            if let recordingURL = session.recordingURL, !recordingURL.isEmpty {
                                Button(action: { showingRecording = true }) {
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                        Text("Watch Recording")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Transcript
                            if let transcriptURL = session.transcriptURL, !transcriptURL.isEmpty {
                                Button(action: { /* Open transcript */ }) {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                        Text("View Transcript")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                    .padding()
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Session Summary
                            if !session.summary.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Session Summary")
                                        .font(.headline)
                                    Text(session.summary)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            
                            // Analytics (for hosts)
                            if isHost {
                                Button(action: { showingAnalytics = true }) {
                                    HStack {
                                        Image(systemName: "chart.bar.fill")
                                        Text("View Analytics")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                    .padding()
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Archive/Unarchive (for completed sessions)
                            if !session.isActive && session.endTime != nil {
                                Button(action: {
                                    if session.isArchived {
                                        unarchiveSession()
                                    } else {
                                        showingArchiveConfirmation = true
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: session.isArchived ? "archivebox.fill" : "archivebox")
                                        Text(session.isArchived ? "Unarchive Session" : "Archive Session")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(session.isArchived ? .orange : .blue)
                                    .padding()
                                    .background((session.isArchived ? Color.orange : Color.blue).opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isHost {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button(role: .destructive, action: {
                                showingDeleteConfirmation = true
                            }) {
                                Label("Delete Session", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Session", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSession()
                }
            } message: {
                Text("Are you sure you want to delete this session? This action cannot be undone. All participants, messages, and recordings associated with this session will be removed.")
            }
            .alert("Archive Session", isPresented: $showingArchiveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Archive") {
                    archiveSession()
                }
            } message: {
                Text("Archive this session? Archived sessions will be moved to the Archived section and hidden from your main session list. You can unarchive it later if needed.")
            }
            .sheet(isPresented: $showingChat) {
                LiveSessionChatView(session: session)
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(activityItems: [shareText])
            }
            .sheet(isPresented: $showingInviteUsers) {
                InviteUsersView(session: session)
            }
            .sheet(isPresented: $showingInviteCode) {
                InviteCodeView(session: session)
            }
            .fullScreenCover(isPresented: $showingLiveStream) {
                LiveStreamView(session: session)
            }
            .fullScreenCover(isPresented: $showingBroadcastStream) {
                if #available(iOS 17.0, *) {
                    BroadcastStreamView_HLS(session: session)
                }
            }
            .fullScreenCover(isPresented: $showingMultiParticipantStream) {
                if #available(iOS 17.0, *) {
                    MultiParticipantStreamView(session: session)
                }
            }
            .sheet(isPresented: $showingHostProfile) {
                HostProfileView(session: session)
            }
            .sheet(isPresented: $showingAgenda) {
                AgendaView(agenda: session.agenda)
            }
            .sheet(isPresented: $showingAnalytics) {
                SessionAnalyticsView(session: session)
            }
            .sheet(isPresented: $showingRecording) {
                if let url = session.recordingURL, !url.isEmpty {
                    RecordingPlayerView(recordingURL: url)
                }
            }
            .onAppear {
                // Initialize sync service safely
                // CloudKitPublicSyncService removed - use Firebase for sync
                // if syncService == nil {
                //     syncService = CloudKitPublicSyncService.shared
                // }
                checkJoinStatus()
                if isHost && primaryInviteCode == nil {
                    generateInviteCodeIfNeeded()
                }
            }
        }
    }
    
    private var connectionQualityColor: Color {
        switch session.connectionQuality {
        case "Good", "Excellent": return .green
        case "Fair": return .yellow
        case "Poor": return .red
        default: return .gray
        }
    }
    
    private func raiseHand() {
        // Implement raise hand functionality
        if let participant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier }) {
            participant.handRaised = true
            try? modelContext.save()
        }
    }
    
    private func muteParticipant(_ participant: LiveSessionParticipant) {
        guard isHost else { return }
        participant.isMuted = true
        try? modelContext.save()
    }
    
    private func removeParticipant(_ participant: LiveSessionParticipant) {
        guard isHost && !participant.isHost else { return }
        participant.isActive = false
        session.currentParticipants = max(0, session.currentParticipants - 1)
        try? modelContext.save()
    }
    
    private func lockSession() {
        guard isHost else { return }
        session.isLocked.toggle()
        try? modelContext.save()
    }
    
    private func endSessionForAll() {
        guard isHost else { return }
        session.isActive = false
        session.endTime = Date()
        // Mark all participants as inactive
        for participant in sessionParticipants {
            participant.isActive = false
            participant.leftAt = Date()
        }
        try? modelContext.save()
    }
    
    private func archiveSession() {
        guard !session.isActive && session.endTime != nil else { return }
        
        session.isArchived = true
        
        do {
            try modelContext.save()
            print("✅ Session archived: \(session.title)")
        } catch {
            print("❌ Error archiving session: \(error)")
        }
    }
    
    private func unarchiveSession() {
        session.isArchived = false
        
        do {
            try modelContext.save()
            print("✅ Session unarchived: \(session.title)")
        } catch {
            print("❌ Error unarchiving session: \(error)")
        }
    }
    
    private func deleteSession() {
        guard isHost else { return }
        
        // Delete all associated participants
        for participant in sessionParticipants {
            modelContext.delete(participant)
        }
        
        // Delete all associated messages
        let sessionMessages = messages.filter { $0.sessionId == session.id }
        for message in sessionMessages {
            modelContext.delete(message)
        }
        
        // Delete all associated invitations
        let sessionInvitations = invitations.filter { $0.sessionId == session.id }
        for invitation in sessionInvitations {
            modelContext.delete(invitation)
        }
        
        // Delete the session itself
        modelContext.delete(session)
        
        do {
            try modelContext.save()
            
            // CloudKitPublicSyncService removed - use Firebase for sync
            // if userService.isAuthenticated, let sync = syncService {
            //     Task {
            //         do {
            //             try await sync.deleteSession(session.id)
            //         } catch {
            //             print("Error deleting session from CloudKit: \(error)")
            //         }
            //     }
            // }
            
            dismiss()
        } catch {
            print("Error deleting session: \(error)")
        }
    }
    
    private func promoteToCoHost(_ participant: LiveSessionParticipant) {
        guard isHost && !participant.isHost else { return }
        participant.isCoHost = true
        try? modelContext.save()
    }
    
    private func startLiveStream() {
        switch streamMode {
        case .broadcast:
            showingBroadcastStream = true
        case .conference:
            showingLiveStream = true
        case .multiParticipant:
            showingMultiParticipantStream = true
        }
    }
    
    private func joinLiveStream() {
        // For non-hosts, join as viewer/participant
        // Try to determine stream mode from session or default to conference
        if session.currentParticipants > 1 {
            showingMultiParticipantStream = true
        } else {
            showingLiveStream = true
        }
    }
    
    private func checkJoinStatus() {
        let userId = userService.userIdentifier
        hasJoined = sessionParticipants.contains { $0.userId == userId }
    }
    
    private func joinSession() {
        let userId = userService.userIdentifier
        let userName = userService.getDisplayName(userProfile: userProfile)
        
        let participant = LiveSessionParticipant(
            sessionId: session.id,
            userId: userId,
            userName: userName,
            isHost: false
        )
        modelContext.insert(participant)
        
        session.currentParticipants += 1
        
        do {
            try modelContext.save()
            
            // CloudKitPublicSyncService removed - use Firebase for sync
            // if userService.isAuthenticated && !session.isPrivate, let sync = syncService {
            //     Task {
            //         do {
            //             try await sync.syncParticipantToPublic(participant)
            //             try await sync.syncSessionToPublic(session)
            //         } catch {
            //             print("Error syncing participant to public database: \(error)")
            //         }
            //     }
            // }
            
            hasJoined = true
            
            // Schedule notification for participant joined (if host)
            // Note: Uncomment when SessionNotificationService.swift is added to Xcode project
            /*
            if isHost {
                await notificationService.scheduleParticipantJoined(session: session, participantName: userName)
            }
            */
        } catch {
            print("Error joining session: \(error)")
        }
    }
    
    private func shareSession() {
        showingShareSheet = true
    }
    
    private func shareToSocialMedia(platform: String) {
        // In production, integrate with social media SDKs
        // For now, use share sheet with platform-specific text
        let shareText = platform == "twitter" 
            ? "Join me for a live session: \(session.title) #FaithJournal"
            : "Join me for a live session on Faith Journal!"
        // TODO: Use shareText when implementing actual sharing
        _ = shareText // Suppress warning until sharing is implemented
        showingShareSheet = true
    }
    
    private func generateInviteCodeIfNeeded() {
        // Generate default invite code for host if none exists
        if primaryInviteCode == nil {
            let code = UUID().uuidString.prefix(8).uppercased()
            let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
            let invitation = SessionInvitation(
                sessionId: session.id,
                sessionTitle: session.title,
                hostId: session.hostId,
                hostName: userService.getDisplayName(userProfile: userProfile),
                inviteCode: String(code),
                expiresAt: expirationDate
            )
            modelContext.insert(invitation)
            do {
                try modelContext.save()
                
                // Sync to Firebase for cross-device sync
                Task {
                    await FirebaseSyncService.shared.syncSessionInvitation(invitation)
                    print("✅ [INVITATION] Synced invitation to Firebase: \(code)")
                }
            } catch {
                print("❌ Error saving invitation: \(error.localizedDescription)")
                ErrorHandler.shared.handle(.saveFailed)
            }
        }
    }
}

@available(iOS 17.0, *)
struct ParticipantBadge: View {
    let participant: LiveSessionParticipant
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: participant.isHost ? "crown.fill" : "person.fill")
                .font(.title2)
                .foregroundColor(participant.isHost ? .orange : .purple)
            
            Text(participant.userName)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

@available(iOS 17.0, *)
struct EnhancedParticipantBadge: View {
    let participant: LiveSessionParticipant
    let isHost: Bool
    let onRaiseHand: () -> Void
    let onMute: () -> Void
    let onRemove: () -> Void
    let onPromote: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: participant.isHost ? "crown.fill" : "person.fill")
                    .font(.title2)
                    .foregroundColor(participant.isHost ? .orange : .purple)
                
                // Speaking indicator
                if participant.isSpeaking {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                
                // Hand raised indicator
                if participant.handRaised {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .offset(x: -4, y: -4)
                }
            }
            
            Text(participant.userName)
                .font(.caption)
                .lineLimit(1)
            
            // Status indicators
            HStack(spacing: 4) {
                if participant.isMuted {
                    Image(systemName: "mic.slash.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                
                if !participant.isVideoEnabled {
                    Image(systemName: "video.slash.fill")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                // Connection quality
                Circle()
                    .fill(qualityColor)
                    .frame(width: 4, height: 4)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .contextMenu {
            if !participant.isHost {
                Button(action: onRaiseHand) {
                    Label("Raise Hand", systemImage: "hand.raised.fill")
                }
            }
            
            if isHost {
                Button(action: onMute) {
                    Label(participant.isMuted ? "Unmute" : "Mute", systemImage: participant.isMuted ? "mic.fill" : "mic.slash.fill")
                }
                
                if !participant.isHost {
                    if !participant.isCoHost {
                        Button(action: onPromote) {
                            Label("Promote to Co-Host", systemImage: "star.fill")
                        }
                    }
                    
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove", systemImage: "person.badge.minus")
                    }
                }
            }
        }
    }
    
    private var qualityColor: Color {
        switch participant.connectionQuality {
        case "Good", "Excellent": return .green
        case "Fair": return .yellow
        case "Poor": return .red
        default: return .gray
        }
    }
}

// MARK: - Supporting Views

@available(iOS 17.0, *)
struct CountdownTimerView: View {
    let timeUntil: TimeInterval
    @State private var remaining: TimeInterval
    
    init(timeUntil: TimeInterval) {
        self.timeUntil = timeUntil
        self._remaining = State(initialValue: timeUntil)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
            Text(formattedTime)
        }
        .font(.caption)
        .foregroundColor(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(8)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                remaining = max(0, remaining - 1)
            }
        }
    }
    
    private var formattedTime: String {
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) / 60 % 60
        let seconds = Int(remaining) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@available(iOS 17.0, *)
struct HostProfileView: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Profile header
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.purple)
                        
                        Text(session.hostName.isEmpty ? "Host" : session.hostName)
                            .font(.title)
                            .font(.body.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    
                    // Bio
                    if !session.hostBio.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                            Text(session.hostBio)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session Stats")
                            .font(.headline)
                        
                        HStack {
                            StatItem(icon: "video.fill", label: "Sessions", value: "\(session.currentParticipants)")
                            StatItem(icon: "eye.fill", label: "Views", value: "\(session.viewerCount)")
                            StatItem(icon: "clock.fill", label: "Duration", value: session.formattedDuration)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Host Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

@available(iOS 17.0, *)
struct AgendaView: View {
    let agenda: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(agenda)
                    .font(.body)
                    .padding()
            }
            .navigationTitle("Session Agenda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct SessionAnalyticsView: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeRange: TimeRange = .allTime
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case allTime = "All Time"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Time range selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Overview")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        AnalyticsCard(title: "Peak Viewers", value: "\(session.peakViewerCount)", icon: "chart.line.uptrend.xyaxis")
                        AnalyticsCard(title: "Total Viewers", value: "\(session.viewerCount)", icon: "eye.fill")
                        AnalyticsCard(title: "Watch Time", value: formatWatchTime(session.viewerCount * Int(session.duration)), icon: "clock.arrow.circlepath")
                        AnalyticsCard(title: "Duration", value: session.formattedDuration, icon: "clock.fill")
                        AnalyticsCard(title: "Participants", value: "\(session.currentParticipants)", icon: "person.2.fill")
                        AnalyticsCard(title: "Avg. Watch Time", value: formatWatchTime(Int(session.duration)), icon: "timer")
                    }
                    .padding(.horizontal)
                    
                    // Engagement Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Engagement")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        EngagementMetricsCard(
                            title: "Engagement Rate",
                            value: "\(calculateEngagementRate())%",
                            icon: "hand.thumbsup.fill"
                        )
                        
                        EngagementMetricsCard(
                            title: "Messages Sent",
                            value: "\(session.messageCount)",
                            icon: "message.fill"
                        )
                        
                        EngagementMetricsCard(
                            title: "Reactions",
                            value: "\(session.reactionCount)",
                            icon: "heart.fill"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Retention Graph (placeholder)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Viewer Retention")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        RetentionGraphView(session: session)
                            .frame(height: 200)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Session Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formatWatchTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func calculateEngagementRate() -> Int {
        guard session.viewerCount > 0 else { return 0 }
        let engagement = (session.messageCount + session.reactionCount) * 100 / session.viewerCount
        return min(engagement, 100)
    }
}

@available(iOS 17.0, *)
struct EngagementMetricsCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .font(.body.weight(.bold))
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 17.0, *)
struct RetentionGraphView: View {
    let session: LiveSession
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                Path { path in
                    for i in 0...4 {
                        let y = geometry.size.height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                
                // Retention line (simplified - in production, use actual data)
                Path { path in
                    let points = generateRetentionPoints(width: geometry.size.width, height: geometry.size.height)
                    if let first = points.first {
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(Color.purple, lineWidth: 2)
                
                // Fill area under curve
                Path { path in
                    let points = generateRetentionPoints(width: geometry.size.width, height: geometry.size.height)
                    if let first = points.first {
                        path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                        path.addLine(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        if let last = points.last {
                            path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                        }
                        path.closeSubpath()
                    }
                }
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
    
    private func generateRetentionPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        // Generate sample retention data (starts at 100%, gradually decreases)
        var points: [CGPoint] = []
        let segments = 20
        for i in 0...segments {
            let x = width * CGFloat(i) / CGFloat(segments)
            let retention = 1.0 - (Double(i) / Double(segments)) * 0.4 // 40% drop over time
            let y = height * (1.0 - CGFloat(retention))
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
}

@available(iOS 17.0, *)
struct AnalyticsCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .font(.body.weight(.bold))
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

@available(iOS 17.0, *)
struct RecordingPlayerView: View {
    let recordingURL: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Recording Player")
                    .font(.headline)
                Text("Recording URL: \(recordingURL)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                
                // Placeholder for video player
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    )
            }
            .navigationTitle("Session Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct LiveSessionChatView: View {
    let session: LiveSession
    @Query var messages: [ChatMessage]
    @Query var userProfiles: [UserProfile]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    private var userProfile: UserProfile? { userProfiles.first }
    // CloudKitPublicSyncService removed - use Firebase for sync in the future
    // @State private var syncService: CloudKitPublicSyncService?
    @State private var messageText = ""
    @State private var publicMessages: [ChatMessage] = []
    @State private var showingPrayerRequest = false
    @State private var showingBibleVersePicker = false
    @State private var showingEmojiPicker = false
    @State private var selectedMessageForReaction: ChatMessage?
    @State private var showingFilePicker = false
    
    var sessionMessages: [ChatMessage] {
        var combined = messages.filter { $0.sessionId == session.id }
        // Add public messages that aren't already in local
        let localIds = Set(combined.map { $0.id })
        for publicMessage in publicMessages {
            if !localIds.contains(publicMessage.id) {
                combined.append(publicMessage)
            }
        }
        // Remove duplicates by ID, keeping most recent
        var unique: [ChatMessage] = []
        var seenIds: Set<UUID> = []
        for message in combined.sorted(by: { $0.timestamp < $1.timestamp }) {
            if !seenIds.contains(message.id) {
                unique.append(message)
                seenIds.insert(message.id)
            }
        }
        return unique
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(sessionMessages) { message in
                            EnhancedChatBubble(
                                message: message,
                                onReaction: { selectedMessageForReaction = message },
                                onAddReaction: { emoji in addReaction(emoji, to: message) }
                            )
                        }
                    }
                    .padding()
                }
                
                // Enhanced input area
                VStack(spacing: 8) {
                    // Quick action buttons
                    HStack(spacing: 12) {
                        Button(action: { showingPrayerRequest = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "hands.sparkles.fill")
                                Text("Prayer")
                            }
                            .font(.caption)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Button(action: { showingBibleVersePicker = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "book.fill")
                                Text("Bible Verse")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Button(action: { showingFilePicker = true }) {
                            Image(systemName: "paperclip")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(8)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Message input
                    HStack(spacing: 12) {
                        TextField("Type a message...", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                if !messageText.isEmpty {
                                    sendMessage()
                                }
                            }
                        
                        Button(action: { showingEmojiPicker = true }) {
                            Image(systemName: "face.smiling")
                                .font(.title3)
                                .foregroundColor(.purple)
                        }
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                        .disabled(messageText.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Session Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                // Initialize sync service safely
                // CloudKitPublicSyncService removed - use Firebase for sync
                // if syncService == nil {
                //     syncService = CloudKitPublicSyncService.shared
                // }
                loadPublicMessages()
                setupMessageSubscription()
            }
            .refreshable {
                await refreshPublicMessages()
            }
            .sheet(isPresented: $showingPrayerRequest) {
                PrayerRequestChatView(onSend: { prayerText in
                    sendPrayerRequest(prayerText)
                    showingPrayerRequest = false
                })
            }
            .sheet(isPresented: $showingBibleVersePicker) {
                BibleVerseChatPicker(onSelect: { verse, reference in
                    sendBibleVerse(verse, reference: reference)
                    showingBibleVersePicker = false
                })
            }
            .sheet(item: $selectedMessageForReaction) { message in
                EmojiReactionPicker { emoji in
                    addReaction(emoji, to: message)
                    selectedMessageForReaction = nil
                }
            }
            .sheet(isPresented: $showingEmojiPicker) {
                ChatEmojiPickerView { emoji in
                    messageText += emoji
                    showingEmojiPicker = false
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.image, .pdf, .text, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        handleFileAttachment(url: url)
                    }
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleFileAttachment(url: URL) {
        // Handle file attachment - for now, just add a note to the message
        // In a full implementation, you would upload the file and attach it to the message
        let fileName = url.lastPathComponent
        messageText += " 📎 \(fileName)"
    }
    
    private func loadPublicMessages() {
        // CloudKitPublicSyncService removed - use Firebase for sync
        // guard userService.isAuthenticated, let sync = syncService else { return }
        // Load messages from Firebase
        publicMessages = []
    }
    
    private func refreshPublicMessages() async {
        // CloudKitPublicSyncService removed - use Firebase for sync
        // guard userService.isAuthenticated, let sync = syncService else { return }
        // Refresh messages from Firebase
        publicMessages = []
    }
    
    private func setupMessageSubscription() {
        // CloudKitPublicSyncService removed - use Firebase for sync
        // guard userService.isAuthenticated, let sync = syncService else { return }
        // Setup Firebase message listener
    }
    
    private func sendMessage() {
        let userId = userService.userIdentifier
        let userName = userService.getDisplayName(userProfile: userProfile)
        
        // Check for @mentions
        let mentionedUserIds = extractMentions(from: messageText)
        
        let message = ChatMessage(
            sessionId: session.id,
            userId: userId,
            userName: userName,
            message: messageText,
            messageType: .text
        )
        message.mentionedUserIds = mentionedUserIds
        modelContext.insert(message)
        
        do {
            try modelContext.save()
            
            // Sync to public CloudKit database for multi-user support
            // CloudKitPublicSyncService removed - use Firebase for sync
            // if userService.isAuthenticated && !session.isPrivate, let sync = syncService {
            //     Task {
            //         do {
            //             try await sync.syncMessageToPublic(message)
            //         } catch {
            //             print("Error syncing message to public database: \(error)")
            //         }
            //     }
            // }
            
            messageText = ""
            
            // Notify other participants (excluding sender)
            // Note: Uncomment when SessionNotificationService.swift is added to Xcode project
            /*
            await notificationService.scheduleNewMessage(
                session: session,
                senderName: userName,
                message: messageText
            )
            */
        } catch {
            print("Error sending message: \(error)")
        }
    }
    
    private func sendPrayerRequest(_ prayerText: String) {
        let userId = userService.userIdentifier
        let userName = userService.getDisplayName(userProfile: userProfile)
        
        let message = ChatMessage(
            sessionId: session.id,
            userId: userId,
            userName: userName,
            message: prayerText,
            messageType: .prayer
        )
        modelContext.insert(message)
        
        do {
            try modelContext.save()
            
            // CloudKitPublicSyncService removed - use Firebase for sync
            // if userService.isAuthenticated && !session.isPrivate, let sync = syncService {
            //     Task {
            //         do {
            //             try await sync.syncMessageToPublic(message)
            //         } catch {
            //             print("Error syncing message to public database: \(error)")
            //         }
            //     }
            // }
        } catch {
            print("Error sending prayer request: \(error)")
        }
    }
    
    private func sendBibleVerse(_ verse: String, reference: String) {
        let userId = userService.userIdentifier
        let userName = userService.getDisplayName(userProfile: userProfile)
        
        let message = ChatMessage(
            sessionId: session.id,
            userId: userId,
            userName: userName,
            message: "\(reference): \(verse)",
            messageType: .scripture
        )
        message.bibleVerseReference = reference
        modelContext.insert(message)
        
        do {
            try modelContext.save()
            
            // CloudKitPublicSyncService removed - use Firebase for sync
            // if userService.isAuthenticated && !session.isPrivate, let sync = syncService {
            //     Task {
            //         do {
            //             try await sync.syncMessageToPublic(message)
            //         } catch {
            //             print("Error syncing message to public database: \(error)")
            //         }
            //     }
            // }
        } catch {
            print("Error sending Bible verse: \(error)")
        }
    }
    
    private func addReaction(_ emoji: String, to message: ChatMessage) {
        if !message.reactions.contains(emoji) {
            message.reactions.append(emoji)
            try? modelContext.save()
        }
    }
    
    private func extractMentions(from text: String) -> [String] {
        // Simple @mention extraction - in production, use regex
        let words = text.components(separatedBy: .whitespaces)
        return words.filter { $0.hasPrefix("@") }.map { String($0.dropFirst()) }
    }
}

@available(iOS 17.0, *)
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.messageType == .system {
                Text(message.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.userName)
                        .font(.caption)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    Text(message.message)
                        .font(.body)
                        .padding(12)
                        .background(message.messageType == .prayer ? Color.purple.opacity(0.1) : Color(.systemGray5))
                        .cornerRadius(12)
                    
                    // Reactions
                    if !message.reactions.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(message.reactions, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

@available(iOS 17.0, *)
struct EnhancedChatBubble: View {
    let message: ChatMessage
    let onReaction: () -> Void
    let onAddReaction: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChatBubble(message: message)
            
            // Reaction button
            Button(action: onReaction) {
                HStack(spacing: 4) {
                    Image(systemName: "face.smiling")
                    Text("Add Reaction")
                }
                .font(.caption)
                .foregroundColor(.purple)
            }
        }
    }
}

// MARK: - Chat Helper Views

@available(iOS 17.0, *)
struct PrayerRequestChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prayerText = ""
    let onSend: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Share a Prayer Request")
                    .font(.headline)
                    .padding()
                
                TextEditor(text: $prayerText)
                    .frame(height: 200)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()
                
                Button(action: {
                    onSend(prayerText)
                }) {
                    Text("Send Prayer Request")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                .disabled(prayerText.isEmpty)
                .padding()
            }
            .navigationTitle("Prayer Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct BibleVerseChatPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVerse = ""
    @State private var selectedReference = ""
    let onSelect: (String, String) -> Void
    
    let popularVerses = [
        ("John 3:16", "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."),
        ("Philippians 4:13", "I can do all this through him who gives me strength."),
        ("Jeremiah 29:11", "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Popular Verses")) {
                    ForEach(popularVerses, id: \.0) { reference, verse in
                        Button(action: {
                            onSelect(verse, reference)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reference)
                                    .font(.headline)
                                Text(verse)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Custom Verse")) {
                    TextField("Reference (e.g., John 3:16)", text: $selectedReference)
                    TextEditor(text: $selectedVerse)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Share Bible Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        if !selectedVerse.isEmpty && !selectedReference.isEmpty {
                            onSelect(selectedVerse, selectedReference)
                        }
                    }
                    .disabled(selectedVerse.isEmpty || selectedReference.isEmpty)
                }
            }
        }
    }
}

struct EmojiReactionPicker: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void
    
    let emojis = ["👍", "❤️", "🙏", "😊", "🔥", "💯", "✨", "🎉"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Reaction")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: {
                        onSelect(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 40))
                            .frame(width: 60, height: 60)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .padding()
    }
}

// MARK: - Chat Emoji Picker

@available(iOS 17.0, *)
struct ChatEmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void
    
    // Popular emojis organized by category
    let emojiCategories: [(String, [String])] = [
        ("Smileys & People", ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "🤭", "🤫", "🤥", "😶", "😐", "😑", "😬", "🙄", "😯", "😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪", "😵", "🤐", "🥴", "🤢", "🤮", "🤧", "😷", "🤒", "🤕", "🤑", "🤠", "😈", "👿", "👹", "👺", "🤡", "💩", "👻", "💀", "☠️", "👽", "👾", "🤖", "🎃"]),
        ("Hands & Gestures", ["👋", "🤚", "🖐", "✋", "🖖", "👌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏", "✍️", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🧠", "🦷", "🦴", "👀", "👁", "👅", "👄"]),
        ("Hearts & Emotions", ["💋", "💘", "💝", "💖", "💗", "💓", "💞", "💕", "💟", "❣️", "💔", "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💯", "💢", "💥", "💫", "💦", "💨", "🕳️", "💣", "💬", "👁️‍🗨️", "🗨️", "🗯️", "💭", "💤"]),
        ("Prayer & Faith", ["🙏", "✝️", "☦️", "☪️", "🕉️", "🕎", "☸️", "☯️", "🛐", "⛪", "🕌", "🕍", "⛩️", "🕋", "⛲", "⛺", "🌁", "🌃", "🌄", "🌅", "🌆", "🌇", "🌉", "♨️", "🎆", "🎇", "✨", "🌟", "💫", "⭐", "🌠", "☄️", "💥", "🔥", "🌈", "☀️", "⛅", "☁️", "⛈️", "🌤️", "🌦️", "🌧️", "⛈️", "🌩️", "🌨️", "❄️", "☃️", "⛄", "🌬️", "💨", "💧", "💦", "☔", "☂️", "🌊", "🌫️"]),
        ("Celebration", ["🎉", "🎊", "🎈", "🎁", "🎀", "🎂", "🍰", "🧁", "🍭", "🍬", "🍫", "🍿", "🍩", "🍪", "🌰", "🥜", "🍯", "🥛", "🍼", "☕", "🍵", "🧃", "🥤", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹", "🧉", "🍾", "🧊"]),
        ("Common Reactions", ["👍", "👎", "❤️", "🔥", "😊", "😍", "😂", "😮", "😢", "🙏", "👏", "🎉", "💯", "✨", "🌟", "🙌", "👌", "💪", "🤔", "😎"])
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(emojiCategories, id: \.0) { category, emojis in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                                ForEach(emojis, id: \.self) { emoji in
                                    Button(action: {
                                        onSelect(emoji)
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 40))
                                            .frame(width: 50, height: 50)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Emoji Picker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
extension LiveSession: Identifiable {}



