//
//  InvitationsView.swift
//  Faith Journal
//
//  Shows pending session invitations
//

import SwiftUI
import SwiftData
import UserNotifications

struct InvitationsView: View {
    @Query(sort: [SortDescriptor(\SessionInvitation.createdAt, order: .reverse)]) var allInvitations: [SessionInvitation]
    @Query(sort: [SortDescriptor(\LiveSession.startTime, order: .reverse)]) var allSessions: [LiveSession]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var userService = CloudKitUserService.shared
    @StateObject private var syncService = CloudKitPublicSyncService.shared
    @State private var selectedInvitation: SessionInvitation?
    @State private var showingInvitationDetail = false
    @State private var showingJoinByCode = false
    @State private var inviteCodeInput = ""
    @State private var publicInvitations: [SessionInvitation] = []
    @State private var isLoadingInvitations = false
    
    var pendingInvitations: [SessionInvitation] {
        let userId = userService.userIdentifier
        var combined = allInvitations.filter { invitation in
            (invitation.invitedUserId == userId || invitation.invitedEmail != nil) &&
            invitation.status == .pending &&
            !invitation.isExpired
        }
        
        // Add public invitations
        let localIds = Set(combined.map { $0.id })
        for publicInvitation in publicInvitations.filter({ $0.status == .pending && !$0.isExpired }) {
            if !localIds.contains(publicInvitation.id) &&
               (publicInvitation.invitedUserId == userId || publicInvitation.invitedEmail != nil) {
                combined.append(publicInvitation)
            }
        }
        
        return combined
    }
    
    var expiredInvitations: [SessionInvitation] {
        let userId = userService.userIdentifier
        var combined = allInvitations.filter { invitation in
            (invitation.invitedUserId == userId || invitation.invitedEmail != nil) &&
            (invitation.status == .expired || invitation.isExpired)
        }
        
        // Add public expired invitations
        let localIds = Set(combined.map { $0.id })
        for publicInvitation in publicInvitations.filter({ $0.status == .expired || $0.isExpired }) {
            if !localIds.contains(publicInvitation.id) &&
               (publicInvitation.invitedUserId == userId || publicInvitation.invitedEmail != nil) {
                combined.append(publicInvitation)
            }
        }
        
        return combined
    }
    
    var sentInvitations: [SessionInvitation] {
        let userId = userService.userIdentifier
        var combined = allInvitations.filter { invitation in
            invitation.hostId == userId && invitation.status == .pending
        }
        
        // Add public sent invitations
        let localIds = Set(combined.map { $0.id })
        for publicInvitation in publicInvitations.filter({ $0.hostId == userId && $0.status == .pending }) {
            if !localIds.contains(publicInvitation.id) {
                combined.append(publicInvitation)
            }
        }
        
        return combined
    }
    
    var body: some View {
        NavigationView {
            List {
                if pendingInvitations.isEmpty && sentInvitations.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "envelope")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No Invitations")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("You don't have any pending invitations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: { showingJoinByCode = true }) {
                            HStack {
                                Image(systemName: "qrcode")
                                Text("Join by Code")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowInsets(EdgeInsets())
                } else {
                    // Pending Invitations (Received)
                    if !pendingInvitations.isEmpty {
                        Section(header: Text("Pending Invitations")) {
                            ForEach(pendingInvitations) { invitation in
                                InvitationRow(invitation: invitation) {
                                    selectedInvitation = invitation
                                    showingInvitationDetail = true
                                }
                            }
                        }
                    }
                    
                    // Sent Invitations
                    if !sentInvitations.isEmpty {
                        Section(header: Text("Sent Invitations")) {
                            ForEach(sentInvitations) { invitation in
                                SentInvitationRow(invitation: invitation)
                            }
                        }
                    }
                    
                    // Expired Invitations
                    if !expiredInvitations.isEmpty {
                        Section(header: Text("Expired")) {
                            ForEach(expiredInvitations) { invitation in
                                ExpiredInvitationRow(invitation: invitation)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Invitations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingJoinByCode = true }) {
                        Image(systemName: "qrcode")
                    }
                }
            }
            .sheet(item: $selectedInvitation) { invitation in
                InvitationDetailView(invitation: invitation)
            }
            .sheet(isPresented: $showingJoinByCode) {
                JoinByCodeView()
            }
            .onAppear {
                loadPublicInvitations()
            }
            .refreshable {
                await refreshPublicInvitations()
            }
        }
    }
    
