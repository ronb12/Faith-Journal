import SwiftUI
import LocalAuthentication
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var journalEntries: [JournalEntry]
    @Query private var prayers: [PrayerRequest]
    @Query private var devotionals: [Devotional]
    
    @AppStorage("useBiometrics") private var useBiometrics = false
    @AppStorage("defaultPrivate") private var defaultPrivate = false
    @AppStorage("reminderNotifications") private var reminderNotifications = true
    @AppStorage("username") private var username = ""
    @State private var showingPrivacySheet = false
    @State private var showingAboutSheet = false
    @State private var showingClearConfirmation = false
    @State private var showingExportSheet = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Your Name", text: $username)
                }
                
                Section("Privacy & Security") {
                    Toggle("Use Face ID / Touch ID", isOn: $useBiometrics)
                    Toggle("Make New Entries Private by Default", isOn: $defaultPrivate)
                    
                    Button("Privacy Policy") {
                        showingPrivacySheet = true
                    }
                }
                
                Section("Notifications") {
                    Toggle("Prayer Reminders", isOn: $reminderNotifications)
                }
                
                Section("Data Management") {
                    Button("Export Data") {
                        exportData()
                    }
                    
                    Button("Import Data") {
                        // Handle import
                    }
                    
                    Button("Clear All Data", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }
                
                Section("About") {
                    Button("About Faith Journal") {
                        showingAboutSheet = true
                    }
                    
                    Link("Rate on App Store", destination: URL(string: "https://apps.apple.com")!)
                    
                    Link("Send Feedback", destination: URL(string: "mailto:feedback@faithjournal.app")!)
                }
                
                Section {
                    Text("Version 1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert("Clear All Data", isPresented: $showingClearConfirmation) {
                Button("Delete", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete all data? This action cannot be undone.")
            }
            .sheet(isPresented: $showingExportSheet) {
                ShareLink(
                    item: exportDataToJSON(),
                    preview: SharePreview(
                        "Faith Journal Data",
                        image: Image(systemName: "doc.fill")
                    )
                )
            }
            .sheet(isPresented: $showingPrivacySheet) {
                NavigationStack {
                    ScrollView {
                        Text("Privacy Policy content...")
                            .padding()
                    }
                    .navigationTitle("Privacy Policy")
                    .toolbar {
                        Button("Done") {
                            showingPrivacySheet = false
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAboutSheet) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(systemName: "book.closed.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.blue)
                            
                            Text("Faith Journal")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Your personal space for spiritual reflection, prayer, and devotion.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            Text("Made with ❤️ by the Faith Journal team")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    .navigationTitle("About")
                    .toolbar {
                        Button("Done") {
                            showingAboutSheet = false
                        }
                    }
                }
            }
        }
    }
    
    private func clearAllData() {
        for entry in journalEntries {
            modelContext.delete(entry)
        }
        for prayer in prayers {
            modelContext.delete(prayer)
        }
        for devotional in devotionals {
            modelContext.delete(devotional)
        }
    }
    
    private func exportData() {
        showingExportSheet = true
    }
    
    private func exportDataToJSON() -> String {
        let data = [
            "journalEntries": journalEntries.map { entry in
                [
                    "title": entry.title,
                    "content": entry.content,
                    "date": entry.date.ISO8601Format(),
                    "mood": entry.mood ?? "",
                    "location": entry.location ?? "",
                    "bibleReference": entry.bibleReference ?? "",
                    "prayerPoints": entry.prayerPoints,
                    "tags": entry.tags,
                    "isPrivate": entry.isPrivate
                ]
            },
            "prayers": prayers.map { prayer in
                [
                    "title": prayer.title,
                    "details": prayer.details,
                    "dateCreated": prayer.dateCreated.ISO8601Format(),
                    "dateAnswered": prayer.dateAnswered?.ISO8601Format() ?? "",
                    "status": prayer.status.rawValue,
                    "category": prayer.category ?? "",
                    "reminderDate": prayer.reminderDate?.ISO8601Format() ?? "",
                    "isPrivate": prayer.isPrivate,
                    "tags": prayer.tags
                ]
            },
            "devotionals": devotionals.map { devotional in
                [
                    "title": devotional.title,
                    "scripture": devotional.scripture,
                    "reflection": devotional.reflection,
                    "date": devotional.date.ISO8601Format(),
                    "tags": devotional.tags,
                    "mood": devotional.mood ?? "",
                    "isPrivate": devotional.isPrivate,
                    "relatedVerses": devotional.relatedVerses,
                    "prayerPoints": devotional.prayerPoints
                ]
            }
        ]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        return String(data: jsonData ?? Data(), encoding: .utf8) ?? "{}"
    }
}

#Preview {
    SettingsView()
} 