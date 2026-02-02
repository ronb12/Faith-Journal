//
//  TranslationSettingsView.swift
//  Faith Journal
//
//  UI for managing translation settings and language preferences
//

import SwiftUI

@available(iOS 17.0, *)
struct TranslationSettingsView: View {
    @ObservedObject private var translationService = TranslationService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage: String
    @State private var autoTranslateEnabled = true
    
    init() {
        _selectedLanguage = State(initialValue: TranslationService.shared.defaultTargetLanguage)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Auto-Translate Messages", isOn: $autoTranslateEnabled)
                } header: {
                    Text("Translation Settings")
                } footer: {
                    Text("When enabled, messages in other languages will automatically show translation options")
                }
                
                Section {
                    Picker("Default Translation Language", selection: $selectedLanguage) {
                        ForEach(translationService.supportedLanguages, id: \.code) { language in
                            HStack {
                                Text(language.name)
                                Spacer()
                                if language.code == selectedLanguage {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .tag(language.code)
                        }
                    }
                    .onChange(of: selectedLanguage) { _, newValue in
                        translationService.defaultTargetLanguage = newValue
                    }
                } header: {
                    Text("Target Language")
                } footer: {
                    Text("Messages will be translated to this language when you tap 'Translate'")
                }
                
                Section {
                    ForEach(translationService.supportedLanguages, id: \.code) { language in
                        HStack {
                            Text(language.name)
                            Spacer()
                            Text(language.code.uppercased())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Supported Languages")
                } footer: {
                    Text("These languages are supported for chat message translation")
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Translation Service")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Uses iOS native translation (iOS 18.0+). Language detection available on iOS 12+. Translation uses Apple's native Translation framework - same engine as iOS system-wide translation. Language models download automatically on first use and work offline. Supports 28 languages.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Translation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        translationService.defaultTargetLanguage = selectedLanguage
                        dismiss()
                    }
                }
            }
        }
    }
}
