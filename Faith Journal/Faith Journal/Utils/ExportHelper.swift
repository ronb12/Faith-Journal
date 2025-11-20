//
//  ExportHelper.swift
//  Faith Journal
//
//  Export functionality for journal entries
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

class ExportHelper {
    static let shared = ExportHelper()
    
    private init() {}
    
    func exportJournalEntryAsPDF(_ entry: JournalEntry) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "Faith Journal",
            kCGPDFContextAuthor: "User",
            kCGPDFContextTitle: entry.title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
            
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
            
            var yPosition: CGFloat = 60
            
            // Title
            entry.title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: entry.date)
            dateString.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: dateAttributes)
            yPosition += 30
            
            // Content
            let contentRect = CGRect(x: 50, y: yPosition, width: pageRect.width - 100, height: pageRect.height - yPosition - 50)
            entry.content.draw(in: contentRect, withAttributes: bodyAttributes)
            
            // Tags
            if !entry.tags.isEmpty {
                yPosition = pageRect.height - 60
                let tagsText = "Tags: \(entry.tags.joined(separator: ", "))"
                tagsText.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: dateAttributes)
            }
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(entry.title.replacingOccurrences(of: " ", with: "_")).pdf")
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    func exportJournalEntryAsText(_ entry: JournalEntry) -> String {
        var text = """
        \(entry.title)
        \(String(repeating: "=", count: entry.title.count))
        
        Date: \(entry.date.formatted(date: .long, time: .shortened))
        
        \(entry.content)
        
        """
        
        if !entry.tags.isEmpty {
            text += "Tags: \(entry.tags.joined(separator: ", "))\n"
        }
        
        if let mood = entry.mood {
            text += "Mood: \(mood)\n"
        }
        
        return text
    }
    
    func shareJournalEntry(_ entry: JournalEntry, format: ExportFormat = .text) -> [Any] {
        switch format {
        case .pdf:
            if let pdfURL = try? exportJournalEntryAsPDF(entry) {
                return [pdfURL]
            } else {
                return [exportJournalEntryAsText(entry)]
            }
        case .text:
            return [exportJournalEntryAsText(entry)]
        }
    }
}

enum ExportFormat {
    case pdf
    case text
}

struct JournalExportView: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .text
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $selectedFormat) {
                        Text("Plain Text").tag(ExportFormat.text)
                        Text("PDF Document").tag(ExportFormat.pdf)
                    }
                }
                
                Section {
                    Button(action: {
                        shareItems = ExportHelper.shared.shareJournalEntry(entry, format: selectedFormat)
                        showingShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export & Share")
                        }
                    }
                }
            }
            .navigationTitle("Export Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(activityItems: shareItems)
            }
        }
    }
}
