import SwiftUI
import Foundation

#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension Color {
    static var platformSystemBackground: Color {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }

    static var platformSystemGray5: Color {
        #if os(iOS)
        Color(UIColor.systemGray5)
        #else
        Color(NSColor.separatorColor)
        #endif
    }

    static var platformSystemGray6: Color {
        #if os(iOS)
        Color(UIColor.systemGray6)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }

    static var platformSystemGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }

    static var platformSecondarySystemBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }

    static var platformTertiarySystemBackground: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemBackground)
        #else
        Color(NSColor.textBackgroundColor)
        #endif
    }

    static var platformPlaceholderText: Color {
        #if os(iOS)
        Color(UIColor.placeholderText)
        #else
        Color(NSColor.placeholderTextColor)
        #endif
    }

    static var platformSeparator: Color {
        #if os(iOS)
        Color(UIColor.separator)
        #else
        Color(NSColor.separatorColor)
        #endif
    }
}

#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#endif

/// Resize image to max dimension (for faster processing). Returns original if already small.
func platformImageResized(_ image: PlatformImage, maxDimension: CGFloat = 400) -> PlatformImage {
    #if os(iOS)
    let size = image.size
    guard size.width > maxDimension || size.height > maxDimension else { return image }
    let ratio = min(maxDimension / size.width, maxDimension / size.height)
    let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    #elseif os(macOS)
    let size = image.size
    guard size.width > maxDimension || size.height > maxDimension else { return image }
    let ratio = min(maxDimension / size.width, maxDimension / size.height)
    let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
    let newImage = NSImage(size: newSize)
    newImage.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: newSize))
    newImage.unlockFocus()
    return newImage
    #else
    return image
    #endif
}

/// Cross-platform image to JPEG data conversion
func platformImageToJPEGData(_ image: PlatformImage, quality: CGFloat = 0.8) -> Data? {
    #if os(iOS)
    return image.jpegData(compressionQuality: quality)
    #elseif os(macOS)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: Double(quality))])
    #else
    return nil
    #endif
}

/// Cross-platform create image from data
func platformImageFromData(_ data: Data) -> PlatformImage? {
    #if os(iOS)
    return UIImage(data: data)
    #elseif os(macOS)
    return NSImage(data: data)
    #else
    return nil
    #endif
}

/// SwiftUI Image from platform image (for use in views).
func platformImage(_ image: PlatformImage) -> Image {
    #if os(iOS)
    return Image(uiImage: image)
    #elseif os(macOS)
    return Image(nsImage: image)
    #else
    return Image(systemName: "photo")
    #endif
}

// MARK: - Faith-based thumbnail presets for live sessions

/// Preset cover images hosts can choose instead of uploading from device.
enum FaithThumbnailPreset: String, CaseIterable, Identifiable {
    case prayer = "Prayer"
    case bible = "Bible"
    case cross = "Cross"
    case worship = "Worship"
    case peace = "Peace"
    case heart = "Heart"
    case community = "Community"
    case hope = "Hope"
    case devotional = "Devotional"
    case faith = "Faith"
    
    var id: String { rawValue }
    
    /// Asset catalog image set name (FaithThumbnails/FaithThumbnail*.imageset).
    var assetImageName: String {
        switch self {
        case .prayer: return "FaithThumbnailPrayer"
        case .bible: return "FaithThumbnailBible"
        case .cross: return "FaithThumbnailCross"
        case .worship: return "FaithThumbnailWorship"
        case .peace: return "FaithThumbnailPeace"
        case .heart: return "FaithThumbnailHeart"
        case .community: return "FaithThumbnailCommunity"
        case .hope: return "FaithThumbnailHope"
        case .devotional: return "FaithThumbnailDevotional"
        case .faith: return "FaithThumbnailFaith"
        }
    }
    
    var symbolName: String {
        switch self {
        case .prayer: return "hands.sparkles.fill"
        case .bible: return "book.closed.fill"
        case .cross: return "cross.fill"
        case .worship: return "music.note"
        case .peace: return "leaf.fill"
        case .heart: return "heart.fill"
        case .community: return "person.3.fill"
        case .hope: return "sun.max.fill"
        case .devotional: return "book.fill"
        case .faith: return "star.fill"
        }
    }
}

