import SwiftUI
import Foundation
import UserNotifications
import LocalAuthentication

struct SettingsView: View {
    @AppStorage("selectedTheme") private var selectedTheme: String = "System"
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = false
    @AppStorage("reminderTime") private var reminderTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = false
    @State private var showResetAlert = false
    @State private var showExportSheet = false
    @State private var exportData: String = ""
    @State private var showAuthLock = false
    @State private var isAuthenticated = false
    
    let themes = ["System", "Light", "Dark", "Purple", "Blue", "Green"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Reminders")) {
                    Toggle("Daily Reminder", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, enabled in
                            if enabled {
                                scheduleDailyReminder(at: reminderTime)
                            } else {
                                cancelDailyReminder()
                            }
                        }
                    if reminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _, newTime in
                                if reminderEnabled {
                                    scheduleDailyReminder(at: newTime)
                                }
                            }
                    }
                }
                
                Section(header: Text("Privacy & Security")) {
                    Toggle("Enable Biometric Lock", isOn: $biometricEnabled)
                        .onChange(of: biometricEnabled) { _, enabled in
                            if enabled {
                                showAuthLock = true
                            }
                        }
                }
                
                Section(header: Text("Data")) {
                    Button("Export Data") {
                        exportData = exportAllData()
                        showExportSheet = true
                    }
                    .sheet(isPresented: $showExportSheet) {
                        ActivityView(activityItems: [exportData])
                    }
                    Button("Reset App Data", role: .destructive) {
                        showResetAlert = true
                    }
                    .alert("Reset All Data?", isPresented: $showResetAlert) {
                        Button("Delete Everything", role: .destructive) {
                            resetAllData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all your journal entries, prayers, and settings. This cannot be undone.")
                    }
                }
                
                Section(header: Text("App Info")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Contact Support")
                        Spacer()
                        Link("Email", destination: URL(string: "mailto:support@faithjournal.app")!)
                    }
                    HStack {
                        Text("About")
                        Spacer()
                        Text("Faith Journal helps you grow in faith, one day at a time.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $showAuthLock) {
                BiometricLockView(isAuthenticated: $isAuthenticated)
            }
        }
    }
    
    // REMINDERS
    func scheduleDailyReminder(at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Faith Journal"
            content.body = "Don't forget to reflect and journal today!"
            content.sound = .default
            let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
            center.add(request)
        }
    }
    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
    }
    
    // BIOMETRIC
    struct BiometricLockView: View {
        @Binding var isAuthenticated: Bool
        @Environment(\.dismiss) var dismiss
        @State private var errorMessage: String?
        var body: some View {
            VStack(spacing: 24) {
                Text("Unlock Faith Journal")
                    .font(.title)
                    .fontWeight(.bold)
                Button("Unlock with Face ID / Touch ID") {
                    authenticate()
                }
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            .onAppear(perform: authenticate)
        }
        func authenticate() {
            let context = LAContext()
            var error: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Faith Journal") { success, authError in
                    DispatchQueue.main.async {
                        if success {
                            isAuthenticated = true
                            dismiss()
                        } else {
                            errorMessage = "Authentication failed. Try again."
                        }
                    }
                }
            } else {
                errorMessage = "Biometric authentication not available."
            }
        }
    }
    
    // EXPORT DATA (replace with real data fetch)
    func exportAllData() -> String {
        // TODO: Replace with real data export logic
        let entries = ["Sample Journal Entry", "Sample Prayer Request"]
        let jsonData = try? JSONEncoder().encode(entries)
        return String(data: jsonData ?? Data(), encoding: .utf8) ?? "No data"
    }
    
    // RESET DATA
    func resetAllData() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        // TODO: Also delete all SwiftData/CoreData if used
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 