//
//  LiveSessionsView.swift
//  Faith Journal
//
//  Created on 11/18/25.
//

import SwiftUI
import SwiftData
import AVKit
#if os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers

/// Returns true if the string looks like a device name (iPhone, iPad, or exact device/host name).
@available(iOS 17.0, *)
fileprivate func isDeviceName(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty { return true }
    if t.contains("iPhone") || t.contains("iPad") || t.contains("iPod") { return true }
    #if os(iOS)
    if t == UIDevice.current.name { return true }
    #else
    if t == ProcessInfo.processInfo.hostName { return true }
    #endif
    return false
}

/// Best display name for the current user (profile name when set; never returns device name).
/// Posted when a live session thumbnail URL is saved so the list can refresh and show the custom image.
fileprivate let liveSessionThumbnailDidSaveNotification = Notification.Name("LiveSessionThumbnailDidSave")

/// Sample replay URL for trying the replay player (short test video).
fileprivate let sampleReplayVideoURL = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"

@available(iOS 17.0, *)
@MainActor
fileprivate func profileDisplayNameForCurrentUser(userProfile: UserProfile?, userService: LocalUserService) -> String {
    let pm = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !pm.isEmpty && !isDeviceName(pm) { return pm }
    let name = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !name.isEmpty && !isDeviceName(name) { return name }
    let raw = userService.getDisplayName(userProfile: userProfile)
    return isDeviceName(raw) ? "Participant" : raw
}

/// Display name for session host: prefers profile name, never shows device name (returns "Host" instead).
@available(iOS 17.0, *)
@MainActor
fileprivate func liveSessionHostDisplayName(session: LiveSession, isHost: Bool, userProfile: UserProfile?) -> String {
    if isHost {
        let pm = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pm.isEmpty && !isDeviceName(pm) { return pm }
        let name = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && !isDeviceName(name) { return name }
        return "Host"
    }
    let stored = session.hostName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !stored.isEmpty && !isDeviceName(stored) { return stored }
    return "Host"
}

// MARK: - Stream Template (Feature 4)

struct LiveStreamTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let title: String
    let description: String
    let category: String
    let tags: [String]
    let suggestedSegments: [StreamSegment]
}

extension LiveStreamTemplate {
    static let all: [LiveStreamTemplate] = [
        LiveStreamTemplate(
            name: "Sunday Sermon", icon: "megaphone.fill", color: .purple,
            title: "Sunday Morning Sermon", description: "Join us for worship and the Word of God.",
            category: "Bible Study", tags: ["Sermon", "Worship", "Sunday"],
            suggestedSegments: [
                StreamSegment(name: "Opening Worship", scriptureReference: "", durationMinutes: 15),
                StreamSegment(name: "Message", scriptureReference: "", durationMinutes: 30),
                StreamSegment(name: "Altar Call", scriptureReference: "", durationMinutes: 10),
                StreamSegment(name: "Closing Prayer", scriptureReference: "", durationMinutes: 5)
            ]
        ),
        LiveStreamTemplate(
            name: "Bible Study", icon: "book.fill", color: .blue,
            title: "Weekly Bible Study", description: "Deep dive into scripture together.",
            category: "Bible Study", tags: ["Bible Study", "Scripture", "Learning"],
            suggestedSegments: [
                StreamSegment(name: "Review & Prayer", scriptureReference: "", durationMinutes: 5),
                StreamSegment(name: "Scripture Reading", scriptureReference: "", durationMinutes: 15),
                StreamSegment(name: "Discussion", scriptureReference: "", durationMinutes: 25),
                StreamSegment(name: "Application & Close", scriptureReference: "", durationMinutes: 10)
            ]
        ),
        LiveStreamTemplate(
            name: "Prayer Meeting", icon: "hands.sparkles.fill", color: .orange,
            title: "Community Prayer Meeting", description: "Come together to lift each other up in prayer.",
            category: "Prayer", tags: ["Prayer", "Intercession", "Community"],
            suggestedSegments: [
                StreamSegment(name: "Praise & Worship", scriptureReference: "", durationMinutes: 10),
                StreamSegment(name: "Prayer Requests", scriptureReference: "", durationMinutes: 5),
                StreamSegment(name: "Corporate Prayer", scriptureReference: "", durationMinutes: 20),
                StreamSegment(name: "Thanksgiving", scriptureReference: "", durationMinutes: 5)
            ]
        ),
        LiveStreamTemplate(
            name: "Worship Night", icon: "music.note.list", color: .pink,
            title: "Worship Night", description: "An evening of praise, worship, and God's presence.",
            category: "Worship", tags: ["Worship", "Praise", "Music"],
            suggestedSegments: [
                StreamSegment(name: "Worship Set 1", scriptureReference: "", durationMinutes: 20),
                StreamSegment(name: "Devotional Word", scriptureReference: "", durationMinutes: 10),
                StreamSegment(name: "Worship Set 2", scriptureReference: "", durationMinutes: 20),
                StreamSegment(name: "Prayer & Close", scriptureReference: "", durationMinutes: 10)
            ]
        )
    ]
}

// MARK: - Wall Prayer Request (Feature 1)

struct WallPrayerRequest: Identifiable {
    let id: String
    let text: String
    let authorName: String
    var isPinned: Bool
}

@available(iOS 17.0, *)
struct LiveSessionsView: View {
    @Query(sort: [SortDescriptor(\LiveSession.startTime, order: .reverse)]) var allSessions: [LiveSession]
    @Query(sort: [SortDescriptor(\LiveSessionParticipant.joinedAt, order: .reverse)]) var allParticipants: [LiveSessionParticipant]
    @Query(sort: [SortDescriptor(\SessionInvitation.createdAt, order: .reverse)]) var allInvitations: [SessionInvitation]
    @Query var allMessages: [ChatMessage]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    // CloudKitPublicSyncService removed - use Firebase for sync in the future
    // @State private var syncService: CloudKitPublicSyncService?
    @State private var showingCreateSession = false
    @State private var selectedSession: LiveSession?
    /// Tap a session card → open stream directly. Nil when stream is dismissed.
    @State private var sessionToStream: LiveSession?
    @State private var pendingDeleteSessionId: UUID?
    @State private var pendingDeleteHostId: String?
    @State private var pendingDeleteIsHost: Bool = false
    @State private var showingSessionDetail = false
    @State private var showingInvitations = false
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    @State private var selectedFilter: SessionFilter = .liveNow
    @State private var selectedSort: SessionSort = .recentlyStarted
    @State private var isLoadingPublicSessions = false
    @State private var publicSessions: [LiveSession] = []
    /// Forces list to re-render when a thumbnail is saved (so @Query shows updated thumbnailURL).
    @State private var thumbnailRefreshID = UUID()
    @State private var showingSampleReplay = false
    @State private var showingSortFilterHelp = false
    
    enum SessionFilter: String, CaseIterable {
        case liveNow = "Live Now"
        case upcoming = "Upcoming"
        case past = "Past"
        case replays = "Replays"
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
    