    private func loadPublicInvitations() {
        guard userService.isAuthenticated else { return }
        
        isLoadingInvitations = true
        Task {
            do {
                let userId = userService.userIdentifier
                let invitations = try await syncService.fetchPublicInvitations(for: userId)
                await MainActor.run {
                    publicInvitations = invitations
                    isLoadingInvitations = false
                }
            } catch {
                print("Error loading public invitations: \(error)")
                await MainActor.run {
                    isLoadingInvitations = false
                }
            }
        }
    }
    
    private func refreshPublicInvitations() async {
        guard userService.isAuthenticated else { return }
        
        do {
            let userId = userService.userIdentifier
            let invitations = try await syncService.fetchPublicInvitations(for: userId)
            await MainActor.run {
                publicInvitations = invitations
            }
        } catch {
            print("Error refreshing public invitations: \(error)")
        }
    }
}

struct InvitationRow: View {
    let invitation: SessionInvitation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.purple)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.sessionTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("From: \(invitation.hostName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let expiresAt = invitation.expiresAt {
                        Text("Expires: \(expiresAt, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SentInvitationRow: View {
    let invitation: SessionInvitation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "paperplane.fill")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.sessionTitle)
                    .font(.headline)
                
                Text("To: \(invitation.invitedUserName ?? invitation.invitedEmail ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Code: \(invitation.inviteCode)")
                        .font(.caption)
                        .foregroundColor(.purple)
                    
                    Button(action: {
                        UIPasteboard.general.string = invitation.inviteCode
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                    }
                }
            }
            
            Spacer()
            
            Text(invitation.status.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
        .padding(.vertical, 8)
    }
}

