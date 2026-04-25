import Foundation
import UniformTypeIdentifiers
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class PresentationService: ObservableObject {
    static let shared = PresentationService()

    struct PresentationAsset: Identifiable, Equatable {
        enum AssetType: Equatable {
            case pdf
            case image
        }

        let id: UUID
        let title: String
        let fileURL: URL
        let type: AssetType
    }

    enum PresentationError: LocalizedError {
        case unsupportedType
        case missingDirectory

        var errorDescription: String? {
            switch self {
            case .unsupportedType:
                return "Selected file is not supported. Please choose a PDF or image."
            case .missingDirectory:
                return "Unable to prepare storage for presentations."
            }
        }
    }

    @Published var currentAsset: PresentationAsset?

    private let presentationsDirectory: URL?

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let dir = documents?.appendingPathComponent("Presentations", isDirectory: true)
        if let directory = dir {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                presentationsDirectory = directory
            } catch {
                presentationsDirectory = nil
                print("⚠️ [PresentationService] Could not create presentations directory: \(error.localizedDescription)")
            }
        } else {
            presentationsDirectory = nil
        }
    }

    func presentMaterial(from url: URL, title: String? = nil) async throws {
        guard let directory = presentationsDirectory else {
            throw PresentationError.missingDirectory
        }

        // Access security-scoped resource first (required for fileImporter URLs from Files/iCloud)
        let needsStop = url.startAccessingSecurityScopedResource()
        defer {
            if needsStop {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let contentType: UTType?
        if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]) {
            contentType = resourceValues.contentType
        } else {
            contentType = nil
        }

        let assetType: PresentationAsset.AssetType
        if let ct = contentType, ct.conforms(to: .pdf) {
            assetType = .pdf
        } else if let ct = contentType, ct.conforms(to: .image) {
            assetType = .image
        } else if url.pathExtension.lowercased() == "pdf" {
            assetType = .pdf
        } else if ["jpg", "jpeg", "png", "heic", "gif"].contains(url.pathExtension.lowercased()) {
            assetType = .image
        } else {
            throw PresentationError.unsupportedType
        }
        let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: url, to: destination)

        let asset = PresentationAsset(
            id: UUID(),
            title: title ?? url.lastPathComponent,
            fileURL: destination,
            type: assetType
        )

        currentAsset = asset
    }

    /// Load presentation from a remote URL (e.g. for participants when host shares).
    func presentFromRemoteURL(_ urlString: String, title: String) async throws {
        guard let directory = presentationsDirectory else {
            throw PresentationError.missingDirectory
        }
        guard let url = URL(string: urlString) else { return }
        let (data, _) = try await URLSession.shared.data(from: url)
        let ext = url.pathExtension.isEmpty ? (urlString.lowercased().contains("pdf") ? "pdf" : "jpg") : url.pathExtension
        let destination = directory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try data.write(to: destination)
        let assetType: PresentationAsset.AssetType = (ext == "pdf") ? .pdf : .image
        currentAsset = PresentationAsset(id: UUID(), title: title, fileURL: destination, type: assetType)
    }

    func presentBibleStudy(topic: BibleStudyTopic) async throws {
        guard let directory = presentationsDirectory else {
            throw PresentationError.missingDirectory
        }

        let destination = directory.appendingPathComponent("\(topic.id.uuidString)-\(UUID().uuidString).pdf")
        try renderPDF(for: topic, to: destination)

        let asset = PresentationAsset(
            id: UUID(),
            title: topic.title,
            fileURL: destination,
            type: .pdf
        )

        currentAsset = asset
    }

    private func renderPDF(for topic: BibleStudyTopic, to url: URL) throws {
        struct TextSection {
            let heading: String
            let lines: [String]
        }

        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)

        #if os(iOS)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        try renderer.writePDF(to: url, withActions: { context in
            var currentY: CGFloat = 20
            let margin: CGFloat = 36
            let textWidth = pageBounds.width - margin * 2
            var pageStarted = false

            func ensurePageStarted() {
                if !pageStarted {
                    context.beginPage()
                    pageStarted = true
                }
            }

            func drawText(_ text: String, attributes: [NSAttributedString.Key: Any]) {
                ensurePageStarted()
                let text = text as NSString
                let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
                let boundingRect = text.boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                                                     options: options,
                                                     attributes: attributes,
                                                     context: nil)

                if currentY + boundingRect.height > pageBounds.height - 40 {
                    context.beginPage()
                    pageStarted = true
                    currentY = 20
                }

                text.draw(with: CGRect(x: margin, y: currentY, width: textWidth, height: boundingRect.height),
                          options: options,
                          attributes: attributes,
                          context: nil)

                currentY += boundingRect.height + 8
            }

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14)
            ]

            drawText(topic.title, attributes: titleAttributes)
            drawText("Category: \(topic.category.rawValue)", attributes: headingAttributes)
            drawText("Summary:", attributes: headingAttributes)
            drawText(topic.topicDescription, attributes: bodyAttributes)

            let sections: [TextSection] = [
                TextSection(heading: "Key Verses", lines: topic.keyVerses),
                TextSection(heading: "Verse Texts", lines: topic.verseTexts),
                TextSection(heading: "Study Questions", lines: topic.studyQuestions),
                TextSection(heading: "Discussion Prompts", lines: topic.discussionPrompts),
                TextSection(heading: "Application Points", lines: topic.applicationPoints)
            ]

            for section in sections where !section.lines.isEmpty {
                drawText(section.heading, attributes: headingAttributes)
                for line in section.lines {
                    drawText("• \(line)", attributes: bodyAttributes)
                }
            }
        })
        #elseif os(macOS)
        var mediaBox = pageBounds
        guard let pdfContext = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PresentationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }
        pdfContext.beginPDFPage(nil)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 24)]
        let headingAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16, weight: .semibold)]
        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14)]
        var y: CGFloat = pageBounds.height - 40
        let margin: CGFloat = 36
        let textWidth = pageBounds.width - margin * 2
        func drawMacText(_ text: String, attrs: [NSAttributedString.Key: Any]) {
            let str = NSAttributedString(string: text, attributes: attrs)
            str.draw(at: CGPoint(x: margin, y: y))
            y -= 24
        }
        drawMacText(topic.title, attrs: titleAttrs)
        drawMacText("Category: \(topic.category.rawValue)", attrs: headingAttrs)
        drawMacText("Summary:", attrs: headingAttrs)
        drawMacText(topic.topicDescription, attrs: bodyAttrs)
        for verse in topic.keyVerses { drawMacText("• \(verse)", attrs: bodyAttrs) }
        for line in topic.verseTexts { drawMacText("• \(line)", attrs: bodyAttrs) }
        for q in topic.studyQuestions { drawMacText("• \(q)", attrs: bodyAttrs) }
        for p in topic.discussionPrompts { drawMacText("• \(p)", attrs: bodyAttrs) }
        for a in topic.applicationPoints { drawMacText("• \(a)", attrs: bodyAttrs) }
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        #endif
    }

    func clearPresentation() {
        currentAsset = nil
    }
}