    // Combine local sessions + public sessions from Firestore (invited + all public non-private)
    var allSessionsCombined: [LiveSession] {
        var combined = allSessions
        // Add only sessions the user has received an invitation for
        let localIds = Set(combined.map { $0.id })
        for invitedSession in publicSessions {
            if !localIds.contains(invitedSession.id) {
                combined.append(invitedSession)
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
    
    /// Past sessions that have a replay (public sessions: no invite code needed to watch).
    var replaySessions: [LiveSession] {
        pastSessions.filter { session in
            guard let url = session.recordingURL, !url.isEmpty else { return false }
            return !url.hasPrefix("file://") // only cloud replays (watchable by anyone)
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
        case .replays:
            return replaySessions
        case .mySessions:
            return mySessions
        case .favorites:
            return favoriteSessions
        case .archived:
            return archivedSessions
        }
    }
    
    /// Predefined categories shown in the filter bar (matches create-session options + Worship).
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
                    .background(Color.platformSystemGray6)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Session filter dropdown (Live Now, Upcoming, Past, Replays…)
                    HStack {
                        Text("Show:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Show", selection: $selectedFilter) {
                            ForEach(SessionFilter.allCases, id: \.self) { filter in
                                Text("\(filter.rawValue) (\(filterCount(for: filter)))").tag(filter)
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.platformSystemGray6)
                    
                    // Category dropdown (same style as Sort)
                    if !categories.isEmpty {
                        HStack {
                            Text("Category:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(categories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.platformSystemGray6)
                    }
                    
                    // Sort Picker + Help
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
                        Button {
                            showingSortFilterHelp = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .alert("Live Sessions", isPresented: $showingSortFilterHelp) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Live Now: sessions currently in progress. Use the filter tabs to see Upcoming, Past, Replays, or My Sessions. Sort changes the order (e.g. Recently Started, Most Popular).")
                    }
                    
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
                        GeometryReader { geo in
                            // Adaptive grid: iPhone 1 col; iPad portrait 2 col; iPad landscape 3 col
                            let width = max(geo.size.width, 1)
                            let gridColumns: [GridItem] = horizontalSizeClass == .regular
                                ? (width >= 900
                                    ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                                    : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)])
                                : [GridItem(.flexible(), spacing: 12)]
                            
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 16) {
                                    // Live Now Section (if applicable)
                                    if selectedFilter == .liveNow && !liveNowSessions.isEmpty {
                                        LiveNowSectionHeader(count: liveNowSessions.count)
                                        
                                        LazyVGrid(columns: gridColumns, spacing: 12) {
                                            ForEach(liveNowSessions.prefix(6)) { session in
                                                EnhancedLiveSessionCard(session: session, onTap: {
                                                    if !session.isArchived { sessionToStream = session }
                                                }, onInfo: { selectedSession = session }, onRemove: { removeSessionFromList(session) })
                                                    .id(session.id.uuidString + (session.thumbnailURL ?? ""))
                                            }
                                        }
                                    }
                                    
                                    // Main Session Grid (when Live Now is shown, skip already-shown to avoid duplicates)
                                    let sessionsToShow = selectedFilter == .liveNow && !liveNowSessions.isEmpty
                                        ? Array(filteredSessions.dropFirst(min(6, liveNowSessions.count)))
                                        : filteredSessions
                                    if selectedFilter == .replays {
                                        Text("Public replays — no invite code needed")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Button(action: { showingSampleReplay = true }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: "play.rectangle.fill")
                                                    .font(.title)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Try sample replay")
                                                        .font(.headline)
                                                    Text("Play a short sample video to try the replay player")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                            }
                                            .padding()
                                            .background(Color.purple.opacity(0.15))
                                            .foregroundColor(.primary)
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    if !sessionsToShow.isEmpty {
                                        if selectedFilter == .liveNow && !liveNowSessions.isEmpty {
                                            SectionHeader(title: "All Sessions", count: sessionsToShow.count)
                                        }
                                        if selectedFilter == .replays {
                                            SectionHeader(title: "Replays", count: sessionsToShow.count)
                                        }
                                        LazyVGrid(columns: gridColumns, spacing: 12) {
                                            ForEach(sessionsToShow) { session in
                                                EnhancedLiveSessionCard(session: session, onTap: {
                                                    if !session.isArchived { sessionToStream = session }
                                                }, onInfo: { selectedSession = session }, onRemove: { removeSessionFromList(session) })
                                                    .id(session.id.uuidString + (session.thumbnailURL ?? ""))
                                            }
                                        }
                                    }
                                }
                                .id(thumbnailRefreshID)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(minHeight: 0)
                    }
                }
                }
                .onReceive(NotificationCenter.default.publisher(for: liveSessionThumbnailDidSaveNotification)) { _ in
                    thumbnailRefreshID = UUID()
                }
                .navigationTitle("Live Sessions")
                #if os(iOS)
                .navigationViewStyle(.stack)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
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
                    
                    ToolbarItem(placement: .automatic) {
                        Button(action: {
                            Task { await refreshPublicSessions() }
                        }) {
                            if isLoadingPublicSessions {
                                ProgressView()
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .disabled(isLoadingPublicSessions)
                        .accessibilityLabel("Refresh live sessions")
                    }
                    ToolbarItem(placement: .automatic) {
                        Button(action: { showingCreateSession = true }) {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                .sheet(isPresented: $showingInvitations) {
                    InvitationsView()
                        .macOSSheetFrameStandard()
                }
                .sheet(isPresented: $showingCreateSession) {
                    CreateLiveSessionView()
                        .macOSSheetFrameForm()
                }
                .sheet(isPresented: $showingSampleReplay) {
                    RecordingPlayerView(recordingURL: sampleReplayVideoURL)
                        .macOSSheetFrameForm()
                }
                .sheet(item: $selectedSession, onDismiss: { performPendingSessionDelete() }) { session in
                    LiveSessionDetailView(
                        session: session,
                        onPrepareDelete: { id, hostId, isHost in
                            pendingDeleteSessionId = id
                            pendingDeleteHostId = hostId
                            pendingDeleteIsHost = isHost
                        },
                        onDeleted: { deletedId in
                            selectedSession = nil
                            publicSessions = publicSessions.filter { $0.id != deletedId }
                        }
                    )
                    .macOSSheetFrameLarge()
                }
                #if os(iOS)
                .fullScreenCover(item: $sessionToStream, onDismiss: { sessionToStream = nil }) { session in
                    if #available(iOS 17.0, *) {
                        MultiParticipantStreamView(session: session)
                    }
                }
                #endif
                #if os(macOS)
                .sheet(item: $sessionToStream, onDismiss: { sessionToStream = nil }) { session in
                    if #available(macOS 14.0, *) {
                        MultiParticipantStreamView(session: session)
                            .macOSSheetFrameLarge()
                    }
                }
                #endif
                .onAppear {
                    // Ensure CloudKit services are initialized before use
                    // Note: App works fully without CloudKit - this is optional for multi-user features
                    Task { @MainActor in
                        // CloudKitPublicSyncService removed - use Firebase for sync
                        // Sync service initialization removed
                        // Give services a moment to initialize
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        archiveOldSessionsIfNeeded()
                        loadPublicSessions()
                        setupSubscriptions()
                    }
                }
                .refreshable {
                    await refreshPublicSessions()
                }
        } else {
            Text("Live Sessions are only available on iOS 17+")
        }
    }
    
    /// Archives ended sessions older than 30 days so they only appear under "Archived".
    private func archiveOldSessionsIfNeeded() {
        let daysToKeepInPast = 30
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -daysToKeepInPast, to: Date()) else { return }
        var descriptor = FetchDescriptor<LiveSession>(predicate: #Predicate<LiveSession> { $0.endTime != nil && !$0.isArchived })
        descriptor.sortBy = [SortDescriptor(\.endTime, order: .forward)]
        guard let ended = try? modelContext.fetch(descriptor) else { return }
        var archivedCount = 0
        for session in ended {
            guard let end = session.endTime, end < cutoff else { continue }
            session.isArchived = true
            archivedCount += 1
        }
        if archivedCount > 0 {
            do {
                try modelContext.save()
                print("✅ Auto-archived \(archivedCount) session(s) older than \(daysToKeepInPast) days")
            } catch {
                print("❌ Auto-archive save failed: \(error)")
            }
        }
    }

    private func loadPublicSessions() {
        isLoadingPublicSessions = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s for invitations to load
            await loadInvitedAndPublicSessions()
            isLoadingPublicSessions = false
        }
    }
    
    /// Called by the refresh button and pull-to-refresh. Fetches from Firebase and updates the list.
    private func refreshPublicSessions() async {
        await MainActor.run { isLoadingPublicSessions = true }
        await loadInvitedAndPublicSessions()
        await MainActor.run { isLoadingPublicSessions = false }
    }
    
    /// Fetch invited sessions plus all public (non-private) live sessions from Firestore so they appear in Live Now.
    private func loadInvitedAndPublicSessions() async {
        let userId = userService.userIdentifier
        let invitedSessionIds = allInvitations
            .filter { $0.hostId != userId && !$0.isExpired }
            .map { $0.sessionId }
        
        var fetched: [LiveSession] = []
        for sessionId in invitedSessionIds {
            if let session = await FirebaseSyncService.shared.fetchLiveSessionPublic(sessionId: sessionId) {
                fetched.append(session)
            }
        }
        let invitedIds = Set(fetched.map { $0.id })
        let publicSessionsFromFirestore = await FirebaseSyncService.shared.fetchPublicSessions()
        for session in publicSessionsFromFirestore {
            if !invitedIds.contains(session.id) {
                fetched.append(session)
            }
        }
        
        await MainActor.run {
            self.publicSessions = fetched
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
        case .replays:
            return replaySessions.count
        case .mySessions:
            return mySessions.count
        case .favorites:
            return favoriteSessions.count
        case .archived:
            return archivedSessions.count
        }
    }

    /// Called when the session detail sheet is dismissed; performs delete if user confirmed delete (avoids SwiftData fault crash).
    private func performPendingSessionDelete() {
        guard let sessionId = pendingDeleteSessionId, let hostId = pendingDeleteHostId else { return }
        let isHostDeletion = pendingDeleteIsHost
        pendingDeleteSessionId = nil
        pendingDeleteHostId = nil
        pendingDeleteIsHost = false

        // Defer delete so the sheet view is fully gone and no longer holds the session (avoids "detached without resolving attribute faults" on .tags, .relatedResources, etc.)
        let ctx = modelContext
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000) // 0.35s
            guard let session = (try? ctx.fetch(FetchDescriptor<LiveSession>(predicate: #Predicate<LiveSession> { $0.id == sessionId })))?.first else { return }
            if isHostDeletion {
                for inv in (try? ctx.fetch(FetchDescriptor<SessionInvitation>()))?.filter({ $0.sessionId == sessionId }) ?? [] { ctx.delete(inv) }
                for p in (try? ctx.fetch(FetchDescriptor<LiveSessionParticipant>()))?.filter({ $0.sessionId == sessionId }) ?? [] { ctx.delete(p) }
            } else {
                if let me = (try? ctx.fetch(FetchDescriptor<LiveSessionParticipant>()))?.first(where: { $0.sessionId == sessionId && $0.userId == LocalUserService.shared.userIdentifier }) {
                    ctx.delete(me)
                }
            }
            for m in (try? ctx.fetch(FetchDescriptor<ChatMessage>()))?.filter({ $0.sessionId == sessionId }) ?? [] { ctx.delete(m) }
            ctx.delete(session)
            do {
                try ctx.save()
                if isHostDeletion {
                    await FirebaseSyncService.shared.deleteLiveSession(sessionId: sessionId, hostId: hostId)
                }
            } catch {
                print("Error deleting session: \(error)")
            }
        }
    }

    /// Remove or delete a session from the list. Hosts delete from Firebase; participants remove locally.
    /// Sessions can be local (SwiftData) or from publicSessions (Firebase-only); only local ones are deleted from context.
    private func removeSessionFromList(_ session: LiveSession) {
        let sessionId = session.id
        let isHost = session.hostId == userService.userIdentifier
        let isLocalSession = allSessions.contains { $0.id == sessionId }

        if isLocalSession {
            if isHost {
                let sessionParticipants = allParticipants.filter { $0.sessionId == sessionId }
                for participant in sessionParticipants {
                    modelContext.delete(participant)
                }
                let sessionInvitations = allInvitations.filter { $0.sessionId == sessionId }
                for invitation in sessionInvitations {
                    modelContext.delete(invitation)
                }
            } else {
                if let userParticipant = allParticipants.first(where: { $0.sessionId == sessionId && $0.userId == userService.userIdentifier }) {
                    modelContext.delete(userParticipant)
                }
            }

            let sessionMessages = allMessages.filter { $0.sessionId == sessionId }
            for message in sessionMessages {
                modelContext.delete(message)
            }

            modelContext.delete(session)

            do {
                try modelContext.save()
                if isHost {
                    Task { await FirebaseSyncService.shared.deleteLiveSession(session) }
                }
                // Remove from publicSessions so combined list updates immediately (assign new array so SwiftUI refreshes)
                publicSessions = publicSessions.filter { $0.id != sessionId }
            } catch {
                print("Error removing session: \(error)")
            }
        } else {
            // Session only in publicSessions (invited from Firebase) – remove from list and remove invitation so it doesn’t reappear
            publicSessions = publicSessions.filter { $0.id != sessionId }
            let invitationsToRemove = allInvitations.filter { $0.sessionId == sessionId }
            for invitation in invitationsToRemove {
                modelContext.delete(invitation)
            }
            try? modelContext.save()
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

/// "Live Now" section title with a red dot (SF Symbol so it never renders as "?").
private struct LiveNowSectionHeader: View {
    let count: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundColor(.red)
            Text("Live Now")
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
                    .fill(isSelected ? Color.purple : Color.platformSystemGray5)
            )
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, *)
struct EnhancedLiveSessionCard: View {
    let session: LiveSession
    let onTap: () -> Void
    var onInfo: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    @Query var userProfiles: [UserProfile]
    @State private var isFavorite = false

    private var userProfile: UserProfile? { userProfiles.first }

    var isHost: Bool {
        session.hostId == userService.userIdentifier
    }

    /// When current user is host, show profile name; otherwise session.hostName (never device name).
    private var hostDisplayName: String {
        liveSessionHostDisplayName(session: session, isHost: isHost, userProfile: userProfile)
    }
    
    /// Format session duration (e.g. "8 min, 49 sec" or "1 hr 5 min") for ended sessions.
    private func formatSessionDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        }
        if minutes > 0 {
            return "\(minutes) min, \(secs) sec"
        }
        return "\(secs) sec"
    }
    
    private var thumbnailPlaceholder: some View {
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
    }
    
    var body: some View {
        Button { onTap() } label: {
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
                                    thumbnailPlaceholder
                                case .empty:
                                    thumbnailPlaceholder
                                        .overlay(ProgressView())
                                @unknown default:
                                    thumbnailPlaceholder
                                }
                            }
                            .id(urlString)
                            .frame(height: 180)
                            .clipped()
                        } else {
                            thumbnailPlaceholder
                        }
                    }
                    .cornerRadius(12)
                    
