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

#if os(iOS)
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
#elseif os(macOS)
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