/// Lightweight custom thumbnail styles for live sessions.
enum CustomThumbnailStyle: String, CaseIterable, Identifiable {
    case sunrise = "Sunrise"
    case violet = "Violet"
    case ocean = "Ocean"
    case forest = "Forest"
    case rose = "Rose"
    case midnight = "Midnight"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .sunrise: return "sun.max.fill"
        case .violet: return "sparkles"
        case .ocean: return "water.waves"
        case .forest: return "leaf.fill"
        case .rose: return "heart.fill"
        case .midnight: return "moon.stars.fill"
        }
    }
}

/// Faith-based virtual backgrounds for live streams. These are generated locally so hosts can hide their room/location without adding large binary assets to the app bundle.
enum FaithLiveBackgroundPreset: String, CaseIterable, Identifiable {
    case none = "None"
    case crossSunrise = "Cross Sunrise"
    case scriptureLight = "Scripture Light"
    case worshipGlow = "Worship Glow"
    case peaceGarden = "Peace Garden"
    case stainedGlass = "Stained Glass"
    case doveSky = "Dove Sky"
    case blur = "Privacy Blur"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .none: return "camera.fill"
        case .crossSunrise: return "cross.fill"
        case .scriptureLight: return "book.closed.fill"
        case .worshipGlow: return "music.note"
        case .peaceGarden: return "leaf.fill"
        case .stainedGlass: return "sparkles"
        case .doveSky: return "bird.fill"
        case .blur: return "camera.filters"
        }
    }

    var isVirtualBackground: Bool {
        self != .none
    }
}

/// Returns the bundled asset image for a faith preset, or nil if the asset is not in the app bundle. Use this to show the real thumbnail in the preset strip; use platformImageFromFaithPreset when you need an image (bundled or fallback) for upload.
func platformBundledImageForFaithPreset(_ preset: FaithThumbnailPreset, size: CGSize = CGSize(width: 400, height: 224)) -> PlatformImage? {
    #if os(iOS)
    guard let bundled = UIImage(named: preset.assetImageName),
          bundled.size.width > 1, bundled.size.height > 1 else { return nil }
    let targetRect = CGRect(origin: .zero, size: size)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in bundled.draw(in: targetRect) }
    #elseif os(macOS)
    guard let bundled = NSImage(named: preset.assetImageName),
          bundled.size.width > 1, bundled.size.height > 1 else { return nil }
    let targetSize = NSSize(width: size.width, height: size.height)
    let out = NSImage(size: targetSize)
    out.lockFocus()
    bundled.draw(in: NSRect(origin: .zero, size: targetSize))
    out.unlockFocus()
    return out
    #else
    return nil
    #endif
}

