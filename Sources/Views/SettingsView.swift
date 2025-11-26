import SwiftUI

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    private var feedbackURL: URL {
        URL(string: "https://github.com/faithjournal/issues")!
    }

    var body: some View {
        NavigationView {
            List {
                Section("Appearance") {
                    Text("Theme: \(themeManager.currentTheme.rawValue)")
                }
                Section("App Info") {
                    Text("Version 1.0")
                }
                Section("Feedback") {
                    Link("Report an issue", destination: feedbackURL)
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
#endif
            .navigationTitle("Settings")
        }
    }
}

