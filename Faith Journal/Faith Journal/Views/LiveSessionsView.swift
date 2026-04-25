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
import AVKit
import AVFoundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@available(iOS 17.0, *)
struct LiveSessionsView: View {
    @Query(sort: [SortDescriptor(\LiveSession.startTime, order: .reverse)]) var allSessions: [LiveSession]
    @Query(sort: [SortDescriptor(\LiveSessionParticipant.joinedAt, order: .reverse)]) var allParticipants: [LiveSessionParticipant]
    @Query(sort: [SortDescriptor(\SessionInvitation.createdAt, order: .reverse)]) var allInvitations: [SessionInvitation]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
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
    @Query var allRatings: [SessionRating]
    
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
        case rating = "Highest Rated"
        case duration = "Duration"
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
        // Include sessions that have ended (have endTime) or are not active and not scheduled
        allSessionsCombined.filter { session in
            // Session has ended (has endTime) OR is not active and not scheduled
            (session.endTime != nil) || (!session.isActive && !session.isScheduled && !session.isArchived)
        }
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
    
    private static let filterCategories = ["All", "Bible Study", "Devotional", "Fellowship", "Other", "Prayer", "Testimony", "Worship"]
    
    var categories: [String] {
        var cats = Set(allActiveSessions.map { $0.category })
        for name in Self.filterCategories where name != "All" {
            cats.insert(name)
        }
        cats.insert("All")
        return Array(cats).sorted()
    }
    
