//
//  LiveSessionsView.swift
//  Faith Journal
//
//  Created on 11/18/25.
//

import SwiftUI
import SwiftData
import UIKit
import CloudKit

struct LiveSessionsView: View {
    @Query(sort: [SortDescriptor(\LiveSession.startTime, order: .reverse)]) var allSessions: [LiveSession]
    @Query(sort: [SortDescriptor(\LiveSessionParticipant.joinedAt, order: .reverse)]) var allParticipants: [LiveSessionParticipant]
    @Query(sort: [SortDescriptor(\SessionInvitation.createdAt, order: .reverse)]) var allInvitations: [SessionInvitation]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var userService = CloudKitUserService.shared
    @StateObject private var syncService = CloudKitPublicSyncService.shared
    @State private var showingCreateSession = false
    @State private var selectedSession: LiveSession?
    @State private var showingSessionDetail = false
    @State private var showingInvitations = false
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    @State private var isLoadingPublicSessions = false
    @State private var publicSessions: [LiveSession] = []
    
    // Combine local and public sessions, removing duplicates
    var allActiveSessions: [LiveSession] {
        var combined = allSessions.filter { $0.isActive }
        // Add public sessions that aren't already in local
        let localIds = Set(combined.map { $0.id })
        for publicSession in publicSessions.filter({ $0.isActive }) {
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
                session.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
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
                
                // Category Filter
                if !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category
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
                                .font(.title2)
                                .fontWeight(.semibold)
                            
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
                    List {
                        ForEach(filteredSessions) { session in
                            LiveSessionCard(session: session) {
                                selectedSession = session
                                showingSessionDetail = true
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Live Sessions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingInvitations = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "envelope.fill")
                                .fontWeight(.semibold)
                            
                            let pendingCount = allInvitations.filter { invitation in
                                (invitation.invitedUserId == userService.userIdentifier || invitation.invitedEmail != nil) &&
                                invitation.status == .pending &&
                                !invitation.isExpired
                            }.count
                            
                            if pendingCount > 0 {
                                Text("\(pendingCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
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
                            .fontWeight(.semibold)
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
                loadPublicSessions()
                setupSubscriptions()
            }
            .refreshable {
                await refreshPublicSessions()
            }
        }
    }
    
    private func loadPublicSessions() {
        isLoadingPublicSessions = true
        Task { @MainActor in
            do {
                // Wait a bit for CloudKit to initialize if needed
                if !userService.isAuthenticated {
                    // CloudKit might still be initializing
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                
                guard userService.isAuthenticated else {
                    isLoadingPublicSessions = false
                    return
                }
                
                let sessions = try await syncService.fetchPublicSessions()
                publicSessions = sessions
                isLoadingPublicSessions = false
            } catch {
                print("Error loading public sessions: \(error.localizedDescription)")
                isLoadingPublicSessions = false
            }
        }
    }
    
    private func refreshPublicSessions() async {
        guard await MainActor.run(body: { userService.isAuthenticated }) else { return }
        
        do {
            let sessions = try await syncService.fetchPublicSessions()
            await MainActor.run {
                self.publicSessions = sessions
            }
        } catch {
            print("Error refreshing public sessions: \(error.localizedDescription)")
        }
    }
    
    private func setupSubscriptions() {
        Task { @MainActor in
            do {
                // Wait a bit for CloudKit to initialize if needed
                if !userService.isAuthenticated {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                
                guard userService.isAuthenticated else {
                    return
                }
                
                try await syncService.subscribeToSessions()
            } catch {
                print("Error setting up subscriptions: \(error.localizedDescription)")
            }
        }
    }
}

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
                            .fontWeight(.semibold)
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
    let action: () -> Void
    
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
                        .fill(isSelected ? Color.purple : Color(.systemGray5))
                )
        }
    }
}

struct CreateLiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var userService = CloudKitUserService.shared
    @StateObject private var syncService = CloudKitPublicSyncService.shared
    @State private var title = ""
    @State private var details = ""
    @State private var category = "Prayer"
    @State private var maxParticipants = 10
    @State private var tags = ""
    @State private var isPrivate = false
    
    let categories = ["Prayer", "Bible Study", "Devotional", "Testimony", "Fellowship", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Session Details")) {
                    TextField("Session Title", text: $title)
                    TextEditor(text: $details)
                        .frame(height: 100)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
                
                Section(header: Text("Participants")) {
                    Stepper("Max Participants: \(maxParticipants)", value: $maxParticipants, in: 2...50)
                }
                
                Section(header: Text("Tags (comma separated)")) {
                    TextField("Tags", text: $tags)
                }
                
                Section {
                    Toggle("Private Session", isOn: $isPrivate)
                }
            }
            .navigationTitle("Create Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createSession()
                    }
                    .disabled(title.isEmpty || details.isEmpty)
                }
            }
        }
    }
    
    private func createSession() {
        let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        // Use CloudKit user ID for multi-user support
        let userId = userService.userIdentifier
        let userName = userService.displayName
        
        let session = LiveSession(
            title: title,
            description: details,
            hostId: userId,
            category: category,
            maxParticipants: maxParticipants,
            tags: tagArray
        )
        session.isPrivate = isPrivate
        
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
            
            // Sync to public CloudKit database for multi-user sharing
            if !isPrivate && userService.isAuthenticated {
                Task {
                    do {
                        try await syncService.syncSessionToPublic(session)
                        try await syncService.syncParticipantToPublic(participant)
                    } catch {
                        print("Error syncing session to public database: \(error)")
                    }
                }
            }
            
            dismiss()
        } catch {
            print("Error creating session: \(error)")
        }
    }
}

