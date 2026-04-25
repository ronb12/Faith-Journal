//
//  ExportHelper.swift
//  Faith Journal
//
//  Export functionality for journal entries
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class ExportHelper {
    static let shared = ExportHelper()

    private init() {}

    func exportJournalEntryAsPDF(_ entry: Any) throws -> URL {
        guard #available(iOS 17.0, macOS 14.0, *), let entry = entry as? JournalEntry else {
            throw NSError(domain: "ExportHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "PDF export requires iOS 17+ / macOS 14+"])
        }
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(entry.title.replacingOccurrences(of: " ", with: "_")).pdf")

        #if os(iOS)
        let pdfMetaData = [
            kCGPDFContextCreator: "Faith Journal",
            kCGPDFContextAuthor: "User",
            kCGPDFContextTitle: entry.title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
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
            entry.title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: entry.date)
            dateString.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: dateAttributes)
            yPosition += 30
            let contentRect = CGRect(x: 50, y: yPosition, width: pageRect.width - 100, height: pageRect.height - yPosition - 50)
            entry.content.draw(in: contentRect, withAttributes: bodyAttributes)
            if !entry.tags.isEmpty {
                yPosition = pageRect.height - 60
                let tagsText = "Tags: \(entry.tags.joined(separator: ", "))"
                tagsText.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: dateAttributes)
            }
        }
        try data.write(to: tempURL)
        #elseif os(macOS)
        var mediaBox = pageRect
        guard let context = CGContext(tempURL as CFURL, mediaBox: &mediaBox, [kCGPDFContextCreator: "Faith Journal", kCGPDFContextAuthor: "User", kCGPDFContextTitle: entry.title] as CFDictionary) else {
            throw NSError(domain: "ExportHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.labelColor
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.labelColor
        ]
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        var yPos: CGFloat = 60
        NSAttributedString(string: entry.title, attributes: titleAttrs).draw(at: CGPoint(x: 50, y: pageRect.height - yPos - 24))
        yPos += 40
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: entry.date)
        NSAttributedString(string: dateString, attributes: dateAttrs).draw(at: CGPoint(x: 50, y: pageRect.height - yPos - 12))
        yPos += 30
        let contentRect = CGRect(x: 50, y: 50, width: pageRect.width - 100, height: pageRect.height - yPos - 100)
        NSAttributedString(string: entry.content, attributes: bodyAttrs).draw(in: contentRect)
        if !entry.tags.isEmpty {
            let tagsText = "Tags: \(entry.tags.joined(separator: ", "))"
            NSAttributedString(string: tagsText, attributes: dateAttrs).draw(at: CGPoint(x: 50, y: 60))
        }
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        #endif
        return tempURL
    }
    
    func exportJournalEntryAsText(_ entry: Any) -> String {
        guard #available(iOS 17.0, macOS 14.0, *), let entry = entry as? JournalEntry else {
            return "Export as text requires iOS 17+ / macOS 14+"
        }
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
    
    func shareJournalEntry(_ entry: Any, format: ExportFormat = .text) -> [Any] {
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
    let entry: Any
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .text
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        if #available(iOS 17.0, macOS 14.0, *), let entry = entry as? JournalEntry {
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
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    ActivityView(activityItems: shareItems)
                }
                #elseif os(macOS)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button("Done") { dismiss() }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    MacShareSheet(shareItems: shareItems)
                }
                #endif
            }
        } else {
            Text("Export is only available on iOS 17+ / macOS 14+")
        }
    }
}

#if os(macOS)
struct MacShareSheet: View {
    let shareItems: [Any]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Export complete")
                .font(.headline)
            HStack(spacing: 16) {
                Button("Copy to Clipboard") {
                    if let str = shareItems.first as? String {
                        PlatformPasteboard.setString(str)
                    }
                    dismiss()
                }
                Button("Save to File...") {
                    saveToFile()
                    dismiss()
                }
                Button("Done") { dismiss() }
            }
        }
        .padding(40)
        .frame(minWidth: 300)
    }

    private func saveToFile() {
        if let url = shareItems.first as? URL {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf, .plainText]
            panel.nameFieldStringValue = url.lastPathComponent
            panel.directoryURL = url.deletingLastPathComponent()
            panel.begin { response in
                if response == .OK, let destURL = panel.url {
                    try? FileManager.default.copyItem(at: url, to: destURL)
                }
            }
        } else if let str = shareItems.first as? String {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = "journal_export.txt"
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    try? str.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        }
    }
}
#endif