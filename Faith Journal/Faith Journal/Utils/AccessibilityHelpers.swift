//
//  AccessibilityHelpers.swift
//  Faith Journal
//
//  Accessibility helpers for VoiceOver and Dynamic Type
//

import SwiftUI

@available(iOS 17.0, *)
struct AccessibilityHelpers {
    /// Configure accessibility label and hint for VoiceOver
    static func accessibilityLabel(_ label: String, hint: String? = nil) -> some ViewModifier {
        AccessibilityModifier(label: label, hint: hint)
    }
    
    /// Dynamic Type scaled font
    static func scaledFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default).weight(weight)
    }
    
    /// Minimum touch target size (44x44 points)
    static let minTouchTarget: CGFloat = 44.0
}

struct AccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

extension View {
    /// Add accessibility support with label and optional hint
    @available(iOS 17.0, *)
    func accessibility(_ label: String, hint: String? = nil) -> some View {
        self.modifier(AccessibilityModifier(label: label, hint: hint))
    }
    
    /// Ensure minimum touch target size for accessibility
    func minTouchTarget() -> some View {
        self.frame(minWidth: AccessibilityHelpers.minTouchTarget, 
                  minHeight: AccessibilityHelpers.minTouchTarget)
    }
}