    var filteredSessions: [LiveSession] {
        var filtered = allActiveSessions
        
        if !searchText.isEmpty {
            filtered = filtered.filter { session in
                session.title.localizedCaseInsensitiveContains(searchText) ||
                session.details.localizedCaseInsensitiveContains(searchText) ||
                session.agenda.localizedCaseInsensitiveContains(searchText) ||
                session.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                session.hostName.localizedCaseInsensitiveContains(searchText) ||
                session.category.localizedCaseInsensitiveContains(searchText) ||
                session.relatedResources.contains { $0.localizedCaseInsensitiveContains(searchText) }
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
        case .rating:
            // Sort by rating (placeholder - would need ratings data)
            filtered = filtered.sorted(by: { $0.startTime > $1.startTime })
        case .duration:
            filtered = filtered.sorted(by: { $0.duration > $1.duration })
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
    
    var favoriteSessionsForUser: [LiveSession] {
        return allSessionsCombined.filter { $0.isFavorite }
    }
    
    func getRecommendations() -> [LiveSession] {
        let userId = userService.userIdentifier
        return SessionRecommendationService.shared.getRecommendations(
            for: userId,
            allSessions: allSessionsCombined,
            userRatings: allRatings,
            userParticipants: allParticipants,
            userFavorites: favoriteSessionsForUser
        )
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
                    ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
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
                        ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { category in
                                    CategoryChip(
                                        title: category,
                                        isSelected: selectedCategory == category,
                                        color: themeManager.colors.primary
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
                                    
                                    let previewSessions = Array(liveNowSessions.prefix(3))
                                    let previewIds = Set(previewSessions.map { $0.id })
                                    
                                    ForEach(previewSessions) { session in
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
                                        .foregroundColor(themeManager.colors.primary)
                                        .padding(.vertical, 8)
                                    }
                                    
                                    // Main Session List (excluding preview sessions to avoid duplicates)
                                    ForEach(filteredSessions.filter { !previewIds.contains($0.id) }) { session in
                                        EnhancedLiveSessionCard(session: session) {
                                            selectedSession = session
                                            showingSessionDetail = true
                                        }
                                    }
                                } else {
                                    // Main Session List (when not showing Live Now preview)
                                    ForEach(filteredSessions) { session in
                                        EnhancedLiveSessionCard(session: session) {
                                            selectedSession = session
                                            showingSessionDetail = true
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        // Recommendations section
                        let recommendations = getRecommendations()
                        if !recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                    Text("Recommended for You")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                                    HStack(spacing: 12) {
                                        ForEach(recommendations.prefix(5)) { session in
                                            EnhancedLiveSessionCard(session: session) {
                                                selectedSession = session
                                                showingSessionDetail = true
                                            }
                                            .frame(width: 300)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
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
    @ObservedObject private var themeManager = ThemeManager.shared
    
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
                    .fill(isSelected ? themeManager.colors.primary : Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, *)
struct EnhancedLiveSessionCard: View {
    let session: LiveSession
    let onTap: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    @Query var userProfiles: [UserProfile]
    @Query(filter: #Predicate<LiveSessionParticipant> { $0.isActive == true }) var allParticipants: [LiveSessionParticipant]
    private var userProfile: UserProfile? { userProfiles.first }
    @State private var isFavorite = false
    @State private var timeUntilStart: TimeInterval = 0
    @State private var timer: Timer?
    
    var isHost: Bool {
        session.hostId == userService.userIdentifier
    }
    
    // Get participants for this session
    private var sessionParticipants: [LiveSessionParticipant] {
        allParticipants.filter { $0.sessionId == session.id }
    }
    
    // Get display name for host - prioritize host participant's userName if available
    var hostDisplayName: String {
        // First check if host has a participant record with a valid userName
        if let hostParticipant = sessionParticipants.first(where: { $0.userId == session.hostId && $0.isHost }) {
            let storedName = hostParticipant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || storedName.contains("iPad") || storedName == UIDevice.current.name
            
            // Use stored name if it's valid and not a device name
            if !storedName.isEmpty && !isStoredNameDevice {
                return storedName
            }
        }
        
        if isHost {
            // If current user is host, ALWAYS use their profile name from settings
            // First check ProfileManager (Firebase) for name
            let profileManagerName = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileManagerName.isEmpty {
                let isDeviceName = profileManagerName.contains("iPhone") || 
                                 profileManagerName.contains("iPad") || 
                                 profileManagerName == UIDevice.current.name
                if !isDeviceName {
                    return profileManagerName
                }
            }
            
            // Fallback to local UserProfile name
            let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileName.isEmpty {
                let isDeviceName = profileName.contains("iPhone") || 
                                 profileName.contains("iPad") || 
                                 profileName == UIDevice.current.name
                if !isDeviceName {
                    return profileName
                }
            }
            
            // No valid profile name - return "Host" (never device name)
            return "Host"
        } else {
            // For other users' sessions, use stored hostName if it's not a device name
            let storedHostName = session.hostName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isHostNameDevice = storedHostName.contains("iPhone") || 
                                  storedHostName.contains("iPad") || 
                                  storedHostName == UIDevice.current.name
            
            if !storedHostName.isEmpty && !isHostNameDevice {
                return storedHostName
            }
            
            // No valid name - return "Host" (never device name)
            return "Host"
        }
    }
    
    var isScheduled: Bool {
        session.isScheduled && (session.scheduledStartTime ?? Date.distantFuture) > Date()
    }
    
    var isRecurring: Bool {
        session.isRecurring
    }
    
    private var sessionThumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [themeManager.colors.primary.opacity(0.6), themeManager.colors.secondary.opacity(0.6)]),
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
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Thumbnail/Preview Area
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let urlString = session.thumbnailURL, !urlString.isEmpty, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    sessionThumbnailPlaceholder
                                case .empty:
                                    sessionThumbnailPlaceholder
                                        .overlay(ProgressView())
                                @unknown default:
                                    sessionThumbnailPlaceholder
                                }
                            }
                            .id(urlString)
                            .frame(height: 180)
                            .clipped()
                        } else {
                            sessionThumbnailPlaceholder
                        }
                    }
                    .cornerRadius(12)
                    
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
                        } else if isScheduled {
                            // Scheduled badge with countdown
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text(formatCountdown(timeUntilStart))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.colors.primary.opacity(0.9))
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
                                    Text(hostDisplayName)
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                                
                                // Category
                                Text(session.category)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeManager.colors.primary.opacity(0.2))
                                    .foregroundColor(themeManager.colors.primary)
                                    .cornerRadius(8)
                            }
                        }

                        if session.durationLimitMinutes > 0 {
                            Text("Time limit: \(session.durationLimitMinutes)m")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Status indicator
                        if isScheduled {
                            // Show countdown for scheduled sessions
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption)
                                    Text("Starts in")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(themeManager.colors.primary)
                                
                                if let scheduledTime = session.scheduledStartTime {
                                    // Show countdown
                                    Text(formatCountdown(timeUntilStart))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(themeManager.colors.primary)
                                    
                                    // Show date and time for recurring sessions or upcoming sessions
                                    if isRecurring {
                                        Text(scheduledTime.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(scheduledTime.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else if !session.isActive && session.endTime != nil {
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
            updateCountdown()
            startCountdownTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if isScheduled {
                updateCountdown()
            }
        }
        .onChange(of: timeUntilStart) { _, _ in
            // Force view update when countdown changes
        }
    }
    
    private func updateCountdown() {
        if let scheduledTime = session.scheduledStartTime {
            timeUntilStart = scheduledTime.timeIntervalSinceNow
        }
    }
    
    private func startCountdownTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                // Force view update by triggering state change
                // This works because the timer closure captures the session
                if let scheduledTime = session.scheduledStartTime {
                    let _ = scheduledTime.timeIntervalSinceNow
                }
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func formatCountdown(_ interval: TimeInterval) -> String {
        guard interval > 0 else {
            return "Starting..."
        }
        
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
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
    @ObservedObject private var themeManager = ThemeManager.shared
    
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
                            .background(themeManager.colors.primary.opacity(0.2))
                            .foregroundColor(themeManager.colors.primary)
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
    @ObservedObject private var themeManager = ThemeManager.shared
    
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
        .buttonStyle(.plain)
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
    private let notificationService = SessionNotificationService.shared
    @State private var title = ""
    @State private var details = ""
    @State private var category = "Prayer"
    @State private var maxParticipants = 10
    @State private var tags = ""
    @State private var selectedTags: Set<String> = []
    @State private var manualTagInput = ""
    @State private var isPrivate = false
    @State private var durationLimitMinutes = 30
    @State private var scheduledDate: Date?
    @State private var enableReminders = true
    @State private var reminderMinutes: Int = 5
    @State private var addToCalendar = false
    @State private var enableWaitingRoom = false
    @State private var selectedThumbnailImage: PlatformImage?
    @State private var showingThumbnailPicker = false
    @State private var isRecurring = false
    @State private var recurrencePattern = "weekly"
    @State private var showingCalendarError = false
    @State private var calendarErrorMessage = ""
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    let categories = ["Prayer", "Bible Study", "Devotional", "Testimony", "Fellowship", "Worship", "Other"]
    let predefinedTags = ["Prayer", "Bible Study", "Fellowship", "Worship", "Testimony", "Encouragement", "Healing", "Praise", "Intercession", "Community"]
    private let durationOptions = [15, 30, 45, 60]
    
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
                        
                        // Thumbnail Card (optional cover image)
                        thumbnailCard
                        
                        // Category Selection Card
                        categoryCard
                        
                        // Settings Cards
                        participantsCard
                        timeLimitCard
                        
                        if scheduledDate != nil || enableReminders {
                            scheduleCard
                        }
                        
                        // Recurring Session Card (only show if scheduled)
                        if scheduledDate != nil {
                            recurringSessionCard
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
            .alert("Calendar Error", isPresented: $showingCalendarError) {
                Button("OK") { }
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            } message: {
                Text(calendarErrorMessage)
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
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
    
    private var thumbnailCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "photo.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Thumbnail (optional)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Text("Add a cover image for your live session, like YouTube Live.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button(action: { showingThumbnailPicker = true }) {
                Group {
                    if let img = selectedThumbnailImage {
                        platformImage(img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemBackground))
                            .frame(height: 160)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.title)
                                    Text("Tap to add thumbnail")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.secondary)
                            )
                    }
                }
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            if selectedThumbnailImage != nil {
                Button("Remove thumbnail") {
                    selectedThumbnailImage = nil
                }
                .font(.subheadline)
                .foregroundColor(themeManager.colors.primary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingThumbnailPicker) {
            #if os(iOS)
            ImagePicker(image: $selectedThumbnailImage)
            #elseif os(macOS)
            MacImagePicker(image: $selectedThumbnailImage)
            #endif
        }
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
            
            ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
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

    private var timeLimitCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Session Time Limit")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Text("Keep the session under Agora’s maximum by capping how long it runs.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Time Limit", selection: $durationLimitMinutes) {
                ForEach(durationOptions, id: \.self) { option in
                    Text("\(option)m").tag(option)
                }
            }
            .pickerStyle(.segmented)
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
    
    private var recurringSessionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Recurring Session")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                Toggle(isOn: $isRecurring) {
                    HStack {
                        Image(systemName: isRecurring ? "repeat.circle.fill" : "repeat.circle")
                            .foregroundColor(themeManager.colors.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Make This Recurring")
                                .foregroundColor(.primary)
                            Text(isRecurring ? "Session will repeat automatically" : "Create a one-time session")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(themeManager.colors.primary)
                
                if isRecurring {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repeat Frequency")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Picker("Recurrence Pattern", selection: $recurrencePattern) {
                            Text("Daily").tag("daily")
                            Text("Weekly").tag("weekly")
                            Text("Bi-Weekly").tag("biweekly")
                            Text("Monthly").tag("monthly")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.top, 4)
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
                            Text(isPrivate ? "Private Session" : "Public")
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
                    ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
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
        
        // ALWAYS use profile name from settings - never device name
        // First check ProfileManager (Firebase) for name
        var userName: String = ""
        let profileManagerName = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileManagerName.isEmpty {
            let isDeviceName = profileManagerName.contains("iPhone") || 
                             profileManagerName.contains("iPad") || 
                             profileManagerName == UIDevice.current.name
            if !isDeviceName {
                userName = profileManagerName
            }
        }
        
        // Fallback to local UserProfile name if ProfileManager doesn't have it
        if userName.isEmpty {
            let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileName.isEmpty {
                let isDeviceName = profileName.contains("iPhone") || 
                                 profileName.contains("iPad") || 
                                 profileName == UIDevice.current.name
                if !isDeviceName {
                    userName = profileName
                }
            }
        }
        
        // If still no valid profile name, user must set it before creating session
        guard !userName.isEmpty else {
            errorMessage = "Please set your name in Settings > Profile before creating a session."
            showingErrorAlert = true
            print("⚠️ [CREATE] Cannot create session - user has no profile name set")
            return
        }
        
        let session = LiveSession(
            title: title,
            description: details,
            hostId: userId,
            category: category,
            maxParticipants: maxParticipants,
            tags: tagArray
        )
        session.durationLimitMinutes = durationLimitMinutes
        session.isPrivate = isPrivate
        session.hostName = userName
        session.waitingRoomEnabled = enableWaitingRoom
        session.hasWaitingRoom = enableWaitingRoom
        session.isRecurring = isRecurring
        session.recurrencePattern = recurrencePattern
        if let scheduled = scheduledDate {
            session.scheduledStartTime = scheduled
            session.isActive = false // Scheduled sessions are not active until start time
        }
        
        modelContext.insert(session)
        
        // Check if host participant already exists (shouldn't happen, but prevent duplicates)
        // We need to save the session first so we can query for participants
        do {
            try modelContext.save()
        } catch {
            print("❌ [CREATE SESSION] Failed to save session: \(error)")
            errorMessage = "Failed to create session: \(error.localizedDescription)"
            showingErrorAlert = true
            return
        }
        
        // Now check if participant already exists (check for ANY participant with this userId, not just host)
        // Capture values before using in predicate
        let sessionId = session.id
        let hostUserId = userId
        let checkDescriptor = FetchDescriptor<LiveSessionParticipant>(
            predicate: #Predicate<LiveSessionParticipant> { p in
                p.sessionId == sessionId && p.userId == hostUserId
            }
        )
        let existingParticipants = (try? modelContext.fetch(checkDescriptor)) ?? []
        
        let participant: LiveSessionParticipant
        if let existing = existingParticipants.first {
            // Participant already exists - update it to be the host
            participant = existing
            participant.isActive = true
            participant.isBroadcaster = true
            participant.isHost = true
            participant.userName = userName
            print("⚠️ [CREATE SESSION] Participant already exists, updating to host: userId=\(userId), sessionId=\(session.id)")
        } else {
            // Create participant entry for host
            participant = LiveSessionParticipant(
                sessionId: session.id,
                userId: userId,
                userName: userName,
                isHost: true,
                isBroadcaster: true // Host is always a broadcaster
            )
            // Ensure host participant is marked as active
            participant.isActive = true
            modelContext.insert(participant)
            print("✅ [CREATE SESSION] Created host participant: userId=\(userId), sessionId=\(session.id), isActive=\(participant.isActive)")
        }
        
        // If there were multiple participants, delete the duplicates
        if existingParticipants.count > 1 {
            print("⚠️ [CREATE SESSION] Found \(existingParticipants.count) existing participants, removing duplicates")
            for duplicate in existingParticipants.dropFirst() {
                modelContext.delete(duplicate)
            }
        }
        
        // Initialize participant count to 1 (host)
        // This will be updated by updateParticipantCount() but set initial value
        session.currentParticipants = 1
        session.currentBroadcasters = 1 // Host is a broadcaster
        
        do {
            try modelContext.save()
            
            // Immediately clean up any duplicates that might have been created
            // Use a small delay to ensure the save is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Query for all participants for this session
                let sessionId = session.id
                let descriptor = FetchDescriptor<LiveSessionParticipant>(
                    predicate: #Predicate<LiveSessionParticipant> { p in
                        p.sessionId == sessionId
                    }
                )
                if let allSessionParticipants = try? modelContext.fetch(descriptor) {
                    // Group by userId
                    let grouped = Dictionary(grouping: allSessionParticipants) { $0.userId }
                    for (userId, duplicates) in grouped where duplicates.count > 1 {
                        print("⚠️ [CREATE SESSION] Found \(duplicates.count) duplicates for userId: \(userId), removing extras")
                        // Keep the most recent active one
                        let sorted = duplicates.sorted { p1, p2 in
                            if p1.isActive != p2.isActive { return p1.isActive }
                            return p1.joinedAt > p2.joinedAt
                        }
                        // Delete all but the first
                        for duplicate in sorted.dropFirst() {
                            modelContext.delete(duplicate)
                        }
                    }
                    try? modelContext.save()
                }
            }
            
            // Sync session to Firebase for cross-device sync and invitation lookup
            Task {
                await FirebaseSyncService.shared.syncLiveSession(session)
                
                print("✅ [SESSION] Synced session to Firebase: \(session.id)")
            }
            
            // Schedule notifications and calendar event
            Task {
                if scheduledDate != nil {
                    if enableReminders {
                        await notificationService.scheduleSessionStartingSoon(session: session, minutesBefore: reminderMinutes)
                    }
                    
                    if addToCalendar {
                        do {
                            try await notificationService.addSessionToCalendar(session: session)
                            print("✅ Session added to calendar")
                        } catch let error as NotificationError {
                            await MainActor.run {
                                calendarErrorMessage = error.localizedDescription
                                if let suggestion = error.recoverySuggestion {
                                    calendarErrorMessage += "\n\n\(suggestion)"
                                }
                                showingCalendarError = true
                            }
                        } catch {
                            await MainActor.run {
                                calendarErrorMessage = "Failed to add session to calendar: \(error.localizedDescription)"
                                showingCalendarError = true
                            }
                        }
                    }
                }
            }
            
            let sessionId = session.id
            let thumbImage = selectedThumbnailImage
            dismiss()
            
            // Upload thumbnail and save URL to session (so list shows custom thumbnail)
            if let image = thumbImage, let jpegData = platformImageToJPEGData(image, quality: 0.85) {
                Task {
                    do {
                        let urlString = try await FirebaseSyncService.shared.uploadLiveSessionThumbnail(sessionId: sessionId, imageData: jpegData)
                        await MainActor.run {
                            FirebaseSyncService.shared.saveThumbnailURL(sessionId: sessionId, urlString: urlString)
                        }
                    } catch {
                        print("⚠️ [LIVE SESSION] Thumbnail upload failed: \(error.localizedDescription)")
                    }
                }
            }
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
    @Query(sort: [SortDescriptor(\LiveSessionParticipant.joinedAt, order: .forward)]) var participants: [LiveSessionParticipant]
    @Query var invitations: [SessionInvitation]
    @Query var userProfiles: [UserProfile]
    
    // Get ALL participants for this session (including inactive) for duplicate checking
    private var allSessionParticipants: [LiveSessionParticipant] {
        participants.filter { $0.sessionId == session.id }
    }
    @ObservedObject private var themeManager = ThemeManager.shared
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
    @State private var showingWaitingRoom = false
    @State private var showingClips = false
    @State private var showingEditName = false
    @State private var participantCountRefreshTrigger = UUID() // Force view refresh when count changes
    @State private var editedParticipantName = ""
    @State private var isCreatingParticipant = false // Prevent concurrent participant creation
    @Query var messages: [ChatMessage]
    @Query var ratings: [SessionRating]
    @State private var chatMessageListener: Any? // ListenerRegistration
    @State private var participantListener: Any? // ListenerRegistration
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var showingThumbnailPicker = false
    @State private var selectedThumbnailImage: PlatformImage?
    @State private var isUploadingThumbnail = false
    
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
        // Query database directly to get all participants (not just from query which might be stale)
        let sessionId = session.id
        let descriptor = FetchDescriptor<LiveSessionParticipant>(
            predicate: #Predicate<LiveSessionParticipant> { p in
                p.sessionId == sessionId && p.isActive == true
            }
        )
        let activeParticipants = (try? modelContext.fetch(descriptor)) ?? []
        
        // Remove duplicates by userId - keep only the most recent one for each user
        var uniqueParticipants: [LiveSessionParticipant] = []
        var seenUserIds: Set<String> = []
        var duplicatesFound: [LiveSessionParticipant] = []
        
        // Sort by joinedAt (most recent first) to keep the latest entry
        // Also prefer host participants
        let sorted = activeParticipants.sorted { p1, p2 in
            if p1.isHost != p2.isHost { return p1.isHost }
            return p1.joinedAt > p2.joinedAt
        }
        
        for participant in sorted {
            if !seenUserIds.contains(participant.userId) {
                uniqueParticipants.append(participant)
                seenUserIds.insert(participant.userId)
            } else {
                // Found a duplicate - collect it for deletion
                duplicatesFound.append(participant)
            }
        }
        
        // If we found duplicates, delete them immediately
        if !duplicatesFound.isEmpty {
            print("⚠️ [SESSION PARTICIPANTS] Found \(duplicatesFound.count) duplicate active participants, deleting immediately")
            for duplicate in duplicatesFound {
                print("🗑️ [SESSION PARTICIPANTS] Deleting duplicate: \(duplicate.id) for userId: \(duplicate.userId)")
                modelContext.delete(duplicate)
            }
            do {
                try modelContext.save()
                print("✅ [SESSION PARTICIPANTS] Deleted \(duplicatesFound.count) duplicate(s)")
                // Force UI refresh
                participantCountRefreshTrigger = UUID()
            } catch {
                print("❌ [SESSION PARTICIPANTS] Failed to delete duplicates: \(error)")
            }
        }
        
        return uniqueParticipants
    }
    
    // Computed property for accurate participant count
    // Always ensure at least 1 if host exists (host should always be counted)
    // This matches how other apps work (Zoom, Teams, etc.) - the host is always counted
    var participantCount: Int {
        let activeCount = sessionParticipants.count
        let userId = userService.userIdentifier
        
        // If we're the host, we should always be counted as at least 1 participant
        // This handles cases where:
        // 1. The query hasn't loaded the participant yet (SwiftData async loading)
        // 2. The participant exists but isn't marked as active
        // 3. The participant record hasn't been created yet
        if session.hostId == userId {
            // Host should always count as at least 1
            return max(activeCount, 1)
        }
        
        // For non-hosts, return the actual count
        return activeCount
    }
    
    // Ensure host is added as a participant if missing
    private func ensureHostIsParticipant() {
        // Prevent concurrent execution
        guard !isCreatingParticipant else {
            print("⏸️ [SESSION] ensureHostIsParticipant() already in progress, skipping")
            return
        }
        
        let userId = userService.userIdentifier
        
        // Check all participants (not just active ones) to find host
        // Use the computed property that includes all participants
        let existingHostParticipant = allSessionParticipants.first { $0.userId == session.hostId && $0.isHost }
        
        // Also check database directly to avoid timing issues with query loading
        // Capture values before using in predicate
        let sessionId = session.id
        let hostId = session.hostId
        let descriptor = FetchDescriptor<LiveSessionParticipant>(
            predicate: #Predicate<LiveSessionParticipant> { p in
                p.sessionId == sessionId && p.userId == hostId && p.isHost == true
            }
        )
        let dbParticipants = (try? modelContext.fetch(descriptor)) ?? []
        let dbHostParticipant = dbParticipants.first
        
        // Use database result if query hasn't loaded yet
        let hostParticipant = existingHostParticipant ?? dbHostParticipant
        
        print("🔍 [SESSION] ensureHostIsParticipant() - userId: \(userId), hostId: \(session.hostId)")
        print("   - Found in query: \(existingHostParticipant != nil)")
        print("   - Found in DB: \(dbHostParticipant != nil)")
        print("   - Total participants for session: \(allSessionParticipants.count)")
        print("   - Active participants: \(sessionParticipants.count)")
        
        // FIRST: Check for and remove duplicates for this user
        let duplicateCheckDescriptor = FetchDescriptor<LiveSessionParticipant>(
            predicate: #Predicate<LiveSessionParticipant> { p in
                p.sessionId == sessionId && p.userId == userId
            }
        )
        let allUserParticipants = (try? modelContext.fetch(duplicateCheckDescriptor)) ?? []
        
        if allUserParticipants.count > 1 {
            print("⚠️ [SESSION] Found \(allUserParticipants.count) duplicate participants for userId: \(userId), removing extras")
            // Sort by joinedAt (most recent first), prefer active and host
            let sorted = allUserParticipants.sorted { p1, p2 in
                if p1.isHost != p2.isHost { return p1.isHost }
                if p1.isActive != p2.isActive { return p1.isActive }
                return p1.joinedAt > p2.joinedAt
            }
            // Keep the first one (most recent, active, host), delete the rest
            for duplicate in sorted.dropFirst() {
                print("🗑️ [SESSION] Removing duplicate participant: \(duplicate.id) for userId: \(userId)")
                modelContext.delete(duplicate)
            }
            // Update the kept participant to ensure it's correct
            if let kept = sorted.first {
                if session.hostId == userId {
                    kept.isHost = true
                    kept.isBroadcaster = true
                }
                kept.isActive = true
            }
            do {
                try modelContext.save()
                print("✅ [SESSION] Removed \(allUserParticipants.count - 1) duplicate participant(s)")
                // Force UI refresh
                participantCountRefreshTrigger = UUID()
            } catch {
                print("❌ [SESSION] Failed to remove duplicates: \(error)")
            }
            // After removing duplicates, exit early - we've handled it
            return
        }
        
        // If host participant doesn't exist, create it
        // But first check if ANY participant exists for this user in this session (to prevent duplicates)
        if hostParticipant == nil && session.hostId == userId {
            // Double-check: query database directly for ANY participant with this userId and sessionId
            let sessionId = session.id
            let checkDescriptor = FetchDescriptor<LiveSessionParticipant>(
                predicate: #Predicate<LiveSessionParticipant> { p in
                    p.sessionId == sessionId && p.userId == userId
                }
            )
            let existingAnyParticipant = (try? modelContext.fetch(checkDescriptor))?.first
            
            if existingAnyParticipant != nil {
                // Found an existing participant - update it to be the host instead of creating new
                print("⚠️ [SESSION] Found existing participant for host, updating to host: userId=\(userId)")
                existingAnyParticipant!.isHost = true
                existingAnyParticipant!.isBroadcaster = true
                existingAnyParticipant!.isActive = true
                if existingAnyParticipant!.userName.isEmpty {
                    existingAnyParticipant!.userName = userService.getDisplayName(userProfile: userProfile)
                }
                try? modelContext.save()
                return
            }
            
            // No participant exists, create new host participant
            // BUT FIRST: Double-check one more time that no participant exists (race condition protection)
            let finalCheckDescriptor = FetchDescriptor<LiveSessionParticipant>(
                predicate: #Predicate<LiveSessionParticipant> { p in
                    p.sessionId == sessionId && p.userId == userId
                }
            )
            let finalCheck = (try? modelContext.fetch(finalCheckDescriptor)) ?? []
            
            if finalCheck.isEmpty {
                isCreatingParticipant = true
                defer { isCreatingParticipant = false }
                
                let userName = userService.getDisplayName(userProfile: userProfile)
                let newHostParticipant = LiveSessionParticipant(
                    sessionId: session.id,
                    userId: userId,
                    userName: userName,
                    isHost: true,
                    isBroadcaster: true // Host is always a broadcaster
                )
                newHostParticipant.isActive = true
                modelContext.insert(newHostParticipant)
                
                do {
                    try modelContext.save()
                    print("✅ [SESSION] Created missing host participant for session: \(session.id), isActive: \(newHostParticipant.isActive)")
                    
                    // Immediately check for duplicates after creation
                    let postCreateCheck = (try? modelContext.fetch(duplicateCheckDescriptor)) ?? []
                    if postCreateCheck.count > 1 {
                        print("⚠️ [SESSION] Duplicate created! Found \(postCreateCheck.count) participants after creation, removing extras")
                        let sorted = postCreateCheck.sorted { p1, p2 in
                            if p1.isHost != p2.isHost { return p1.isHost }
                            return p1.joinedAt > p2.joinedAt
                        }
                        for duplicate in sorted.dropFirst() {
                            modelContext.delete(duplicate)
                        }
                        try? modelContext.save()
                        participantCountRefreshTrigger = UUID()
                    }
                    
                    // Sync host participant to Firebase
                    Task {
                        await FirebaseSyncService.shared.syncSessionParticipant(newHostParticipant)
                        print("✅ [SESSION] Synced host participant to Firebase")
                    }
                } catch {
                    print("❌ [SESSION] Failed to create host participant: \(error)")
                }
            } else {
                // Participant was created between checks - update it instead
                if let existing = finalCheck.first {
                    existing.isHost = true
                    existing.isBroadcaster = true
                    existing.isActive = true
                    try? modelContext.save()
                    print("ℹ️ [SESSION] Participant created between checks, updated to host")
                }
            }
        } else if let hostParticipant = hostParticipant {
            // Check again for duplicates - they might have been created between checks
            let finalCheckDescriptor = FetchDescriptor<LiveSessionParticipant>(
                predicate: #Predicate<LiveSessionParticipant> { p in
                    p.sessionId == sessionId && p.userId == userId
                }
            )
            if let finalCheck = try? modelContext.fetch(finalCheckDescriptor), finalCheck.count > 1 {
                print("⚠️ [SESSION] Still found \(finalCheck.count) duplicates after initial check, removing now")
                let sorted = finalCheck.sorted { p1, p2 in
                    if p1.isHost != p2.isHost { return p1.isHost }
                    if p1.isActive != p2.isActive { return p1.isActive }
                    return p1.joinedAt > p2.joinedAt
                }
                for duplicate in sorted.dropFirst() {
                    modelContext.delete(duplicate)
                }
                try? modelContext.save()
                print("✅ [SESSION] Removed remaining duplicates")
                // Force UI refresh
                participantCountRefreshTrigger = UUID()
                return
            }
            
            // Ensure host participant is marked as active
            if !hostParticipant.isActive {
                hostParticipant.isActive = true
                do {
                    try modelContext.save()
                    print("✅ [SESSION] Activated host participant")
                    
                    // Sync updated participant to Firebase
                    Task {
                        await FirebaseSyncService.shared.syncSessionParticipant(hostParticipant)
                        print("✅ [SESSION] Synced activated host participant to Firebase")
                    }
                } catch {
                    print("❌ [SESSION] Failed to activate host participant: \(error)")
                }
            } else {
                print("ℹ️ [SESSION] Host participant already active")
                
                // Even if already active, ensure it's synced to Firebase
                Task {
                    await FirebaseSyncService.shared.syncSessionParticipant(hostParticipant)
                }
            }
        } else if session.hostId != userId {
            print("ℹ️ [SESSION] Current user is not the host, skipping host participant creation")
        }
    }
    
