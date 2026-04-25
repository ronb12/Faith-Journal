//
//  ContactSupportView.swift
//  Faith Journal
//
//  Contact support view for sending email
//

import SwiftUI
import MessageUI

@available(iOS 17.0, *)
struct ContactSupportView: View {
    @Environment(\.dismiss) var dismiss
    @State private var issueTitle: String = ""
    @State private var issueDescription: String = ""
    @State private var deviceInfo: String = ""
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage: String = ""
    @State private var showingEmailComposer = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Issue Details")) {
                    TextField("Issue Title", text: $issueTitle)
                        .textInputAutocapitalization(.words)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.primary)
                        TextEditor(text: $issueDescription)
                            .frame(minHeight: 150)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                Section {
                    Text(deviceInfo)
                        .font(.caption)
                        .foregroundColor(.primary)
                } header: {
                    Text("Device Information")
                } footer: {
                    Text("This information helps us diagnose issues. It will be included in your support email.")
                }
                
                Section {
                    Button(action: sendEmail) {
                        HStack {
                            Spacer()
                            if showingSuccess {
                                Label("Email Sent", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Label("Send Email", systemImage: "envelope.fill")
                            }
                            Spacer()
                        }
                    }
                    .disabled(issueTitle.isEmpty || issueDescription.isEmpty || showingSuccess)
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadDeviceInfo()
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your email has been sent successfully. We'll get back to you as soon as possible!")
            }
            .sheet(isPresented: $showingEmailComposer) {
                if MFMailComposeViewController.canSendMail() {
                    SupportEmailComposerView(
                        recipient: "ronellbradley@gmail.com",
                        subject: "Faith Journal Support: \(issueTitle)",
                        body: createEmailBody(),
                        onEmailSent: {
                            showingSuccess = true
                        }
                    )
                } else {
                    // Fallback to mailto: link if Mail app is not configured
                    VStack(spacing: 20) {
                        Text("Mail Not Configured")
                            .font(.headline)
                        Text("Please configure Mail in Settings to send support emails.")
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Open Mail Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                    }
                    .padding()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadDeviceInfo() {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = device.model
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        deviceInfo = """
        Device: \(model)
        iOS Version: \(systemVersion)
        App Version: \(appVersion) (\(buildNumber))
        """
    }
    
    private func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            showingEmailComposer = true
        } else {
            // Fallback to mailto: link
            let subject = issueTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let body = createEmailBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let mailtoURL = "mailto:ronellbradley@gmail.com?subject=\(subject)&body=\(body)"
            
            if let url = URL(string: mailtoURL) {
                UIApplication.shared.open(url) { success in
                    if success {
                        showingSuccess = true
                    } else {
                        errorMessage = "Could not open Mail app. Please configure Mail in Settings."
                        showingError = true
                    }
                }
            } else {
                errorMessage = "Could not create email. Please try again."
                showingError = true
            }
        }
    }
    
    private func createEmailBody() -> String {
        return """
        Issue Description:
        \(issueDescription)
        
        ---
        
        Device Information:
        \(deviceInfo)
        
        ---
        
        This message was sent from the Faith Journal app.
        """
    }
}

// Email Composer for Contact Support
struct SupportEmailComposerView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    var onEmailSent: (() -> Void)?
    
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
        Coordinator(dismiss: dismiss, onEmailSent: onEmailSent)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        let onEmailSent: (() -> Void)?
        
        init(dismiss: DismissAction, onEmailSent: (() -> Void)?) {
            self.dismiss = dismiss
            self.onEmailSent = onEmailSent
        }
        
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) {
                if result == .sent {
                    self.onEmailSent?()
                }
                self.dismiss()
            }
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    ContactSupportView()
}

