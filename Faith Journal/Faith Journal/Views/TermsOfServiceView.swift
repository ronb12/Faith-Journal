import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.colors.primary)
                        .padding(.top)
                    
                    Text("Last Updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(themeManager.colors.textSecondary)
                    
                    Divider()
                    
                    Group {
                        SectionView(
                            title: "1. Acceptance of Terms",
                            content: """
                            By downloading, installing, or using the Faith Journal app ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App.
                            
                            We reserve the right to modify these Terms at any time. Your continued use of the App after any changes constitutes your acceptance of the new Terms.
                            """
                        )
                        
                        SectionView(
                            title: "2. Description of Service",
                            content: """
                            Faith Journal is a mobile application designed to help users:
                            - Create and manage personal journal entries
                            - Track prayer requests and answers
                            - Record mood and spiritual reflections
                            - Participate in live faith-based sessions
                            - Access daily devotionals and Bible verses
                            
                            We reserve the right to modify, suspend, or discontinue any aspect of the App at any time.
                            """
                        )
                        
                        SectionView(
                            title: "3. User Accounts and Responsibilities",
                            content: """
                            You are responsible for:
                            - Maintaining the confidentiality of your account information
                            - All activities that occur under your account
                            - Ensuring your use of the App complies with all applicable laws
                            
                            You agree not to:
                            - Use the App for any illegal or unauthorized purpose
                            - Transmit any harmful code, viruses, or malicious software
                            - Attempt to gain unauthorized access to the App or its systems
                            - Interfere with or disrupt the App's functionality
                            """
                        )
                        
                        SectionView(
                            title: "4. User Content",
                            content: """
                            You retain ownership of all content you create, upload, or share through the App ("User Content").
                            
                            By using the App, you grant us a non-exclusive, worldwide, royalty-free license to:
                            - Store, process, and display your User Content to provide the App's services
                            - Use your User Content for technical and operational purposes
                            
                            You are solely responsible for your User Content and represent that you have all necessary rights to share it.
                            """
                        )
                        
                        SectionView(
                            title: "5. Privacy and Data",
                            content: """
                            Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.
                            
                            The App uses iCloud to sync your data across your devices. By using the App, you consent to the storage and processing of your data through Apple's iCloud services.
                            """
                        )
                        
                        SectionView(
                            title: "6. Live Sessions and Community Features",
                            content: """
                            The App may include features that allow you to interact with other users, including live sessions and community sharing.
                            
                            You agree to:
                            - Respect other users and maintain a positive, supportive environment
                            - Not share inappropriate, offensive, or harmful content
                            - Not use these features to spam, harass, or harm others
                            
                            We reserve the right to remove content or suspend accounts that violate these guidelines.
                            """
                        )
                        
                        SectionView(
                            title: "7. Intellectual Property",
                            content: """
                            The App, including its design, features, and content (excluding User Content), is owned by us and protected by copyright, trademark, and other intellectual property laws.
                            
                            You may not:
                            - Copy, modify, or create derivative works of the App
                            - Reverse engineer or attempt to extract the source code
                            - Use our trademarks or logos without permission
                            """
                        )
                        
                        SectionView(
                            title: "8. Disclaimers and Limitations",
                            content: """
                            THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED.
                            
                            We do not guarantee that:
                            - The App will be uninterrupted or error-free
                            - All features will always be available
                            - Your data will never be lost or corrupted
                            
                            You use the App at your own risk.
                            """
                        )
                        
                        SectionView(
                            title: "9. Limitation of Liability",
                            content: """
                            TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF THE APP.
                            
                            Our total liability shall not exceed the amount you paid for the App, if any.
                            """
                        )
                        
                        SectionView(
                            title: "10. Termination",
                            content: """
                            We may terminate or suspend your access to the App at any time, with or without cause or notice.
                            
                            Upon termination:
                            - Your right to use the App will immediately cease
                            - We may delete your account and User Content
                            - You may export your data before termination
                            """
                        )
                        
                        SectionView(
                            title: "11. Governing Law",
                            content: """
                            These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which we operate, without regard to its conflict of law provisions.
                            """
                        )
                        
                        SectionView(
                            title: "12. Contact Information",
                            content: """
                            If you have any questions about these Terms, please contact us through the App's settings or support channels.
                            """
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
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

struct SectionView: View {
    let title: String
    let content: String
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.colors.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TermsOfServiceView()
}