                    // Top overlay: info button, status badges (LIVE/ENDED/etc), then favorite — single row to avoid overlap
                    HStack(alignment: .center, spacing: 8) {
                        if onInfo != nil {
                            Button(action: { onInfo?() }) {
                                Image(systemName: "info.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .buttonStyle(.plain)
                        }
                        
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
                        
                        if let url = session.recordingURL, !url.isEmpty, !url.hasPrefix("file://") {
                            HStack(spacing: 4) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.caption2)
                                Text("REPLAY")
                                    .font(.caption2)
                                    .font(.body.weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.9))
                            .cornerRadius(8)
                        }
                        
                        if session.isPrivate == true {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                Text("Private")
                                    .font(.caption2)
                                    .font(.body.weight(.bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.9))
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
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(8)
                                if session.isPrivate == true {
                                    HStack(spacing: 2) {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                        Text("Private")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                                }
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
                                
                                Text(formatSessionDuration(session.duration))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else if session.isActive && !isHost {
                            // Quick Join Button (if live)
                            Button { onTap() } label: {
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
                        } else if session.endTime != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.badge.checkmark.fill")
                                Text("Lasted \(formatSessionDuration(session.duration))")
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
                                    .background(Color.platformSystemGray5)
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
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let onRemove = onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label(isHost ? "Delete Session" : "Remove from My Sessions", systemImage: "trash")
                }
            }
        }
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
        Button { onTap() } label: {
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

                        if session.durationLimitMinutes > 0 {
                            Text("Time limit: \(session.durationLimitMinutes)m")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if session.hasWaitingRoom || session.waitingRoomEnabled {
                            Text("Waiting room")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if session.isRecurring {
                            Text("Recurring")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
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
                                .background(Color.platformSystemGray5)
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    Text((session.scheduledStartTime ?? session.startTime), style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.platformSystemBackground)
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
                        .fill(isSelected ? color : Color.platformSystemGray5)
                )
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, *)
/// Session type when creating: broadcast = 1 host + many viewers; conference = everyone on camera.
enum CreateSessionType: String, CaseIterable {
    case broadcast
    case conference
}

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
    /// For broadcast: max audience size (50–1000). For conference: not used.
    @State private var maxAudience: Int = 100
    /// Session type at create: broadcast = 1 host + many viewers; conference = everyone on camera.
    @State private var createSessionType: CreateSessionType = .broadcast
    @State private var tags = ""
    @State private var selectedTags: Set<String> = []
    @State private var manualTagInput = ""
    @State private var isPrivate = false
    @State private var scheduledDate: Date?
    @State private var enableReminders = true
    @State private var reminderMinutes: Int = 5
    @State private var addToCalendar = false
    @State private var durationLimitMinutes: Int = 30
    @State private var enableWaitingRoom: Bool = false
    /// Record this session when you go live (saved so broadcast view can start recording automatically).
    @AppStorage("recordNextSession") private var recordNextSession = false
    /// When true, replay is uploaded so everyone can watch; when false, replay stays on this device only.
    @AppStorage("uploadReplayToCloud") private var uploadReplayToCloud = false
    @State private var isRecurring: Bool = false
    @State private var recurrencePattern: String = "weekly"
    @State private var selectedThumbnailImage: PlatformImage?
    @State private var selectedThumbnailPreset: FaithThumbnailPreset?
    @State private var showingThumbnailPicker = false
    @State private var isCreating = false
    @State private var createErrorMessage: String?

    // Feature 4 – Templates
    @State private var selectedTemplate: LiveStreamTemplate? = nil

    // Feature 5 – Scheduled + Friend Notifications
    @State private var notifyAllFriends: Bool = true
    @State private var showingSchedulePicker = false

    // Feature 6 – Agenda & Checklist
    @State private var segments: [StreamSegment] = []
    @State private var newSegmentName = ""
    @State private var newSegmentRef = ""
    @State private var checklistDone: [String: Bool] = [
        "Microphone": false, "Camera": false, "Internet": false, "Bible": false, "Notes": false
    ]

    let categories = ["Prayer", "Bible Study", "Devotional", "Testimony", "Fellowship", "Worship", "Other"]
    let predefinedTags = ["Prayer", "Bible Study", "Fellowship", "Worship", "Testimony", "Encouragement", "Healing", "Praise", "Intercession", "Community"]
    let durationOptions: [Int] = [15, 30, 45, 60, 90, 0]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - use adaptive color for dark mode support
                Color.platformSystemBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        headerSection

                        // Feature 4 – Stream Templates
                        streamTemplatesCard

                        // Session Details Card
                        sessionDetailsCard

                        // Thumbnail (optional cover image)
                        thumbnailCard

                        // Category Selection Card
                        categoryCard

                        // Settings Cards
                        participantsCard

                        timeLimitCard

                        // Feature 5 – Schedule + Friend Notifications (always visible)
                        scheduleAndNotifyCard

                        if scheduledDate != nil {
                            recurringSessionCard
                        }

                        if enableReminders {
                            remindersCard
                        }

                        // Feature 6 – Segment Agenda
                        segmentAgendaCard

                        // Feature 6 – Pre-Stream Checklist
                        preStreamChecklistCard

                        // Privacy & Tags Card
                        privacyAndTagsCard

                        // Recording & Replay Card
                        recordingAndReplayCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Live Session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .onAppear {
                // Initialize selectedTags from tags string if it exists
                if !tags.isEmpty {
                    let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    selectedTags = Set(tagArray)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                        .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: { createSession() }) {
                        HStack(spacing: 6) {
                            if isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Create")
                            }
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
                    .disabled(title.isEmpty || details.isEmpty || isCreating)
                }
            }
            .alert("Could not create session", isPresented: Binding(get: { createErrorMessage != nil }, set: { if !$0 { createErrorMessage = nil } })) {
                Button("OK", role: .cancel) { createErrorMessage = nil }
            } message: {
                if let msg = createErrorMessage { Text(msg) }
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
                    .background(Color.platformTertiarySystemBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.platformSeparator, lineWidth: 0.5)
                    )
                
                ZStack(alignment: .topLeading) {
                    if details.isEmpty {
                        Text("Describe your session...")
                            .foregroundColor(Color.platformPlaceholderText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                        .foregroundColor(.primary)
                        .padding(4)
                        .background(Color.platformTertiarySystemBackground)
                        .cornerRadius(12)
                        .scrollContentBackground(.hidden)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.platformSeparator, lineWidth: 0.5)
                        )
                }
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
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
            Text("Add a cover image for your live session.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button(action: {
                selectedThumbnailPreset = nil
                showingThumbnailPicker = true
            }) {
                Group {
                    if let img = selectedThumbnailImage {
                        platformImage(img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.platformTertiarySystemBackground)
                            .frame(height: 160)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.title)
                                    Text("Tap to add from device")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.secondary)
                            )
                    }
                }
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.platformSeparator, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            Text("Or choose a faith-based preset:")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                HStack(spacing: 10) {
                    ForEach(FaithThumbnailPreset.allCases) { preset in
                        Button {
                            if let img = platformImageFromFaithPreset(preset, size: CGSize(width: 400, height: 224)) {
                                selectedThumbnailImage = img
                                selectedThumbnailPreset = preset
                            }
                        } label: {
                            presetThumbnailPreview(preset)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedThumbnailPreset == preset ? themeManager.colors.primary : Color.clear, lineWidth: 3)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 72)
            if selectedThumbnailImage != nil {
                Button("Remove thumbnail") {
                    selectedThumbnailImage = nil
                    selectedThumbnailPreset = nil
                }
                .font(.subheadline)
                .foregroundColor(themeManager.colors.primary)
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingThumbnailPicker) {
            #if os(iOS)
            ImagePicker(image: $selectedThumbnailImage)
                .macOSSheetFrameCompact()
            #elseif os(macOS)
            MacImagePicker(image: $selectedThumbnailImage)
                .macOSSheetFrameCompact()
            #endif
        }
    }
    
