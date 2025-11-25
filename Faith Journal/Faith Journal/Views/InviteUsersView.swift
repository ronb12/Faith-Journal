//
//  InviteUsersView.swift
//  Faith Journal
//
//  Host view to invite users to a session
//

import SwiftUI
import SwiftData
import MessageUI

struct InviteUsersView: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var userService = CloudKitUserService.shared
    @StateObject private var syncService = CloudKitPublicSyncService.shared
    @State private var inviteMethod: InviteMethod = .code
    @State private var emailAddress = ""
    @State private var userName = ""
    @State private var showingEmailComposer = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Query var invitations: [SessionInvitation]
    
    enum InviteMethod: String, CaseIterable {
        case code = "Invitation Code"
        case email = "Email"
        case share = "Share Link"
    }
    
    var sessionInviteCode: String {
        invitations.first(where: { $0.sessionId == session.id && $0.status == .pending })?.inviteCode ??
        generateNewCode()
    }
    
    var inviteLink: String {
        "faithjournal://session/\(session.id.uuidString)/code/\(sessionInviteCode)"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Invite Method")) {
                    Picker("Method", selection: $inviteMethod) {
                        ForEach(InviteMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if inviteMethod == .code {
                    Section(header: Text("Invitation Code"), footer: Text("Share this code with people you want to invite. They can enter it in the 'Join by Code' screen.")) {
                        HStack {
                            Text(sessionInviteCode)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                                .fontDesign(.monospaced)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = sessionInviteCode
                                alertMessage = "Code copied to clipboard!"
                                showingAlert = true
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Button(action: {
                            let shareText = """
                            You're invited to join: \(session.title)
                            
                            \(session.details)
                            
                            Use invitation code: \(sessionInviteCode)
                            
                            Or join in Faith Journal app!
                            """
                            UIPasteboard.general.string = shareText
                            alertMessage = "Invitation details copied!"
                            showingAlert = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Code via Message")
                            }
                        }
                    }
                }
                
                if inviteMethod == .email {
                    Section(header: Text("Send Email Invitation"), footer: Text("Enter the email address or name of the person you want to invite.")) {
                        TextField("Email Address", text: $emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        TextField("Name (Optional)", text: $userName)
                    }
                    
                    Button(action: sendEmailInvitation) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Send Invitation Email")
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(emailAddress.isEmpty)
                    .sheet(isPresented: $showingEmailComposer) {
                        EmailComposerView(
                            recipient: emailAddress,
                            subject: "Invitation to \(session.title)",
                            body: emailInvitationBody
                        )
                    }
                }
                
                if inviteMethod == .share {
                    Section(header: Text("Share Invitation Link"), footer: Text("Share this link to invite people to your session. They can join directly from the link.")) {
                        HStack {
                            Text(inviteLink)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = inviteLink
                                alertMessage = "Link copied to clipboard!"
                                showingAlert = true
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Button(action: {
                            let shareText = """
                            Join me for a live session: \(session.title)
                            
                            \(session.details)
                            
                            Category: \(session.category)
                            Invitation Code: \(sessionInviteCode)
                            
                            Join via link: \(inviteLink)
                            """
                            let activityView = UIActivityViewController(
                                activityItems: [shareText, URL(string: inviteLink) as Any],
                                applicationActivities: nil
                            )
                            
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootViewController = windowScene.windows.first?.rootViewController {
                                rootViewController.present(activityView, animated: true)
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Invitation Link")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("Invited Users")) {
                    let sentInvitations = invitations.filter { $0.sessionId == session.id && $0.hostId == userService.userIdentifier }
                    
                    if sentInvitations.isEmpty {
                        Text("No invitations sent yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(sentInvitations) { invitation in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(invitation.invitedUserName ?? invitation.invitedEmail ?? "User")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        Text("Code: \(invitation.inviteCode)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        
                                        Text(invitation.status.rawValue)
                                            .font(.caption)
                                            .foregroundColor(statusColor(invitation.status))
                                    }
                                }
                                
                                Spacer()
                                
                                if invitation.status == .pending {
                                    Button(action: {
                                        resendInvitation(invitation)
                                    }) {
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Invite Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Success", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func generateNewCode() -> String {
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
        return String(code)
    }
    
    private var emailInvitationBody: String {
        """
        Hi!
        
        I'd like to invite you to join my live session: \(session.title)
        
        \(session.details)
        
        Category: \(session.category)
        
        To join:
        1. Open the Faith Journal app
        2. Go to Live Sessions
        3. Tap "Join by Code"
        4. Enter code: \(sessionInviteCode)
        
        Or use this link: \(inviteLink)
        
        Hope to see you there!
        """
    }
    
    private func sendEmailInvitation() {
        // Create invitation record
        let invitation = SessionInvitation(
            sessionId: session.id,
            sessionTitle: session.title,
            hostId: session.hostId,
            hostName: userService.displayName,
            invitedUserName: userName.isEmpty ? nil : userName,
            invitedEmail: emailAddress,
            inviteCode: sessionInviteCode
        )
        modelContext.insert(invitation)
        
        do {
            try modelContext.save()
            
            // Sync to public database
            if userService.isAuthenticated {
                Task {
                    do {
                        try await syncService.syncInvitationToPublic(invitation)
                        await MainActor.run {
                            sendInvitationNotification(invitation)
                            showingEmailComposer = true
                        }
                    } catch {
                        await MainActor.run {
                            showingEmailComposer = true
                            print("Error syncing invitation: \(error)")
                        }
                    }
                }
            } else {
                showingEmailComposer = true
            }
        } catch {
            alertMessage = "Error creating invitation: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func resendInvitation(_ invitation: SessionInvitation) {
        if let email = invitation.invitedEmail {
            emailAddress = email
            userName = invitation.invitedUserName ?? ""
            showingEmailComposer = true
        } else {
            // Resend code via share
            let shareText = """
            You're invited to join: \(invitation.sessionTitle)
            
            Invitation Code: \(invitation.inviteCode)
            """
            UIPasteboard.general.string = shareText
            alertMessage = "Invitation details copied!"
            showingAlert = true
        }
    }
    
    private func statusColor(_ status: SessionInvitation.InvitationStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .green
        case .declined: return .red
        case .expired: return .gray
        }
    }
    
    private func sendInvitationNotification(_ invitation: SessionInvitation) {
        // This would send push notification via CloudKit
        // For now, notification is handled when invitation is synced
    }
}

struct EmailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        
        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
            dismiss()
        }
    }
}

struct InviteCodeView: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query var invitations: [SessionInvitation]
    @StateObject private var userService = CloudKitUserService.shared
    @State private var inviteCode: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)
                    
                    Text("Invitation Code")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let code = inviteCode ?? getOrCreateCode() {
                        Text(code)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.purple)
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Text("Share this code with people you want to invite")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                HStack(spacing: 16) {
                    Button(action: {
                        if let code = inviteCode ?? getOrCreateCode() {
                            UIPasteboard.general.string = code
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Code")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        if let code = inviteCode ?? getOrCreateCode() {
                            let shareText = """
                            Join me for: \(session.title)
                            
                            Invitation Code: \(code)
                            
                            Open Faith Journal app and use "Join by Code" to enter this code.
                            """
                            let activityView = UIActivityViewController(
                                activityItems: [shareText],
                                applicationActivities: nil
                            )
                            
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootViewController = windowScene.windows.first?.rootViewController {
                                rootViewController.present(activityView, animated: true)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.headline)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Invitation Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func getOrCreateCode() -> String? {
        if let existing = invitations.first(where: { $0.sessionId == session.id && $0.status == .pending }) {
            return existing.inviteCode
        }
        
        // Create new invitation code
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
        return String(code)
    }
}