    // Remove duplicate participants (same userId and sessionId)
    // This prevents the same user from appearing multiple times in the participant list
    private func removeDuplicateParticipants() {
        // Use database query to get all participants for this session (not just from query)
        let sessionId = session.id
        let descriptor = FetchDescriptor<LiveSessionParticipant>(
            predicate: #Predicate<LiveSessionParticipant> { p in
                p.sessionId == sessionId
            }
        )
        let allParticipants = (try? modelContext.fetch(descriptor)) ?? []
        
        // Group participants by userId to find duplicates
        let groupedByUserId = Dictionary(grouping: allParticipants) { $0.userId }
        var totalRemoved = 0
        
        for (userId, duplicates) in groupedByUserId {
            // If there are multiple participants for the same user, keep only the most recent active one
            if duplicates.count > 1 {
                print("⚠️ [SESSION] Found \(duplicates.count) duplicate participants for user: \(userId)")
                
                // Sort by joinedAt (most recent first), prefer active participants
                let sorted = duplicates.sorted { p1, p2 in
                    // Prefer active participants, then most recent
                    if p1.isActive != p2.isActive {
                        return p1.isActive
                    }
                    return p1.joinedAt > p2.joinedAt
                }
                
                // Keep the first one (most recent active), delete the rest
                for duplicate in sorted.dropFirst() {
                    print("🗑️ [SESSION] Removing duplicate participant: \(duplicate.id) for user: \(userId)")
                    modelContext.delete(duplicate)
                    totalRemoved += 1
                }
                
                // Ensure the kept participant is active and has correct broadcaster status
                if let kept = sorted.first {
                    if !kept.isActive {
                        kept.isActive = true
                        kept.joinedAt = Date()
                    }
                    // If this is the host, ensure they're marked as broadcaster
                    if kept.isHost && !kept.isBroadcaster {
                        kept.isBroadcaster = true
                    }
                }
            }
        }
        