/// Renders a faith preset into a platform image (e.g. for live session thumbnail). Uses bundled asset image when available; otherwise draws gradient + symbol.
func platformImageFromFaithPreset(_ preset: FaithThumbnailPreset, size: CGSize = CGSize(width: 400, height: 224)) -> PlatformImage? {
    #if os(iOS)
    if let bundled = UIImage(named: preset.assetImageName), bundled.size.width > 1, bundled.size.height > 1 {
        let targetRect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            bundled.draw(in: targetRect)
        }
    }
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let rect = CGRect(origin: .zero, size: size)
        let (start, end): (UIColor, UIColor) = presetGradientColors(preset)
        let colors = [start.cgColor, end.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
        let config = UIImage.SymbolConfiguration(pointSize: min(size.width, size.height) * 0.35, weight: .medium)
        guard let symbol = UIImage(systemName: preset.symbolName, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
        let symbolRect = CGRect(x: (size.width - symbol.size.width) / 2, y: (size.height - symbol.size.height) / 2, width: symbol.size.width, height: symbol.size.height)
        symbol.draw(in: symbolRect)
    }
    #elseif os(macOS)
    if let bundled = NSImage(named: preset.assetImageName), bundled.size.width > 1, bundled.size.height > 1 {
        let targetSize = NSSize(width: size.width, height: size.height)
        let out = NSImage(size: targetSize)
        out.lockFocus()
        bundled.draw(in: NSRect(origin: .zero, size: targetSize))
        out.unlockFocus()
        return out
    }
    let image = NSImage(size: NSSize(width: size.width, height: size.height))
    image.lockFocus()
    let rect = NSRect(origin: .zero, size: size)
    let (start, end) = presetGradientColorsMac(preset)
    let gradient = NSGradient(starting: start, ending: end)!
    gradient.draw(in: rect, angle: 135)
    if let symbol = NSImage(systemSymbolName: preset.symbolName, accessibilityDescription: preset.rawValue) {
        let config = NSImage.SymbolConfiguration(pointSize: min(size.width, size.height) * 0.35, weight: .medium)
        let configured = symbol.withSymbolConfiguration(config) ?? symbol
        let symSize = configured.size
        let symbolRect = NSRect(x: (size.width - symSize.width) / 2, y: (size.height - symSize.height) / 2, width: symSize.width, height: symSize.height)
        configured.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
    image.unlockFocus()
    return image
    #else
    return nil
    #endif
}

/// Renders a user-designed live session thumbnail. The output uses the same image pipeline as uploaded photos and presets.
func platformImageFromCustomThumbnail(
    title: String,
    subtitle: String,
    style: CustomThumbnailStyle,
    symbolName: String,
    size: CGSize = CGSize(width: 1200, height: 675)
) -> PlatformImage? {
    #if os(iOS)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        let rect = CGRect(origin: .zero, size: size)
        let colors = customThumbnailUIColorPair(style)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [colors.0.cgColor, colors.1.cgColor] as CFArray, locations: [0, 1]) {
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        drawCustomThumbnailTextIOS(title: title, subtitle: subtitle, symbolName: symbolName, in: rect)
    }
    #elseif os(macOS)
    let image = NSImage(size: NSSize(width: size.width, height: size.height))
    image.lockFocus()
    let rect = NSRect(origin: .zero, size: size)
    let colors = customThumbnailNSColorPair(style)
    NSGradient(starting: colors.0, ending: colors.1)?.draw(in: rect, angle: 315)
    drawCustomThumbnailTextMac(title: title, subtitle: subtitle, symbolName: symbolName, in: rect)
    image.unlockFocus()
    return image
    #else
    return nil
    #endif
}

/// Renders a live stream background at 16:9. Keep the center calm because the host's face/body will usually be there.
func platformImageFromFaithLiveBackground(
    _ preset: FaithLiveBackgroundPreset,
    size: CGSize = CGSize(width: 1280, height: 720)
) -> PlatformImage? {
    guard preset != .none && preset != .blur else { return nil }
    #if os(iOS)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        let rect = CGRect(origin: .zero, size: size)
        drawFaithLiveBackgroundIOS(preset, in: rect, context: context.cgContext)
    }
    #elseif os(macOS)
    let image = NSImage(size: NSSize(width: size.width, height: size.height))
    image.lockFocus()
    drawFaithLiveBackgroundMac(preset, in: NSRect(origin: .zero, size: size))
    image.unlockFocus()
    return image
    #else
    return nil
    #endif
}

