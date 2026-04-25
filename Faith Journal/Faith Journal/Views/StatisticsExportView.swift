//
//  StatisticsExportView.swift
//  Faith Journal
//
//  Export statistics as PDF/CSV view
//

import SwiftUI
import PDFKit

@available(iOS 17.0, *)
struct StatisticsExportView: View {
    let entries: [JournalEntry]
    let prayers: [PrayerRequest]
    let moods: [MoodEntry]
    let plans: [ReadingPlan]
    let statsService: StatisticsService
    
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: ExportFormat = .pdf
    @State private var showingShareSheet = false
    @State private var exportData: Data?
    
    enum ExportFormat {
        case pdf, csv, json
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $exportFormat) {
                        Text("PDF Report").tag(ExportFormat.pdf)
                        Text("CSV Data").tag(ExportFormat.csv)
                        Text("JSON Data").tag(ExportFormat.json)
                    }
                }
                
                Section(header: Text("Statistics Included")) {
                    Toggle("Journal Entries", isOn: .constant(true))
                    Toggle("Prayer Requests", isOn: .constant(true))
                    Toggle("Mood Check-ins", isOn: .constant(true))
                    Toggle("Reading Plans", isOn: .constant(true))
                }
                
                Section {
                    Button(action: exportStatistics) {
                        HStack {
                            Spacer()
                            Text("Export Statistics")
                                .font(.body.weight(.semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Export Statistics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
            .sheet(isPresented: $showingShareSheet) {
                if let data = exportData {
                    StatisticsShareSheet(data: data, format: exportFormat)
                }
            }
        }
    }
    
    private func exportStatistics() {
        switch exportFormat {
        case .pdf:
            exportData = generatePDFReport()
        case .csv:
            exportData = generateCSVData()?.data(using: .utf8)
        case .json:
            exportData = generateJSONData()
        }
        
        if exportData != nil {
            showingShareSheet = true
        }
    }
    
    private func generatePDFReport() -> Data? {
        // Simplified PDF generation - would need proper PDFKit implementation
        let text = """
        Faith Journal Statistics Report
        Generated: \(Date())
        
        Journal Entries: \(entries.count)
        Prayer Requests: \(prayers.count)
        Mood Check-ins: \(moods.count)
        Reading Plans: \(plans.count)
        
        Total Words: \(statsService.getTotalWords(entries: entries))
        Average Entry Length: \(statsService.getAverageEntryLength(entries: entries)) words
        """
        
        return text.data(using: .utf8)
    }
    
    private func generateCSVData() -> String? {
        var csv = "Type,Count\n"
        csv += "Journal Entries,\(entries.count)\n"
        csv += "Prayer Requests,\(prayers.count)\n"
        csv += "Mood Check-ins,\(moods.count)\n"
        csv += "Reading Plans,\(plans.count)\n"
        csv += "Total Words,\(statsService.getTotalWords(entries: entries))\n"
        csv += "Average Entry Length,\(statsService.getAverageEntryLength(entries: entries))\n"
        return csv
    }
    
    private func generateJSONData() -> Data? {
        let json: [String: Any] = [
            "generated": ISO8601DateFormatter().string(from: Date()),
            "statistics": [
                "journalEntries": entries.count,
                "prayerRequests": prayers.count,
                "moodCheckins": moods.count,
                "readingPlans": plans.count,
                "totalWords": statsService.getTotalWords(entries: entries),
                "averageEntryLength": statsService.getAverageEntryLength(entries: entries)
            ]
        ]
        
        return try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
    }
}

@available(iOS 17.0, *)
struct StatisticsShareSheet: UIViewControllerRepresentable {
    let data: Data
    let format: StatisticsExportView.ExportFormat
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("statistics.\(format == .pdf ? "pdf" : format == .csv ? "csv" : "json")")
        try? data.write(to: tempURL)
        
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