    @ViewBuilder
    private func presetThumbnailPreview(_ preset: FaithThumbnailPreset) -> some View {
        // Prefer bundled asset from catalog (SwiftUI Image loads from main bundle)
        Image(preset.assetImageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 100, height: 56)
            .clipped()
            .cornerRadius(10)
            .overlay(
                // Fallback gradient + symbol if asset failed to load (empty/small image)
                Group {
                    if platformBundledImageForFaithPreset(preset, size: CGSize(width: 2, height: 2)) == nil {
                        let (start, end) = faithPresetGradientColors(preset)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .overlay(
                                Image(systemName: preset.symbolName)
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .allowsHitTesting(false)
            )
    }
    
    private func faithPresetGradientColors(_ preset: FaithThumbnailPreset) -> (Color, Color) {
        switch preset {
        case .prayer: return (Color(red: 0.85, green: 0.65, blue: 0.2), Color(red: 0.6, green: 0.4, blue: 0.1))
        case .bible: return (Color(red: 0.2, green: 0.35, blue: 0.7), Color(red: 0.1, green: 0.2, blue: 0.5))
        case .cross: return (Color(red: 0.45, green: 0.25, blue: 0.65), Color(red: 0.3, green: 0.15, blue: 0.5))
        case .worship: return (Color(red: 0.9, green: 0.5, blue: 0.2), Color(red: 0.7, green: 0.3, blue: 0.1))
        case .peace: return (Color(red: 0.5, green: 0.75, blue: 0.9), Color(red: 0.3, green: 0.55, blue: 0.75))
        case .heart: return (Color(red: 0.85, green: 0.35, blue: 0.45), Color(red: 0.65, green: 0.2, blue: 0.35))
        case .community: return (Color(red: 0.2, green: 0.6, blue: 0.6), Color(red: 0.1, green: 0.45, blue: 0.5))
        case .hope: return (Color(red: 0.95, green: 0.8, blue: 0.25), Color(red: 0.85, green: 0.6, blue: 0.1))
        case .devotional: return (Color(red: 0.35, green: 0.3, blue: 0.65), Color(red: 0.2, green: 0.2, blue: 0.5))
        case .faith: return (Color(red: 0.6, green: 0.4, blue: 0.75), Color(red: 0.9, green: 0.7, blue: 0.2))
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
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private static let audienceOptions = [50, 100, 250, 500, 1000]
    
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
            
            // Session type: Broadcast (1 host + many viewers) vs Conference (everyone on camera)
            Picker("Session type", selection: $createSessionType) {
                Text("Broadcast (1 host, many viewers)").tag(CreateSessionType.broadcast)
                Text("Conference (everyone on camera)").tag(CreateSessionType.conference)
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.platformTertiarySystemBackground)
            .cornerRadius(12)
            
            if createSessionType == .broadcast {
                // Max audience size for broadcast: 50, 100, 250, 500, 1000
                HStack {
                    Text("Max audience size")
                        .foregroundColor(.primary)
                    Spacer()
                    Picker("Audience", selection: $maxAudience) {
                        ForEach(Self.audienceOptions, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 80)
                }
                .padding()
                .background(Color.platformTertiarySystemBackground)
                .cornerRadius(12)
                Text("One host streams; up to \(maxAudience) people can join as viewers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Conference: max participants 2–50
                HStack {
                    Text("Max participants")
                        .foregroundColor(.primary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: {
                            if maxParticipants > 2 { maxParticipants -= 1 }
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
                            if maxParticipants < 50 { maxParticipants += 1 }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(maxParticipants < 50 ? themeManager.colors.primary : .gray)
                                .font(.title3)
                        }
                        .disabled(maxParticipants >= 50)
                    }
                }
                .padding()
                .background(Color.platformTertiarySystemBackground)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var timeLimitCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Session Controls")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                Picker("Time Limit", selection: $durationLimitMinutes) {
                    ForEach(durationOptions, id: \.self) { option in
                        Text(option == 0 ? "No limit" : "\(option)m").tag(option)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color.platformTertiarySystemBackground)
                .cornerRadius(12)
                
                Toggle(isOn: $enableWaitingRoom) {
                    HStack {
                        Image(systemName: enableWaitingRoom ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark")
                            .foregroundColor(themeManager.colors.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Waiting Room")
                                .foregroundColor(.primary)
                            Text("Approve participants before they join")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(themeManager.colors.primary)
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var recurringSessionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "repeat")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Recurring")
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
                    Picker("Repeat Frequency", selection: $recurrencePattern) {
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
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
                    .background(Color.platformTertiarySystemBackground)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
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
                    .background(Color.platformTertiarySystemBackground)
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
        .background(Color.platformSecondarySystemBackground)
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
                            Text("Make session public or private")
                                .foregroundColor(.primary)
                            Text(isPrivate ? "Private: only invited users can join" : "Public: anyone with the link can join")
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
                            .background(Color.platformTertiarySystemBackground)
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
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var recordingAndReplayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Recording & Replay")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Text("Record this session and optionally save a replay so others can watch later.")
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(spacing: 12) {
                Toggle(isOn: $recordNextSession) {
                    HStack {
                        Image(systemName: "record.circle")
                            .foregroundColor(themeManager.colors.primary)
                        Text("Record this session")
                            .foregroundColor(.primary)
                    }
                }
                .tint(themeManager.colors.primary)
                Toggle(isOn: $uploadReplayToCloud) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(themeManager.colors.primary)
                            Text("Upload replay (share with everyone)")
                                .foregroundColor(.primary)
                        }
                        Text("Off = replay only on your device. On = anyone can watch later.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(themeManager.colors.primary)
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: – Feature 4: Stream Templates Card

    private var streamTemplatesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Quick Start Templates")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if selectedTemplate != nil {
                    Button("Clear") { selectedTemplate = nil }
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("Tap a template to pre-fill session details and build a segment agenda.")
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LiveStreamTemplate.all) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedTemplate?.id == template.id
                                              ? template.color
                                              : template.color.opacity(0.15))
                                        .frame(width: 80, height: 64)
                                    Image(systemName: template.icon)
                                        .font(.title2)
                                        .foregroundColor(selectedTemplate?.id == template.id ? .white : template.color)
                                }
                                Text(template.name)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 80)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func applyTemplate(_ template: LiveStreamTemplate) {
        selectedTemplate = template
        title = template.title
        details = template.description
        category = template.category
        selectedTags = Set(template.tags)
        updateTagsString()
        segments = template.suggestedSegments
    }

    // MARK: – Feature 5: Schedule + Friend Notifications Card

    private var scheduleAndNotifyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Schedule & Notifications")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            VStack(spacing: 12) {
                // Schedule toggle
                Toggle(isOn: Binding(
                    get: { scheduledDate != nil },
                    set: { on in scheduledDate = on ? Calendar.current.date(byAdding: .hour, value: 1, to: Date()) : nil }
                )) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(themeManager.colors.primary)
                        Text("Schedule for later")
                            .foregroundColor(.primary)
                    }
                }
                .tint(themeManager.colors.primary)

                if let scheduled = scheduledDate {
                    DatePicker("Start Time", selection: Binding(
                        get: { scheduled },
                        set: { scheduledDate = $0 }
                    ), in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .tint(themeManager.colors.primary)
                }

                Divider()

                // Reminder toggle
                Toggle(isOn: $enableReminders) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(themeManager.colors.primary)
                        Text("Remind me before it starts")
                            .foregroundColor(.primary)
                    }
                }
                .tint(themeManager.colors.primary)

                if enableReminders {
                    Picker("Remind me", selection: $reminderMinutes) {
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // Friend notifications
                Toggle(isOn: $notifyAllFriends) {
                    HStack {
                        Image(systemName: "person.wave.2.fill")
                            .foregroundColor(themeManager.colors.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notify Faith Friends")
                                .foregroundColor(.primary)
                            Text("All connected friends get an alert when you go live")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(themeManager.colors.primary)
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: – Feature 6: Segment Agenda Card

    private var segmentAgendaCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .foregroundColor(themeManager.colors.primary)
                    .font(.title3)
                Text("Session Agenda")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if !segments.isEmpty {
                    Text("\(segments.count) segment\(segments.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("Add named segments so viewers see a live \"Now:\" tracker during the stream.")
                .font(.caption)
                .foregroundColor(.secondary)

            if !segments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(segments) { seg in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(seg.name)
                                    .font(.subheadline.weight(.medium))
                                if !seg.scriptureReference.isEmpty {
                                    Text(seg.scriptureReference)
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                            }
                            Spacer()
                            if seg.durationMinutes > 0 {
                                Text("\(seg.durationMinutes)m")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Button {
                                segments.removeAll { $0.id == seg.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.platformTertiarySystemBackground)
                        .cornerRadius(8)
                    }
                }
            }

            // Add segment row
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Segment name (e.g. Worship)", text: $newSegmentName)
                        .font(.subheadline)
                        .padding(10)
                        .background(Color.platformTertiarySystemBackground)
                        .cornerRadius(8)
                    Button {
                        addSegment()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(newSegmentName.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? .secondary : themeManager.colors.primary)
                    }
                    .disabled(newSegmentName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                TextField("Scripture (optional, e.g. Psalm 23)", text: $newSegmentRef)
                    .font(.caption)
                    .padding(10)
                    .background(Color.platformTertiarySystemBackground)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: – Feature 6: Pre-Stream Checklist Card

    private var preStreamChecklistCard: some View {
        let items = ["Microphone", "Camera", "Internet", "Bible", "Notes"]
        let doneCount = items.filter { checklistDone[$0] == true }.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(doneCount == items.count ? .green : themeManager.colors.primary)
                    .font(.title3)
                Text("Pre-Stream Checklist")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(doneCount)/\(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(doneCount == items.count ? .green : .secondary)
            }
            ForEach(items, id: \.self) { item in
                Button {
                    checklistDone[item] = !(checklistDone[item] ?? false)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: checklistDone[item] == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(checklistDone[item] == true ? .green : .secondary)
                            .font(.title3)
                        Text(checklistItem(item))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            if doneCount == items.count {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("You're all set to go live!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.platformSecondarySystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func checklistItem(_ key: String) -> String {
        switch key {
        case "Microphone": return "Microphone is working"
        case "Camera": return "Camera is working"
        case "Internet": return "Internet connection is stable"
        case "Bible": return "Bible is open / passage ready"
        case "Notes": return "Notes / outline are prepared"
        default: return key
        }
    }

    private func addSegment() {
        let name = newSegmentName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        segments.append(StreamSegment(name: name, scriptureReference: newSegmentRef.trimmingCharacters(in: .whitespaces)))
        newSegmentName = ""
        newSegmentRef = ""
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
        isCreating = true
        createErrorMessage = nil
        
        let tagArray = Array(selectedTags)
        let userId = userService.userIdentifier
        // Prefer profile name; never persist device name (store "Host" if only device name available)
        let pmName = ProfileManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileName = (userProfile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = !pmName.isEmpty ? pmName : (!profileName.isEmpty ? profileName : userService.getDisplayName(userProfile: userProfile))
        let nameToStore = isDeviceName(candidate) ? "Host" : candidate
        
        // Broadcast: host + up to maxAudience viewers. Conference: up to maxParticipants (2–50).
        let effectiveMax = createSessionType == .broadcast ? (1 + maxAudience) : maxParticipants
        let session = LiveSession(
            title: title,
            description: details,
            hostId: userId,
            category: category,
            maxParticipants: effectiveMax,
            tags: tagArray
        )
        session.isPrivate = isPrivate
        session.hostName = nameToStore
        session.streamMode = (createSessionType == .broadcast ? StreamMode.broadcast : StreamMode.conference).rawValue
        session.durationLimitMinutes = durationLimitMinutes
        session.waitingRoomEnabled = enableWaitingRoom
        session.hasWaitingRoom = enableWaitingRoom
        session.isRecurring = isRecurring
        session.recurrencePattern = isRecurring ? recurrencePattern : ""
        if !segments.isEmpty {
            session.segmentsData = try? JSONEncoder().encode(segments)
        }
        if let scheduled = scheduledDate {
            session.scheduledStartTime = scheduled
            session.isActive = false
        }
        
        modelContext.insert(session)
        
        // Create participant entry for host
        let participant = LiveSessionParticipant(
            sessionId: session.id,
            userId: userId,
            userName: nameToStore,
            isHost: true
        )
        participant.userAvatarURL = userProfile?.avatarPhotoURL ?? ProfileManager.shared.profileImageURL
        modelContext.insert(participant)
        
        do {
            try modelContext.save()

            // Create and sync invite code immediately so it's in Firebase before the host shares it.
            let code = String(UUID().uuidString.prefix(8).uppercased())
            let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
            let invitation = SessionInvitation(
                sessionId: session.id,
                sessionTitle: session.title,
                hostId: userId,
                hostName: nameToStore,
                inviteCode: code,
                expiresAt: expirationDate
            )
            modelContext.insert(invitation)
            try modelContext.save()

            // Persist thumbnail to disk and to the session BEFORE dismiss so it survives app close. Then upload to Firebase in background.
            let sessionId = session.id
            let thumbImage = selectedThumbnailImage
            let isPrivateSession = session.isPrivate
            let ctx = modelContext
            let canUseFirebase = FirebaseInitializer.shared.isConfigured
            if let image = thumbImage, let localURL = ProfileManager.shared.saveLiveSessionThumbnailToLocalSync(sessionId: sessionId, image: image) {
                session.thumbnailURL = localURL
                try? ctx.save()
                NotificationCenter.default.post(name: liveSessionThumbnailDidSaveNotification, object: nil)
            }

            // Dismiss immediately so the user sees the sheet close and the new session in the list.
            isCreating = false
            dismiss()

            // Background: sync public session to Firebase, then upload thumbnail and update to https when done.
            Task {
                if !isPrivateSession {
                    await FirebaseSyncService.shared.syncLiveSessionPublic(session)
                    await FirebaseSyncService.shared.syncSessionInvitation(invitation)
                }
                var sessionToSync: LiveSession? = session
                if let image = thumbImage, canUseFirebase, let jpegData = platformImageToJPEGData(image, quality: 0.85) {
                    do {
                        let httpsURL = try await FirebaseSyncService.shared.uploadLiveSessionThumbnail(sessionId: sessionId, imageData: jpegData)
                        await MainActor.run {
                            var descriptor = FetchDescriptor<LiveSession>()
                            descriptor.predicate = #Predicate<LiveSession> { $0.id == sessionId }
                            if let fetched = try? ctx.fetch(descriptor).first {
                                fetched.thumbnailURL = httpsURL
                                try? ctx.save()
                                sessionToSync = fetched
                            }
                            FirebaseSyncService.shared.saveThumbnailURL(sessionId: sessionId, urlString: httpsURL)
                            NotificationCenter.default.post(name: liveSessionThumbnailDidSaveNotification, object: nil)
                        }
                        print("✅ [LIVE SESSION] Thumbnail uploaded to Firebase: \(httpsURL.prefix(60))...")
                    } catch {
                        let ns = error as NSError
                        if ns.domain == "FirebaseSyncService", ns.code == 401 {
                            print("ℹ️ [LIVE SESSION] \(ns.localizedDescription)")
                        } else {
                            print("⚠️ [LIVE SESSION] Firebase thumbnail upload failed; local thumbnail already saved: \(FirebaseSyncService.formatFirebaseStorageError(error))")
                        }
                    }
                }
                if !isPrivateSession, let toSync = sessionToSync, toSync.thumbnailURL != nil, toSync.thumbnailURL?.hasPrefix("https") == true {
                    await FirebaseSyncService.shared.syncLiveSessionPublic(toSync)
                }
            }
            
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
        } catch {
            isCreating = false
            createErrorMessage = error.localizedDescription
            print("Error creating session: \(error)")
        }
    }
}

@available(iOS 17.0, *)
struct LiveSessionDetailView: View {
    let session: LiveSession
    /// Called before dismiss so parent can perform delete in sheet onDismiss (avoids accessing deleted session).
    var onPrepareDelete: ((UUID, String, Bool) -> Void)? = nil
    var onDeleted: ((UUID) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var participants: [LiveSessionParticipant]
    @Query var invitations: [SessionInvitation]
    @Query var userProfiles: [UserProfile]
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
    @Query var messages: [ChatMessage]

    // Feature 1 – Prayer Wall
    @State private var wallRequests: [WallPrayerRequest] = []
    @State private var wallListener: Any? = nil
    @State private var pinnedRequestId: String? = nil
    @State private var showingPrayerWallSubmit = false
    @State private var prayerWallText = ""

    // Feature 2 – Scripture Overlay
    @State private var scriptureOverlay: (reference: String, text: String)? = nil
    @State private var scriptureListener: Any? = nil
    @State private var showingScriptureOverlayPicker = false

    // Feature 3 – Amen Moments + Reactions
    @State private var amenMoments: [Date] = []
    @State private var showingReactionBar = false
    @State private var currentSegmentIndex: Int = 0
    
    private var streamModeDescription: String {
        switch streamMode {
        case .broadcast:
            return "One host streams to viewers. Viewers watch and can chat; no video from participants."
        case .conference:
            return "Everyone can turn on camera and mic. See and hear all participants in real time."
        case .multiParticipant:
            return "Same as Conference: all participants can share video and audio in the session."
        }
    }
    
    var shareText: String {
        """
        Join me for a live session: \(session.title)

        \(session.details)

        Category: \(session.category)
        Participants: \(uniqueParticipantCount)/\(session.maxParticipants)
        """
    }

    /// Present chat sheet with a short delay so nested sheet-from-sheet works on macOS (and avoids flakiness on iOS).
    private func presentChat() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            showingChat = true
        }
    }
    
    var sessionParticipants: [LiveSessionParticipant] {
        participants.filter { $0.sessionId == session.id && $0.isActive }
    }
    
    /// Actual unique participant count (use for display so we never show 3 when only 2 people).
    private var uniqueParticipantCount: Int {
        Set(sessionParticipants.map { $0.userId }).count
    }
    
    var canJoin: Bool {
        !session.isArchived && session.isActive && uniqueParticipantCount < session.maxParticipants
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
                }
            )
    }
    
    var isHost: Bool {
        // Safely check if current user is host
        let userId = userService.userIdentifier
        return session.hostId == userId
    }
    
    var sessionInvitations: [SessionInvitation] {
        invitations.filter { $0.sessionId == session.id }
    }

    /// Display name for the host: when current user is host, use profile name; otherwise use stored hostName (never device name).
    var hostDisplayName: String {
        liveSessionHostDisplayName(session: session, isHost: isHost, userProfile: userProfile)
    }
    
    /// Display name for a chat message author: profile name when it's the current user, otherwise stored name or "Participant".
    private func messageAuthorDisplayName(_ message: ChatMessage) -> String {
        if message.userId == userService.userIdentifier {
            return profileDisplayNameForCurrentUser(userProfile: userProfile, userService: userService)
        }
        return isDeviceName(message.userName) ? "Participant" : message.userName
    }
    
    var primaryInviteCode: String? {
        sessionInvitations.first(where: { $0.status == .pending })?.inviteCode ??
        sessionInvitations.first?.inviteCode
    }

    var body: some View {
        detailViewContent
    }

    private var detailViewNavigation: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                // On macOS, constrain ScrollView to available height so content actually scrolls in the sheet.
                GeometryReader { geo in
                    ScrollView {
                        detailScrollContent
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #else
                ScrollView {
                    detailScrollContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #endif
            }
            .navigationTitle("Session Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label(isHost ? "Delete Session" : "Remove from My Sessions", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(isHost ? "Delete Session" : "Remove Session", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button(isHost ? "Delete" : "Remove", role: .destructive) {
                    deleteSession()
                }
            } message: {
                Text(isHost
                    ? "Are you sure you want to delete this session? This action cannot be undone. All participants, messages, and recordings associated with this session will be removed."
                    : "Remove this session from your list? This will only remove it from your device and won't affect the host or other participants.")
            }
            .alert("Archive Session", isPresented: $showingArchiveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Archive") {
                    archiveSession()
                }
            } message: {
                Text("Archive this session? Archived sessions will be moved to the Archived section and hidden from your main session list. You can unarchive it later if needed.")
            }
        }
    }

    // MARK: – Feature 1: Prayer Wall Section

    private var prayerWallSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hands.sparkles.fill")
                    .foregroundColor(.orange)
                Text("Prayer Wall")
                    .font(.headline)
                Spacer()
                Button {
                    prayerWallText = ""
                    showingPrayerWallSubmit = true
                } label: {
                    Label("Submit", systemImage: "plus.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if wallRequests.isEmpty {
                Text("No prayer requests yet. Be the first to share.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(wallRequests) { req in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: req.isPinned ? "hands.sparkles.fill" : "person.crop.circle")
                            .foregroundColor(req.isPinned ? .orange : .secondary)
                            .font(req.isPinned ? .title3 : .body)

                        VStack(alignment: .leading, spacing: 4) {
                            if req.isPinned {
                                Text("LIFTED UP")
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(.orange)
                            }
                            Text(req.text)
                                .font(.subheadline)
                            Text("— \(req.authorName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if isHost {
                            Button {
                                let newPinned = !req.isPinned
                                pinnedRequestId = newPinned ? req.id : nil
                                Task { await FirebaseSyncService.shared.setPrayerWallPinned(
                                    sessionId: session.id, requestId: req.id, pinned: newPinned) }
                            } label: {
                                Image(systemName: req.isPinned ? "pin.slash" : "pin.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(10)
                    .background(req.isPinned
                                ? Color.orange.opacity(0.1)
                                : Color.platformSystemGray6)
                    .cornerRadius(10)
                    .overlay(
                        req.isPinned
                        ? RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        : nil
                    )
                }
            }
        }
        .padding()
        .background(Color.platformSystemGray6)
        .cornerRadius(12)
        .sheet(isPresented: $showingPrayerWallSubmit) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Share what's on your heart and let the group intercede with you.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    TextEditor(text: $prayerWallText)
                        .frame(height: 160)
                        .padding(8)
                        .background(Color.platformSystemGray6)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    Button {
                        let name = profileDisplayNameForCurrentUser(userProfile: userProfile, userService: userService)
                        Task { await FirebaseSyncService.shared.submitPrayerWallRequest(
                            sessionId: session.id, text: prayerWallText, authorName: name) }
                        showingPrayerWallSubmit = false
                    } label: {
                        Text("Submit Prayer Request")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .disabled(prayerWallText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal)
                }
                .navigationTitle("Prayer Request")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingPrayerWallSubmit = false } } }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: – Feature 2: Scripture Overlay Card

    @ViewBuilder
    private func scriptureOverlayCard(_ overlay: (reference: String, text: String)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(.purple)
                Text("Scripture")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.purple)
                Spacer()
                if isHost {
                    Button {
                        Task { await FirebaseSyncService.shared.dismissScriptureOverlay(sessionId: session.id) }
                        withAnimation { scriptureOverlay = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            Text(overlay.reference)
                .font(.title3.weight(.bold))
                .foregroundColor(.purple)
            Text(overlay.text)
                .font(.body)
                .lineSpacing(5)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(10)

            Button {
                let verse = BookmarkedVerse(
                    verseReference: overlay.reference,
                    verseText: overlay.text,
                    translation: "KJV",
                    sessionId: session.id,
                    sessionTitle: session.title
                )
                modelContext.insert(verse)
                try? modelContext.save()
                Task { await FirebaseSyncService.shared.syncBookmarkedVerse(verse) }
            } label: {
                Label("Save to Bookmarks", systemImage: "bookmark.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.purple)
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [Color.purple.opacity(0.12), Color.purple.opacity(0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.purple.opacity(0.3), lineWidth: 1))
        .sheet(isPresented: $showingScriptureOverlayPicker) {
            BibleVerseChatPicker { reference, text in
                Task { await FirebaseSyncService.shared.pushScriptureOverlay(
                    sessionId: session.id, reference: reference, text: text) }
                withAnimation { scriptureOverlay = (reference, text) }
                showingScriptureOverlayPicker = false
            }
            .presentationDetents([.large])
        }
    }

    // MARK: – Feature 3: Reactions + Amen Moments Section

    private var reactionAndAmenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Agenda tracker (current segment)
            let sessionSegments: [StreamSegment] = {
                guard let data = session.segmentsData else { return [] }
                return (try? JSONDecoder().decode([StreamSegment].self, from: data)) ?? []
            }()
            if !sessionSegments.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.purple)
                    Text("Now: \(sessionSegments[min(currentSegmentIndex, sessionSegments.count - 1)].name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.purple)
                    Spacer()
                    if isHost && currentSegmentIndex < sessionSegments.count - 1 {
                        Button("Next →") {
                            withAnimation { currentSegmentIndex += 1 }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }

            // Reaction emoji row
            HStack(spacing: 0) {
                ForEach([("🙏", "Praying"), ("❤️", "Love"), ("✝️", "Amen"), ("🔥", "Fire")], id: \.0) { emoji, _ in
                    Button {
                        sendReaction(emoji)
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.platformSystemGray6)
                    }
                    .buttonStyle(.plain)
                }

                // Amen Moment button (host only)
                if isHost {
                    Button {
                        recordAmenMoment()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Amen")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.yellow)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.15))
                    }
                    .buttonStyle(.plain)
                }

                // Scripture push (host only)
                if isHost {
                    Button {
                        showingScriptureOverlayPicker = true
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "book.fill")
                                .foregroundColor(.blue)
                            Text("Verse")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.platformSeparator, lineWidth: 0.5))

            // Amen moment history
            if !amenMoments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Amen Moments (\(amenMoments.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(amenMoments.enumerated()), id: \.offset) { idx, ts in
                                Text("⭐ \(ts, style: .time)")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.platformSystemGray6)
        .cornerRadius(12)
    }

    private func removeStreamListeners() {
        #if canImport(FirebaseFirestore)
        FirebaseSyncService.shared.removeListener(wallListener)
        FirebaseSyncService.shared.removeListener(scriptureListener)
        #endif
        wallListener = nil
        scriptureListener = nil
    }

    private func sendReaction(_ emoji: String) {
        session.reactionCount += 1
        try? modelContext.save()
    }

    private func recordAmenMoment() {
        amenMoments.append(Date())
        let intervals = amenMoments.map { $0.timeIntervalSince1970 }
        session.amenMomentsData = try? JSONEncoder().encode(intervals)
        try? modelContext.save()
    }

    private var detailViewContent: some View {
        detailViewNavigation
            .sheet(isPresented: $showingChat) {
                LiveSessionChatView(session: session, canSend: hasJoined || isHost)
                    .macOSSheetFrameForm()
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(activityItems: [shareText])
                    .macOSSheetFrameCompact()
            }
            .sheet(isPresented: $showingInviteUsers) {
                InviteUsersView(session: session)
                    .macOSSheetFrameStandard()
            }
            .sheet(isPresented: $showingInviteCode) {
                InviteCodeView(session: session)
                    .macOSSheetFrameCompact()
            }
            #if os(iOS)
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
                    // .id(session.id helps prevent view replacement on re-render so connect isn’t cancelled (Code=100).
                    MultiParticipantStreamView(session: session)
                        .id(session.id)
                }
            }
            #else
            .sheet(isPresented: $showingLiveStream) {
                LiveStreamView(session: session)
                    .macOSSheetFrameForm()
            }
            .sheet(isPresented: $showingBroadcastStream) {
                if #available(macOS 14.0, *) {
                    BroadcastStreamView_HLS(session: session)
                        .macOSSheetFrameForm()
                }
            }
            .sheet(isPresented: $showingMultiParticipantStream) {
                if #available(macOS 14.0, *) {
                    MultiParticipantStreamView(session: session)
                        .id(session.id)
                        .macOSSheetFrameForm()
                }
            }
            #endif
            .sheet(isPresented: $showingHostProfile) {
                HostProfileView(session: session, hostDisplayName: hostDisplayName)
                    .macOSSheetFrameStandard()
            }
            .sheet(isPresented: $showingAgenda) {
                AgendaView(agenda: session.agenda)
                    .macOSSheetFrameStandard()
            }
            .sheet(isPresented: $showingAnalytics) {
                SessionAnalyticsView(session: session)
                    .macOSSheetFrameStandard()
            }
            .sheet(isPresented: $showingRecording) {
                if let url = session.recordingURL, !url.isEmpty {
                    RecordingPlayerView(recordingURL: url)
                        .macOSSheetFrameForm()
                }
            }
            .sheet(isPresented: $showingWaitingRoom) {
                WaitingRoomView(session: session)
                    .macOSSheetFrameForm()
            }
            .sheet(isPresented: $showingClips) {
                SessionClipsView(session: session)
                    .macOSSheetFrameStandard()
            }
            .onAppear {
                checkJoinStatus()
                streamMode = session.typedStreamMode
                if isHost && primaryInviteCode == nil {
                    generateInviteCodeIfNeeded()
                }
                reconcileParticipantCount()

                // Restore amen moments from model
                if let data = session.amenMomentsData,
                   let intervals = try? JSONDecoder().decode([TimeInterval].self, from: data) {
                    amenMoments = intervals.map { Date(timeIntervalSince1970: $0) }
                }

                // Feature 1 – live prayer wall listener
                wallListener = FirebaseSyncService.shared.listenForPrayerWall(sessionId: session.id) { docs in
                    wallRequests = docs.compactMap { d -> WallPrayerRequest? in
                        guard let id = d["id"] as? String, let text = d["text"] as? String else { return nil }
                        let author = d["authorName"] as? String ?? "Anonymous"
                        let pinned = d["isPinned"] as? Bool ?? false
                        return WallPrayerRequest(id: id, text: text, authorName: author, isPinned: pinned)
                    }
                    pinnedRequestId = wallRequests.first(where: { $0.isPinned })?.id
                }

                // Feature 2 – live scripture overlay listener
                scriptureListener = FirebaseSyncService.shared.listenForScriptureOverlay(sessionId: session.id) { data in
                    if let data, let ref = data["reference"] as? String, let text = data["text"] as? String {
                        withAnimation { scriptureOverlay = (ref, text) }
                    } else {
                        withAnimation { scriptureOverlay = nil }
                    }
                }
            }
            .onDisappear {
                removeStreamListeners()
            }
            .onChange(of: participants.count) { _, _ in
                // Don’t run participant sync while the stream is open — it triggers modelContext.save() and parent re-renders that can replace the stream view and cancel the connection (Code 100).
                if showingMultiParticipantStream { return }
                checkJoinStatus()
                reconcileParticipantCount()
            }
    }
    
    private var detailScrollContent: some View {
        VStack(alignment: .leading, spacing: 24) {
                    // Cover image (custom thumbnail or placeholder)
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
                        } else {
                            sessionDetailThumbnailPlaceholder
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.platformSeparator, lineWidth: 0.5)
                    )
                    
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
                            if session.isPrivate == true {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                    Text("Private")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                            }
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
                                    Text(hostDisplayName)
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
                            .background(Color.platformSystemGray6)
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
                        .background(Color.platformSystemGray6)
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
                        .background(Color.platformSystemGray6)
                        .cornerRadius(12)
                    }
                    
                    // Participants with enhanced features
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Participants (\(uniqueParticipantCount)/\(session.maxParticipants))")
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
                            ScrollView(.horizontal, showsIndicators: PlatformScroll.horizontalShowsIndicators) {
                                HStack(spacing: 12) {
                                    ForEach(sessionParticipants) { participant in
                                        EnhancedParticipantBadge(
                                            participant: participant,
                                            isHost: isHost,
                                            displayNameOverride: participant.isHost ? hostDisplayName : nil,
                                            currentUserId: userService.userIdentifier,
                                            currentUserDisplayName: profileDisplayNameForCurrentUser(userProfile: userProfile, userService: userService),
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
                                    Button(action: presentChat) {
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
                                            Text(messageAuthorDisplayName(message))
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
                            .background(Color.platformSystemGray6)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Feature 2 – Scripture Overlay Banner
                    if let overlay = scriptureOverlay {
                        scriptureOverlayCard(overlay)
                    }

                    // Feature 1 – Prayer Wall
                    if session.isActive {
                        prayerWallSection
                    }

                    // Feature 3 – Reactions + Amen Moments + Agenda Tracker
                    if session.isActive && (hasJoined || isHost) {
                        reactionAndAmenSection
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
                                            .background(Color.platformSystemGray5)
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
                                        PlatformPasteboard.setString(code)
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
                    VStack(spacing: 10) {
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
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 14)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.red, Color.orange]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(10)
                                    }
                                    
                                    // Stream Mode Picker
                                    VStack(alignment: .leading, spacing: 8) {
                                        Picker("Stream Mode", selection: $streamMode) {
                                            Text("Broadcast").tag(StreamMode.broadcast)
                                            Text("Conference").tag(StreamMode.conference)
                                            Text("Multi-Participant").tag(StreamMode.multiParticipant)
                                        }
                                        .pickerStyle(.segmented)
                                        Text(streamModeDescription)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                            
                            Button(action: presentChat) {
                                HStack {
                                    Image(systemName: "message.fill")
                                    Text(hasJoined || isHost ? "Open Chat" : "View Chat")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color.purple)
                                .cornerRadius(10)
                            }
                        } else {
                            // Non-host Actions
                            if (session.hasWaitingRoom || session.waitingRoomEnabled) && !session.isActive && !hasJoined {
                                Button(action: { showingWaitingRoom = true }) {
                                    HStack {
                                        Image(systemName: "clock.fill")
                                        Text("Join Waiting Room")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .background(Color.orange)
                                    .cornerRadius(10)
                                }
                            } else if canJoin && !hasJoined {
                                Button(action: joinSession) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                        Text("Join Session")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .background(Color.green)
                                    .cornerRadius(10)
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
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                                }
                                
                                Button(action: presentChat) {
                                    HStack {
                                        Image(systemName: "message.fill")
                                        Text("Open Chat")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .background(Color.purple)
                                    .cornerRadius(10)
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(themeManager.colors.primary.opacity(0.1))
                                .cornerRadius(10)
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
                                    
                                    if session.endTime != nil {
                                        Text("Lasted \(session.formattedDuration)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.platformSystemGray6)
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
                                .background(Color.platformSystemGray6)
                                .cornerRadius(12)
                            }
                            
                            // View Clips (when recording available)
                            if let recordingURL = session.recordingURL, !recordingURL.isEmpty {
                                Button(action: { showingClips = true }) {
                                    HStack {
                                        Image(systemName: "scissors")
                                        Text("View Clips")
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
                        .background(Color.platformSystemGray6)
                        .cornerRadius(12)
                    }
                    }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
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
        participant.isMuted.toggle()
        try? modelContext.save()
        Task {
            await FirebaseSyncService.shared.updateParticipantMuteState(sessionId: session.id, userId: participant.userId, isMuted: participant.isMuted)
        }
    }
    
    private func removeParticipant(_ participant: LiveSessionParticipant) {
        guard isHost && !participant.isHost else { return }
        participant.isActive = false
        try? modelContext.save()
        let newCount = uniqueParticipantCount
        session.currentParticipants = newCount
        try? modelContext.save()
        Task {
            await FirebaseSyncService.shared.updateSessionParticipantCount(session.id, count: newCount)
        }
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
        let sessionId = session.id
        let hostId = session.hostId
        let isHostDeletion = isHost

        // If session is only in publicSessions (not in SwiftData), just remove from list and dismiss
        var descriptor = FetchDescriptor<LiveSession>(predicate: #Predicate<LiveSession> { $0.id == sessionId })
        descriptor.fetchLimit = 1
        let inContext = (try? modelContext.fetch(descriptor))?.first != nil
        if !inContext {
            onDeleted?(sessionId)
            dismiss()
            return
        }

        // Schedule delete to run in parent's onDismiss so we never access session after it's deleted (avoids SwiftData fault crash)
        onPrepareDelete?(sessionId, hostId, isHostDeletion)
        onDeleted?(sessionId)
        dismiss()
    }
    
    private func promoteToCoHost(_ participant: LiveSessionParticipant) {
        guard isHost && !participant.isHost else { return }
        participant.isCoHost = true
        try? modelContext.save()
    }
    
    private func startLiveStream() {
        guard !session.isArchived else { return }
        // Ensure the session is marked live, and start time is anchored for countdowns/time limits.
        // Without this, scheduled sessions (isActive=false) never show a running countdown.
        if !session.isActive {
            session.isActive = true
            session.startTime = Date()
            session.endTime = nil
        }

        // Persist the selected mode on the session so non-hosts can join consistently.
        session.typedStreamMode = streamMode
        try? modelContext.save()

        // Publish updated session state to Firebase (start time + active flag).
        if !session.isPrivate {
            Task {
                await FirebaseSyncService.shared.syncLiveSessionPublic(session)
                // Notify friends only when the host actually starts the stream (not on create/thumbnail sync).
                await FirebaseSyncService.shared.notifyFriendsOfNewSession(session: session)
            }
        }

        // Use the multi-participant stream view as the unified experience (item-based so parent re-renders don’t recreate view → Code 100).
        showingMultiParticipantStream = true
    }
    
    private func joinLiveStream() {
        guard !session.isArchived else { return }
        streamMode = session.typedStreamMode

        showingMultiParticipantStream = true
    }
    
    private func checkJoinStatus() {
        let userId = userService.userIdentifier
        hasJoined = sessionParticipants.contains { $0.userId == userId }
    }
    
    /// Keep stored count in sync with unique participants; remove duplicate records (same user twice) so count is accurate.
    private func reconcileParticipantCount() {
        let list = sessionParticipants

        // Remove duplicate participant records (same user in session twice) so we have at most one per person
        let byUser = Dictionary(grouping: list, by: { $0.userId })
        for (_, group) in byUser where group.count > 1 {
            let toKeep = group.first(where: { $0.isHost }) ?? group.max(by: { $0.joinedAt < $1.joinedAt }) ?? group[0]
            for p in group where p.id != toKeep.id {
                modelContext.delete(p)
            }
        }
        try? modelContext.save()

        // After deduping, count unique participants and update stored count
        let actual = uniqueParticipantCount
        if session.currentParticipants != actual {
            session.currentParticipants = actual
            try? modelContext.save()
        }
        Task {
            await FirebaseSyncService.shared.updateSessionParticipantCount(session.id, count: actual)
        }
    }
    
    private func joinSession() {
        let userId = userService.userIdentifier
        // Avoid duplicate participant (e.g. already joined via invite or double-tap)
        if sessionParticipants.contains(where: { $0.userId == userId }) {
            hasJoined = true
            return
        }
        let nameToStore = profileDisplayNameForCurrentUser(userProfile: userProfile, userService: userService)
        
        let participant = LiveSessionParticipant(
            sessionId: session.id,
            userId: userId,
            userName: nameToStore,
            isHost: false
        )
        participant.userAvatarURL = userProfile?.avatarPhotoURL ?? ProfileManager.shared.profileImageURL
        modelContext.insert(participant)
        
        do {
            try modelContext.save()
            // Set count from actual unique participants so we never show 3 when only 2 people
            let newCount = uniqueParticipantCount
            session.currentParticipants = newCount
            try? modelContext.save()
            Task {
                await FirebaseSyncService.shared.updateSessionParticipantCount(session.id, count: newCount)
            }
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
            let rawHost = profileDisplayNameForCurrentUser(userProfile: userProfile, userService: userService)
            let hostNameToStore = (rawHost == "Participant" || isDeviceName(rawHost)) ? "Host" : rawHost
            let invitation = SessionInvitation(
                sessionId: session.id,
                sessionTitle: session.title,
                hostId: session.hostId,
                hostName: hostNameToStore,
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
    var currentUserId: String? = nil
    var currentUserDisplayName: String? = nil
    
    private var displayName: String {
        if participant.userId == currentUserId, let name = currentUserDisplayName, !name.isEmpty { return name }
        return isDeviceName(participant.userName) ? "Participant" : participant.userName
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: participant.isHost ? "crown.fill" : "person.fill")
                .font(.title2)
                .foregroundColor(participant.isHost ? .orange : .purple)
            
            Text(displayName)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(8)
        .background(Color.platformSystemGray6)
        .cornerRadius(8)
    }
}

@available(iOS 17.0, *)
struct EnhancedParticipantBadge: View {
    let participant: LiveSessionParticipant
    let isHost: Bool
    /// When set (e.g. for host), use this instead of participant.userName so profile name is shown.
    var displayNameOverride: String? = nil
    /// When participant is current user, show this (profile name).
    var currentUserId: String? = nil
    var currentUserDisplayName: String? = nil
    let onRaiseHand: () -> Void
    let onMute: () -> Void
    let onRemove: () -> Void
    let onPromote: () -> Void
    
    private var displayName: String {
        if participant.userId == currentUserId, let name = currentUserDisplayName, !name.isEmpty { return name }
        if let override = displayNameOverride, !override.isEmpty { return override }
        return isDeviceName(participant.userName) ? "Participant" : participant.userName
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                participantAvatar
                
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
            
            Text(displayName)
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
        .background(Color.platformSystemGray6)
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
    
    @ViewBuilder
    private var participantAvatar: some View {
        let size: CGFloat = 44
        if let urlString = participant.userAvatarURL, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure, .empty:
                    fallbackIcon
                @unknown default:
                    fallbackIcon
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            fallbackIcon
        }
    }
    
    private var fallbackIcon: some View {
        Image(systemName: participant.isHost ? "crown.fill" : "person.fill")
            .font(.title2)
            .foregroundColor(participant.isHost ? .orange : .purple)
            .frame(width: 44, height: 44)
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
    /// When provided (e.g. from session detail), use this instead of session.hostName so profile name shows when logged in.
    var hostDisplayName: String? = nil
    @Environment(\.dismiss) private var dismiss

    private var displayedName: String {
        if let name = hostDisplayName, !name.isEmpty { return name }
        return session.hostName.isEmpty ? "Host" : session.hostName
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
                        
                        Text(displayedName)
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
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
                            .background(Color.platformSystemGray6)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Session Analytics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
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
        .background(Color.platformSystemGray6)
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
        .background(Color.platformSystemGray6)
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                }
            }
            .onAppear { setupPlayer() }
            .onDisappear { player?.pause() }
        }
    }
    
    private func setupPlayer() {
        guard let url = URL(string: recordingURL) else {
            errorMessage = "Invalid recording URL"
            return
        }
        player = AVPlayer(url: url)
    }
}

@available(iOS 17.0, *)
struct LiveSessionChatView: View {
    let session: LiveSession
    let canSend: Bool
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
    @State private var chatMessageListener: Any? // ListenerRegistration from Firebase

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
                if !canSend {
                    Text("Join the session to send messages.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.platformSystemGray6)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(sessionMessages, id: \.id) { message in
                            EnhancedChatBubble(
                                message: message,
                                onReaction: { selectedMessageForReaction = message },
                                onAddReaction: { emoji in addReaction(emoji, to: message) },
                                currentUserId: userService.userIdentifier,
                                currentUserDisplayName: profileDisplayNameForCurrentUser(userProfile: userProfile, userService: userService)
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
                                .background(Color.platformSystemGray5)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Message input
                    HStack(spacing: 12) {
                        TextField("Type a message...", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(!canSend)
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
                        .disabled(!canSend || messageText.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Session Chat")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadPublicMessages()
                setupMessageSubscription()
            }
            .onDisappear {
                if let listener = chatMessageListener {
                    FirebaseSyncService.shared.removeChatMessageListener(listener)
                    chatMessageListener = nil
                }
            }
            .refreshable {
                await refreshPublicMessages()
            }
            .sheet(isPresented: $showingPrayerRequest) {
                PrayerRequestChatView(onSend: { prayerText in
                    sendPrayerRequest(prayerText)
                    showingPrayerRequest = false
                })
                .macOSSheetFrameCompact()
            }
            .sheet(isPresented: $showingBibleVersePicker) {
                BibleVerseChatPicker(onSelect: { verse, reference in
                    sendBibleVerse(verse, reference: reference)
                    showingBibleVersePicker = false
                })
                .macOSSheetFrameStandard()
            }
            .sheet(item: $selectedMessageForReaction) { message in
                EmojiReactionPicker { emoji in
                    addReaction(emoji, to: message)
                    selectedMessageForReaction = nil
                }
                .macOSSheetFrameCompact()
            }
            .sheet(isPresented: $showingEmojiPicker) {
                ChatEmojiPickerView { emoji in
                    messageText += emoji
                    showingEmojiPicker = false
                }
                .macOSSheetFrameCompact()
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
        #if canImport(FirebaseFirestore)
        guard chatMessageListener == nil else { return }
        let ctx = modelContext
        if let listener = FirebaseSyncService.shared.startListeningToChatMessages(sessionId: session.id, onMessageReceived: { message in
            let messageId = message.id
            Task { @MainActor in
                do {
                    var descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate<ChatMessage> { $0.id == messageId })
                    descriptor.fetchLimit = 1
                    let existing = try ctx.fetch(descriptor).first
                    if let existing = existing {
                        existing.reactions = message.reactions
                        try? ctx.save()
                    } else {
                        ctx.insert(message)
                        try? ctx.save()
                    }
                } catch { }
            }
        }) {
            chatMessageListener = listener
        }
        #endif
    }
    
    private func sendMessage() {
        let userId = userService.userIdentifier
        let userName = profileDisplayNameForCurrentUser(userProfile: userProfile, userService: userService)
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
            Task {
                await FirebaseSyncService.shared.syncChatMessage(message)
            }
            messageText = ""
        } catch {
            print("Error sending message: \(error)")
        }
    }
    
    private func sendPrayerRequest(_ prayerText: String) {
        let userId = userService.userIdentifier
        let userName = profileDisplayNameForCurrentUser(userProfile: userProfile, userService: userService)
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
            Task { await FirebaseSyncService.shared.syncChatMessage(message) }
        } catch {
            print("Error sending prayer request: \(error)")
        }
    }
    
    private func sendBibleVerse(_ verse: String, reference: String) {
        let userId = userService.userIdentifier
        let userName = profileDisplayNameForCurrentUser(userProfile: userProfile, userService: userService)
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
            Task { await FirebaseSyncService.shared.syncChatMessage(message) }
        } catch {
            print("Error sending Bible verse: \(error)")
        }
    }
    
    private func addReaction(_ emoji: String, to message: ChatMessage) {
        if !message.reactions.contains(emoji) {
            message.reactions.append(emoji)
            try? modelContext.save()
            Task {
                await FirebaseSyncService.shared.syncChatMessage(message)
            }
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
    /// When message is from current user, show this instead of message.userName (profile name).
    var currentUserId: String? = nil
    var currentUserDisplayName: String? = nil
    
    private var authorDisplayName: String {
        if let uid = currentUserId, let name = currentUserDisplayName, message.userId == uid, !name.isEmpty {
            return name
        }
        return isDeviceName(message.userName) ? "Participant" : message.userName
    }
    
    var body: some View {
        HStack {
            if message.messageType == .system {
                Text(message.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(authorDisplayName)
                        .font(.caption)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                    ZStack(alignment: .topLeading) {
                        // Message body: add top/leading padding when reactions exist so text doesn't sit under the badge
                        Text(message.message)
                            .font(.body)
                            .padding(.top, message.reactions.isEmpty ? 12 : 32)
                            .padding(.leading, message.reactions.isEmpty ? 12 : 12)
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(message.messageType == .prayer ? Color.purple.opacity(0.1) : Color.platformSystemGray5)
                            .cornerRadius(12)
                        
                        // Reactions: fixed in upper left corner of the bubble, separate from message text
                        if !message.reactions.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(message.reactions, id: \.self) { emoji in
                                    Text(emoji)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.platformSystemGray6.opacity(0.95))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                            )
                            .padding(.top, 6)
                            .padding(.leading, 6)
                        }
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
    var currentUserId: String? = nil
    var currentUserDisplayName: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChatBubble(message: message, currentUserId: currentUserId, currentUserDisplayName: currentUserDisplayName)
            
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
                    .background(Color.platformSystemGray6)
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
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
        // Salvation / Gospel
        ("John 3:16", "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."),
        ("Romans 10:9", "That if thou shalt confess with thy mouth the Lord Jesus, and shalt believe in thine heart that God hath raised him from the dead, thou shalt be saved."),
        ("Ephesians 2:8-9", "For by grace are ye saved through faith; and that not of yourselves: it is the gift of God: Not of works, lest any man should boast."),
        ("Acts 16:31", "Believe on the Lord Jesus Christ, and thou shalt be saved, and thy house."),
        
        // Strength / Courage
        ("Philippians 4:13", "I can do all things through Christ which strengtheneth me."),
        ("Isaiah 41:10", "Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness."),
        ("Joshua 1:9", "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the Lord thy God is with thee whithersoever thou goest."),
        ("2 Timothy 1:7", "For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind."),
        
        // Peace / Anxiety
        ("John 14:27", "Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you. Let not your heart be troubled, neither let it be afraid."),
        ("Philippians 4:6-7", "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus."),
        ("Psalm 46:1", "God is our refuge and strength, a very present help in trouble."),
        
        // Guidance / Hope
        ("Jeremiah 29:11", "For I know the thoughts that I think toward you, saith the Lord, thoughts of peace, and not of evil, to give you an expected end."),
        ("Proverbs 3:5-6", "Trust in the Lord with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths."),
        ("Romans 8:28", "And we know that all things work together for good to them that love God, to them who are the called according to his purpose."),
        ("Psalm 23:1", "The Lord is my shepherd; I shall not want."),
        
        // Love / Character
        ("1 Corinthians 13:4", "Charity suffereth long, and is kind; charity envieth not; charity vaunteth not itself, is not puffed up."),
        ("John 13:34", "A new commandment I give unto you, That ye love one another; as I have loved you, that ye also love one another."),
        ("Micah 6:8", "He hath shewed thee, O man, what is good; and what doth the Lord require of thee, but to do justly, and to love mercy, and to walk humbly with thy God?"),
        
        // Prayer / Faith
        ("Psalm 34:17", "The righteous cry, and the Lord heareth, and delivereth them out of all their troubles."),
        ("Mark 11:24", "Therefore I say unto you, What things soever ye desire, when ye pray, believe that ye receive them, and ye shall have them."),
        ("Hebrews 11:1", "Now faith is the substance of things hoped for, the evidence of things not seen."),
        
        // Comfort / Hard times
        ("Matthew 11:28", "Come unto me, all ye that labour and are heavy laden, and I will give you rest."),
        ("Psalm 34:18", "The Lord is nigh unto them that are of a broken heart; and saveth such as be of a contrite spirit."),
        ("2 Corinthians 5:7", "For we walk by faith, not by sight."),
        
        // Worship / Gratitude
        ("Psalm 100:4", "Enter into his gates with thanksgiving, and into his courts with praise: be thankful unto him, and bless his name."),
        ("1 Thessalonians 5:16-18", "Rejoice evermore. Pray without ceasing. In every thing give thanks: for this is the will of God in Christ Jesus concerning you.")
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .automatic) {
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
                            .background(Color.platformSystemGray6)
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
                                            .background(Color.platformSystemGray6)
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
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