/// Writes the generated live stream background to Caches and returns a file URL suitable for Agora's virtual background API.
func platformFaithLiveBackgroundFileURL(for preset: FaithLiveBackgroundPreset) throws -> URL {
    guard let image = platformImageFromFaithLiveBackground(preset),
          let data = platformImageToJPEGData(image, quality: 0.9) else {
        throw NSError(domain: "FaithLiveBackground", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render live background."])
    }
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        .appendingPathComponent("FaithLiveBackgrounds", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let filename = preset.rawValue
        .lowercased()
        .replacingOccurrences(of: " ", with: "-")
        .appending(".jpg")
    let url = directory.appendingPathComponent(filename)
    try data.write(to: url, options: [.atomic])
    return url
}

#if os(iOS)
private func customThumbnailUIColorPair(_ style: CustomThumbnailStyle) -> (UIColor, UIColor) {
    switch style {
    case .sunrise: return (UIColor(red: 0.98, green: 0.64, blue: 0.24, alpha: 1), UIColor(red: 0.54, green: 0.23, blue: 0.72, alpha: 1))
    case .violet: return (UIColor(red: 0.43, green: 0.25, blue: 0.79, alpha: 1), UIColor(red: 0.13, green: 0.14, blue: 0.32, alpha: 1))
    case .ocean: return (UIColor(red: 0.04, green: 0.48, blue: 0.64, alpha: 1), UIColor(red: 0.05, green: 0.18, blue: 0.34, alpha: 1))
    case .forest: return (UIColor(red: 0.12, green: 0.48, blue: 0.32, alpha: 1), UIColor(red: 0.05, green: 0.22, blue: 0.18, alpha: 1))
    case .rose: return (UIColor(red: 0.82, green: 0.25, blue: 0.43, alpha: 1), UIColor(red: 0.33, green: 0.13, blue: 0.29, alpha: 1))
    case .midnight: return (UIColor(red: 0.06, green: 0.09, blue: 0.20, alpha: 1), UIColor(red: 0.22, green: 0.27, blue: 0.48, alpha: 1))
    }
}

private func drawCustomThumbnailTextIOS(title: String, subtitle: String, symbolName: String, in rect: CGRect) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineBreakMode = .byWordWrapping
    let shadow = NSShadow()
    shadow.shadowColor = UIColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = CGSize(width: 0, height: 3)
    shadow.shadowBlurRadius = 12
    if let symbol = UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 88, weight: .semibold))?.withTintColor(.white.withAlphaComponent(0.95), renderingMode: .alwaysOriginal) {
        symbol.draw(in: CGRect(x: 82, y: 78, width: 112, height: 112))
    }
    let titleText = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Live Session" : title
    let subtitleText = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    (titleText as NSString).draw(in: CGRect(x: 82, y: 246, width: rect.width - 164, height: 220), withAttributes: [
        .font: UIFont.systemFont(ofSize: 78, weight: .bold),
        .foregroundColor: UIColor.white,
        .paragraphStyle: paragraph,
        .shadow: shadow
    ])
    if !subtitleText.isEmpty {
        (subtitleText as NSString).draw(in: CGRect(x: 86, y: 488, width: rect.width - 172, height: 82), withAttributes: [
            .font: UIFont.systemFont(ofSize: 34, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.88),
            .paragraphStyle: paragraph,
            .shadow: shadow
        ])
    }
}

private func presetGradientColors(_ preset: FaithThumbnailPreset) -> (UIColor, UIColor) {
    switch preset {
    case .prayer: return (UIColor(red: 0.85, green: 0.65, blue: 0.2, alpha: 1), UIColor(red: 0.6, green: 0.4, blue: 0.1, alpha: 1))
    case .bible: return (UIColor(red: 0.2, green: 0.35, blue: 0.7, alpha: 1), UIColor(red: 0.1, green: 0.2, blue: 0.5, alpha: 1))
    case .cross: return (UIColor(red: 0.45, green: 0.25, blue: 0.65, alpha: 1), UIColor(red: 0.3, green: 0.15, blue: 0.5, alpha: 1))
    case .worship: return (UIColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1), UIColor(red: 0.7, green: 0.3, blue: 0.1, alpha: 1))
    case .peace: return (UIColor(red: 0.5, green: 0.75, blue: 0.9, alpha: 1), UIColor(red: 0.3, green: 0.55, blue: 0.75, alpha: 1))
    case .heart: return (UIColor(red: 0.85, green: 0.35, blue: 0.45, alpha: 1), UIColor(red: 0.65, green: 0.2, blue: 0.35, alpha: 1))
    case .community: return (UIColor(red: 0.2, green: 0.6, blue: 0.6, alpha: 1), UIColor(red: 0.1, green: 0.45, blue: 0.5, alpha: 1))
    case .hope: return (UIColor(red: 0.95, green: 0.8, blue: 0.25, alpha: 1), UIColor(red: 0.85, green: 0.6, blue: 0.1, alpha: 1))
    case .devotional: return (UIColor(red: 0.35, green: 0.3, blue: 0.65, alpha: 1), UIColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 1))
    case .faith: return (UIColor(red: 0.6, green: 0.4, blue: 0.75, alpha: 1), UIColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1))
    }
}

