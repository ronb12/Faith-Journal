//
//  InviteUsersView.swift
//  Faith Journal
//
//  Invite helpers for live sessions (code, email, share)
//

import SwiftUI
import SwiftData
import MessageUI
import UIKit

@available(iOS 17.0, *)
struct InviteUsersView: View {
    let session: LiveSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @available(iOS 17.0, *)
    @Query private var invitations: [SessionInvitation]
    @Query private var userProfiles: [UserProfile]

    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    private var userProfile: UserProfile? { userProfiles.first }
    // Use regular property for singleton, not @StateObject
    // CloudKitPublicSyncService removed - use Firebase for sync in the future
    // private let syncService = CloudKitPublicSyncService.shared

    @State private var inviteMethod: InviteMethod = .code
    @State private var emailAddress: String = ""
    @State private var userName: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingEmailComposer = false
    @State private var sessionInviteCode: String = ""
    @State private var inviteLink: String = ""
    @State private var showingRegenerateAlert = false
    @State private var showingShareSheet = false
    @State private var shareText: String = ""

    enum InviteMethod: String, CaseIterable, Identifiable {
        case code = "Code"
        case email = "Email"
        case share = "Share"
        var id: String { rawValue }
    }
    
    // MARK: - Computed Properties for View Sections
    
