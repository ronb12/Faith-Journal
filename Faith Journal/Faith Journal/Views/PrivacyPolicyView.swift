import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
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
                            title: "1. Introduction",
                            content: """
                            We are committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use the Faith Journal app ("App").
                            
                            By using the App, you consent to the data practices described in this policy.
                            """
                        )
                        
                        SectionView(
                            title: "2. Information We Collect",
                            content: """
                            We collect the following types of information:
                            
                            Personal Information:
                            - Name and email address (if you choose to provide them)
                            - Profile information you create
                            
                            Usage Data:
                            - Journal entries, prayer requests, and mood entries you create
                            - Preferences and settings you configure
                            - App usage patterns and interactions
                            
                            Device Information:
                            - Device type and operating system
                            - Unique device identifiers
                            - App version and crash reports
                            """
                        )
                        
                        SectionView(
                            title: "3. How We Use Your Information",
                            content: """
                            We use the information we collect to:
                            - Provide and maintain the App's functionality
                            - Sync your data across your devices via iCloud
                            - Improve and personalize your experience
                            - Send you notifications (if you opt in)
                            - Respond to your support requests
                            - Analyze usage patterns to enhance the App
                            """
                        )
                        
                        SectionView(
                            title: "4. Data Storage and iCloud",
                            content: """
                            Your data is stored locally on your device and synced to Apple's iCloud service when you enable iCloud sync.
                            
                            By using iCloud sync:
                            - Your data is encrypted in transit and at rest
                            - Your data is stored on Apple's servers
                            - Your data is subject to Apple's iCloud Terms and Conditions
                            - You can disable iCloud sync at any time in your device settings
                            
                            We do not have direct access to your iCloud data. Apple handles all iCloud storage and security.
                            """
                        )
                        
                        SectionView(
                            title: "5. CloudKit and Public Data",
                            content: """
                            The App uses Apple's CloudKit to enable certain features like Live Sessions and community sharing.
                            
                            When you participate in Live Sessions:
                            - Your session data may be stored in CloudKit's public database
                            - Your display name and user identifier may be visible to other participants
                            - Chat messages and session information are shared with session participants
                            
                            You can choose to create private sessions that are not shared publicly.
                            """
                        )
                        
                        SectionView(
                            title: "6. Data Sharing and Disclosure",
                            content: """
                            We do not sell, trade, or rent your personal information to third parties.
                            
                            We may share your information:
                            - With Apple (for iCloud and CloudKit services)
                            - With other users (only when you explicitly participate in shared features like Live Sessions)
                            - When required by law or to protect our rights
                            - In case of a business transfer or merger
                            """
                        )
                        
                        SectionView(
                            title: "7. Data Security",
                            content: """
                            We implement appropriate technical and organizational measures to protect your data:
                            - Data encryption in transit and at rest
                            - Secure authentication methods
                            - Regular security assessments
                            
                            However, no method of transmission over the internet or electronic storage is 100% secure. While we strive to protect your data, we cannot guarantee absolute security.
                            """
                        )
                        
                        SectionView(
                            title: "8. Your Rights and Choices",
                            content: """
                            You have the right to:
                            - Access your personal data stored in the App
                            - Export your data (available in Settings)
                            - Delete your account and data
                            - Opt out of data collection (by not using the App)
                            - Disable iCloud sync in your device settings
                            
                            To exercise these rights, use the App's settings or contact us through support channels.
                            """
                        )
                        
                        SectionView(
                            title: "9. Children's Privacy",
                            content: """
                            The App is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13.
                            
                            If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately.
                            """
                        )
                        
                        SectionView(
                            title: "10. Third-Party Services",
                            content: """
                            The App integrates with:
                            - Apple iCloud (for data syncing)
                            - Apple CloudKit (for Live Sessions)
                            - Apple's App Store (for app distribution)
                            
                            These services have their own privacy policies. We encourage you to review them.
                            """
                        )
                        
                        SectionView(
                            title: "11. Changes to This Policy",
                            content: """
                            We may update this Privacy Policy from time to time. We will notify you of any changes by:
                            - Updating the "Last Updated" date
                            - Posting the new policy in the App
                            - Sending you a notification (if significant changes occur)
                            
                            Your continued use of the App after changes constitutes acceptance of the updated policy.
                            """
                        )
                        
                        SectionView(
                            title: "12. Contact Us",
                            content: """
                            If you have questions or concerns about this Privacy Policy or our data practices, please contact us through the App's settings or support channels.
                            
                            We will respond to your inquiries as soon as possible.
                            """
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
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