private func drawFaithLiveBackgroundIOS(_ preset: FaithLiveBackgroundPreset, in rect: CGRect, context: CGContext) {
    let colors = faithLiveBackgroundUIColorPair(preset)
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [colors.0.cgColor, colors.1.cgColor] as CFArray, locations: [0, 1]) {
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
    }
    context.setFillColor(UIColor.white.withAlphaComponent(0.10).cgColor)
    for index in 0..<7 {
        let diameter = rect.width * CGFloat(0.12 + Double(index % 3) * 0.035)
        let x = rect.width * CGFloat(0.08 + Double(index) * 0.145)
        let y = rect.height * CGFloat(index.isMultiple(of: 2) ? 0.18 : 0.72)
        context.fillEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
    }
    let symbolName = preset.symbolName
    if let symbol = UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 150, weight: .light))?.withTintColor(.white.withAlphaComponent(0.18), renderingMode: .alwaysOriginal) {
        symbol.draw(in: CGRect(x: rect.maxX - 280, y: 86, width: 170, height: 170))
    }
    if preset == .crossSunrise {
        context.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
        context.fill(CGRect(x: rect.midX - 10, y: 105, width: 20, height: 190))
        context.fill(CGRect(x: rect.midX - 70, y: 165, width: 140, height: 18))
    } else if preset == .stainedGlass {
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.16).cgColor)
        context.setLineWidth(3)
        for x in stride(from: rect.minX + 80, through: rect.maxX - 80, by: 120) {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x + 70, y: rect.maxY))
        }
        for y in stride(from: rect.minY + 70, through: rect.maxY - 70, by: 100) {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y + 20))
        }
        context.strokePath()
    }
    let vignette = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.28).cgColor] as CFArray, locations: [0.55, 1])
    if let vignette {
        context.drawRadialGradient(vignette, startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 80, endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: rect.width * 0.65, options: [])
    }
}

private func faithLiveBackgroundUIColorPair(_ preset: FaithLiveBackgroundPreset) -> (UIColor, UIColor) {
    switch preset {
    case .crossSunrise: return (UIColor(red: 0.95, green: 0.55, blue: 0.22, alpha: 1), UIColor(red: 0.20, green: 0.28, blue: 0.58, alpha: 1))
    case .scriptureLight: return (UIColor(red: 0.12, green: 0.42, blue: 0.54, alpha: 1), UIColor(red: 0.08, green: 0.12, blue: 0.27, alpha: 1))
    case .worshipGlow: return (UIColor(red: 0.50, green: 0.24, blue: 0.66, alpha: 1), UIColor(red: 0.12, green: 0.09, blue: 0.24, alpha: 1))
    case .peaceGarden: return (UIColor(red: 0.18, green: 0.54, blue: 0.40, alpha: 1), UIColor(red: 0.06, green: 0.22, blue: 0.23, alpha: 1))
    case .stainedGlass: return (UIColor(red: 0.18, green: 0.24, blue: 0.68, alpha: 1), UIColor(red: 0.67, green: 0.25, blue: 0.45, alpha: 1))
    case .doveSky: return (UIColor(red: 0.34, green: 0.64, blue: 0.86, alpha: 1), UIColor(red: 0.10, green: 0.20, blue: 0.42, alpha: 1))
    case .none, .blur: return (UIColor.black, UIColor.darkGray)
    }
}
#elseif os(macOS)
private func customThumbnailNSColorPair(_ style: CustomThumbnailStyle) -> (NSColor, NSColor) {
    switch style {
    case .sunrise: return (NSColor(red: 0.98, green: 0.64, blue: 0.24, alpha: 1), NSColor(red: 0.54, green: 0.23, blue: 0.72, alpha: 1))
    case .violet: return (NSColor(red: 0.43, green: 0.25, blue: 0.79, alpha: 1), NSColor(red: 0.13, green: 0.14, blue: 0.32, alpha: 1))
    case .ocean: return (NSColor(red: 0.04, green: 0.48, blue: 0.64, alpha: 1), NSColor(red: 0.05, green: 0.18, blue: 0.34, alpha: 1))
    case .forest: return (NSColor(red: 0.12, green: 0.48, blue: 0.32, alpha: 1), NSColor(red: 0.05, green: 0.22, blue: 0.18, alpha: 1))
    case .rose: return (NSColor(red: 0.82, green: 0.25, blue: 0.43, alpha: 1), NSColor(red: 0.33, green: 0.13, blue: 0.29, alpha: 1))
    case .midnight: return (NSColor(red: 0.06, green: 0.09, blue: 0.20, alpha: 1), NSColor(red: 0.22, green: 0.27, blue: 0.48, alpha: 1))
    }
}