    private var invitationMethodSection: some View {
        Section(header: Text("Invitation Method")) {
            Picker("Method", selection: $inviteMethod) {
                ForEach(InviteMethod.allCases) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var invitationCodeSection: some View {
        Section(
            header: Text("Invitation Code"),
            footer: Text("Share your invitation code so others can join your session.")
        ) {
            if !sessionInviteCode.isEmpty {
                HStack {
                    Text(sessionInviteCode)
                        .font(.title3)
                        .font(.body.weight(.bold))
                        .fontDesign(.monospaced)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Button(action: {
                        UIPasteboard.general.string = sessionInviteCode
                        alertMessage = "Invitation code copied to clipboard"
                        showingAlert = true
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4)
                
                Button(action: { showingRegenerateAlert = true }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Generate New Code")
                    }
                    .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            } else {
                NavigationLink("Show Invitation Code") {
                    InviteCodeView(session: session)
                }
            }
        }
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            NavigationStack {
                Form {
                    invitationMethodSection
                    
                    if inviteMethod == .code {
                        invitationCodeSection
                    }

                    if inviteMethod == .email {
                        Section(
                            header: Text("Send Email Invitation"),
                            footer: Text("Enter the email address or name of the person you want to invite.")
                        ) {
                            TextField("Email Address", text: $emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                            TextField("Name (Optional)", text: $userName)
                            Button(action: sendEmailInvitation) {
                                Label("Send Invitation Email", systemImage: "envelope.fill")
                            }
                            .disabled(emailAddress.isEmpty)
                        }
                        .sheet(isPresented: $showingEmailComposer) {
                            if MFMailComposeViewController.canSendMail() {
                                EmailComposerView(
                                    recipient: emailAddress,
                                    subject: "Invitation to \(session.title)",
                                    body: emailInvitationBody
                                )
                            } else {
                                // Fallback: Show alert or share sheet if mail is not configured
                                VStack {
                                    Text("Mail Not Configured")
                                        .font(.headline)
                                        .padding()
                                    Text("Please configure a mail account in Settings or use the Share option instead.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                    Button("OK") {
                                        showingEmailComposer = false
                                    }
                                    .padding()
                                }
                                .padding()
                            }
                        }
                    }

                    if inviteMethod == .share {
                        Section(
                            header: Text("Share Invitation Link"),
                            footer: Text("Share this link so others can join your session.")
                        ) {
                            HStack {
                                Text(inviteLink)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = inviteLink
                                    alertMessage = "Link copied to clipboard!"
                                    showingAlert = true
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.purple)
                                }
                            }
                            Button {
                                // Prepare share items with both text and URL
                                let items = prepareShareItems()
                                shareText = items.first as? String ?? prepareShareText()
                                // Ensure invite link is set
                                if inviteLink.isEmpty {
                                    let code = sessionInviteCode.isEmpty ? getOrCreateCode() : sessionInviteCode
                                    inviteLink = "faithjournal://invite/\(code)"
                                }
                                showingShareSheet = true
                            } label: {
                                Label("Share Invitation Link", systemImage: "square.and.arrow.up")
                            }
                        }
                    }

                    Section(header: Text("Invited Users")) {
                        let sent = invitations.filter { $0.sessionId == session.id && $0.hostId == userService.userIdentifier }
                        if sent.isEmpty {
                            Text("No invitations sent yet").foregroundColor(.secondary)
                        } else {
                            ForEach(sent) { invitation in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(invitation.invitedUserName ?? invitation.invitedEmail ?? "User")
                                            .font(.subheadline)
                                            .font(.body.weight(.medium))
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
                                        Button { resendInvitation(invitation) } label: {
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
                .alert("Generate New Code", isPresented: $showingRegenerateAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Generate New Code", role: .destructive) {
                        regenerateInviteCode()
                    }
                } message: {
                    Text("This will create a new invitation code and invalidate the current one. Anyone with the old code will not be able to join. Continue?")
                }
                .sheet(isPresented: $showingShareSheet) {
                    InviteUsersActivityView(
                        activityItems: {
                            // Use the full text with all details
                            let code = sessionInviteCode.isEmpty ? getOrCreateCode() : sessionInviteCode
                            let text = shareText.isEmpty ? prepareShareText() : shareText
                            
                            // Use deep link format that works if app is installed
                            let deepLink = inviteLink.isEmpty ? "faithjournal://invite/\(code)" : inviteLink
                            
                            // Create URLs for sharing
                            var items: [Any] = [text]
                            
                            if let deepLinkURL = URL(string: deepLink) {
                                items.append(deepLinkURL)
                            }
                            
                            if let appStoreURL = URL(string: AppStoreHelper.appStoreURL) {
                                items.append(appStoreURL)
                            }
                            
                            return items
                        }(),
                        onDismiss: {
                            showingShareSheet = false
                        }
                    )
                }
                .task { prepareDefaults() }
            }
        } else {
            Text("Inviting users is only available on iOS 17+")
        }
    }

    // MARK: - Helpers

    private func prepareDefaults() {
        let code = getOrCreateCode()
        sessionInviteCode = code
        // Use URL scheme that works with the app (faithjournal://invite/CODE)
        // This will open the app and handle the invitation code
        // Format: faithjournal://invite/CODE
        inviteLink = "faithjournal://invite/\(code)"
        
        // Also provide a fallback https link for instructions (even if not clickable)
        // The share text will include both the code and clear instructions
    }
    
    private func prepareShareText() -> String {
        let code = sessionInviteCode.isEmpty ? getOrCreateCode() : sessionInviteCode
        let deepLink = "faithjournal://invite/\(code)"
        let appStoreURL = AppStoreHelper.appStoreURL
        
        // Include all session details in the message
        // Use deep link format that works if app is installed
        let message = """
        Join me for a live session on Faith Journal!
        
        📋 SESSION DETAILS:
        Title: \(session.title)
        
        \(session.details)
        
        Category: \(session.category)
        
        🔑 INVITATION CODE: \(code)
        
        📱 TO JOIN:
        
        If you have the Faith Journal app installed:
        1. Copy this code: \(code)
        2. Open the Faith Journal app
        3. Go to Live Sessions → Invitations
        4. Tap "Join by Code"
        5. Paste the code: \(code)
        
        Or tap this link (if app is installed):
        \(deepLink)
        
        📲 DON'T HAVE THE APP?
        Install from the App Store:
        \(appStoreURL)
        
        After installing:
        1. Open the app and sign in
        2. Go to Live Sessions → Invitations
        3. Tap "Join by Code"
        4. Enter code: \(code)
        """
        
        return message
    }
    
    private func prepareShareItems() -> [Any] {
        let code = sessionInviteCode.isEmpty ? getOrCreateCode() : sessionInviteCode
        
        // Get the full text with all session details
        let shareText = prepareShareText()
        
        // Use deep link format that works if app is installed
        // This will open the app directly if installed, or do nothing if not
        let deepLink = inviteLink.isEmpty ? "faithjournal://invite/\(code)" : inviteLink
        
        // Create URL objects for sharing
        // Include both deep link (for app) and App Store link (for users without app)
        guard let deepLinkURL = URL(string: deepLink),
              let appStoreURL = URL(string: AppStoreHelper.appStoreURL) else {
            // Fallback if URL creation fails
            return [shareText]
        }
        
        // Return text with both URLs
        // The deep link will work if app is installed
        // The App Store link is in the text for users without the app
        return [
            shareText,
            deepLinkURL,
            appStoreURL
        ]
    }

    private func generateNewCode() -> String {
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
            print("❌ Error creating invitation: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.saveFailed)
        }
        return String(code)
    }

    private var emailInvitationBody: String {
        let code = sessionInviteCode.isEmpty ? getOrCreateCode() : sessionInviteCode
        let clickableLink = inviteLink.isEmpty ? "https://faith-journal.web.app/invite/\(code)" : inviteLink
        let appStoreURL = AppStoreHelper.appStoreURL
        
        return """
        Hi!
        
        I'd like to invite you to join my live session on Faith Journal.
        
        Session Details:
        Title: \(session.title)
        
        \(session.details)
        
        Category: \(session.category)
        
        How to Join:
        
        If you have the Faith Journal app:
        1. Tap this link: \(clickableLink)
        2. Or open the app and go to Live Sessions → Invitations
        3. Tap "Join by Code" and enter: \(code)
        
        If you don't have the app:
        1. Install Faith Journal from the App Store:
           \(appStoreURL)
        2. Open the app and sign in
        3. Go to Live Sessions → Invitations
        4. Tap "Join by Code" and enter: \(code)
        
        I hope to see you there!
        """
    }
    
    private func getOrCreateCode() -> String {
        // Check if there's an existing invitation for this session
        let existing = invitations.first { $0.sessionId == session.id && $0.hostId == userService.userIdentifier }
        if let code = existing?.inviteCode, !code.isEmpty {
            return code
        }
        // Generate a new code
        return generateNewCode()
    }
    
    private func sendEmailInvitation() {
        // Check if mail is available before proceeding
        guard MFMailComposeViewController.canSendMail() else {
            // If mail is not available, use share sheet instead
            shareText = emailInvitationBody
            showingShareSheet = true
            alertMessage = "Mail is not configured. Using share sheet instead."
            showingAlert = true
            return
        }
        
        let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        let code = sessionInviteCode.isEmpty ? getOrCreateCode() : sessionInviteCode
        
        let invitation = SessionInvitation(
            sessionId: session.id,
            sessionTitle: session.title,
            hostId: session.hostId,
            hostName: userService.getDisplayName(userProfile: userProfile),
            inviteCode: code,
            expiresAt: expirationDate
        )
        invitation.invitedEmail = emailAddress
        invitation.invitedUserName = userName.isEmpty ? nil : userName
        
        modelContext.insert(invitation)
        do {
            try modelContext.save()
            
            // Sync to Firebase for cross-device sync
            Task {
                await FirebaseSyncService.shared.syncSessionInvitation(invitation)
                print("✅ [INVITATION] Synced invitation to Firebase: \(code)")
            }
            
            showingEmailComposer = true
            alertMessage = "Email invitation prepared. Please review and send."
        } catch {
            print("❌ Error creating invitation: \(error.localizedDescription)")
            ErrorHandler.shared.handle(.saveFailed)
            alertMessage = "Failed to create invitation: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func resendInvitation(_ invitation: SessionInvitation) {
        emailAddress = invitation.invitedEmail ?? ""
        userName = invitation.invitedUserName ?? ""
        sessionInviteCode = invitation.inviteCode
        sendEmailInvitation()
    }
    
    private func regenerateInviteCode() {
        let newCode = generateNewCode()
        sessionInviteCode = newCode
        inviteLink = "faithjournal://invite/\(newCode)"
        alertMessage = "New invitation code generated: \(newCode)"
        showingAlert = true
    }
    
    private func statusColor(_ status: SessionInvitation.InvitationStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .declined:
            return .red
        case .expired:
            return .gray
        }
    }
}

// MARK: - Email Composer View

struct EmailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    
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
        Coordinator()
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Share Activity View

struct InviteUsersActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create activity items with proper source for better Messages support
        let items = activityItems.map { item -> Any in
            if let text = item as? String {
                return ShareTextItem(text: text)
            } else if let url = item as? URL {
                return ShareURLItem(url: url)
            }
            return item
        }
        
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Exclude activities that might truncate text
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Share Item Sources

class ShareTextItem: NSObject, UIActivityItemSource {
    let text: String
    
    init(text: String) {
        self.text = text
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return text
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // For Messages, return the full text with all details
        if activityType == .message {
            return text
        }
        // For other activities, return the text as well
        return text
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        // Extract title from text for email subject
        if let titleRange = text.range(of: "Title: ") {
            let afterTitle = text[titleRange.upperBound...]
            if let newlineRange = afterTitle.range(of: "\n") {
                return String(afterTitle[..<newlineRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        return "Live Session Invitation"
    }
}

class ShareURLItem: NSObject, UIActivityItemSource {
    let url: URL
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }
}
