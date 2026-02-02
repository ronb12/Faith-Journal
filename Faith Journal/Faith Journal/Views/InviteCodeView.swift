//
//  InviteCodeView.swift
//  Faith Journal
//
//  View for displaying and sharing invite codes with QR codes
//

import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

@available(iOS 17.0, *)
struct InviteCodeView: View {
    let session: LiveSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Use regular property for singleton, not @StateObject
    private let userService = LocalUserService.shared
    @Query var invitations: [SessionInvitation]

    @State private var showingShareSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingRegenerateAlert = false
    
    var sessionInvitation: SessionInvitation? {
        return invitations.first(where: { $0.sessionId == session.id && $0.status == .pending })
    }
    
    var inviteCode: String {
        sessionInvitation?.inviteCode ?? ""
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // QR Code
                    if !inviteCode.isEmpty {
                        VStack(spacing: 16) {
                            // Generate QR code with deep link URL so it opens the app when scanned
                            if let qrImage = generateQRCode(from: "faithjournal://invite/\(inviteCode)") {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.1), radius: 10)
                            }
                            Text("Scan to Join")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("QR code will open the app and join automatically")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top)
                    }
                    
                    // Invite Code Display
                    VStack(spacing: 12) {
                        Text("Invite Code")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if inviteCode.isEmpty {
                            Button(action: generateInviteCode) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Generate Code")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                            }
                        } else {
                            HStack(spacing: 16) {
                                Text(inviteCode)
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .foregroundColor(.purple)
                                    .tracking(4)
                                
                                Button(action: copyCode) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.title2)
                                        .foregroundColor(.purple)
                                }
                            }
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Generate New Code Button
                            Button(action: { showingRegenerateAlert = true }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Generate New Code")
                                }
                                .font(.subheadline)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    // Session Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.title)
                            .font(.title2)
                            .font(.body.weight(.semibold))
                        
                        Text(session.details)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label(session.category, systemImage: "tag.fill")
                                .font(.caption)
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            Label("\(session.currentParticipants)/\(session.maxParticipants)", systemImage: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Share Button
                    if !inviteCode.isEmpty {
                        Button(action: { showingShareSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Invite")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to Join")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            InstructionRow(number: "1", text: "Open Faith Journal app")
                            InstructionRow(number: "2", text: "Go to Live Sessions")
                            InstructionRow(number: "3", text: "Tap the envelope icon")
                            InstructionRow(number: "4", text: "Enter the invite code or scan QR")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Invite Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                InviteCodeActivityView(activityItems: [shareText])
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Generate New Code", isPresented: $showingRegenerateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Generate New Code", role: .destructive) {
                    regenerateInviteCode()
                }
            } message: {
                Text("This will create a new invitation code and invalidate the current one. Anyone with the old code will not be able to join. Continue?")
            }
            .onAppear {
                if sessionInvitation == nil {
                    generateInviteCode()
                }
            }
        }
    }
    
    var shareText: String {
        let inviteLink = "faithjournal://invite/\(inviteCode)"
        _ = AppStoreHelper.appStoreURL
        let installationInstructions = AppStoreHelper.installationInstructions(inviteCode: inviteCode)
        
        return """
        Join me for "\(session.title)" on Faith Journal!
        
        🔑 Invitation Code: \(inviteCode)
        
        📱 HAVE THE APP?
        Tap this link to join: \(inviteLink)
        
        Or manually:
        1. Open Faith Journal app
        2. Go to Live Sessions → Invitations
        3. Tap "Join by Code"
        4. Enter code: \(inviteCode)
        
        📲 DON'T HAVE THE APP?
        \(installationInstructions)
        
        The invitation code will work once you install the app!
        """
    }
    
    func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        // Scale up the QR code
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    func generateInviteCode() {
        let code = String(UUID().uuidString.prefix(8).uppercased())
        
        // Set expiration to 30 days from now (default, but be explicit)
        // Make sure expiration is in the future
        let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
        
        // Ensure expiration is definitely in the future
        let finalExpirationDate = max(expirationDate, Date().addingTimeInterval(60)) // At least 1 minute in the future
        
        let invitation = SessionInvitation(
            sessionId: session.id,
            sessionTitle: session.title,
            hostId: session.hostId,
            hostName: userService.displayName,
            inviteCode: code,
            expiresAt: finalExpirationDate
        )
        
        modelContext.insert(invitation)
        
        do {
            try modelContext.save()
            
            // Sync to Firebase for cross-device sync
            Task {
                await FirebaseSyncService.shared.syncSessionInvitation(invitation)
                print("✅ [INVITATION] Generated and synced new invitation code: \(code), expires: \(finalExpirationDate)")
            }
        } catch {
            errorMessage = "Failed to generate invite code"
            showingError = true
        }
    }
    
    func regenerateInviteCode() {
        // Mark existing pending invitations as expired
        let existingInvitations = invitations.filter { 
            $0.sessionId == session.id && $0.status == .pending 
        }
        
        // Sync expired status to Firebase before generating new code
        Task {
            for invitation in existingInvitations {
                invitation.status = .expired
                invitation.respondedAt = Date()
                
                // Sync expiration to Firebase immediately
                await FirebaseSyncService.shared.syncSessionInvitation(invitation)
                print("✅ [INVITATION] Marked old invitation as expired in Firebase: \(invitation.inviteCode)")
            }
            
            // Generate a new code after syncing old ones
            await MainActor.run {
                do {
                    try modelContext.save()
                    generateInviteCode()
                    print("✅ [INVITATION] Generated new invitation code")
                } catch {
                    errorMessage = "Failed to regenerate invite code: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    func copyCode() {
        UIPasteboard.general.string = inviteCode
    }
}


struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .font(.body.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.purple)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}


@available(iOS 17.0, *)
struct InviteCodeView_Previews: PreviewProvider {
    static var previews: some View {
        let session = LiveSession(
            title: "Morning Prayer",
            description: "Join us for morning prayer and devotional",
            hostId: "test-user",
            category: "Prayer"
        )
        InviteCodeView(session: session)
            .modelContainer(for: [SessionInvitation.self, LiveSession.self], inMemory: true)
    }
}

// MARK: - ActivityView Helper
struct InviteCodeActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

