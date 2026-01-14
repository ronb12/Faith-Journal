//
//  MoodExportView.swift
//  Faith Journal
//
//  Mood data export view
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@available(iOS 17.0, *)
struct MoodExportView: View {
    @Query(sort: [SortDescriptor(\MoodEntry.date, order: .reverse)]) var entries: [MoodEntry]
    // Use regular property for singleton, not @StateObject
    private let analyticsService = MoodAnalyticsService.shared
    @State private var exportFormat: ExportFormat = .csv
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL?
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        case pdf = "PDF Report"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                }
                
                Section(header: Text("Export Options")) {
                    Button(action: performExport) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Data")
                        }
                    }
                }
                
                Section(header: Text("Statistics")) {
                    HStack {
                        Text("Total Entries")
                        Spacer()
                        Text("\(entries.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Date Range")
                        Spacer()
                        if let first = entries.last?.date, let last = entries.first?.date {
                            Text("\(first, style: .date) - \(last, style: .date)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                if let exportFileURL = exportFileURL {
                    MoodExportShareSheet(items: [exportFileURL])
                }
            }
        }
    }
    
    private func performExport() {
        let exportService = MoodExportService.shared
        let tempDir = FileManager.default.temporaryDirectory
        
        switch exportFormat {
        case .csv:
            let csv = exportService.exportToCSV(entries: entries)
            let url = tempDir.appendingPathComponent("mood_data.csv")
            try? csv.write(to: url, atomically: true, encoding: String.Encoding.utf8)
            exportFileURL = url
            
        case .json:
            if let jsonData = exportService.exportToJSON(entries: entries) {
                let url = tempDir.appendingPathComponent("mood_data.json")
                try? jsonData.write(to: url)
                exportFileURL = url
            }
            
        case .pdf:
            Task { @MainActor in
                if let pdfData = exportService.generatePDFReport(entries: entries, analytics: analyticsService) {
                    let url = tempDir.appendingPathComponent("mood_report.txt")
                    try? pdfData.write(to: url)
                    exportFileURL = url
                    showingShareSheet = true
                }
            }
            return
        }
        
        showingShareSheet = true
    }
}

struct MoodExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
