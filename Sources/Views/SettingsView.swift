import SwiftUI

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedTheme: ThemeManager.Theme = .default
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(ThemeManager.Theme.allCases, id: \.self) { theme in
                            Text(theme.rawValue)
                        }
                    }
                    .onChange(of: selectedTheme) { newTheme in
                        themeManager.currentTheme = newTheme
                    }
                }
                Section(header: Text("About")) {
                    Text("Faith Journal v1.0")
                    Text("Developed for spiritual growth and reflection.")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                selectedTheme = themeManager.currentTheme
            }
        }
    }
} 