        if totalRemoved > 0 {
            do {
                try modelContext.save()
                print("✅ [SESSION] Removed \(totalRemoved) duplicate participant(s) for session: \(session.id)")
                
                // Update participant counts after removing duplicates
                updateParticipantCount()
            } catch {
                print("❌ [SESSION] Failed to remove duplicates: \(error)")
            }
        }
    }
    
    // Update session's currentParticipants count based on actual participant records
    private func updateParticipantCount() {
        // FIRST: Aggressively remove duplicates before doing anything else
        let sessionId = session.id
        let userId = userService.userIdentifier
        let duplicateDescriptor = FetchDescriptor<LiveSessionParticipant>(
            predicate: #Predicate<LiveSessionParticipant> { p in
                p.sessionId == sessionId && p.userId == userId
            }
        )
        if let userParticipants = try? modelContext.fetch(duplicateDescriptor), userParticipants.count > 1 {
            print("⚠️ [UPDATE COUNT] Found \(userParticipants.count) duplicates for userId: \(userId), removing immediately")
            let sorted = userParticipants.sorted { p1, p2 in
                if p1.isHost != p2.isHost { return p1.isHost }
                if p1.isActive != p2.isActive { return p1.isActive }
                return p1.joinedAt > p2.joinedAt
            }
            for duplicate in sorted.dropFirst() {
                print("🗑️ [UPDATE COUNT] Deleting duplicate: \(duplicate.id)")
                modelContext.delete(duplicate)
            }
            if let kept = sorted.first {
                kept.isHost = (session.hostId == userId)
                kept.isBroadcaster = kept.isHost
                kept.isActive = true
            }
            try? modelContext.save()
            print("✅ [UPDATE COUNT] Removed \(userParticipants.count - 1) duplicate(s)")
            // Force UI refresh
            participantCountRefreshTrigger = UUID()
        }
        
        // Then ensure host is a participant
        ensureHostIsParticipant()
        
        // Get actual count from participants
        let actualCount = sessionParticipants.count
        
        // Count broadcasters separately
        let actualBroadcasters = sessionParticipants.filter { $0.isBroadcaster }.count
        
        // Use computed participantCount which handles edge cases
        let finalCount = participantCount
        
        // Debug logging
        print("🔍 [SESSION] updateParticipantCount() called")
        print("   - sessionParticipants.count: \(actualCount)")
        print("   - broadcasters: \(actualBroadcasters)")
        print("   - isHost: \(isHost)")
        print("   - participantCount (computed): \(finalCount)")
        print("   - session.currentParticipants (stored): \(session.currentParticipants)")
        print("   - session.currentBroadcasters (stored): \(session.currentBroadcasters)")
        print("   - All participants for session: \(participants.filter { $0.sessionId == session.id }.count)")
        print("   - Active participants: \(participants.filter { $0.sessionId == session.id && $0.isActive }.count)")
        
        // Always update if we're the host and count is 0, or if counts don't match
        // Also always update the trigger to force view refresh
        participantCountRefreshTrigger = UUID()
        
        var needsUpdate = false
        
        if (isHost && finalCount == 0) || session.currentParticipants != finalCount {
            session.currentParticipants = finalCount
            needsUpdate = true
        }
        
        if session.currentBroadcasters != actualBroadcasters {
            session.currentBroadcasters = actualBroadcasters
            needsUpdate = true
        }
        
        if needsUpdate {
            try? modelContext.save()
            
            print("✅ [SESSION] Updated participant count: \(finalCount) total, \(actualBroadcasters) broadcasters (actual participants in DB: \(actualCount))")
            
            // Sync count to Firebase
            Task {
                await FirebaseSyncService.shared.updateSessionParticipantCount(session.id, count: finalCount)
            }
        } else {
            print("ℹ️ [SESSION] Participant count unchanged: \(finalCount) total, \(actualBroadcasters) broadcasters, but refreshing view anyway")
        }
    }
    
    var canJoin: Bool {
        // Determine if user would join as broadcaster or audience based on stream mode
        let wouldJoinAsBroadcaster: Bool
        if session.streamMode == "broadcast" {
            // In broadcast mode, only host is broadcaster, everyone else is audience
            wouldJoinAsBroadcaster = isHost
        } else {
            // In conference/multi-participant mode, everyone can be a broadcaster
            // But we limit broadcasters to 17 (Agora's recommended limit)
            wouldJoinAsBroadcaster = true
        }
        
        if session.waitingRoomEnabled && !session.isActive {
            // Waiting room allows joining before session starts
            // If joining as broadcaster, check broadcaster limit; otherwise unlimited
            if wouldJoinAsBroadcaster {
                // Check broadcaster limit (17 recommended by Agora, or maxParticipants if lower)
                let maxBroadcasters = min(17, session.maxParticipants)
                return session.currentBroadcasters < maxBroadcasters
            } else {
                // Audience members are unlimited
                return true
            }
        }
        
        if !session.isActive {
            return false
        }
        
        // If joining as broadcaster, check broadcaster limit; otherwise unlimited
        if wouldJoinAsBroadcaster {
            // Check broadcaster limit (17 recommended by Agora, or maxParticipants if lower)
            let maxBroadcasters = min(17, session.maxParticipants)
            return session.currentBroadcasters < maxBroadcasters
        } else {
            // Audience members are unlimited
            return true
        }
    }
    
    var isInWaitingRoom: Bool {
        guard session.waitingRoomEnabled else { return false }
        let userId = userService.userIdentifier
        return sessionParticipants.contains { $0.userId == userId } && !session.isActive
    }
    
    var isHost: Bool {
        // Safely check if current user is host
        let userId = userService.userIdentifier
        return session.hostId == userId
    }
    
    private var sessionDetailThumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [themeManager.colors.primary.opacity(0.6), themeManager.colors.secondary.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 160)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: session.category == "Prayer" ? "hands.sparkles.fill" : "book.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Tap to set cover image")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            )
    }
    
    private func uploadTestThumbnail() {
        guard let image = platformImageTestThumbnail(), let jpegData = platformImageToJPEGData(image, quality: 0.85) else { return }
        let sessionId = session.id
        isUploadingThumbnail = true
        Task {
            do {
                let urlString = try await FirebaseSyncService.shared.uploadLiveSessionThumbnail(sessionId: sessionId, imageData: jpegData)
                await MainActor.run {
                    FirebaseSyncService.shared.saveThumbnailURL(sessionId: sessionId, urlString: urlString)
                    isUploadingThumbnail = false
                }
            } catch {
                await MainActor.run {
                    isUploadingThumbnail = false
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    // Get display name for host - prioritize host participant's userName if available
    var hostDisplayName: String {
        // First check if host has a participant record with a valid userName
        if let hostParticipant = sessionParticipants.first(where: { $0.userId == session.hostId && $0.isHost }) {
            let storedName = hostParticipant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || storedName.contains("iPad") || storedName == UIDevice.current.name
            
            // Use stored name if it's valid and not a device name
            if !storedName.isEmpty && !isStoredNameDevice {
                return storedName
            }
        }
        
        if isHost {
            // If current user is host, ALWAYS use their profile name from settings
            // First check ProfileManager (Firebase) for name
            let profileManagerName = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileManagerName.isEmpty {
                let isDeviceName = profileManagerName.contains("iPhone") || 
                                 profileManagerName.contains("iPad") || 
                                 profileManagerName == UIDevice.current.name
                if !isDeviceName {
                    return profileManagerName
                }
            }
            
            // Fallback to local UserProfile name
            let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileName.isEmpty {
                let isDeviceName = profileName.contains("iPhone") || 
                                 profileName.contains("iPad") || 
                                 profileName == UIDevice.current.name
                if !isDeviceName {
                    return profileName
                }
            }
            
            // No valid profile name - return "Host" (never device name)
            return "Host"
        } else {
            // For other users' sessions, use stored hostName if it's not a device name
            let storedHostName = session.hostName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isHostNameDevice = storedHostName.contains("iPhone") || 
                                  storedHostName.contains("iPad") || 
                                  storedHostName == UIDevice.current.name
            
            if !storedHostName.isEmpty && !isHostNameDevice {
                return storedHostName
            }
            
            // No valid name - return "Host" (never device name)
            return "Host"
        }
    }
    
    var sessionInvitations: [SessionInvitation] {
        invitations.filter { $0.sessionId == session.id }
    }
    
    var primaryInviteCode: String? {
        sessionInvitations.first(where: { $0.status == .pending })?.inviteCode ??
        sessionInvitations.first?.inviteCode
    }
    
    var body: some View {
        NavigationStack {
            scrollViewContent
        }
    }
    
    @ViewBuilder
    private var scrollViewContent: some View {
        let scrollContent = ScrollView {
            detailContent
                .padding()
        }
        
        let withNavigation = scrollContent
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
        
        let withAlerts = withNavigation
            .alert("Delete Session", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSession()
                }
            } message: {
                if isHost {
                    Text("Are you sure you want to delete this session? This action cannot be undone. All participants, messages, and recordings associated with this session will be removed from all devices.")
                } else {
                    Text("Are you sure you want to remove this session from your view? This will only remove it from your device and won't affect other participants.")
                }
            }
            .alert("Archive Session", isPresented: $showingArchiveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Archive") {
                    archiveSession()
                }
            } message: {
                Text("Archive this session? Archived sessions will be moved to the Archived section and hidden from your main session list. You can unarchive it later if needed.")
            }
        
        let withSheets = withAlerts
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
                    // Pass streamMode to differentiate behavior
                    // Convert LiveSessionDetailView.StreamMode to MultiParticipantStreamView.StreamMode
                    let convertedMode: MultiParticipantStreamView.StreamMode = {
                        switch streamMode {
                        case .broadcast:
                            return .broadcast
                        case .conference:
                            return .conference
                        case .multiParticipant:
                            return .multiParticipant
                        }
                    }()
                    MultiParticipantStreamView(session: session, streamMode: convertedMode)
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
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showingWaitingRoom) {
                WaitingRoomView(session: session)
            }
            .sheet(isPresented: $showingClips) {
                SessionClipsView(session: session)
            }
            .sheet(isPresented: $showingEditName) {
                EditSessionNameView(
                    currentName: editedParticipantName,
                    onSave: { newName in
                        updateParticipantName(newName)
                        showingEditName = false
                    },
                    onCancel: {
                        showingEditName = false
                    }
                )
            }
        
        let withLifecycle = withSheets
            .task {
                // IMMEDIATELY remove ALL duplicates for ALL users in this session before anything else
                let sessionId = session.id
                let descriptor = FetchDescriptor<LiveSessionParticipant>(
                    predicate: #Predicate<LiveSessionParticipant> { p in
                        p.sessionId == sessionId
                    }
                )
                if let allParticipants = try? modelContext.fetch(descriptor) {
                    // Group by userId
                    let grouped = Dictionary(grouping: allParticipants) { $0.userId }
                    var totalRemoved = 0
                    
                    for (userId, duplicates) in grouped where duplicates.count > 1 {
                        print("🚨 [TASK] Found \(duplicates.count) duplicates for userId: \(userId), removing NOW")
                        let sorted = duplicates.sorted { p1, p2 in
                            if p1.isHost != p2.isHost { return p1.isHost }
                            if p1.isActive != p2.isActive { return p1.isActive }
                            return p1.joinedAt > p2.joinedAt
                        }
                        for duplicate in sorted.dropFirst() {
                            modelContext.delete(duplicate)
                            totalRemoved += 1
                        }
                    }
                    
                    if totalRemoved > 0 {
                        try? modelContext.save()
                        print("✅ [TASK] Removed \(totalRemoved) duplicate participant(s) total")
                        // Force immediate UI refresh
                        participantCountRefreshTrigger = UUID()
                    }
                }
            }
            .onAppear {
            checkJoinStatus()
            if isHost && primaryInviteCode == nil {
                generateInviteCodeIfNeeded()
            }
            
            // Clean up any duplicate participants first (run immediately and after delay)
            removeDuplicateParticipants()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                removeDuplicateParticipants()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                removeDuplicateParticipants()
            }
            
            // Ensure host is added as participant if missing
            ensureHostIsParticipant()
            
            // Update participant count based on actual records
            // Use a small delay to ensure SwiftData query has loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                updateParticipantCount()
            }
            
            // Also update immediately in case query is already loaded
            updateParticipantCount()
            
            // If session is active, ensure count is correct
            if session.isActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    updateParticipantCount()
                }
            }
            
            // Update session hostName if current user is host and profile name changed
            if isHost {
                let currentProfileName = userService.getDisplayName(userProfile: userProfile)
                if !currentProfileName.isEmpty && session.hostName != currentProfileName {
                    session.hostName = currentProfileName
                    // Update host participant's userName too
                    if let hostParticipant = sessionParticipants.first(where: { $0.isHost }) {
                        hostParticipant.userName = currentProfileName
                    }
                    try? modelContext.save()
                    
                    // Sync updated host name to Firebase
                    Task {
                        await FirebaseSyncService.shared.syncLiveSession(session)
                    }
                }
            }
            
            // Update participant userName if they are current user and profile name changed
            if let userParticipant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier }) {
                // Get profile name directly (not fallback to device name)
                let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Always update if we have a valid profile name (not empty, not device name)
                // and current stored name is a device name or different
                if !profileName.isEmpty {
                    let isProfileNameDevice = profileName.contains("iPhone") || profileName.contains("iPad")
                    let isCurrentNameDevice = userParticipant.userName.contains("iPhone") || 
                                              userParticipant.userName.contains("iPad") ||
                                              userParticipant.userName == UIDevice.current.name
                    
                    // Update if:
                    // 1. Current name is a device name AND profile name is valid, OR
                    // 2. Profile name is different from current name
                    if isCurrentNameDevice && !isProfileNameDevice {
                        userParticipant.userName = profileName
                        try? modelContext.save()
                        
                        // Sync updated participant to Firebase (non-blocking)
                        Task {
                            await FirebaseSyncService.shared.syncSessionParticipant(userParticipant)
                            print("✅ [PARTICIPANT] Updated name from '\(userParticipant.userName)' to '\(profileName)'")
                        }
                    } else if !isProfileNameDevice && userParticipant.userName != profileName && userParticipant.userName != "" {
                        // Also update if names are different and both are valid
                        userParticipant.userName = profileName
                        try? modelContext.save()
                        
                        Task {
                            await FirebaseSyncService.shared.syncSessionParticipant(userParticipant)
                            print("✅ [PARTICIPANT] Updated name from '\(userParticipant.userName)' to '\(profileName)'")
                        }
                    }
                }
            }
            
            // Start listening for new participants (for host notifications)
            if isHost {
                setupParticipantListener()
            }
        }
        .onChange(of: participants.count) { _, _ in
            updateParticipantCount()
        }
        .onChange(of: userProfile?.name) { _, newName in
            // Update participant name when profile name changes
            if let userParticipant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier }),
               let newNameValue = newName,
               let profileName = Optional(newNameValue.trimmingCharacters(in: .whitespacesAndNewlines)),
               !profileName.isEmpty {
                let isProfileNameDevice = profileName.contains("iPhone") || profileName.contains("iPad")
                let isCurrentNameDevice = userParticipant.userName.contains("iPhone") || 
                                          userParticipant.userName.contains("iPad") ||
                                          userParticipant.userName == UIDevice.current.name
                
                if (isCurrentNameDevice && !isProfileNameDevice) || 
                   (!isProfileNameDevice && userParticipant.userName != profileName) {
                    let oldName = userParticipant.userName
                    userParticipant.userName = profileName
                    
                    // Update all existing chat messages from this user in this session
                    let userId = userService.userIdentifier
                    let sessionMessages = messages.filter { $0.sessionId == session.id && $0.userId == userId }
                    for message in sessionMessages {
                        if message.userName != profileName {
                            message.userName = profileName
                        }
                    }
                    
                    do {
                        try modelContext.save()
                        
                        Task {
                            await FirebaseSyncService.shared.syncSessionParticipant(userParticipant)
                            print("✅ [PARTICIPANT] Profile changed: Updated name from '\(oldName)' to '\(profileName)'")
                            
                            // Sync updated messages to Firebase
                            for message in sessionMessages {
                                await FirebaseSyncService.shared.syncChatMessage(message)
                            }
                            if !sessionMessages.isEmpty {
                                print("✅ [CHAT] Updated \(sessionMessages.count) message(s) with new profile name")
                            }
                        }
                    } catch {
                        print("❌ [PARTICIPANT] Error updating name from profile change: \(error)")
                    }
                }
            }
        }
        .onChange(of: participants.count) { _, _ in
            // Clean up duplicates when participants change
            removeDuplicateParticipants()
            // Update count when participants change
            updateParticipantCount()
        }
        .onChange(of: sessionParticipants.count) { _, _ in
            // Clean up duplicates when active participants change
            removeDuplicateParticipants()
            // Update count when active participants change
            updateParticipantCount()
        }
        .onChange(of: session.isActive) { _, isActive in
            // When session becomes active, ensure participant count is correct
            if isActive {
                ensureHostIsParticipant()
                updateParticipantCount()
                // Also update after a delay to handle async query loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    updateParticipantCount()
                }
            }
        }
            .onDisappear {
                // Clean up listeners
                cleanupListeners()
            }
        
        withLifecycle
    }
    
    @ViewBuilder
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Cover image / Thumbnail (host can change)
            if isHost {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cover image")
                            .font(.headline)
                        Spacer()
                        Button(action: { showingThumbnailPicker = true }) {
                            if isUploadingThumbnail {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Label("Change", systemImage: "photo.badge.plus")
                                    .font(.subheadline)
                            }
                        }
                        .disabled(isUploadingThumbnail)
                        .foregroundColor(themeManager.colors.primary)
                        Button("Test thumbnail") {
                            uploadTestThumbnail()
                        }
                        .font(.caption)
                        .disabled(isUploadingThumbnail)
                        .foregroundColor(themeManager.colors.primary.opacity(0.8))
                    }
                    Button(action: { showingThumbnailPicker = true }) {
                        Group {
                            if let urlString = session.thumbnailURL, !urlString.isEmpty, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure, .empty:
                                        sessionDetailThumbnailPlaceholder
                                    @unknown default:
                                        sessionDetailThumbnailPlaceholder
                                    }
                                }
                                .frame(height: 160)
                                .clipped()
                            } else if let img = selectedThumbnailImage {
                                platformImage(img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 160)
                                    .clipped()
                            } else {
                                sessionDetailThumbnailPlaceholder
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isUploadingThumbnail)
                }
                .sheet(isPresented: $showingThumbnailPicker) {
                    #if os(iOS)
                    ImagePicker(image: $selectedThumbnailImage)
                    #elseif os(macOS)
                    MacImagePicker(image: $selectedThumbnailImage)
                    #endif
                }
                .onChange(of: selectedThumbnailImage) { _, newImage in
                    guard let image = newImage, let jpegData = platformImageToJPEGData(image, quality: 0.85) else { return }
                    let sessionId = session.id
                    isUploadingThumbnail = true
                    Task {
                        do {
                            let urlString = try await FirebaseSyncService.shared.uploadLiveSessionThumbnail(sessionId: sessionId, imageData: jpegData)
                            await MainActor.run {
                                FirebaseSyncService.shared.saveThumbnailURL(sessionId: sessionId, urlString: urlString)
                                isUploadingThumbnail = false
                                selectedThumbnailImage = nil
                            }
                        } catch {
                            await MainActor.run {
                                isUploadingThumbnail = false
                                selectedThumbnailImage = nil
                                errorMessage = error.localizedDescription
                                showingErrorAlert = true
                            }
                        }
                    }
                }
            }
            
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(session.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                            .background(themeManager.colors.primary.opacity(0.2))
                            .foregroundColor(themeManager.colors.primary)
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
                
                // Host Profile / Channel
                Button(action: { showingHostProfile = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.colors.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                            Text(hostDisplayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                                
                            }
                            
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
                                .foregroundColor(themeManager.colors.primary)
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
                                .foregroundColor(themeManager.colors.primary)
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
                    // Use max of computed and stored to ensure we always show at least the correct count
                    // This handles cases where the computed property hasn't updated yet
                    // Show broadcaster count vs total participants
                    let broadcasterText = session.streamMode == "broadcast" ? 
                        "\(session.currentBroadcasters) broadcaster" : 
                        "\(session.currentBroadcasters) broadcasting"
                    Text("Participants (\(max(participantCount, session.currentParticipants)) total, \(broadcasterText))")
                        .font(.headline)
                        .id(participantCountRefreshTrigger) // Force refresh when trigger changes
                    
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
                    ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                        HStack(spacing: 12) {
                            // Filter to unique userIds to prevent duplicates from showing even if they exist in DB
                            // Use userId as the key to ensure only one per user is shown
                            let uniqueParticipants = sessionParticipants.reduce(into: [String: LiveSessionParticipant]()) { dict, participant in
                                // Always keep the most recent or host participant
                                if let existing = dict[participant.userId] {
                                    if participant.isHost && !existing.isHost {
                                        dict[participant.userId] = participant
                                    } else if participant.joinedAt > existing.joinedAt {
                                        dict[participant.userId] = participant
                                    }
                                } else {
                                    dict[participant.userId] = participant
                                }
                            }.values.sorted { p1, p2 in
                                if p1.isHost != p2.isHost { return p1.isHost }
                                return p1.joinedAt > p2.joinedAt
                            }
                            
                            // Use userId as identifier to prevent showing duplicates
                            ForEach(Array(uniqueParticipants), id: \.userId) { participant in
                                EnhancedParticipantBadge(
                                    participant: participant,
                                    isHost: isHost,
                                    isCurrentUser: participant.userId == userService.userIdentifier,
                                    currentUserProfile: userProfile,
                                    onRaiseHand: { raiseHand() },
                                    onLowerHand: { lowerHand(for: participant) },
                                    onMute: { muteParticipant(participant) },
                                    onRemove: { removeParticipant(participant) },
                                    onPromote: { promoteToCoHost(participant) },
                                    onDemote: { demoteFromCoHost(participant) }
                                )
                            }
                        }
                    }
                    
                    // Edit name button for current user
                    if let currentUserParticipant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier }) {
                        Button(action: {
                            editedParticipantName = currentUserParticipant.userName
                            showingEditName = true
                        }) {
                            HStack {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Edit Your Name")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.top, 8)
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
                                    .foregroundColor(themeManager.colors.primary)
                            }
                        }
                        
                        ForEach(Array(recentMessages), id: \.id) { message in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(themeManager.colors.primary)
                                
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
                    
                    ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
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
                                    .foregroundColor(themeManager.colors.primary)
                            }
                        }
                    }
                    
                    if let code = primaryInviteCode {
                        HStack {
                            Text(code)
                                .font(.title2)
                                .font(.body.weight(.bold))
                                .foregroundColor(themeManager.colors.primary)
                                .fontDesign(.monospaced)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = code
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.title3)
                                    .foregroundColor(themeManager.colors.primary)
                            }
                        }
                        .padding()
                        .background(themeManager.colors.primary.opacity(0.1))
                        .cornerRadius(8)
                    } else if isHost {
                        Button(action: { showingInviteCode = true }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Generate Invitation Code")
                            }
                            .font(.subheadline)
                            .foregroundColor(themeManager.colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.colors.primary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Action Buttons (Join, Start Stream, etc.)
            actionButtonsSection
            
            // Post-Stream Features (Recording, Transcript, etc.)
            postStreamFeaturesSection
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Host Actions
            if isHost {
                // Host Controls Section
                if hasJoined && session.isActive {
                    VStack(spacing: 8) {
                        let columns = [GridItem(.flexible()), GridItem(.flexible())]
                        LazyVGrid(columns: columns, spacing: 12) {
                            hostControlButton(
                                title: session.isLocked ? "Unlock" : "Lock",
                                systemImage: session.isLocked ? "lock.fill" : "lock.open.fill",
                                background: session.isLocked ? Color.red : Color.orange,
                                action: lockSession
                            )
                            
                            hostControlButton(
                                title: "Analytics",
                                systemImage: "chart.bar.fill",
                                background: Color.purple,
                                action: { showingAnalytics = true }
                            )
                            
                            hostControlButton(
                                title: "End All",
                                systemImage: "stop.circle.fill",
                                background: Color.red,
                                action: endSessionForAll
                            )
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
                                gradient: Gradient(colors: [themeManager.colors.secondary, themeManager.colors.primary]),
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
                    .background(themeManager.colors.primary.opacity(0.1))
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
                        .background(themeManager.colors.secondary)
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
    }
    
    @ViewBuilder
    private var postStreamFeaturesSection: some View {
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
                        .foregroundColor(themeManager.colors.primary)
                        .padding()
                        .background(themeManager.colors.primary.opacity(0.1))
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
                        .foregroundColor(themeManager.colors.primary)
                        .padding()
                        .background(themeManager.colors.primary.opacity(0.1))
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
    
    private var connectionQualityColor: Color {
        switch session.connectionQuality {
        case "Good", "Excellent": return .green
        case "Fair": return .yellow
        case "Poor": return .red
        default: return .gray
        }
    }
    
    private func raiseHand() {
        if let participant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier }) {
            participant.handRaised = true
            do {
                try modelContext.save()
                print("✅ Raised hand")
            } catch {
                print("❌ Error raising hand: \(error)")
            }
        }
    }
    
    private func lowerHand(for participant: LiveSessionParticipant? = nil) {
        let targetParticipant: LiveSessionParticipant?
        if let participant = participant {
            targetParticipant = participant
        } else {
            targetParticipant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier })
        }
        
        guard let targetParticipant = targetParticipant, targetParticipant.handRaised else { return }
        targetParticipant.handRaised = false
        do {
            try modelContext.save()
            print("✅ Lowered hand")
        } catch {
            print("❌ Error lowering hand: \(error)")
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
        
        // Decrement counts
        session.currentParticipants = max(0, session.currentParticipants - 1)
        if participant.isBroadcaster {
            session.currentBroadcasters = max(0, session.currentBroadcasters - 1)
        }
        
        try? modelContext.save()
        
        // Update participant count to sync to Firebase
        updateParticipantCount()
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
        
        do {
            try modelContext.save()
            print("✅ [SESSION] Session ended and saved locally: \(session.title)")
            
            // Sync to Firebase to update on all devices
            Task {
                await FirebaseSyncService.shared.syncLiveSession(session)
                print("✅ [SESSION] Synced ended session to Firebase: \(session.id)")
            }
        } catch {
            print("❌ [SESSION] Error ending session: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func hostControlButton(
        title: String,
        systemImage: String,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(background)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
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
        let sessionTitle = session.title
        let sessionToDelete = session // Capture session reference before deletion
        let isHostDeletion = isHost // Capture host status before deletion
        
        // Delete all associated participants (only if user is host or has local participant data)
        if isHost {
            // Host deletes all participants
            for participant in sessionParticipants {
                modelContext.delete(participant)
            }
        } else {
            // Non-host only deletes their own participant entry
            if let userParticipant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier }) {
                modelContext.delete(userParticipant)
            }
        }
        
        // Delete all associated messages (only delete locally - don't affect Firebase for non-hosts)
        let sessionMessages = messages.filter { $0.sessionId == session.id }
        for message in sessionMessages {
            modelContext.delete(message)
        }
        
        // Delete all associated invitations (only if host)
        if isHost {
            let sessionInvitations = invitations.filter { $0.sessionId == session.id }
            for invitation in sessionInvitations {
                modelContext.delete(invitation)
            }
        }
        
        // Delete the session itself
        modelContext.delete(session)
        
        do {
            try modelContext.save()
            
            // Only sync deletion to Firebase if user is the host
            if isHostDeletion {
                Task {
                    await FirebaseSyncService.shared.deleteLiveSession(sessionToDelete)
                    print("✅ [SESSION] Deleted session from Firebase: \(sessionTitle)")
                }
            } else {
                print("✅ [SESSION] Removed session locally (non-host deletion): \(sessionTitle)")
            }
            
            dismiss()
        } catch {
            print("Error deleting session: \(error)")
        }
    }
    
    private func promoteToCoHost(_ participant: LiveSessionParticipant) {
        guard isHost && !participant.isHost else { return }
        participant.isCoHost = true
        do {
            try modelContext.save()
            print("✅ Promoted \(participant.userName) to co-host")
        } catch {
            print("❌ Error promoting to co-host: \(error)")
        }
    }
    
    private func updateParticipantName(_ newName: String) {
        guard let userParticipant = sessionParticipants.first(where: { $0.userId == userService.userIdentifier }) else {
            print("⚠️ [PARTICIPANT] Could not find current user participant to update name")
            return
        }
        
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("⚠️ [PARTICIPANT] Cannot set empty name")
            return
        }
        
        let oldName = userParticipant.userName
        let userId = userService.userIdentifier
        print("🔄 [PARTICIPANT] Updating name from '\(oldName)' to '\(trimmedName)'")
        
        userParticipant.userName = trimmedName
        
        // Update all existing chat messages from this user in this session
        let sessionMessages = messages.filter { $0.sessionId == session.id && $0.userId == userId }
        var updatedMessages: [ChatMessage] = []
        for message in sessionMessages {
            if message.userName != trimmedName {
                message.userName = trimmedName
                updatedMessages.append(message)
            }
        }
        
        if !updatedMessages.isEmpty {
            print("🔄 [CHAT] Updating \(updatedMessages.count) chat message(s) with new name")
        }
        
        do {
            try modelContext.save()
            print("✅ [PARTICIPANT] Successfully saved session name update: '\(trimmedName)'")
            
            // Sync participant and updated messages to Firebase
            Task {
                await FirebaseSyncService.shared.syncSessionParticipant(userParticipant)
                print("✅ [PARTICIPANT] Synced name update to Firebase")
                
                // Sync updated messages to Firebase
                for message in updatedMessages {
                    await FirebaseSyncService.shared.syncChatMessage(message)
                }
                if !updatedMessages.isEmpty {
                    print("✅ [CHAT] Synced \(updatedMessages.count) updated message(s) to Firebase")
                }
            }
            
            // Force UI refresh by updating participant count (triggers view refresh)
            updateParticipantCount()
            
            // Small delay to ensure SwiftData context propagates the change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Force view refresh
                print("🔄 [PARTICIPANT] Triggering view refresh after name update")
            }
        } catch {
            print("❌ [PARTICIPANT] Error updating participant name: \(error)")
            print("❌ [PARTICIPANT] Error details: \(error.localizedDescription)")
        }
    }
    
    private func demoteFromCoHost(_ participant: LiveSessionParticipant) {
        guard isHost && !participant.isHost && participant.isCoHost else { return }
        participant.isCoHost = false
        do {
            try modelContext.save()
            print("✅ Demoted \(participant.userName) from co-host")
        } catch {
            print("❌ Error demoting from co-host: \(error)")
        }
    }
    
    private func startLiveStream() {
        print("🎬 [SESSION] startLiveStream() called")
        
        // Ensure host is a participant before starting stream
        ensureHostIsParticipant()
        
        // Mark session as active if it isn't already
        if !session.isActive {
            session.isActive = true
            session.startTime = Date()
            do {
                try modelContext.save()
                print("✅ [SESSION] Activated session: \(session.id)")
                
                // Sync session to Firebase
                Task {
                    await FirebaseSyncService.shared.syncLiveSession(session)
                    print("✅ [SESSION] Synced activated session to Firebase")
                }
            } catch {
                print("❌ [SESSION] Failed to activate session: \(error)")
            }
        }
        
        // Ensure host participant is synced to Firebase before starting stream
        if let hostParticipant = participants.first(where: { $0.sessionId == session.id && $0.userId == session.hostId && $0.isHost }) {
            Task {
                await FirebaseSyncService.shared.syncSessionParticipant(hostParticipant)
                print("✅ [SESSION] Synced host participant before starting stream")
            }
        }
        
        // Force update participant count immediately
        // This ensures the count is correct before the stream view opens
        updateParticipantCount()
        
        // Also force update after a small delay to handle async query loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateParticipantCount()
        }
        
        // Store stream mode in session so non-hosts know which mode to use
        switch streamMode {
        case .broadcast:
            session.streamMode = "broadcast"
        case .conference:
            session.streamMode = "conference"
        case .multiParticipant:
            session.streamMode = "multiParticipant"
        }
        try? modelContext.save()
        
        // Use Agora for ALL streaming modes (works globally via Vercel token server)
        // Agora supports broadcast, conference, and multi-participant modes
        // All modes use MultiParticipantStreamView but with different role configurations
        showingMultiParticipantStream = true
        
        print("🎬 [SESSION] Starting live stream - mode: \(session.streamMode), participant count: \(participantCount), stored: \(session.currentParticipants)")
    }
    
    private func joinLiveStream() {
        // For non-hosts, join as viewer/participant using Agora
        // Use the stream mode stored in the session (set by host when starting)
        // Convert session.streamMode string to StreamMode enum
        switch session.streamMode {
        case "broadcast":
            streamMode = .broadcast
        case "conference":
            streamMode = .conference
        case "multiParticipant":
            streamMode = .multiParticipant
        default:
            // Default to conference if mode not set (backward compatibility)
            streamMode = .conference
        }
        
        showingMultiParticipantStream = true
        print("👤 [SESSION] Non-host joining stream - mode: \(session.streamMode)")
    }
    
    private func checkJoinStatus() {
        let userId = userService.userIdentifier
        hasJoined = sessionParticipants.contains { $0.userId == userId }
    }
    
    private func joinSession() {
        let userId = userService.userIdentifier
        
        // ALWAYS use profile name from settings - never device name
        // First check ProfileManager (Firebase) for name
        var userName: String = ""
        let profileManagerName = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileManagerName.isEmpty {
            let isDeviceName = profileManagerName.contains("iPhone") || 
                             profileManagerName.contains("iPad") || 
                             profileManagerName == UIDevice.current.name
            if !isDeviceName {
                userName = profileManagerName
            }
        }
        
        // Fallback to local UserProfile name if ProfileManager doesn't have it
        if userName.isEmpty {
            let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileName.isEmpty {
                let isDeviceName = profileName.contains("iPhone") || 
                                 profileName.contains("iPad") || 
                                 profileName == UIDevice.current.name
                if !isDeviceName {
                    userName = profileName
                }
            }
        }
        
        // If still no valid profile name, check if participant has a valid edited name
        if userName.isEmpty {
            if let existingParticipant = sessionParticipants.first(where: { $0.userId == userId }) {
                let storedName = existingParticipant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
                let isStoredNameDevice = storedName.contains("iPhone") || 
                                       storedName.contains("iPad") || 
                                       storedName == UIDevice.current.name
                
                if !storedName.isEmpty && !isStoredNameDevice {
                    userName = storedName
                }
            }
        }
        
        // If still no valid name, we cannot join - user must set profile name
        guard !userName.isEmpty else {
            errorMessage = "Please set your name in Settings > Profile before joining a session."
            showingErrorAlert = true
            print("⚠️ [JOIN] Cannot join session - user has no profile name set")
            return
        }
        
        // Determine if user is joining as broadcaster or audience based on stream mode
        let joiningAsBroadcaster: Bool
        if session.streamMode == "broadcast" {
            // In broadcast mode, only host is broadcaster, everyone else is audience
            joiningAsBroadcaster = isHost
        } else {
            // In conference/multi-participant mode, everyone can be a broadcaster
            // But check if we've reached the broadcaster limit
            let maxBroadcasters = min(17, session.maxParticipants)
            if session.currentBroadcasters >= maxBroadcasters {
                // Broadcaster limit reached, join as audience
                joiningAsBroadcaster = false
                print("ℹ️ [JOIN] Broadcaster limit reached (\(session.currentBroadcasters)/\(maxBroadcasters)), joining as audience")
            } else {
                joiningAsBroadcaster = true
            }
        }
        
        // Check if participant already exists (check ALL participants, not just active ones)
        // This prevents duplicates even if a participant was marked inactive
        if let existingParticipant = allSessionParticipants.first(where: { $0.userId == userId }) {
            // Update existing participant with profile name if it changed
            if existingParticipant.userName != userName {
                existingParticipant.userName = userName
                try? modelContext.save()
                // Sync to Firebase
                Task {
                    await FirebaseSyncService.shared.syncSessionParticipant(existingParticipant)
                }
            }
            
            // Update broadcaster status if it changed
            if existingParticipant.isBroadcaster != joiningAsBroadcaster {
                existingParticipant.isBroadcaster = joiningAsBroadcaster
                // Update broadcaster count
                if joiningAsBroadcaster {
                    session.currentBroadcasters += 1
                } else if existingParticipant.isBroadcaster {
                    session.currentBroadcasters = max(0, session.currentBroadcasters - 1)
                }
                try? modelContext.save()
                print("✅ [JOIN] Updated broadcaster status: \(joiningAsBroadcaster)")
            }
            
            // Ensure participant is marked as active and joined
            if !existingParticipant.isActive {
                existingParticipant.isActive = true
                existingParticipant.joinedAt = Date()
                try? modelContext.save()
                print("✅ [JOIN] Reactivated existing participant: \(userId)")
            }
            
            // Participant already exists, just mark as joined
            hasJoined = true
            updateParticipantCount()
            return
        }
        
        // Create new participant with profile name
        let participant = LiveSessionParticipant(
            sessionId: session.id,
            userId: userId,
            userName: userName,
            isHost: false,
            isBroadcaster: joiningAsBroadcaster
        )
        modelContext.insert(participant)
        
        // Update participant counts
        session.currentParticipants += 1
        if joiningAsBroadcaster {
            session.currentBroadcasters += 1
        }
        
        do {
            try modelContext.save()
            
            // Sync participant to Firebase
            Task {
                await FirebaseSyncService.shared.syncSessionParticipant(participant)
                await FirebaseSyncService.shared.updateSessionParticipantCount(session.id, count: session.currentParticipants)
                
                print("✅ [JOIN] Synced participant to Firebase - broadcaster: \(joiningAsBroadcaster), total: \(session.currentParticipants), broadcasters: \(session.currentBroadcasters)")
            }
            
            hasJoined = true
        } catch {
            print("Error joining session: \(error)")
        }
    }
    
    private func shareSession() {
        showingShareSheet = true
    }
    
    private func shareToSocialMedia(platform: String) {
        // Use share sheet with platform-specific text
        let shareText = platform == "twitter" 
            ? "Join me for a live session: \(session.title) #FaithJournal"
            : "Join me for a live session: \(session.title) on Faith Journal!"
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // For iPad support
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                          y: rootViewController.view.bounds.midY, 
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func setupParticipantListener() {
        #if canImport(FirebaseFirestore)
        // Capture values needed in closure
        let currentSessionId = session.id
        let currentUserId = userService.userIdentifier
        let currentSession = session
        
        // Listen for new participants joining the session
        // When a new participant is detected, notify the host
        if let listener = FirebaseSyncService.shared.startListeningToParticipants(
            sessionId: currentSessionId,
            onParticipantAdded: { participant in
                Task { @MainActor in
                    // Persist participant locally so breakout room assignment works.
                    // Check ALL participants (not just active) to prevent duplicates
                    // Capture participant.userId before using in predicate
                    let participantUserId = participant.userId
                    
                    // Check for existing participant by userId (CloudKit ID)
                    let descriptor = FetchDescriptor<LiveSessionParticipant>(
                        predicate: #Predicate<LiveSessionParticipant> { p in
                            p.sessionId == currentSessionId && p.userId == participantUserId
                        }
                    )
                    let existing = (try? modelContext.fetch(descriptor)) ?? []
                    
                    // Also check if there's a participant with the same sessionId but different userId
                    // (in case Firebase UID and CloudKit ID mismatch)
                    let allSessionDescriptor = FetchDescriptor<LiveSessionParticipant>(
                        predicate: #Predicate<LiveSessionParticipant> { p in
                            p.sessionId == currentSessionId
                        }
                    )
                    let allSessionParticipants = (try? modelContext.fetch(allSessionDescriptor)) ?? []
                    
                    // Check if this participant's userId matches any existing participant's userId
                    let matchingParticipant = allSessionParticipants.first { $0.userId == participantUserId }
                    
                    if let existingParticipant = matchingParticipant ?? existing.first {
                        // Participant already exists (by userId match), update it instead of creating duplicate
                        existingParticipant.isActive = participant.isActive
                        existingParticipant.userName = participant.userName
                        existingParticipant.joinedAt = participant.joinedAt
                        existingParticipant.isBroadcaster = participant.isBroadcaster
                        existingParticipant.isHost = participant.isHost
                        try? modelContext.save()
                        print("ℹ️ [PARTICIPANT] Updated existing participant from Firebase: \(participant.userId)")
                    } else if existing.isEmpty {
                        // Double-check one more time before inserting (race condition protection)
                        let doubleCheck = (try? modelContext.fetch(descriptor)) ?? []
                        if doubleCheck.isEmpty {
                            // No existing participant with this userId and sessionId, safe to insert
                            modelContext.insert(participant)
                            try? modelContext.save()
                            print("✅ [PARTICIPANT] Inserted participant from Firebase: \(participant.userId)")
                        } else {
                            // Participant was created between checks - update it instead
                            if let existingParticipant = doubleCheck.first {
                                existingParticipant.isActive = participant.isActive
                                existingParticipant.userName = participant.userName
                                existingParticipant.joinedAt = participant.joinedAt
                                existingParticipant.isBroadcaster = participant.isBroadcaster
                                existingParticipant.isHost = participant.isHost
                                try? modelContext.save()
                                print("ℹ️ [PARTICIPANT] Participant created between checks, updated from Firebase: \(participant.userId)")
                            }
                        }
                    }
                    
                    // Only notify if this is a new participant (not the host themselves)
                    if !participant.isHost && participant.userId != currentUserId {
                        await SessionNotificationService.shared.scheduleParticipantJoined(
                            session: currentSession,
                            participantName: participant.userName
                        )
                        print("✅ [NOTIFICATION] Notified host: \(participant.userName) joined session")
                    }
                }
            }
        ) {
            participantListener = listener
            print("✅ [LISTENER] Started listening for participants in session: \(currentSessionId)")
        }
        #endif
    }
    
    private func cleanupListeners() {
        #if canImport(FirebaseFirestore)
        if let listener = participantListener as? ListenerRegistration {
            listener.remove()
            participantListener = nil
            print("✅ [LISTENER] Removed participant listener")
        }
        if let listener = chatMessageListener as? ListenerRegistration {
            listener.remove()
            chatMessageListener = nil
            print("✅ [LISTENER] Removed chat message listener")
        }
        #endif
    }
    
    private func generateInviteCodeIfNeeded() {
        // Generate default invite code for host if none exists
        if primaryInviteCode == nil {
            let code = UUID().uuidString.prefix(8).uppercased()
            let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
            // Use hostDisplayName which prioritizes participant userName
            let invitation = SessionInvitation(
                sessionId: session.id,
                sessionTitle: session.title,
                hostId: session.hostId,
                hostName: hostDisplayName,
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
    @Query var userProfiles: [UserProfile]
    private let userService = LocalUserService.shared
    private var userProfile: UserProfile? { userProfiles.first }
    
    // Get display name for participant - ALWAYS prioritize profile name, never device name
    private var participantDisplayName: String {
        // If current user, ALWAYS use profile name from settings
        let isCurrentUser = participant.userId == userService.userIdentifier
        if isCurrentUser {
            // First check ProfileManager (Firebase) for name
            let profileManagerName = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileManagerName.isEmpty {
                let isDeviceName = profileManagerName.contains("iPhone") || 
                                 profileManagerName.contains("iPad") || 
                                 profileManagerName == UIDevice.current.name
                if !isDeviceName {
                    return profileManagerName
                }
            }
            
            // Fallback to local UserProfile name
            let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileName.isEmpty {
                let isDeviceName = profileName.contains("iPhone") || 
                                 profileName.contains("iPad") || 
                                 profileName == UIDevice.current.name
                if !isDeviceName {
                    return profileName
                }
            }
        }
        
        // For current user, check if participant has a valid edited name (not device name)
        if isCurrentUser {
            let storedName = participant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || 
                                   storedName.contains("iPad") || 
                                   storedName == UIDevice.current.name
            
            // Use stored name only if it's not a device name
            if !storedName.isEmpty && !isStoredNameDevice {
                return storedName
            }
        } else {
            // For other participants, use stored name if it's not a device name
            let storedName = participant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || 
                                   storedName.contains("iPad") || 
                                   storedName == UIDevice.current.name
            
            if !storedName.isEmpty && !isStoredNameDevice {
                return storedName
            }
        }
        
        // No valid name - return "Participant" (never device name)
        return "Participant"
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: participant.isHost ? "crown.fill" : "person.fill")
                .font(.title2)
                .foregroundColor(participant.isHost ? .orange : .purple)
            
            Text(participantDisplayName)
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
    let isCurrentUser: Bool
    let currentUserProfile: UserProfile?
    let onRaiseHand: () -> Void
    let onLowerHand: () -> Void
    let onMute: () -> Void
    let onRemove: () -> Void
    let onPromote: () -> Void
    let onDemote: () -> Void
    
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    
    // Get display name for participant - ALWAYS prioritize profile name, never device name
    var participantDisplayName: String {
        // If current user, ALWAYS use profile name from settings
        if isCurrentUser {
            // First check ProfileManager (Firebase) for name
            let profileManagerName = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileManagerName.isEmpty {
                let isDeviceName = profileManagerName.contains("iPhone") || 
                                 profileManagerName.contains("iPad") || 
                                 profileManagerName == UIDevice.current.name
                if !isDeviceName {
                    return profileManagerName
                }
            }
            
            // Fallback to local UserProfile name
            let profileName = (currentUserProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !profileName.isEmpty {
                let isDeviceName = profileName.contains("iPhone") || 
                                 profileName.contains("iPad") || 
                                 profileName == UIDevice.current.name
                if !isDeviceName {
                    return profileName
                }
            }
            
            // Check if participant has a valid edited name (not device name)
            let storedName = participant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || 
                                   storedName.contains("iPad") || 
                                   storedName == UIDevice.current.name
            
            if !storedName.isEmpty && !isStoredNameDevice {
                return storedName
            }
            
            // No valid profile name - return "Participant" (never device name)
            return "Participant"
        } else {
            // For other participants, use stored name if it's not a device name
            let storedName = participant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || 
                                   storedName.contains("iPad") || 
                                   storedName == UIDevice.current.name
            
            if !storedName.isEmpty && !isStoredNameDevice {
                return storedName
            }
            
            // No valid name - return "Participant" (never device name)
            return "Participant"
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: participantIcon)
                    .font(.title2)
                    .foregroundColor(participantIconColor)
                
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
            
            Text(participantDisplayName)
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
            // Current user actions
            if isCurrentUser && !participant.isHost {
                if participant.handRaised {
                    Button(action: onLowerHand) {
                        Label("Lower Hand", systemImage: "hand.raised.slash.fill")
                    }
                } else {
                    Button(action: onRaiseHand) {
                        Label("Raise Hand", systemImage: "hand.raised.fill")
                    }
                }
            }
            
            // Host actions
            if isHost {
                Button(action: onMute) {
                    Label(participant.isMuted ? "Unmute" : "Mute", systemImage: participant.isMuted ? "mic.fill" : "mic.slash.fill")
                }
                
                if !participant.isHost {
                    // Lower hand if raised
                    if participant.handRaised {
                        Button(action: onLowerHand) {
                            Label("Lower Hand", systemImage: "hand.raised.slash.fill")
                        }
                    }
                    
                    // Co-host management
                    if participant.isCoHost {
                        Button(action: onDemote) {
                            Label("Demote from Co-Host", systemImage: "star.slash.fill")
                        }
                    } else {
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
    
    private var participantIcon: String {
        if participant.isHost {
            return "crown.fill"
        } else if participant.isCoHost {
            return "star.circle.fill"
        } else {
            return "person.fill"
        }
    }
    
    private var participantIconColor: Color {
        if participant.isHost {
            return .orange
        } else if participant.isCoHost {
            return .blue
        } else {
            return .purple
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
    @Environment(\.modelContext) private var modelContext
    @Query var userProfiles: [UserProfile]
    @Query(filter: #Predicate<LiveSessionParticipant> { $0.isActive == true }) var allParticipants: [LiveSessionParticipant]
    private let userService = LocalUserService.shared
    
    // Get participants for this session
    private var sessionParticipants: [LiveSessionParticipant] {
        allParticipants.filter { $0.sessionId == session.id }
    }
    
    @State private var isLoading = false
    
    private var userProfile: UserProfile? { userProfiles.first }
    
    // Check if current user is the host
    private var isCurrentUserHost: Bool {
        session.hostId == userService.userIdentifier
    }
    
    // Get display name - prioritize host participant's userName if available
    private var displayName: String {
        // First check if host has a participant record with a valid userName
        if let hostParticipant = sessionParticipants.first(where: { $0.userId == session.hostId && $0.isHost }) {
            let storedName = hostParticipant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || storedName.contains("iPad") || storedName == UIDevice.current.name
            
            // Use stored name if it's valid and not a device name
            if !storedName.isEmpty && !isStoredNameDevice {
                return storedName
            }
        }
        
        if isCurrentUserHost {
            // If viewing own profile, check profile name
            let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let isProfileNameDevice = profileName.contains("iPhone") || profileName.contains("iPad")
            
            // Only use profile name if it's valid and not a device name
            if !profileName.isEmpty && !isProfileNameDevice {
                return profileName
            }
            
            // Fallback to stored hostName if profile name is not valid
            let storedHostName = session.hostName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isHostNameDevice = storedHostName.contains("iPhone") || storedHostName.contains("iPad")
            
            if !storedHostName.isEmpty && !isHostNameDevice {
                return storedHostName
            }
            
            return "Host"
        } else {
            // For other users, check stored hostName (fallback if no participant record)
            let storedHostName = session.hostName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isHostNameDevice = storedHostName.contains("iPhone") || storedHostName.contains("iPad")
            
            // Only use stored hostName if it's not a device name
            if !storedHostName.isEmpty && !isHostNameDevice {
                return storedHostName
            }
            
            return "Host"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Profile header
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.purple)
                        
                        Text(displayName)
                            .font(.title)
                            .font(.body.weight(.bold))
                        
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .onAppear {
                        // Update stored hostName if viewing own profile and it's a device name
                        if isCurrentUserHost {
                            // Get profile name directly (not fallback to device name)
                            let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Only update if we have a valid profile name (not empty, not device name)
                            if !profileName.isEmpty {
                                let isProfileNameDevice = profileName.contains("iPhone") || profileName.contains("iPad")
                                let isHostNameDevice = session.hostName.contains("iPhone") || session.hostName.contains("iPad")
                                
                                // Only update if host name is a device name AND profile name is valid (not device name)
                                if isHostNameDevice && !isProfileNameDevice {
                                    session.hostName = profileName
                                    try? modelContext.save()
                                    
                                    // Sync to Firebase (non-blocking)
                                    Task {
                                        await FirebaseSyncService.shared.syncLiveSession(session)
                                        print("✅ [HOST PROFILE] Updated host name to: \(profileName)")
                                    }
                                }
                            }
                        }
                    }
                    
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
    @Environment(\.modelContext) private var modelContext
    @Query var allRatings: [SessionRating]
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
                        
                        EngagementMetricsCard(
                            title: "Message Engagement",
                            value: "\(calculateMessageEngagement())%",
                            icon: "bubble.left.and.bubble.right.fill"
                        )
                        
                        EngagementMetricsCard(
                            title: "Reaction Engagement",
                            value: "\(calculateReactionEngagement())%",
                            icon: "heart.circle.fill"
                        )
                        
                        EngagementMetricsCard(
                            title: "Peak Engagement",
                            value: peakEngagementTimeString,
                            icon: "chart.line.uptrend.xyaxis"
                        )
                        
                        EngagementMetricsCard(
                            title: "Retention Rate",
                            value: "\(calculateRetentionRate())%",
                            icon: "arrow.clockwise"
                        )
                        
                        EngagementMetricsCard(
                            title: "Avg Watch Time",
                            value: formatWatchTime(Int(calculateAverageWatchTime())),
                            icon: "clock.arrow.circlepath"
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
    
    private func calculateMessageEngagement() -> Int {
        guard session.viewerCount > 0 else { return 0 }
        return (session.messageCount * 100) / max(session.viewerCount, 1)
    }
    
    private func calculateReactionEngagement() -> Int {
        guard session.viewerCount > 0 else { return 0 }
        return (session.reactionCount * 100) / max(session.viewerCount, 1)
    }
    
    private var peakEngagementTimeString: String {
        if let scheduled = session.scheduledStartTime {
            return scheduled.formatted(date: .omitted, time: .shortened)
        }
        return session.startTime.formatted(date: .omitted, time: .shortened)
    }
    
    private func calculateRetentionRate() -> Int {
        guard session.viewerCount > 0, session.peakViewerCount > 0 else { return 0 }
        let retention = Double(session.viewerCount) / Double(session.peakViewerCount) * 100.0
        return min(Int(retention), 100)
    }
    
    private func calculateAverageWatchTime() -> TimeInterval {
        // Calculate average watch time based on duration and viewer count
        guard session.viewerCount > 0 else { return 0 }
        return session.duration
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
    @State private var player: AVPlayer?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Error Loading Recording")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if let player = player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .navigationTitle("Session Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                player?.pause()
            }
        }
    }
    
    private func setupPlayer() {
        guard let url = URL(string: recordingURL) else {
            errorMessage = "Invalid recording URL"
            return
        }
        
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        
        // Use VideoPlayer's built-in controls - it handles playback, seeking, and time display
    }
}

@available(iOS 17.0, *)
struct LiveSessionChatView: View {
    let session: LiveSession
    @Query var messages: [ChatMessage]
    @Query var userProfiles: [UserProfile]
    @Query(filter: #Predicate<LiveSessionParticipant> { $0.isActive == true }) var allParticipants: [LiveSessionParticipant]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    private var userProfile: UserProfile? { userProfiles.first }
    @State private var messageText = ""
    @State private var publicMessages: [ChatMessage] = []
    @State private var showingTranslationSettings = false
    @State private var showingPrayerRequest = false
    @State private var showingBibleVersePicker = false
    @State private var showingEmojiPicker = false
    @State private var selectedMessageForReaction: ChatMessage?
    @State private var showingFilePicker = false
    @State private var chatMessageListener: Any? // ListenerRegistration
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    // Get participants for this session
    private var sessionParticipants: [LiveSessionParticipant] {
        allParticipants.filter { $0.sessionId == session.id }
    }
    
    // Get the current user's session display name (prioritizes edited session name over profile name)
    private var sessionDisplayName: String {
        // ALWAYS use profile name from settings - never device name
        // First check ProfileManager (Firebase) for name
        let profileManagerName = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileManagerName.isEmpty {
            let isDeviceName = profileManagerName.contains("iPhone") || 
                             profileManagerName.contains("iPad") || 
                             profileManagerName == UIDevice.current.name
            if !isDeviceName {
                return profileManagerName
            }
        }
        
        // Fallback to local UserProfile name
        let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !profileName.isEmpty {
            let isDeviceName = profileName.contains("iPhone") || 
                             profileName.contains("iPad") || 
                             profileName == UIDevice.current.name
            if !isDeviceName {
                return profileName
            }
        }
        
        // Check if participant has a valid edited name (not device name)
        let userId = userService.userIdentifier
        if let currentUserParticipant = sessionParticipants.first(where: { $0.userId == userId }) {
            let storedName = currentUserParticipant.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isStoredNameDevice = storedName.contains("iPhone") || 
                                   storedName.contains("iPad") || 
                                   storedName == UIDevice.current.name
            
            // Use stored name only if it's not a device name
            if !storedName.isEmpty && !isStoredNameDevice {
                return storedName
            }
        }
        
        // No valid profile name - return empty string (should prompt user to set name)
        // Never return device name as fallback
        return ""
    }
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingTranslationSettings = true }) {
                        Image(systemName: "textformat")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTranslationSettings) {
                TranslationSettingsView()
            }
            .onAppear {
                loadPublicMessages()
                setupMessageSubscription()
            }
            .onDisappear {
                // Clean up chat message listener
                #if canImport(FirebaseFirestore)
                if let listener = chatMessageListener as? ListenerRegistration {
                    listener.remove()
                    chatMessageListener = nil
                    print("✅ [CHAT] Removed message listener")
                }
                #endif
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
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
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
        // Messages are loaded via Firebase listener in setupMessageSubscription
        // This is called on appear to ensure listener is set up
        publicMessages = []
    }
    
    private func refreshPublicMessages() async {
        // Messages are automatically updated via Firebase listener
        // This refresh is mainly for user-initiated refresh
        print("🔄 [CHAT] Refreshing messages...")
    }
    
    private func setupMessageSubscription() {
        #if canImport(FirebaseFirestore)
        // Start listening for chat messages from Firebase
        if let listener = FirebaseSyncService.shared.startListeningToChatMessages(
            sessionId: session.id,
            onMessageReceived: { message in
                // Check if message already exists locally to prevent duplicates
                let messageId = message.id
                let existingMessageQuery = FetchDescriptor<ChatMessage>(
                    predicate: #Predicate<ChatMessage> { msg in
                        msg.id == messageId
                    }
                )
                
                Task { @MainActor in
                    if (try? modelContext.fetch(existingMessageQuery).first) != nil {
                        // Message already exists - skip
                        print("ℹ️ [CHAT] Message already exists locally: \(message.id)")
                    } else {
                        // New message from Firebase - save locally
                        modelContext.insert(message)
                        do {
                            try modelContext.save()
                            print("✅ [CHAT] Received new message from Firebase: \(message.id)")
                            
                            // Notify user about new message (if not from current user)
                            if message.userId != userService.userIdentifier {
                                await SessionNotificationService.shared.scheduleNewMessage(
                                    session: session,
                                    senderName: message.userName,
                                    message: message.message
                                )
                            }
                        } catch {
                            print("❌ [CHAT] Error saving message: \(error.localizedDescription)")
                        }
                    }
                }
            }
        ) {
            chatMessageListener = listener
            print("✅ [CHAT] Started listening to messages for session: \(session.id)")
        }
        #endif
    }
    
    private func sendMessage() {
        let userId = userService.userIdentifier
        // Use session display name (ALWAYS uses profile name from settings)
        let userName = sessionDisplayName
        
        // If sessionDisplayName is empty, user must set profile name
        guard !userName.isEmpty else {
            errorMessage = "Please set your name in Settings > Profile before sending messages."
            showingErrorAlert = true
            print("⚠️ [CHAT] Cannot send message - user has no profile name set")
            return
        }
        
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
            
            // Sync message to Firebase for real-time chat
            Task {
                await FirebaseSyncService.shared.syncChatMessage(message)
                print("✅ [CHAT] Synced message to Firebase: \(message.id)")
            }
            
            messageText = ""
            
            // Notify other participants (excluding sender) about new message
            Task {
                await SessionNotificationService.shared.scheduleNewMessage(
                    session: session,
                    senderName: userName,
                    message: message.message
                )
            }
        } catch {
            print("Error sending message: \(error)")
        }
    }
    
    private func sendPrayerRequest(_ prayerText: String) {
        let userId = userService.userIdentifier
        // Use session display name (ALWAYS uses profile name from settings)
        let userName = sessionDisplayName
        
        // If sessionDisplayName is empty, user must set profile name
        guard !userName.isEmpty else {
            errorMessage = "Please set your name in Settings > Profile before sending prayer requests."
            showingErrorAlert = true
            print("⚠️ [CHAT] Cannot send prayer request - user has no profile name set")
            return
        }
        
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
            
            // Sync prayer message to Firebase
            Task {
                await FirebaseSyncService.shared.syncChatMessage(message)
                print("✅ [CHAT] Synced prayer message to Firebase")
            }
        } catch {
            print("Error sending prayer request: \(error)")
        }
    }
    
    private func sendBibleVerse(_ verse: String, reference: String) {
        let userId = userService.userIdentifier
        // Use session display name (ALWAYS uses profile name from settings)
        let userName = sessionDisplayName
        
        // If sessionDisplayName is empty, user must set profile name
        guard !userName.isEmpty else {
            errorMessage = "Please set your name in Settings > Profile before sharing Bible verses."
            showingErrorAlert = true
            print("⚠️ [CHAT] Cannot send Bible verse - user has no profile name set")
            return
        }
        
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
            
            // Sync Bible verse message to Firebase
            Task {
                await FirebaseSyncService.shared.syncChatMessage(message)
                print("✅ [CHAT] Synced Bible verse message to Firebase")
            }
        } catch {
            print("Error sending Bible verse: \(error)")
        }
    }
    
    private func addReaction(_ emoji: String, to message: ChatMessage) {
        // Add reaction to message
        if !message.reactions.contains(emoji) {
            message.reactions.append(emoji)
        }
        
        do {
            try modelContext.save()
            
            // Sync updated message with reaction to Firebase
            Task {
                await FirebaseSyncService.shared.syncChatMessage(message)
                print("✅ [CHAT] Added reaction and synced to Firebase")
            }
        } catch {
            print("Error adding reaction: \(error)")
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

@available(iOS 17.0, *)
struct EditSessionNameView: View {
    @State private var name: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    init(currentName: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        _name = State(initialValue: currentName)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Your Name in This Session")) {
                    TextField("Enter your name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                }
                
                Section {
                    Text("This name will be visible to other participants in this session. It won't change your profile name.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(name)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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