private func drawCustomThumbnailTextMac(title: String, subtitle: String, symbolName: String, in rect: NSRect) {
    if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
        let configured = symbol.withSymbolConfiguration(.init(pointSize: 88, weight: .semibold)) ?? symbol
        configured.draw(in: NSRect(x: 82, y: rect.height - 190, width: 112, height: 112), from: .zero, operation: .sourceOver, fraction: 0.95)
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineBreakMode = .byWordWrapping
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = CGSize(width: 0, height: -3)
    shadow.shadowBlurRadius = 12
    let titleText = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Live Session" : title
    let subtitleText = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    (titleText as NSString).draw(in: NSRect(x: 82, y: rect.height - 466, width: rect.width - 164, height: 220), withAttributes: [
        .font: NSFont.systemFont(ofSize: 78, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
        .shadow: shadow
    ])
    if !subtitleText.isEmpty {
        (subtitleText as NSString).draw(in: NSRect(x: 86, y: rect.height - 570, width: rect.width - 172, height: 82), withAttributes: [
            .font: NSFont.systemFont(ofSize: 34, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.88),
            .paragraphStyle: paragraph,
            .shadow: shadow
        ])
    }
}

private func presetGradientColorsMac(_ preset: FaithThumbnailPreset) -> (NSColor, NSColor) {
    switch preset {
    case .prayer: return (NSColor(red: 0.85, green: 0.65, blue: 0.2, alpha: 1), NSColor(red: 0.6, green: 0.4, blue: 0.1, alpha: 1))
    case .bible: return (NSColor(red: 0.2, green: 0.35, blue: 0.7, alpha: 1), NSColor(red: 0.1, green: 0.2, blue: 0.5, alpha: 1))
    case .cross: return (NSColor(red: 0.45, green: 0.25, blue: 0.65, alpha: 1), NSColor(red: 0.3, green: 0.15, blue: 0.5, alpha: 1))
    case .worship: return (NSColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1), NSColor(red: 0.7, green: 0.3, blue: 0.1, alpha: 1))
    case .peace: return (NSColor(red: 0.5, green: 0.75, blue: 0.9, alpha: 1), NSColor(red: 0.3, green: 0.55, blue: 0.75, alpha: 1))
    case .heart: return (NSColor(red: 0.85, green: 0.35, blue: 0.45, alpha: 1), NSColor(red: 0.65, green: 0.2, blue: 0.35, alpha: 1))
    case .community: return (NSColor(red: 0.2, green: 0.6, blue: 0.6, alpha: 1), NSColor(red: 0.1, green: 0.45, blue: 0.5, alpha: 1))
    case .hope: return (NSColor(red: 0.95, green: 0.8, blue: 0.25, alpha: 1), NSColor(red: 0.85, green: 0.6, blue: 0.1, alpha: 1))
    case .devotional: return (NSColor(red: 0.35, green: 0.3, blue: 0.65, alpha: 1), NSColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 1))
    case .faith: return (NSColor(red: 0.6, green: 0.4, blue: 0.75, alpha: 1), NSColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1))
    }
}

private func drawFaithLiveBackgroundMac(_ preset: FaithLiveBackgroundPreset, in rect: NSRect) {
    let colors = faithLiveBackgroundNSColorPair(preset)
    NSGradient(starting: colors.0, ending: colors.1)?.draw(in: rect, angle: 315)
    NSColor.white.withAlphaComponent(0.10).setFill()
    for index in 0..<7 {
        let diameter = rect.width * CGFloat(0.12 + Double(index % 3) * 0.035)
        let x = rect.width * CGFloat(0.08 + Double(index) * 0.145)
        let y = rect.height * CGFloat(index.isMultiple(of: 2) ? 0.18 : 0.72)
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: diameter, height: diameter)).fill()
    }
    if let symbol = NSImage(systemSymbolName: preset.symbolName, accessibilityDescription: nil) {
        let configured = symbol.withSymbolConfiguration(.init(pointSize: 150, weight: .light)) ?? symbol
        configured.draw(in: NSRect(x: rect.maxX - 280, y: rect.maxY - 256, width: 170, height: 170), from: .zero, operation: .sourceOver, fraction: 0.18)
    }
    if preset == .crossSunrise {
        NSColor.white.withAlphaComponent(0.22).setFill()
        NSRect(x: rect.midX - 10, y: rect.maxY - 295, width: 20, height: 190).fill()
        NSRect(x: rect.midX - 70, y: rect.maxY - 225, width: 140, height: 18).fill()
    } else if preset == .stainedGlass {
        NSColor.white.withAlphaComponent(0.16).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 3
        for x in stride(from: rect.minX + 80, through: rect.maxX - 80, by: 120) {
            path.move(to: NSPoint(x: x, y: rect.minY))
            path.line(to: NSPoint(x: x + 70, y: rect.maxY))
        }
        for y in stride(from: rect.minY + 70, through: rect.maxY - 70, by: 100) {
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y + 20))
        }
        path.stroke()
    }
}