struct LiveSessionDetailView: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var participants: [LiveSessionParticipant]
    @Query var invitations: [SessionInvitation]
    @StateObject private var userService = CloudKitUserService.shared
    @StateObject private var syncService = CloudKitPublicSyncService.shared
    @State private var showingChat = false
    @State private var hasJoined = false
    @State private var showingShareSheet = false
    @State private var showingInviteUsers = false
    @State private var showingInviteCode = false
    
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
        session.hostId == userService.userIdentifier
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
                            }
                        }
                        
                        Text(session.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(session.details)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Participants
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Participants (\(sessionParticipants.count)/\(session.maxParticipants))")
                            .font(.headline)
                        
                        if sessionParticipants.isEmpty {
                            Text("No participants yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(sessionParticipants) { participant in
                                        ParticipantBadge(participant: participant)
                                    }
                                }
                            }
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
                                        .fontWeight(.bold)
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
                    }
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
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
            .onAppear {
                checkJoinStatus()
                if isHost && primaryInviteCode == nil {
                    generateInviteCodeIfNeeded()
                }
            }
        }
    }
    
    private func checkJoinStatus() {
        let userId = userService.userIdentifier
        hasJoined = sessionParticipants.contains { $0.userId == userId }
    }
    
    private func joinSession() {
        let userId = userService.userIdentifier
        let userName = userService.displayName
        
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
            
            // Sync to public CloudKit database for multi-user support
            if userService.isAuthenticated && !session.isPrivate {
                Task {
                    do {
                        try await syncService.syncParticipantToPublic(participant)
                        try await syncService.syncSessionToPublic(session)
                    } catch {
                        print("Error syncing participant to public database: \(error)")
                    }
                }
            }
            
            hasJoined = true
        } catch {
            print("Error joining session: \(error)")
        }
    }
    
    private func shareSession() {
        showingShareSheet = true
    }
    
    private func generateInviteCodeIfNeeded() {
        // Generate default invite code for host if none exists
        if primaryInviteCode == nil {
            let code = UUID().uuidString.prefix(8).uppercased()
            let invitation = SessionInvitation(
                sessionId: session.id,
                sessionTitle: session.title,
                hostId: session.hostId,
                hostName: userService.displayName,
                inviteCode: String(code)
            )
            modelContext.insert(invitation)
            try? modelContext.save()
        }
    }
}

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

struct LiveSessionChatView: View {
    let session: LiveSession
    @Query var messages: [ChatMessage]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var userService = CloudKitUserService.shared
    @StateObject private var syncService = CloudKitPublicSyncService.shared
    @State private var messageText = ""
    @State private var publicMessages: [ChatMessage] = []
    
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
                            ChatBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Session Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadPublicMessages()
                setupMessageSubscription()
            }
            .refreshable {
                await refreshPublicMessages()
            }
        }
    }
    
    private func loadPublicMessages() {
        guard userService.isAuthenticated else { return }
        
        Task {
            do {
                let messages = try await syncService.fetchPublicMessages(for: session.id)
                await MainActor.run {
                    publicMessages = messages
                }
            } catch {
                print("Error loading public messages: \(error)")
            }
        }
    }
    
    private func refreshPublicMessages() async {
        guard userService.isAuthenticated else { return }
        
        do {
            let messages = try await syncService.fetchPublicMessages(for: session.id)
            await MainActor.run {
                publicMessages = messages
            }
        } catch {
            print("Error refreshing public messages: \(error)")
        }
    }
    
    private func setupMessageSubscription() {
        guard userService.isAuthenticated else { return }
        
        Task {
            do {
                try await syncService.subscribeToMessages(for: session.id)
            } catch {
                print("Error setting up message subscription: \(error)")
            }
        }
    }
    
    private func sendMessage() {
        let userId = userService.userIdentifier
        let userName = userService.displayName
        
        let message = ChatMessage(
            sessionId: session.id,
            userId: userId,
            userName: userName,
            message: messageText,
            messageType: .text
        )
        modelContext.insert(message)
        
        do {
            try modelContext.save()
            
            // Sync to public CloudKit database for multi-user support
            if userService.isAuthenticated && !session.isPrivate {
                Task {
                    do {
                        try await syncService.syncMessageToPublic(message)
                    } catch {
                        print("Error syncing message to public database: \(error)")
                    }
                }
            }
            
            messageText = ""
        } catch {
            print("Error sending message: \(error)")
        }
    }
}

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
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(message.message)
                        .font(.body)
                        .padding(12)
                        .background(message.messageType == .prayer ? Color.purple.opacity(0.1) : Color(.systemGray5))
                        .cornerRadius(12)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

extension LiveSession: Identifiable {}

#Preview {
    LiveSessionsView()
        .modelContainer(for: [LiveSession.self, LiveSessionParticipant.self, ChatMessage.self], inMemory: true)
}

