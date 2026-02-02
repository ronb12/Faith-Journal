import Foundation
import UniformTypeIdentifiers
import SwiftUI
import UIKit

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

        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
        guard let contentType = resourceValues.contentType else {
            throw PresentationError.unsupportedType
        }

        let assetType: PresentationAsset.AssetType
        if contentType.conforms(to: .pdf) {
            assetType = .pdf
        } else if contentType.conforms(to: .image) {
            assetType = .image
        } else {
            throw PresentationError.unsupportedType
        }
        let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        let needsStop = url.startAccessingSecurityScopedResource()
        defer {
            if needsStop {
                url.stopAccessingSecurityScopedResource()
            }
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
                .font: UIFont.systemFont(ofSize: 24, weight: .bold)
            ]
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
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
    }

    func clearPresentation() {
        currentAsset = nil
    }
}
