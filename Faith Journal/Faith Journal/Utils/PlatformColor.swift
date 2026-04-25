import SwiftUI
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
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

func platformImageFromData(_ data: Data) -> PlatformImage? {
    #if os(iOS)
    return UIImage(data: data)
    #elseif os(macOS)
    return NSImage(data: data)
    #else
    return nil
    #endif
}

/// Creates a small test image (e.g. for verifying thumbnail upload/save). Purple 100×100.
func platformImageTestThumbnail() -> PlatformImage? {
    #if os(iOS)
    let size = CGSize(width: 100, height: 100)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        UIColor.systemPurple.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white, .font: UIFont.boldSystemFont(ofSize: 14)]
        ("Test" as NSString).draw(at: CGPoint(x: 30, y: 42), withAttributes: attrs)
    }
    #elseif os(macOS)
    let size = NSSize(width: 100, height: 100)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.systemPurple.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
    ("Test" as NSString).draw(at: NSPoint(x: 30, y: 42), withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.boldSystemFont(ofSize: 14)])
    image.unlockFocus()
    return image
    #else
    return nil
    #endif
}

func platformImage(_ image: PlatformImage) -> Image {
    #if os(iOS)
    return Image(uiImage: image)
    #elseif os(macOS)
    return Image(nsImage: image)
    #else
    return Image(systemName: "photo")
    #endif
}

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
    func macOSSheetFrameForm() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 440, maxWidth: 560, minHeight: 520, maxHeight: 720)
        #else
        return self
        #endif
    }
    func macOSSheetFrameStandard() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 420, maxWidth: 520, minHeight: 480, maxHeight: 680)
        #else
        return self
        #endif
    }
    func macOSSheetFrameCompact() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 380, maxWidth: 480, minHeight: 400, maxHeight: 560)
        #else
        return self
        #endif
    }
    func macOSSheetFrameLarge() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 580, maxWidth: 900, minHeight: 600, maxHeight: 900)
        #else
        return self
        #endif
    }
}

/// On macOS, horizontal ScrollViews need visible indicators so the scrollbar appears and users can scroll.
enum PlatformScroll {
    static var horizontalShowsIndicators: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
}

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

