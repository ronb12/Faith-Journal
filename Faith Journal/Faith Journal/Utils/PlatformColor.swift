import SwiftUI

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
}