private func faithLiveBackgroundNSColorPair(_ preset: FaithLiveBackgroundPreset) -> (NSColor, NSColor) {
    switch preset {
    case .crossSunrise: return (NSColor(red: 0.95, green: 0.55, blue: 0.22, alpha: 1), NSColor(red: 0.20, green: 0.28, blue: 0.58, alpha: 1))
    case .scriptureLight: return (NSColor(red: 0.12, green: 0.42, blue: 0.54, alpha: 1), NSColor(red: 0.08, green: 0.12, blue: 0.27, alpha: 1))
    case .worshipGlow: return (NSColor(red: 0.50, green: 0.24, blue: 0.66, alpha: 1), NSColor(red: 0.12, green: 0.09, blue: 0.24, alpha: 1))
    case .peaceGarden: return (NSColor(red: 0.18, green: 0.54, blue: 0.40, alpha: 1), NSColor(red: 0.06, green: 0.22, blue: 0.23, alpha: 1))
    case .stainedGlass: return (NSColor(red: 0.18, green: 0.24, blue: 0.68, alpha: 1), NSColor(red: 0.67, green: 0.25, blue: 0.45, alpha: 1))
    case .doveSky: return (NSColor(red: 0.34, green: 0.64, blue: 0.86, alpha: 1), NSColor(red: 0.10, green: 0.20, blue: 0.42, alpha: 1))
    case .none, .blur: return (NSColor.black, NSColor.darkGray)
    }
}
#endif

/// Cross-platform device identifier, name, and form factor.
enum PlatformDevice {
    static var identifier: String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #elseif os(macOS)
        let key = "FaithJournal.DeviceIdentifier"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: key)
        return newID
        #else
        return UUID().uuidString
        #endif
    }

    static var name: String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #else
        return "Device"
        #endif
    }

    static var isPadOrMac: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #elseif os(macOS)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - macOS Sheet Sizing

extension View {
    /// Applies appropriate frame for sheet presentation on macOS; no-op on iOS.
    /// Use for form-heavy modals (journal entry, prayer request, mood check-in, profile edit).
    func macOSSheetFrameForm() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 440, maxWidth: 560, minHeight: 520, maxHeight: 720)
        #else
        return self
        #endif
    }

    /// Applies appropriate frame for sheet presentation on macOS; no-op on iOS.
    /// Use for standard content modals (terms, privacy, settings panels).
    func macOSSheetFrameStandard() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 420, maxWidth: 520, minHeight: 480, maxHeight: 680)
        #else
        return self
        #endif
    }

    /// Applies appropriate frame for sheet presentation on macOS; no-op on iOS.
    /// Use for compact modals (auth lock, join by code).
    func macOSSheetFrameCompact() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 380, maxWidth: 480, minHeight: 400, maxHeight: 560)
        #else
        return self
        #endif
    }

    /// Applies full-size frame for sheet presentation on macOS; no-op on iOS.
    /// Use for content-heavy modals (devotional detail, long-form reading).
    func macOSSheetFrameLarge() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 580, maxWidth: 900, minHeight: 600, maxHeight: 900)
        #else
        return self
        #endif
    }
}

/// On macOS, horizontal ScrollViews need visible indicators so the scrollbar appears and users can scroll.
/// On iOS, we keep indicators hidden for a cleaner look.
enum PlatformScroll {
    static var horizontalShowsIndicators: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
}

/// Cross-platform pasteboard access
enum PlatformPasteboard {
    static func setString(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}