struct ExpiredInvitationRow: View {
    let invitation: SessionInvitation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope")
                .foregroundColor(.gray)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.sessionTitle)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("From: \(invitation.hostName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Expired")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct InvitationDetailView: View {
    let invitation: SessionInvitation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var sessions: [LiveSession]
    @StateObject private var userService = CloudKitUserService.shared
    @StateObject private var syncService = CloudKitPublicSyncService.shared
    @State private var isProcessing = false
    
    var session: LiveSession? {
        sessions.first { $0.id == invitation.sessionId }
    }
    
    var canAccept: Bool {
        session?.isActive == true &&
        (session?.currentParticipants ?? 0) < (session?.maxParticipants ?? 0) &&
        invitation.isValid
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(invitation.sessionTitle)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("From: \(invitation.hostName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let session = session {
                            Text(session.details)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    
                    // Session Info
                    if let session = session {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "Category", value: session.category)
                            InfoRow(label: "Participants", value: "\(session.currentParticipants)/\(session.maxParticipants)")
                            InfoRow(label: "Status", value: session.isActive ? "Active" : "Ended")
                            if let expiresAt = invitation.expiresAt {
                                InfoRow(label: "Invitation Expires", value: expiresAt, style: .relative)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Actions
                    if canAccept {
                        VStack(spacing: 12) {
                            Button(action: acceptInvitation) {
                                HStack {
                                    if isProcessing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Accept Invitation")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            .disabled(isProcessing)
                            
                            Button(action: declineInvitation) {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text("Decline")
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .disabled(isProcessing)
                        }
                    } else if invitation.isExpired {
                        Text("This invitation has expired")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                    } else if let session = session, !session.isActive {
                        Text("This session has ended")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    // Invite Code
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite Code")
                            .font(.headline)
                        
                        HStack {
                            Text(invitation.inviteCode)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                                .fontDesign(.monospaced)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = invitation.inviteCode
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func acceptInvitation() {
        guard let session = session else { return }
        
        isProcessing = true
        
        // Update invitation status
        invitation.status = .accepted
        invitation.respondedAt = Date()
        
        // Join the session
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
            
            // Sync to public database
            if userService.isAuthenticated && !session.isPrivate {
                Task {
                    do {
                        try await syncService.syncParticipantToPublic(participant)
                        try await syncService.syncSessionToPublic(session)
                        
                        await MainActor.run {
                            sendAcceptanceNotification()
                            isProcessing = false
                            dismiss()
                        }
                    } catch {
                        await MainActor.run {
                            isProcessing = false
                            print("Error syncing acceptance: \(error)")
                        }
                    }
                }
            } else {
                sendAcceptanceNotification()
                isProcessing = false
                dismiss()
            }
        } catch {
            isProcessing = false
            print("Error accepting invitation: \(error)")
        }
    }
    
    private func declineInvitation() {
        invitation.status = .declined
        invitation.respondedAt = Date()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error declining invitation: \(error)")
        }
    }
    
    private func sendAcceptanceNotification() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Invitation Accepted"
        content.body = "You've joined \(invitation.sessionTitle)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}

struct InfoRow: View {
    let label: String
    let value: Any
    let style: Text.DateStyle?
    
    init(label: String, value: Any, style: Text.DateStyle? = nil) {
        self.label = label
        self.value = value
        self.style = style
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            if let date = value as? Date, let style = style {
                Text(date, style: style)
                    .fontWeight(.medium)
            } else {
                Text(String(describing: value))
                    .fontWeight(.medium)
            }
        }
    }
}

struct JoinByCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var invitations: [SessionInvitation]
    @State private var inviteCode = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("Join Session by Code")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter the invitation code shared by the session host")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invitation Code")
                        .font(.headline)
                    
                    TextField("Enter code", text: $inviteCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title3)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)
                
                Button(action: joinByCode) {
                    Text("Join Session")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(inviteCode.isEmpty ? Color.gray : Color.purple)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(inviteCode.isEmpty)
                
                Spacer()
            }
            .navigationTitle("Join by Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func joinByCode() {
        let code = inviteCode.uppercased().trimmingCharacters(in: .whitespaces)
        
        // Find invitation by code
        guard let invitation = invitations.first(where: { $0.inviteCode.uppercased() == code && $0.isValid }) else {
            errorMessage = "Invalid or expired invitation code. Please check the code and try again."
            showingError = true
            return
        }
        
        // Check if session still exists and is active
        let sessionId = invitation.sessionId
        let sessionQuery = FetchDescriptor<LiveSession>(
            predicate: #Predicate { session in
                session.id == sessionId && session.isActive == true
            }
        )
        
        if let session = try? modelContext.fetch(sessionQuery).first {
            // Check if already joined
            let userId = CloudKitUserService.shared.userIdentifier
            let participantSessionId = invitation.sessionId
            let participantQuery = FetchDescriptor<LiveSessionParticipant>(
                predicate: #Predicate { participant in
                    participant.sessionId == participantSessionId &&
                    participant.userId == userId &&
                    participant.isActive == true
                }
            )
            
            if (try? modelContext.fetch(participantQuery).first) != nil {
                errorMessage = "You've already joined this session"
                showingError = true
                return
            }
            
            // Accept the invitation
            invitation.status = .accepted
            invitation.respondedAt = Date()
            
            // Join session
            let participant = LiveSessionParticipant(
                sessionId: session.id,
                userId: userId,
                userName: CloudKitUserService.shared.displayName,
                isHost: false
            )
            modelContext.insert(participant)
            session.currentParticipants += 1
            
            do {
                try modelContext.save()
                
                // Sync to public database if needed
                if !session.isPrivate {
                    Task {
                        do {
                            try await CloudKitPublicSyncService.shared.syncParticipantToPublic(participant)
                            try await CloudKitPublicSyncService.shared.syncSessionToPublic(session)
                        } catch {
                            print("Error syncing join: \(error)")
                        }
                    }
                }
                
                dismiss()
            } catch {
                errorMessage = "Error joining session: \(error.localizedDescription)"
                showingError = true
            }
        } else {
            errorMessage = "This session is no longer active or has been deleted"
            invitation.status = .expired
            
            do {
                try modelContext.save()
            } catch {
                print("❌ Error updating invitation status: \(error.localizedDescription)")
            }
            showingError = true
        }
    }
}

extension SessionInvitation: Identifiable {}

#Preview {
    InvitationsView()
        .modelContainer(for: [SessionInvitation.self, LiveSession.self], inMemory: true)
}

