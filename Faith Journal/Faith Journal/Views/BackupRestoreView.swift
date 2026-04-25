//
//  BackupRestoreView.swift
//  Faith Journal
//
//  Comprehensive backup and restore interface
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
struct BackupRestoreView: View {
    @StateObject private var backupService = BackupRestoreService.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var showingCreateBackup = false
    @State private var showingRestoreBackup = false
    @State private var showingExportPDF = false
    @State private var showingRestoreConfirmation = false
    @State private var selectedBackupURL: URL?
    @State private var restoreMerge = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var backupSuccess = false
    @State private var createdBackupURL: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Automatic Backups Section
                Section {
                    Toggle("Automatic Backups", isOn: $backupService.automaticBackupsEnabled)
                        .onChange(of: backupService.automaticBackupsEnabled) { _, _ in
                            backupService.savePreferences()
                        }
                    
                    if backupService.automaticBackupsEnabled {
                        Picker("Frequency", selection: $backupService.backupFrequency) {
                            ForEach(BackupRestoreService.BackupFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                        .onChange(of: backupService.backupFrequency) { _, _ in
                            backupService.savePreferences()
                        }
                    }
                    
                    if let lastBackup = backupService.lastBackupDate {
                        HStack {
                            Text("Last Backup")
                            Spacer()
                            Text(lastBackup.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Last Backup")
                            Spacer()
                            Text("Never")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Automatic Backups")
                } footer: {
                    Text("Automatically backup your data to keep it safe")
                }
                
                // Manual Backup Section
                Section {
                    Button(action: createBackup) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Create Backup Now")
                        }
                        .foregroundColor(themeManager.colors.primary)
                    }
                    .disabled(backupService.isBackingUp)
                    
                    if backupService.isBackingUp {
                        ProgressView(value: backupService.backupProgress)
                            .padding(.vertical, 4)
                    }
                    
                    Button(action: exportJournalAsPDF) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Export Journal as PDF")
                        }
                        .foregroundColor(themeManager.colors.primary)
                    }
                } header: {
                    Text("Manual Backup")
                } footer: {
                    Text("Create a backup file containing all your journal entries, prayers, and other data")
                }
                
                // Restore Section
                Section {
                    Button(action: { showingRestoreBackup = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Restore from Backup")
                        }
                        .foregroundColor(themeManager.colors.primary)
                    }
                    
                    Toggle("Merge with Existing Data", isOn: $restoreMerge)
                } header: {
                    Text("Restore")
                } footer: {
                    Text("Restore your data from a backup file. Enable merge to add backup data without removing existing entries.")
                }
                
                // Backup Info Section
                Section("About Backups") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your backup includes:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• All journal entries")
                            Text("• All prayer requests")
                            Text("• Mood tracking data")
                            Text("• Bible highlights and notes")
                            Text("• Bookmarked verses")
                            Text("• Reading plans")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Text("Backups are stored locally on your device. For cloud backup, use the Share button to save to iCloud Drive or another cloud service.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Backup & Restore")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
            .fileImporter(
                isPresented: $showingRestoreBackup,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedBackupURL = url
                        showingRestoreConfirmation = true
                    }
                case .failure(let error):
                    errorMessage = "Failed to select backup file: \(error.localizedDescription)"
                    showingError = true
                }
            }
            .alert("Backup Created!", isPresented: $backupSuccess) {
                Button("Share") {
                    if let url = createdBackupURL {
                        shareBackup(url: url)
                    }
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your backup has been created successfully.")
            }
            .alert("Restore Backup?", isPresented: $showingRestoreConfirmation) {
                Button("Restore", role: .destructive) {
                    if let url = selectedBackupURL {
                        restoreBackup(from: url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(restoreMerge ? "This will add backup data to your existing entries." : "This will replace your current data with the backup. Make sure you have a recent backup first.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = createdBackupURL {
                    #if os(macOS)
                    MacShareSheet(shareItems: [url])
                    #else
                    BackupShareSheet(items: [url])
                    #endif
                }
            }
        }
    }
    
    private func createBackup() {
        Task {
            do {
                let backupURL = try await backupService.createBackup(modelContext: modelContext)
                await MainActor.run {
                    createdBackupURL = backupURL
                    backupSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create backup: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func restoreBackup(from url: URL) {
        Task {
            do {
                try await backupService.restoreBackup(from: url, modelContext: modelContext, merge: restoreMerge)
                await MainActor.run {
                    errorMessage = "Backup restored successfully!"
                    showingError = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to restore backup: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func exportJournalAsPDF() {
        Task {
            do {
                let descriptor = FetchDescriptor<JournalEntry>(
                    sortBy: [SortDescriptor(\JournalEntry.date, order: .reverse)]
                )
                let entries = try modelContext.fetch(descriptor)
                
                let pdfURL = try await backupService.exportJournalAsPDF(entries: entries)
                
                await MainActor.run {
                    createdBackupURL = pdfURL
                    shareBackup(url: pdfURL)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to export PDF: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func shareBackup(url: URL) {
        #if os(iOS)
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                          y: rootViewController.view.bounds.midY,
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(activityViewController, animated: true)
        }
        #elseif os(macOS)
        showingShareSheet = true
        #endif
    }
}

#if os(iOS)
private struct BackupShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
